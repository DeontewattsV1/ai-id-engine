// SPDX-License-Identifier: MIT
//! AI Birth Certificate.
//!
//! An in-toto Statement v1 (subjects = weight files with SHA-256 digests,
//! predicate = model / deployment / environment / hardware identity) wrapped
//! in a DSSE envelope signed with ECDSA P-256 by an issuer key that chains to
//! the vendor CA. Optionally embeds an AIQ2 quote from the hardware identity
//! engine (RTL) that measured the same weights.

use crate::attest::{self, Attestation};
use ai_id_verifier::{verify_chain, verify_hw, Cert, HwPolicy, HwQuote, Policy};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use p256::ecdsa::signature::{Signer, Verifier};
use p256::ecdsa::{Signature, SigningKey};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::io::Read;
use std::path::{Path, PathBuf};

pub const PAYLOAD_TYPE: &str = "application/vnd.in-toto+json";
pub const STATEMENT_TYPE: &str = "https://in-toto.io/Statement/v1";
pub const PREDICATE_TYPE: &str =
    "https://github.com/DeontewattsV1/ai-id-engine/ai-birth-certificate/v0.1";
const WEIGHT_EXT: &[&str] = &[
    "safetensors",
    "bin",
    "pt",
    "pth",
    "ckpt",
    "gguf",
    "ggml",
    "onnx",
    "h5",
    "msgpack",
    "npz",
    "tflite",
    "mlmodel",
    "pb",
];

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DsseSig {
    pub keyid: String,
    pub sig: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Envelope {
    #[serde(rename = "payloadType")]
    pub payload_type: String,
    pub payload: String,
    pub signatures: Vec<DsseSig>,
    /// Issuer certificate chain (root first), verifier `Cert` format.
    pub cert_chain: Vec<Cert>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WeightFile {
    pub name: String,
    pub size: u64,
    pub sha256: String,
}

/// DSSE pre-authentication encoding.
pub fn pae(payload_type: &str, body: &[u8]) -> Vec<u8> {
    let mut v = format!(
        "DSSEv1 {} {} {} ",
        payload_type.len(),
        payload_type,
        body.len()
    )
    .into_bytes();
    v.extend_from_slice(body);
    v
}

/// Streaming SHA-256 of a file (1 MiB buffer).
pub fn hash_file(p: &Path) -> Result<(String, u64), String> {
    let mut f = std::fs::File::open(p).map_err(|e| format!("{}: {e}", p.display()))?;
    let mut h = Sha256::new();
    let mut buf = vec![0u8; 1 << 20];
    let mut n = 0u64;
    loop {
        let k = f
            .read(&mut buf)
            .map_err(|e| format!("{}: {e}", p.display()))?;
        if k == 0 {
            break;
        }
        h.update(&buf[..k]);
        n += k as u64;
    }
    Ok((hex::encode(h.finalize()), n))
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> Result<(), String> {
    let mut entries: Vec<_> = std::fs::read_dir(dir)
        .map_err(|e| format!("{}: {e}", dir.display()))?
        .flatten()
        .map(|e| e.path())
        .collect();
    entries.sort();
    for p in entries {
        let name = p
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        if name.starts_with('.') {
            continue;
        }
        if p.is_dir() {
            walk(&p, out)?;
        } else if p.is_file() {
            out.push(p);
        }
    }
    Ok(())
}

/// Hashes the model weights. A directory contributes its weight files
/// (by extension; all files if none match). `weights_sha256` is the file
/// digest for a single weight file, else SHA-256 of the sorted
/// `"<sha256>  <relative path>\n"` manifest.
pub fn hash_weights(path: &Path) -> Result<(Vec<WeightFile>, String, u64), String> {
    let mut files = Vec::new();
    let base = if path.is_dir() {
        path.to_path_buf()
    } else {
        path.parent().map(Path::to_path_buf).unwrap_or_default()
    };
    if path.is_dir() {
        let mut all = Vec::new();
        walk(path, &mut all)?;
        let w: Vec<PathBuf> = all
            .iter()
            .filter(|p| {
                p.extension()
                    .map(|e| WEIGHT_EXT.contains(&e.to_string_lossy().to_lowercase().as_str()))
                    .unwrap_or(false)
            })
            .cloned()
            .collect();
        files = if w.is_empty() { all } else { w };
    } else if path.is_file() {
        files.push(path.to_path_buf());
    } else {
        return Err(format!("{}: not a file or directory", path.display()));
    }
    if files.is_empty() {
        return Err(format!("{}: no files to measure", path.display()));
    }
    let mut out = Vec::new();
    let mut total = 0;
    for f in &files {
        let (h, n) = hash_file(f)?;
        let rel = f
            .strip_prefix(&base)
            .unwrap_or(f)
            .to_string_lossy()
            .replace('\\', "/");
        total += n;
        out.push(WeightFile {
            name: rel,
            size: n,
            sha256: h,
        });
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    let agg = if out.len() == 1 {
        out[0].sha256.clone()
    } else {
        let manifest: String = out
            .iter()
            .map(|w| format!("{}  {}\n", w.sha256, w.name))
            .collect();
        hex::encode(Sha256::digest(manifest.as_bytes()))
    };
    Ok((out, agg, total))
}

/// Reads architecture hints from a Hugging Face style config.json.
pub fn model_config(path: &Path) -> (Option<String>, Value) {
    let dir = if path.is_dir() {
        path.to_path_buf()
    } else {
        path.parent().map(Path::to_path_buf).unwrap_or_default()
    };
    let p = dir.join("config.json");
    let Ok(s) = std::fs::read_to_string(&p) else {
        return (None, Value::Null);
    };
    let Ok(v) = serde_json::from_str::<Value>(&s) else {
        return (None, Value::Null);
    };
    let mut summary = serde_json::Map::new();
    for k in [
        "architectures",
        "model_type",
        "hidden_size",
        "num_hidden_layers",
        "num_attention_heads",
        "intermediate_size",
        "vocab_size",
        "max_position_embeddings",
        "torch_dtype",
    ] {
        if let Some(x) = v.get(k) {
            summary.insert(k.into(), x.clone());
        }
    }
    summary.insert(
        "config_sha256".into(),
        Value::String(hex::encode(Sha256::digest(s.as_bytes()))),
    );
    let arch = v
        .get("architectures")
        .and_then(|a| a.get(0))
        .and_then(|a| a.as_str())
        .map(String::from)
        .or_else(|| {
            v.get("model_type")
                .and_then(|m| m.as_str())
                .map(String::from)
        })
        .or_else(|| {
            let h = v.get("hidden_size")?;
            let l = v.get("num_hidden_layers")?;
            let a = v.get("num_attention_heads")?;
            Some(format!("transformer (hidden {h}, {l} layers, {a} heads)"))
        });
    (arch, Value::Object(summary))
}

pub fn binding_nonce(weights_sha256: &str, instance_id: &str, issued_at: u64) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(b"AIBC-BIND-V1");
    h.update(weights_sha256.as_bytes());
    h.update(instance_id.as_bytes());
    h.update(issued_at.to_be_bytes());
    h.finalize().into()
}

fn default_instance_id(hwid: &str) -> String {
    let boot = std::fs::read_to_string("/proc/sys/kernel/random/boot_id").unwrap_or_default();
    let mut r = [0u8; 8];
    rand_core::RngCore::fill_bytes(&mut rand_core::OsRng, &mut r);
    let mut h = Sha256::new();
    h.update(hwid.as_bytes());
    h.update(boot.trim().as_bytes());
    h.update(r);
    format!("inst-{}", &hex::encode(h.finalize())[..20])
}

pub struct CreateOpts {
    pub weights: PathBuf,
    pub name: Option<String>,
    pub arch: Option<String>,
    pub checkpoint: Option<String>,
    pub instance_id: Option<String>,
    pub container_digest: Option<String>,
    pub issuer_key: SigningKey,
    pub issuer_chain: Vec<Cert>,
    pub issuer_name: String,
    pub validity_days: u64,
    pub attest_mode: String,
    pub hwid_salt: String,
    pub engine_quote: Option<(HwQuote, Vec<Cert>)>,
    pub now: u64,
}

pub fn keyid(k: &p256::ecdsa::VerifyingKey) -> String {
    hex::encode(&Sha256::digest(k.to_encoded_point(true).as_bytes())[..16])
}

/// Creates and signs a birth certificate.
pub fn create(o: CreateOpts) -> Result<Envelope, String> {
    let (files, weights_sha, total) = hash_weights(&o.weights)?;
    let (cfg_arch, cfg) = model_config(&o.weights);
    let hw = crate::hwid::this_machine(&o.hwid_salt, false)?;
    let instance = o
        .instance_id
        .unwrap_or_else(|| default_instance_id(&hw.hwid));
    let env = crate::envinfo::collect(o.container_digest);
    let nonce = binding_nonce(&weights_sha, &instance, o.now);
    let att: Attestation = attest::attest(&nonce, &hw.hwid, &o.attest_mode)?;
    // default name: the model directory (for a single file, its parent dir)
    let name = o.name.unwrap_or_else(|| {
        let p = if o.weights.is_file() {
            o.weights
                .canonicalize()
                .ok()
                .and_then(|p| p.parent().map(Path::to_path_buf))
        } else {
            o.weights.canonicalize().ok()
        };
        p.and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| "model".into())
    });
    let cert_id = format!(
        "AIBC-{}",
        crate::code::b32(
            &Sha256::digest(format!("{weights_sha}{instance}{}", o.now).as_bytes())[..10]
        )
    );
    let issuer_vk = *o.issuer_key.verifying_key();
    let mut predicate = json!({
        "certificate_id": cert_id,
        "issued_at": crate::rfc3339(o.now),
        "issued_at_unix": o.now,
        "expires_at": crate::rfc3339(o.now + o.validity_days * 86_400),
        "expires_at_unix": o.now + o.validity_days * 86_400,
        "issuer": { "name": o.issuer_name, "key_id": keyid(&issuer_vk), "test_only_ca": true },
        "model": {
            "name": name,
            "architecture": o.arch.or(cfg_arch).unwrap_or_else(|| "unspecified".into()),
            "checkpoint_version": o.checkpoint.unwrap_or_else(|| "unspecified".into()),
            "weights_sha256": weights_sha,
            "weights_total_bytes": total,
            "weights_files": files,
            "config": cfg,
        },
        "deployment": { "instance_id": instance },
        "environment": env,
        "hardware": {
            "hwid": hw.hwid,
            "hwid_short": hw.short,
            "hwid_salt_id": hw.salt_id,
            "hwid_components": hw.components.iter().map(|c| c.name.clone()).collect::<Vec<_>>(),
            "attestation": att,
        },
        "signatures_note": "DSSE envelope: ECDSA P-256 over PAE(payloadType, payload); issuer chain in cert_chain",
    });
    if let Some((q, chain)) = o.engine_quote {
        predicate["engine_quote"] = json!({ "quote": q, "chain": chain });
    }
    let statement = json!({
        "_type": STATEMENT_TYPE,
        "subject": files_subjects(&predicate),
        "predicateType": PREDICATE_TYPE,
        "predicate": predicate,
    });
    let body = serde_json::to_vec(&statement).map_err(|e| e.to_string())?;
    let sig: Signature = o.issuer_key.sign(&pae(PAYLOAD_TYPE, &body));
    Ok(Envelope {
        payload_type: PAYLOAD_TYPE.into(),
        payload: B64.encode(&body),
        signatures: vec![DsseSig {
            keyid: keyid(&issuer_vk),
            sig: B64.encode(sig.to_bytes()),
        }],
        cert_chain: o.issuer_chain,
    })
}

fn files_subjects(pred: &Value) -> Value {
    let files = pred["model"]["weights_files"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    Value::Array(
        files
            .iter()
            .map(|f| json!({ "name": f["name"], "digest": { "sha256": f["sha256"] } }))
            .collect(),
    )
}

pub fn statement(env: &Envelope) -> Result<Value, String> {
    let body = B64
        .decode(&env.payload)
        .map_err(|e| format!("payload: {e}"))?;
    serde_json::from_slice(&body).map_err(|e| format!("payload: {e}"))
}

pub struct VerifyOpts {
    pub trusted_root: String,
    pub weights: Option<PathBuf>,
    pub now: u64,
    pub max_age_secs: Option<u64>,
    pub check_this_machine: Option<String>, // HWID salt
    pub require_hardware_attestation: bool,
}

pub struct Check {
    pub name: String,
    pub ok: bool,
    pub detail: String,
}

fn ck(out: &mut Vec<Check>, name: &str, r: Result<String, String>) {
    match r {
        Ok(d) => out.push(Check {
            name: name.into(),
            ok: true,
            detail: d,
        }),
        Err(d) => out.push(Check {
            name: name.into(),
            ok: false,
            detail: d,
        }),
    }
}

/// Verifies a certificate; returns every check (all must pass).
pub fn verify(env: &Envelope, o: &VerifyOpts) -> Vec<Check> {
    let mut out = Vec::new();
    // 1. signature + chain
    let leaf = (|| {
        if env.payload_type != PAYLOAD_TYPE {
            return Err(format!("payloadType {:?}", env.payload_type));
        }
        let pol = Policy {
            trusted_roots: vec![o.trusted_root.clone()],
            ..Default::default()
        };
        let leaf = verify_chain(&env.cert_chain, &pol).map_err(|e| e.to_string())?;
        let body = B64.decode(&env.payload).map_err(|e| e.to_string())?;
        let s = env.signatures.first().ok_or("no signatures")?;
        let raw = B64.decode(&s.sig).map_err(|e| e.to_string())?;
        let sig = Signature::from_slice(&raw).map_err(|e| e.to_string())?;
        leaf.verify(&pae(&env.payload_type, &body), &sig)
            .map_err(|_| "DSSE signature invalid".to_string())?;
        Ok(leaf)
    })();
    match &leaf {
        Ok(k) => ck(
            &mut out,
            "signature",
            Ok(format!(
                "DSSE ECDSA-P256 valid; issuer {} chains to trusted vendor CA",
                keyid(k)
            )),
        ),
        Err(e) => {
            ck(&mut out, "signature", Err(e.clone()));
            return out;
        }
    }
    let st = match statement(env) {
        Ok(s) => s,
        Err(e) => {
            ck(&mut out, "statement", Err(e));
            return out;
        }
    };
    let p = &st["predicate"];
    ck(
        &mut out,
        "statement",
        if st["_type"] == STATEMENT_TYPE && st["predicateType"] == PREDICATE_TYPE {
            Ok(format!(
                "in-toto Statement v1, {}",
                p["certificate_id"].as_str().unwrap_or("?")
            ))
        } else {
            Err("unexpected _type or predicateType".into())
        },
    );
    // 2. freshness
    let issued = p["issued_at_unix"].as_u64().unwrap_or(u64::MAX);
    let expires = p["expires_at_unix"].as_u64().unwrap_or(0);
    ck(
        &mut out,
        "freshness",
        (|| {
            if issued > o.now + 300 {
                return Err(format!("issued in the future ({})", p["issued_at"]));
            }
            if o.now > expires {
                return Err(format!("expired at {}", p["expires_at"]));
            }
            if let Some(m) = o.max_age_secs {
                if o.now.saturating_sub(issued) > m {
                    return Err(format!("older than --max-age {m}s"));
                }
            }
            Ok(format!(
                "issued {}, valid until {}",
                p["issued_at"].as_str().unwrap_or("?"),
                p["expires_at"].as_str().unwrap_or("?")
            ))
        })(),
    );
    // 3. subjects consistent with predicate
    let wsha = p["model"]["weights_sha256"]
        .as_str()
        .unwrap_or("")
        .to_string();
    let files: Vec<WeightFile> =
        serde_json::from_value(p["model"]["weights_files"].clone()).unwrap_or_default();
    ck(
        &mut out,
        "subjects",
        (|| {
            let subj = st["subject"].as_array().ok_or("no subject")?;
            if subj.len() != files.len() {
                return Err("subject list differs from weights_files".into());
            }
            for (s, f) in subj.iter().zip(&files) {
                if s["name"] != f.name.as_str() || s["digest"]["sha256"] != f.sha256.as_str() {
                    return Err(format!("subject {} differs from weights_files", f.name));
                }
            }
            Ok(format!(
                "{} weight file(s), weights_sha256 {}…",
                files.len(),
                wsha.get(..16).unwrap_or("")
            ))
        })(),
    );
    // 4. re-hash weights
    if let Some(w) = &o.weights {
        ck(
            &mut out,
            "weights",
            (|| {
                let (now_files, agg, _) = hash_weights(w)?;
                if agg != wsha {
                    let diff: Vec<String> = now_files
                        .iter()
                        .filter(|f| !files.contains(f))
                        .map(|f| f.name.clone())
                        .collect();
                    return Err(format!(
                        "weights changed: digest {}… != certified {}… (differs: {:?})",
                        &agg[..16],
                        wsha.get(..16).unwrap_or(""),
                        diff
                    ));
                }
                Ok(format!(
                    "re-hashed {} file(s): SHA-256 matches",
                    now_files.len()
                ))
            })(),
        );
    }
    // 5. environment digest integrity
    ck(
        &mut out,
        "environment",
        (|| {
            let m: BTreeMap<String, Value> =
                serde_json::from_value(p["environment"].clone()).map_err(|e| e.to_string())?;
            let want = m
                .get("digest")
                .and_then(|d| d.as_str())
                .unwrap_or("")
                .to_string();
            let got = crate::envinfo::digest(&m);
            if got != want {
                return Err("environment digest does not match its record".into());
            }
            Ok(format!(
                "{} ({})",
                got,
                m.get("os").and_then(|v| v.as_str()).unwrap_or("?")
            ))
        })(),
    );
    // 6. host attestation bound to this certificate
    let hwid = p["hardware"]["hwid"].as_str().unwrap_or("").to_string();
    ck(
        &mut out,
        "host attestation",
        (|| {
            let a: Attestation = serde_json::from_value(p["hardware"]["attestation"].clone())
                .map_err(|e| e.to_string())?;
            let inst = p["deployment"]["instance_id"].as_str().unwrap_or("");
            let nonce = binding_nonce(&wsha, inst, issued);
            let d = attest::verify(&a, &nonce, &hwid, None)?;
            if o.require_hardware_attestation && !a.hardware_backed {
                return Err(format!("{d}, but hardware-backed attestation is required"));
            }
            Ok(d)
        })(),
    );
    if let Some(salt) = &o.check_this_machine {
        ck(
            &mut out,
            "this machine",
            (|| {
                let me = crate::hwid::this_machine(salt, false)?;
                if me.hwid != hwid {
                    return Err(format!(
                        "certificate HWID {}… is not this machine ({}…)",
                        hwid.get(..16).unwrap_or(""),
                        &me.hwid[..16]
                    ));
                }
                Ok("HWID matches this machine".into())
            })(),
        );
    }
    // 7. hardware identity engine quote
    if !p["engine_quote"].is_null() {
        ck(
            &mut out,
            "engine quote",
            (|| {
                let q: HwQuote = serde_json::from_value(p["engine_quote"]["quote"].clone())
                    .map_err(|e| e.to_string())?;
                let chain: Vec<Cert> = serde_json::from_value(p["engine_quote"]["chain"].clone())
                    .map_err(|e| e.to_string())?;
                // PCR2 is the engine's model-weights PCR: extend(0, weights digest)
                let mut wd = [0u8; 32];
                hex::decode_to_slice(&wsha, &mut wd).map_err(|e| e.to_string())?;
                let mut pcrs = BTreeMap::new();
                pcrs.insert(
                    2u8,
                    hex::encode(ai_id_verifier::pcr_extend(&[0u8; 32], &wd)),
                );
                let pol = HwPolicy {
                    base: Policy {
                        trusted_roots: vec![o.trusted_root.clone()],
                        allowed_models: vec![wsha.clone()],
                        allowed_configs: vec![],
                        pcrs,
                        max_skew_secs: 86_400,
                    },
                    ..Default::default()
                };
                let nonce = hex::decode(&q.nonce).map_err(|e| e.to_string())?;
                verify_hw(&q, &chain, &pol, &nonce, issued).map_err(|e| e.to_string())?;
                Ok(format!("AIQ2 quote from device {}… (rev {}) signed by its secure element; engine measured the same weights (PCR2 checked)", &q.device_id[..16], q.hw_rev))
            })(),
        );
    }
    out
}
