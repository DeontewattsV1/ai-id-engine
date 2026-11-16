// SPDX-License-Identifier: MIT
//! Signed pre-silicon evidence report (`aiid evidence`), schema
//! `aiid-evidence/v1`.
//!
//! A report is a body of named fields plus a platform attestation over the
//! body's hash:
//!
//! * every field carries a class: `identity` (identifies what was assessed or
//!   who produced the report: model/netlist digests, HWID, provenance),
//!   `behavior` (a measured outcome: |t| peaks, verdict, area, latency) or
//!   `neither` (the conditions of the measurement: TVLA parameters, stimulus
//!   set, measurement envelope, tool versions);
//! * `provenance` is mandatory. It records what signed the report, taken from
//!   TPM2_GetCapability before signing: `hardware` for a physical TPM,
//!   `software` for swtpm/mssim or the software-fallback key. A report without
//!   it, or whose provenance disagrees with its attestation, fails
//!   validation;
//! * the model digest, the stimulus set and the TVLA parameters are bound by
//!   being in the body;
//! * the measurement envelope says what the numbers are evidence *of*
//!   (simulated gate-level traces on a stated corner and power model), so a
//!   reader cannot mistake them for silicon measurements.
//!
//! Signing reuses [`crate::attest::attest`] with
//! `nonce = SHA-256("AIID-EVIDENCE-V1" || canonical body)`. The canonical
//! body is the compact serde_json serialisation of [`Body`] (fields in the
//! order written). The report is evidence about a simulated design; it is
//! not a certification, and it is only as hardware-rooted as its provenance
//! says.

use crate::attest::{self, Attestation};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

pub const SCHEMA: &str = "aiid-evidence/v1";
const DOMAIN: &[u8] = b"AIID-EVIDENCE-V1";
pub const CLASSES: [&str; 3] = ["identity", "behavior", "neither"];
/// Fields every report must carry (name, class).
pub const REQUIRED: [(&str, &str); 7] = [
    ("provenance", "identity"),
    ("hwid", "identity"),
    ("model_digest", "identity"),
    ("stimulus_set", "neither"),
    ("tvla_parameters", "neither"),
    ("measurement_envelope", "neither"),
    ("tvla_result", "behavior"),
];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Field {
    pub name: String,
    pub class: String,
    pub value: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Body {
    pub schema: String,
    pub created: String,
    pub fields: Vec<Field>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Report {
    pub body: Body,
    /// hex SHA-256 of the canonical body (informational; verify recomputes it)
    pub body_sha256: String,
    pub attestation: Attestation,
}

/// The value `provenance` must have for a given attestation.
pub fn provenance_value(kind: &str, manufacturer: &str, simulated: bool) -> Value {
    let class = if kind == "tpm2-quote" && !simulated {
        "hardware"
    } else {
        "software"
    };
    let source = if kind == "tpm2-quote" {
        "TPM2_GetCapability(TPM_PT_MANUFACTURER, TPM_PT_VENDOR_STRING_1)"
    } else {
        "none: no TPM, software-fallback key file"
    };
    serde_json::json!({
        "source": source,
        "attestation_kind": kind,
        "tpm_manufacturer": manufacturer,
        "simulated_tpm": simulated,
        "root": class,
    })
}

pub fn canonical(body: &Body) -> Result<Vec<u8>, String> {
    serde_json::to_vec(body).map_err(|e| e.to_string())
}

pub fn nonce(body: &Body) -> Result<[u8; 32], String> {
    let mut h = Sha256::new();
    h.update(DOMAIN);
    h.update(canonical(body)?);
    Ok(h.finalize().into())
}

fn field<'a>(body: &'a Body, name: &str) -> Option<&'a Field> {
    body.fields.iter().find(|f| f.name == name)
}

/// Schema check (no signature check): schema id, class tags, required
/// fields with their classes, no duplicates, and a well-formed provenance.
pub fn validate(body: &Body) -> Result<(), String> {
    if body.schema != SCHEMA {
        return Err(format!("schema {:?}, expected {SCHEMA}", body.schema));
    }
    let mut seen = std::collections::BTreeSet::new();
    for f in &body.fields {
        if !CLASSES.contains(&f.class.as_str()) {
            return Err(format!(
                "field {:?} has class {:?}; must be identity, behavior or neither",
                f.name, f.class
            ));
        }
        if !seen.insert(f.name.as_str()) {
            return Err(format!("duplicate field {:?}", f.name));
        }
    }
    for (name, class) in REQUIRED {
        match field(body, name) {
            None => return Err(format!("missing required field {name:?}")),
            Some(f) if f.class != class => {
                return Err(format!(
                    "field {name:?} must be class {class}, is {}",
                    f.class
                ))
            }
            Some(f) if f.value.is_null() => return Err(format!("field {name:?} is null")),
            _ => {}
        }
    }
    let p = &field(body, "provenance").unwrap().value;
    match p.get("root").and_then(Value::as_str) {
        Some("hardware") | Some("software") => Ok(()),
        _ => Err("provenance.root must be \"hardware\" or \"software\"".into()),
    }
}

