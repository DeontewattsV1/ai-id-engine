// SPDX-License-Identifier: MIT
//! Platform attestation for the host running the model.
//!
//! * TPM 2.0 present (tpm2-tools on PATH, `/dev/tpmrm0` or `TPM2TOOLS_TCTI`):
//!   an ECC Endorsement Key and an ECDSA-P256 Attestation Key are created,
//!   the AK is proven to live in the same TPM as the EK with
//!   MakeCredential/ActivateCredential, and `TPM2_Quote` signs PCRs 0-7
//!   (SHA-256 bank) with qualifying data
//!   `SHA-256("AIID-TPM-V1" || nonce || hwid)`. Verification is native Rust:
//!   TPMS_ATTEST parsing, extraData, PCR digest and the AK signature.
//! * No TPM: a SOFTWARE FALLBACK Ed25519 key kept in a local file signs
//!   `"AIID-SOFT-V1" || nonce || hwid || timestamp`. This is clearly marked
//!   `hardware_backed: false`; it proves possession of a file, nothing more.

use base64::{engine::general_purpose::STANDARD as B64, Engine};
use ed25519_dalek::{Signer, Verifier};
use p256::pkcs8::DecodePublicKey;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::process::Command;

pub const PCR_SELECTION: &str = "sha256:0,1,2,3,4,5,6,7";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TpmEvidence {
    /// EK public area (TPM2B_PUBLIC, base64) as written by tpm2_createek.
    pub ek_public: String,
    pub ak_public_pem: String,
    pub ak_name: String,
    /// "verified" when MakeCredential/ActivateCredential round-tripped.
    pub ak_ek_binding: String,
    /// TPM2_PT_MANUFACTURER as reported by the TPM.
    #[serde(default)]
    pub manufacturer: String,
    /// True for a software TPM (swtpm / mssim simulator).
    #[serde(default)]
    pub simulated: bool,
    pub pcr_selection: String,
    pub pcr_values: Vec<String>,
    /// TPMS_ATTEST (base64) and its ECDSA signature (DER, base64).
    pub quote_attest: String,
    pub quote_sig: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SoftEvidence {
    pub public_key: String,
    pub sig: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Attestation {
    /// "tpm2-quote" or "software-fallback".
    pub kind: String,
    pub hardware_backed: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub warning: Option<String>,
    pub nonce: String,
    pub hwid: String,
    pub timestamp: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tpm: Option<TpmEvidence>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub software: Option<SoftEvidence>,
}

fn qualifying(nonce: &[u8], hwid: &str) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(b"AIID-TPM-V1");
    h.update(nonce);
    h.update(hwid.as_bytes());
    h.finalize().into()
}

fn soft_msg(nonce: &[u8], hwid: &str, ts: u64) -> Vec<u8> {
    let mut m = b"AIID-SOFT-V1".to_vec();
    m.extend_from_slice(nonce);
    m.extend_from_slice(hwid.as_bytes());
    m.extend_from_slice(&ts.to_be_bytes());
    m
}

fn tool(name: &str, args: &[&str], dir: &Path) -> Result<Vec<u8>, String> {
    let out = Command::new(name)
        .args(args)
        .current_dir(dir)
        .output()
        .map_err(|e| format!("{name}: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "{name} failed: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }
    Ok(out.stdout)
}

/// True if a TPM 2.0 is reachable through tpm2-tools.
pub fn tpm_available() -> bool {
    let has_dev = Path::new("/dev/tpmrm0").exists() || Path::new("/dev/tpm0").exists();
    let has_tcti = std::env::var("TPM2TOOLS_TCTI").is_ok();
    if !(has_dev || has_tcti) {
        return false;
    }
    Command::new("tpm2_getcap")
        .arg("properties-fixed")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// (manufacturer, simulated) from `tpm2_getcap properties-fixed`.
fn tpm_vendor(dir: &Path) -> (String, bool) {
    let tcti = std::env::var("TPM2TOOLS_TCTI")
        .unwrap_or_default()
        .to_ascii_lowercase();
    let out = tool("tpm2_getcap", &["properties-fixed"], dir)
        .map(|o| String::from_utf8_lossy(&o).to_string())
        .unwrap_or_default();
    let after = |key: &str| {
        out.split(key)
            .nth(1)
            .and_then(|r| r.lines().find(|l| l.contains("value:")))
            .map(|l| l.split('"').nth(1).unwrap_or("").to_string())
            .unwrap_or_default()
    };
    let manu = after("TPM2_PT_MANUFACTURER:");
    let v1 = after("TPM2_PT_VENDOR_STRING_1:");
    let sim = tcti.contains("swtpm") || tcti.contains("mssim") || (manu == "IBM" && v1 == "SW");
    (manu, sim)
}

/// What a later `attest(.., mode)` call will be backed by, from
/// `tpm2_getcap properties-fixed` (TPM2_GetCapability): `(kind,
/// manufacturer, simulated)`. Used to put the provenance into a report body
/// *before* that body's hash is quoted, so the provenance is covered by the
/// signature. A host that lies to tpm2-tools can still lie here; this is
/// bound by the AK signature, not vouched for by an EK certificate chain.
pub fn probe_provenance(mode: &str) -> Result<(String, String, bool), String> {
    let want_tpm = match mode {
        "software" => false,
        "tpm" => true,
        _ => tpm_available(),
    };
    if !want_tpm {
        return Ok(("software-fallback".into(), String::new(), false));
    }
    let dir = tmpdir()?;
    let (manu, sim) = tpm_vendor(&dir);
    let _ = std::fs::remove_dir_all(&dir);
    Ok(("tpm2-quote".into(), manu, sim))
}

fn flush(dir: &Path) {
    let _ = tool("tpm2_flushcontext", &["-t"], dir);
    let _ = tool("tpm2_flushcontext", &["-s"], dir);
}

fn tmpdir() -> Result<PathBuf, String> {
    let mut r = [0u8; 8];
    rand_core::RngCore::fill_bytes(&mut rand_core::OsRng, &mut r);
    let d = std::env::temp_dir().join(format!("aiid-tpm-{}", hex::encode(r)));
    std::fs::create_dir_all(&d).map_err(|e| e.to_string())?;
    Ok(d)
}

fn ak_ek_binding(dir: &Path) -> String {
    // offline MakeCredential to the EK for the AK name, then ActivateCredential
    let run = || -> Result<(), String> {
        let name = std::fs::read(dir.join("ak.name")).map_err(|e| e.to_string())?;
        let mut secret = [0u8; 16];
        rand_core::RngCore::fill_bytes(&mut rand_core::OsRng, &mut secret);
        std::fs::write(dir.join("secret.bin"), secret).map_err(|e| e.to_string())?;
        let name_hex = hex::encode(name);
        tool(
            "tpm2_makecredential",
            &[
                "-T",
                "none",
                "-u",
                "ek.pub",
                "-s",
                "secret.bin",
                "-n",
                &name_hex,
                "-o",
                "cred.out",
            ],
            dir,
        )?;
        tool(
            "tpm2_startauthsession",
            &["--policy-session", "-S", "session.ctx"],
            dir,
        )?;
        tool("tpm2_policysecret", &["-S", "session.ctx", "-c", "e"], dir)?;
        flush_transient(dir);
        let r = tool(
            "tpm2_activatecredential",
            &[
                "-c",
                "ak.ctx",
                "-C",
                "ek.ctx",
                "-i",
                "cred.out",
                "-o",
                "act.out",
                "-P",
                "session:session.ctx",
            ],
            dir,
        );
        let _ = tool("tpm2_flushcontext", &["session.ctx"], dir);
        flush(dir);
        r?;
        let got = std::fs::read(dir.join("act.out")).map_err(|e| e.to_string())?;
        if got != secret {
            return Err("activated secret differs".into());
        }
        Ok(())
    };
    match run() {
        Ok(()) => "verified (MakeCredential/ActivateCredential)".into(),
        Err(e) => format!("not verified: {e}"),
    }
}

fn flush_transient(dir: &Path) {
    let _ = tool("tpm2_flushcontext", &["-t"], dir);
}

fn tpm_attest(nonce: &[u8], hwid: &str) -> Result<TpmEvidence, String> {
    let dir = tmpdir()?;
    let d = dir.as_path();
    let res = (|| {
        flush(d);
        tool(
            "tpm2_createek",
            &["-c", "ek.ctx", "-G", "ecc", "-u", "ek.pub"],
            d,
        )?;
        flush(d);
        tool(
            "tpm2_createak",
            &[
                "-C", "ek.ctx", "-c", "ak.ctx", "-G", "ecc", "-g", "sha256", "-s", "ecdsa", "-u",
                "ak.pem", "-f", "pem", "-n", "ak.name",
            ],
            d,
        )?;
        flush(d);
        let binding = ak_ek_binding(d);
        let (manufacturer, simulated) = tpm_vendor(d);
        let q = hex::encode(qualifying(nonce, hwid));
        tool(
            "tpm2_quote",
            &[
                "-c",
                "ak.ctx",
                "-l",
                PCR_SELECTION,
                "-q",
                &q,
                "-m",
                "quote.msg",
                "-s",
                "quote.sig",
                "-o",
                "quote.pcrs",
                "-g",
                "sha256",
                "-f",
                "plain",
            ],
            d,
        )?;
        flush(d);
        tool("tpm2_pcrread", &[PCR_SELECTION, "-o", "pcrs.bin"], d)?;
        let rd = |f: &str| std::fs::read(d.join(f)).map_err(|e| format!("{f}: {e}"));
        let pcrs = rd("pcrs.bin")?;
        Ok(TpmEvidence {
            ek_public: B64.encode(rd("ek.pub")?),
            ak_public_pem: String::from_utf8_lossy(&rd("ak.pem")?).to_string(),
            ak_name: hex::encode(rd("ak.name")?),
            ak_ek_binding: binding,
            manufacturer,
            simulated,
            pcr_selection: PCR_SELECTION.into(),
            pcr_values: pcrs.chunks(32).map(hex::encode).collect(),
            quote_attest: B64.encode(rd("quote.msg")?),
            quote_sig: B64.encode(rd("quote.sig")?),
        })
    })();
    let _ = std::fs::remove_dir_all(&dir);
    res
}

/// Location of the software-fallback key.
pub fn soft_key_path() -> PathBuf {
    if let Ok(p) = std::env::var("AIID_HOME") {
        return PathBuf::from(p).join("soft-attest.key");
    }
    let base = std::env::var("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|_| std::env::var("HOME").map(|h| PathBuf::from(h).join(".local/share")))
        .or_else(|_| std::env::var("LOCALAPPDATA").map(PathBuf::from))
        .unwrap_or_else(|_| std::env::temp_dir());
    base.join("aiid").join("soft-attest.key")
}

fn read_soft_key(p: &std::path::Path) -> Result<Option<ed25519_dalek::SigningKey>, String> {
    let s = match std::fs::read_to_string(p) {
        Ok(s) => s,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(format!("{}: {e}", p.display())),
    };
    let b = hex::decode(s.trim()).map_err(|e| format!("{}: {e}", p.display()))?;
    let a: [u8; 32] = b
        .try_into()
        .map_err(|_| format!("{}: bad key length", p.display()))?;
    Ok(Some(ed25519_dalek::SigningKey::from_bytes(&a)))
}

fn soft_key() -> Result<ed25519_dalek::SigningKey, String> {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let p = soft_key_path();
    if let Some(k) = read_soft_key(&p)? {
        return Ok(k);
    }
    let k = ed25519_dalek::SigningKey::generate(&mut rand_core::OsRng);
    if let Some(dir) = p.parent() {
        std::fs::create_dir_all(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    }
    // Publish without clobbering: write a uniquely named private temp file,
    // then hard-link it into place. The link fails if another process or
    // thread created the key first, in which case that key is used, so every
    // caller ends up with the same persisted key and no reader ever sees a
    // partially written file.
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let tmp = p.with_extension(format!(
        "key.tmp.{}.{}.{}",
        std::process::id(),
        nanos,
        SEQ.fetch_add(1, Ordering::Relaxed)
    ));
    crate::write_private(&tmp, hex::encode(k.to_bytes()).as_bytes())
        .map_err(|e| format!("{}: {e}", tmp.display()))?;
    let linked = std::fs::hard_link(&tmp, &p);
    let _ = std::fs::remove_file(&tmp);
    let published = match linked {
        Ok(()) => Ok(()),
        // Filesystems without hard links (e.g. FAT/exFAT): still no-clobber,
        // via an exclusive create of the final path.
        Err(e) if e.kind() != std::io::ErrorKind::AlreadyExists => {
            create_new_private(&p, hex::encode(k.to_bytes()).as_bytes())
        }
        Err(e) => Err(e),
    };
    match published {
        Ok(()) => Ok(k),
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => read_soft_key(&p)?
            .ok_or_else(|| format!("{}: key vanished after a creation race", p.display())),
        Err(e) => Err(format!("{}: {e}", p.display())),
    }
}

/// Exclusive (create-new) private write: fails with AlreadyExists instead of
/// overwriting.
fn create_new_private(path: &std::path::Path, data: &[u8]) -> std::io::Result<()> {
    use std::io::Write;
    let mut o = std::fs::OpenOptions::new();
    o.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        o.mode(0o600);
    }
    let mut f = o.open(path)?;
    f.write_all(data)?;
    f.sync_all()
}

/// Produces attestation evidence. `mode`: "auto", "tpm" (require) or "software".
pub fn attest(nonce: &[u8], hwid: &str, mode: &str) -> Result<Attestation, String> {
    let ts = crate::now_secs();
    let want_tpm = match mode {
        "software" => false,
        "tpm" => true,
        _ => tpm_available(),
    };
    if want_tpm {
        match tpm_attest(nonce, hwid) {
            Ok(ev) => {
                let sim = ev.simulated;
                return Ok(Attestation {
                    kind: "tpm2-quote".into(),
                    hardware_backed: !sim,
                    warning: if sim {
                        Some("SIMULATED TPM (swtpm/mssim): real TPM 2.0 protocol, but keys live in software; not hardware-backed".into())
                    } else {
                        None
                    },
                    nonce: hex::encode(nonce),
                    hwid: hwid.into(),
                    timestamp: ts,
                    tpm: Some(ev),
                    software: None,
                });
            }
            Err(e) if mode == "tpm" => return Err(format!("TPM attestation failed: {e}")),
            Err(_) => {}
        }
    }
    let k = soft_key()?;
    let sig = k.sign(&soft_msg(nonce, hwid, ts));
    Ok(Attestation {
        kind: "software-fallback".into(),
        hardware_backed: false,
        warning: Some(
            "NO TPM: software key from a local file; not hardware-backed and not tamper-resistant"
                .into(),
        ),
        nonce: hex::encode(nonce),
        hwid: hwid.into(),
        timestamp: ts,
        tpm: None,
        software: Some(SoftEvidence {
            public_key: hex::encode(k.verifying_key().to_bytes()),
            sig: hex::encode(sig.to_bytes()),
        }),
    })
}

struct Reader<'a> {
    b: &'a [u8],
    i: usize,
}
impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        if self.i + n > self.b.len() {
            return Err("truncated TPMS_ATTEST".into());
        }
        let s = &self.b[self.i..self.i + n];
        self.i += n;
        Ok(s)
    }
    fn u16(&mut self) -> Result<u16, String> {
        let s = self.take(2)?;
        Ok(u16::from_be_bytes([s[0], s[1]]))
    }
    fn u32(&mut self) -> Result<u32, String> {
        let s = self.take(4)?;
        Ok(u32::from_be_bytes([s[0], s[1], s[2], s[3]]))
    }
    fn tpm2b(&mut self) -> Result<&'a [u8], String> {
        let n = self.u16()? as usize;
        self.take(n)
    }
}