/// Inputs for [`create`]: every entry becomes one field.
pub struct Inputs {
    pub hwid: String,
    pub model_digest: Value,
    pub stimulus_set: Value,
    pub tvla_parameters: Value,
    pub measurement_envelope: Value,
    pub tvla_result: Value,
    pub extra: Vec<Field>,
}

fn f(name: &str, class: &str, value: Value) -> Field {
    Field {
        name: name.into(),
        class: class.into(),
        value,
    }
}

fn file_digests(list: Option<&Value>, what: &str) -> Result<Value, String> {
    let list = list
        .and_then(Value::as_array)
        .ok_or(format!("inputs: {what} must be a list of paths"))?;
    if list.is_empty() {
        return Err(format!("inputs: {what} is empty"));
    }
    let mut m = serde_json::Map::new();
    for p in list {
        let p = p
            .as_str()
            .ok_or(format!("inputs: {what} entries must be strings"))?;
        let b = std::fs::read(p).map_err(|e| format!("{p}: {e}"))?;
        m.insert(p.into(), Value::String(hex::encode(Sha256::digest(&b))));
    }
    Ok(Value::Object(m))
}

/// Maps `test/gate.py`'s summary.json and an inputs file
/// (`{"model_files": [..], "stimulus_files": [..], "stimulus": {..},
/// "measurement_envelope": {..}}`, written by `tools/evidence_inputs.py`)
/// onto the report fields. Files are hashed here, at report time.
pub fn from_tvla(sum: &Value, inp: &Value, hwid: &str) -> Result<Inputs, String> {
    let g = |k: &str| {
        sum.get(k)
            .cloned()
            .ok_or(format!("tvla summary: missing {k:?}"))
    };
    let env = inp
        .get("measurement_envelope")
        .filter(|v| v.is_object())
        .cloned()
        .ok_or("inputs: measurement_envelope must be an object")?;
    let t1 = g("first_order")?;
    let t2 = g("second_order")?;
    Ok(Inputs {
        hwid: hwid.into(),
        model_digest: file_digests(inp.get("model_files"), "model_files")?,
        stimulus_set: serde_json::json!({
            "files": file_digests(inp.get("stimulus_files"), "stimulus_files")?,
            "description": inp.get("stimulus").cloned().unwrap_or(Value::Null),
        }),
        tvla_parameters: serde_json::json!({
            "profile": g("profile")?,
            "masked_dut": g("masked_dut")?,
            "traces_per_group": g("traces_per_group")?,
            "samples": g("samples")?,
            "alpha": g("alpha")?,
            "crit_first_order": t1["crit"],
            "crit_second_order": t2["crit"],
            "second_order_tests": t2["tests"],
        }),
        measurement_envelope: env,
        tvla_result: serde_json::json!({
            "null_control": g("null_control")?,
            "positive_control_plain": g("positive_control_plain")?,
            "first_order_peak": t1["peak"],
            "first_order_idx": t1["idx"],
            "second_order_peak": t2["peak"],
            "second_order_univariate": t2["univariate"],
            "second_order_bivariate": t2["bivariate"],
            "mde_sigma": g("mde_sigma")?,
            "verdict": g("verdict")?,
            "exit": g("exit")?,
        }),
        extra: vec![
            f("area", "behavior", g("area")?),
            f("latency_cycles", "behavior", g("latency_cycles")?),
            f(
                "tvla_summary_sha256",
                "neither",
                Value::String(hex::encode(Sha256::digest(
                    serde_json::to_vec(sum).map_err(|e| e.to_string())?,
                ))),
            ),
        ],
    })
}

/// Builds the body (with the provenance probed now), signs its hash with
/// `attest(mode)` and checks that the attestation matches the provenance.
pub fn create(inp: Inputs, mode: &str, now: u64) -> Result<Report, String> {
    let (kind, manu, sim) = attest::probe_provenance(mode)?;
    let mut fields = vec![
        f(
            "provenance",
            "identity",
            provenance_value(&kind, &manu, sim),
        ),
        f("hwid", "identity", Value::String(inp.hwid.clone())),
        f("model_digest", "identity", inp.model_digest),
        f("stimulus_set", "neither", inp.stimulus_set),
        f("tvla_parameters", "neither", inp.tvla_parameters),
        f("measurement_envelope", "neither", inp.measurement_envelope),
        f("tvla_result", "behavior", inp.tvla_result),
    ];
    fields.extend(inp.extra);
    let body = Body {
        schema: SCHEMA.into(),
        created: crate::rfc3339(now),
        fields,
    };
    validate(&body)?;
    let n = nonce(&body)?;
    let a = attest::attest(&n, &inp.hwid, mode)?;
    let r = Report {
        body_sha256: hex::encode(Sha256::digest(canonical(&body)?)),
        body,
        attestation: a,
    };
    check_provenance(&r)?;
    Ok(r)
}