/// Parsed fields of a TPMS_ATTEST quote structure.
#[derive(Debug, PartialEq, Eq)]
pub struct QuoteInfo {
    pub extra_data: Vec<u8>,
    pub pcr_select: Vec<(u16, Vec<u8>)>,
    pub pcr_digest: Vec<u8>,
}

pub fn parse_tpms_attest(b: &[u8]) -> Result<QuoteInfo, String> {
    let mut r = Reader { b, i: 0 };
    if r.u32()? != 0xff54_4347 {
        return Err("TPMS_ATTEST magic is not TPM_GENERATED_VALUE".into());
    }
    if r.u16()? != 0x8018 {
        return Err("TPMS_ATTEST type is not TPM_ST_ATTEST_QUOTE".into());
    }
    r.tpm2b()?; // qualifiedSigner
    let extra = r.tpm2b()?.to_vec();
    r.take(17)?; // clockInfo
    r.take(8)?; // firmwareVersion
    let count = r.u32()?;
    let mut sel = Vec::new();
    for _ in 0..count {
        let alg = r.u16()?;
        let n = r.take(1)?[0] as usize;
        sel.push((alg, r.take(n)?.to_vec()));
    }
    let digest = r.tpm2b()?.to_vec();
    Ok(QuoteInfo {
        extra_data: extra,
        pcr_select: sel,
        pcr_digest: digest,
    })
}