fn check_provenance(r: &Report) -> Result<(), String> {
    let a = &r.attestation;
    let (manu, sim) = match &a.tpm {
        Some(t) => (t.manufacturer.as_str(), t.simulated),
        None => ("", false),
    };
    let want = provenance_value(&a.kind, manu, sim);
    let got = &field(&r.body, "provenance")
        .ok_or("missing provenance")?
        .value;
    if *got != want {
        return Err(format!(
            "provenance in the body ({got}) does not match the attestation ({want})"
        ));
    }
    if want["root"] == "software" && a.hardware_backed {
        return Err("attestation claims hardware backing for a software root".into());
    }
    Ok(())
}

/// Full check: schema, body hash bound into the attestation, attestation
/// signature, and provenance agreement. Returns a one-line description.
pub fn verify(r: &Report, pinned_soft_key: Option<&str>) -> Result<String, String> {
    validate(&r.body)?;
    let canon = canonical(&r.body)?;
    if !r
        .body_sha256
        .eq_ignore_ascii_case(&hex::encode(Sha256::digest(&canon)))
    {
        return Err("body_sha256 does not match the body".into());
    }
    let hwid = field(&r.body, "hwid")
        .and_then(|f| f.value.as_str())
        .ok_or("hwid must be a string")?;
    let desc = attest::verify(&r.attestation, &nonce(&r.body)?, hwid, pinned_soft_key)?;
    check_provenance(r)?;
    let root = field(&r.body, "provenance").unwrap().value["root"].clone();
    Ok(format!(
        "evidence report valid; provenance root {root}; {desc}"
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn inputs() -> Inputs {
        Inputs {
            hwid: "ab".repeat(32),
            model_digest: json!({"build/tvla_masked3.v": "00".repeat(32)}),
            stimulus_set: json!({"seeds": [11, 13, 17]}),
            tvla_parameters: json!({"traces_per_group": 4000, "samples": 4000, "alpha": 0.05}),
            measurement_envelope: json!({"kind": "simulated gate-level traces"}),
            tvla_result: json!({"first_order": 4.22, "exit": 0}),
            extra: vec![],
        }
    }

    fn with_home<T>(tag: &str, f: impl FnOnce() -> T) -> T {
        let _g = crate::TEST_ENV.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("aiid-ev-{tag}-{}", std::process::id()));
        std::env::set_var("AIID_HOME", &dir);
        let r = f();
        let _ = std::fs::remove_dir_all(dir);
        r
    }

    #[test]
    fn software_report_round_trip_and_tamper() {
        with_home("rt", || {
            let r = create(inputs(), "software", 1_763_270_000).unwrap();
            assert_eq!(r.body.fields[0].value["root"], "software");
            assert!(verify(&r, None).unwrap().contains("software"));

            // a behavior number changed after signing
            let mut t = r.clone();
            t.body.fields[6].value = json!({"first_order": 1.0, "exit": 0});
            t.body_sha256 = hex::encode(Sha256::digest(canonical(&t.body).unwrap()));
            assert!(verify(&t, None).is_err());

            // provenance upgraded to "hardware" after signing
            let mut t = r.clone();
            t.body.fields[0].value["root"] = json!("hardware");
            t.body_sha256 = hex::encode(Sha256::digest(canonical(&t.body).unwrap()));
            assert!(verify(&t, None).is_err());

            // wrong pinned key
            assert!(verify(&r, Some(&"00".repeat(32))).is_err());
        });
    }

    #[test]
    fn schema_rejects_missing_provenance_and_bad_classes() {
        with_home("schema", || {
            let r = create(inputs(), "software", 0).unwrap();
            let mut b = r.body.clone();
            b.fields.retain(|f| f.name != "provenance");
            assert!(validate(&b).unwrap_err().contains("provenance"));

            let mut b = r.body.clone();
            b.fields[3].class = "behaviour".into();
            assert!(validate(&b).is_err());

            let mut b = r.body.clone();
            b.fields[6].class = "neither".into(); // tvla_result must be behavior
            assert!(validate(&b).is_err());

            let mut b = r.body.clone();
            b.fields.push(b.fields[1].clone());
            assert!(validate(&b).unwrap_err().contains("duplicate"));

            let mut b = r.body.clone();
            b.fields[0].value["root"] = json!("certified");
            assert!(validate(&b).is_err());
        });
    }

    #[test]
    fn swtpm_is_software_root() {
        assert_eq!(
            provenance_value("tpm2-quote", "IBM", true)["root"],
            "software"
        );
        assert_eq!(
            provenance_value("tpm2-quote", "IFX", false)["root"],
            "hardware"
        );
        assert_eq!(
            provenance_value("software-fallback", "", false)["root"],
            "software"
        );
    }
}