fn ecdsa_sig(raw: &[u8]) -> Result<p256::ecdsa::Signature, String> {
    if raw.len() == 64 {
        p256::ecdsa::Signature::from_slice(raw).map_err(|e| e.to_string())
    } else {
        p256::ecdsa::Signature::from_der(raw).map_err(|e| format!("quote signature: {e}"))
    }
}

/// Verifies attestation evidence for `nonce`/`hwid`. Returns a description.
pub fn verify(
    a: &Attestation,
    nonce: &[u8],
    hwid: &str,
    pinned_soft_key: Option<&str>,
) -> Result<String, String> {
    if !a.nonce.eq_ignore_ascii_case(&hex::encode(nonce)) {
        return Err("attestation nonce mismatch (replay?)".into());
    }
    if a.hwid != hwid {
        return Err("attestation is for a different HWID".into());
    }
    match (a.kind.as_str(), &a.tpm, &a.software) {
        ("tpm2-quote", Some(t), _) => {
            let msg = B64.decode(&t.quote_attest).map_err(|e| e.to_string())?;
            let sig = ecdsa_sig(&B64.decode(&t.quote_sig).map_err(|e| e.to_string())?)?;
            let ak = p256::ecdsa::VerifyingKey::from_public_key_pem(&t.ak_public_pem)
                .map_err(|e| format!("AK public key: {e}"))?;
            ak.verify(&msg, &sig)
                .map_err(|_| "TPM quote signature invalid".to_string())?;
            let qi = parse_tpms_attest(&msg)?;
            if qi.extra_data != qualifying(nonce, hwid) {
                return Err("TPM quote qualifying data does not bind this nonce/HWID".into());
            }
            let mut h = Sha256::new();
            for v in &t.pcr_values {
                h.update(hex::decode(v).map_err(|e| e.to_string())?);
            }
            if qi.pcr_digest[..] != h.finalize()[..] {
                return Err("PCR values do not match the quoted PCR digest".into());
            }
            if !t.ak_ek_binding.starts_with("verified") {
                return Err(format!("AK not bound to EK: {}", t.ak_ek_binding));
            }
            if a.hardware_backed && t.simulated {
                return Err("evidence claims hardware backing for a simulated TPM".into());
            }
            Ok(format!(
                "TPM 2.0 quote valid ({}{}): AK-signed, {} PCRs match digest, nonce+HWID bound, AK/EK credential activation done at issue",
                if t.manufacturer.is_empty() { "unknown vendor" } else { &t.manufacturer },
                if t.simulated { ", SIMULATED swtpm" } else { "" },
                t.pcr_values.len()
            ))
        }
        ("software-fallback", _, Some(s)) => {
            if let Some(pin) = pinned_soft_key {
                if !pin.eq_ignore_ascii_case(&s.public_key) {
                    return Err("software attestation key is not the pinned key".into());
                }
            }
            let pk: [u8; 32] = hex::decode(&s.public_key)
                .map_err(|e| e.to_string())?
                .try_into()
                .map_err(|_| "bad software key".to_string())?;
            let vk = ed25519_dalek::VerifyingKey::from_bytes(&pk).map_err(|e| e.to_string())?;
            let sb: [u8; 64] = hex::decode(&s.sig)
                .map_err(|e| e.to_string())?
                .try_into()
                .map_err(|_| "bad sig".to_string())?;
            vk.verify(
                &soft_msg(nonce, hwid, a.timestamp),
                &ed25519_dalek::Signature::from_bytes(&sb),
            )
            .map_err(|_| "software attestation signature invalid".to_string())?;
            Ok("SOFTWARE FALLBACK signature valid (not hardware-backed)".into())
        }
        _ => Err(format!(
            "unknown or incomplete attestation kind {:?}",
            a.kind
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn software_fallback_round_trip_and_replay() {
        let _g = crate::TEST_ENV.lock().unwrap_or_else(|e| e.into_inner());
        let dir = std::env::temp_dir().join(format!("aiid-test-{}", std::process::id()));
        std::env::set_var("AIID_HOME", &dir);
        let nonce = [3u8; 32];
        let a = attest(&nonce, "ab".repeat(32).as_str(), "software").unwrap();
        assert!(!a.hardware_backed);
        assert!(verify(&a, &nonce, &"ab".repeat(32), None).is_ok());
        assert!(verify(&a, &[4u8; 32], &"ab".repeat(32), None).is_err());
        assert!(verify(&a, &nonce, &"cd".repeat(32), None).is_err());
        assert!(verify(&a, &nonce, &"ab".repeat(32), Some(&"00".repeat(32))).is_err());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn parses_real_tpms_attest() {
        // captured from swtpm (tpm2_quote, PCRs sha256:0-7, 8-byte nonce)
        let msg = hex::decode(concat!(
            "ff54434780180022000b33e19bd89dfebea0ab1e0d8a0ba9272ec3f127522b35",
            "65b963e7b80ed27b7b7c0008001122334455667700000000000021f700000001",
            "0000000001201910230016363600000001000b03ff000000205341e6b2646979",
            "a70e57653007a1f310169421ec9bdd9f1a5648f75ade005af1",
        ))
        .unwrap();
        let q = parse_tpms_attest(&msg).unwrap();
        assert_eq!(q.extra_data, hex::decode("0011223344556677").unwrap());
        assert_eq!(q.pcr_select, vec![(0x000b, vec![0xff, 0, 0])]);
        assert_eq!(q.pcr_digest.len(), 32);
    }
}
