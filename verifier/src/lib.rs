// SPDX-License-Identifier: MIT
//! Reference verifier for AI identity engine attestation quotes.
//!
//! A quote binds a verifier-chosen nonce to the platform measurement state
//! (PCRs), the model-weights digest and the configuration digest, and is
//! signed by the device alias key. The alias key is certified by a chain of
//! P-256 keys that must end at a root the verifier trusts.
//!
//! Wire format (all binary fields are lowercase or uppercase hex):
//!
//! * transcript = SHA-256(nonce || pcrs || model_digest || config_digest ||
//!   timestamp_be64), using the decoded bytes.
//! * `sig` = ECDSA-P256-SHA256(alias_key, transcript) as 64-byte r||s.
//! * Each chain certificate is `{pubkey, sig}` where `pubkey` is a SEC1
//!   P-256 public key and `sig` = ECDSA-P256-SHA256(issuer, CERT_TAG ||
//!   pubkey_bytes). `chain[0]` is the root and is self-signed; the last
//!   entry is the alias (leaf) key.
//!
//! This verifier is a software reference. The hardware quote path in
//! `rtl/quote_signer.v` is intentionally fail-closed until its ECDSA
//! implementation is verified, so quotes today come from software signers
//! (see `examples/` and the `demo` CLI command).

use p256::ecdsa::signature::{Signer, Verifier};
use p256::ecdsa::{Signature, SigningKey, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::fmt;

pub mod hw;
pub use hw::{hw_body, issue_cert_for_pubkey, sign_hw_quote, verify_hw, HwPolicy, HwQuote};

/// Domain-separation tag for certificate signatures.
pub const CERT_TAG: &[u8] = b"AI-ID-CERT-V1";
/// Number of PCRs carried in a quote.
pub const NUM_PCRS: usize = 16;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Quote {
    /// 32-byte verifier nonce, hex.
    pub nonce: String,
    /// Concatenation of NUM_PCRS 32-byte PCR values, hex.
    pub pcrs: String,
    /// 32-byte digest of the model weights, hex.
    pub model_digest: String,
    /// 32-byte digest of tokenizer/runtime configuration, hex.
    pub config_digest: String,
    /// Seconds since the Unix epoch at signing time.
    pub timestamp: u64,
    /// 64-byte ECDSA P-256 signature r||s, hex.
    pub sig: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Cert {
    /// SEC1-encoded P-256 public key, hex.
    pub pubkey: String,
    /// Issuer signature over CERT_TAG || pubkey, hex (64 bytes r||s).
    pub sig: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct Policy {
    /// SEC1 public keys (hex) of roots the verifier trusts.
    pub trusted_roots: Vec<String>,
    /// Allowed model-weights digests (hex).
    pub allowed_models: Vec<String>,
    /// Optional allowed configuration digests (hex). Empty = any.
    #[serde(default)]
    pub allowed_configs: Vec<String>,
    /// PCR index -> expected 32-byte value (hex).
    #[serde(default)]
    pub pcrs: BTreeMap<u8, String>,
    /// Maximum allowed |now - timestamp| in seconds.
    pub max_skew_secs: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VerifyError {
    Malformed(String),
    NonceMismatch,
    Stale { skew: u64, max: u64 },
    EmptyChain,
    UntrustedRoot,
    BadCertSignature(usize),
    BadQuoteSignature,
    ModelNotAllowed(String),
    ConfigNotAllowed(String),
    PcrMismatch(u8),
    PcrIndexOutOfRange(u8),
    Tampered(u8),
    Lifecycle(u8),
    DeviceNotAllowed(String),
    HwRevNotAllowed(String),
}

impl fmt::Display for VerifyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            VerifyError::Malformed(m) => write!(f, "malformed input: {m}"),
            VerifyError::NonceMismatch => write!(f, "nonce mismatch (possible replay)"),
            VerifyError::Stale { skew, max } => {
                write!(f, "quote stale: skew {skew}s exceeds {max}s")
            }
            VerifyError::EmptyChain => write!(f, "empty certificate chain"),
            VerifyError::UntrustedRoot => write!(f, "chain root is not a trusted root"),
            VerifyError::BadCertSignature(i) => {
                write!(f, "certificate {i} not signed by its issuer")
            }
            VerifyError::BadQuoteSignature => write!(f, "quote signature invalid"),
            VerifyError::ModelNotAllowed(m) => write!(f, "model {m} not allowed"),
            VerifyError::ConfigNotAllowed(c) => write!(f, "config {c} not allowed"),
            VerifyError::PcrMismatch(i) => write!(f, "PCR{i} mismatch"),
            VerifyError::PcrIndexOutOfRange(i) => write!(f, "PCR{i} out of range"),
            VerifyError::Tampered(t) => write!(f, "device reports tamper flags 0x{t:02x}"),
            VerifyError::Lifecycle(l) => write!(f, "device lifecycle 0x{l:02x} not allowed"),
            VerifyError::DeviceNotAllowed(d) => write!(f, "device {d} is not enrolled"),
            VerifyError::HwRevNotAllowed(r) => write!(f, "hardware revision {r} not allowed"),
        }
    }
}

impl std::error::Error for VerifyError {}

pub(crate) fn unhex(field: &str, s: &str, len: Option<usize>) -> Result<Vec<u8>, VerifyError> {
    let b = hex::decode(s).map_err(|e| VerifyError::Malformed(format!("{field}: {e}")))?;
    if let Some(n) = len {
        if b.len() != n {
            return Err(VerifyError::Malformed(format!(
                "{field}: expected {n} bytes, got {}",
                b.len()
            )));
        }
    }
    Ok(b)
}

fn parse_key(field: &str, s: &str) -> Result<VerifyingKey, VerifyError> {
    let b = unhex(field, s, None)?;
    VerifyingKey::from_sec1_bytes(&b)
        .map_err(|_| VerifyError::Malformed(format!("{field}: bad P-256 key")))
}

pub(crate) fn parse_sig(field: &str, s: &str) -> Result<Signature, VerifyError> {
    let b = unhex(field, s, Some(64))?;
    Signature::from_slice(&b).map_err(|_| VerifyError::Malformed(format!("{field}: bad signature")))
}

/// Computes the signed transcript of a quote from its decoded fields.
pub fn transcript(q: &Quote) -> Result<[u8; 32], VerifyError> {
    let mut h = Sha256::new();
    h.update(unhex("nonce", &q.nonce, Some(32))?);
    h.update(unhex("pcrs", &q.pcrs, Some(32 * NUM_PCRS))?);
    h.update(unhex("model_digest", &q.model_digest, Some(32))?);
    h.update(unhex("config_digest", &q.config_digest, Some(32))?);
    h.update(q.timestamp.to_be_bytes());
    Ok(h.finalize().into())
}

pub(crate) fn cert_message(pubkey: &[u8]) -> Vec<u8> {
    let mut m = CERT_TAG.to_vec();
    m.extend_from_slice(pubkey);
    m
}

/// Verifies the certificate chain and returns the leaf (alias) key.
pub fn verify_chain(chain: &[Cert], policy: &Policy) -> Result<VerifyingKey, VerifyError> {
    let root = chain.first().ok_or(VerifyError::EmptyChain)?;
    let root_bytes = unhex("chain[0].pubkey", &root.pubkey, None)?;
    let trusted = policy
        .trusted_roots
        .iter()
        .filter_map(|r| hex::decode(r).ok())
        .any(|r| r == root_bytes);
    if !trusted {
        return Err(VerifyError::UntrustedRoot);
    }
    let mut issuer = parse_key("chain[0].pubkey", &root.pubkey)?;
    for (i, c) in chain.iter().enumerate() {
        let subject_bytes = unhex(&format!("chain[{i}].pubkey"), &c.pubkey, None)?;
        let subject = parse_key(&format!("chain[{i}].pubkey"), &c.pubkey)?;
        let sig = parse_sig(&format!("chain[{i}].sig"), &c.sig)?;
        issuer
            .verify(&cert_message(&subject_bytes), &sig)
            .map_err(|_| VerifyError::BadCertSignature(i))?;
        issuer = subject;
    }
    Ok(issuer)
}

/// Full appraisal of a quote against a nonce, a chain and a policy.
pub fn verify(
    q: &Quote,
    chain: &[Cert],
    policy: &Policy,
    expected_nonce: &[u8],
    now: u64,
) -> Result<(), VerifyError> {
    // 1. freshness: nonce (replay resistance) and timestamp window
    if unhex("nonce", &q.nonce, Some(32))? != expected_nonce {
        return Err(VerifyError::NonceMismatch);
    }
    let skew = now.abs_diff(q.timestamp);
    if skew > policy.max_skew_secs {
        return Err(VerifyError::Stale {
            skew,
            max: policy.max_skew_secs,
        });
    }
    // 2. signer trust chain and quote signature
    let leaf = verify_chain(chain, policy)?;
    let t = transcript(q)?;
    let sig = parse_sig("sig", &q.sig)?;
    leaf.verify(&t, &sig)
        .map_err(|_| VerifyError::BadQuoteSignature)?;
    // 3. appraisal policy: approved model, config and measurements
    let model = q.model_digest.to_ascii_lowercase();
    if !policy
        .allowed_models
        .iter()
        .any(|m| m.to_ascii_lowercase() == model)
    {
        return Err(VerifyError::ModelNotAllowed(model));
    }
    let config = q.config_digest.to_ascii_lowercase();
    if !policy.allowed_configs.is_empty()
        && !policy
            .allowed_configs
            .iter()
            .any(|c| c.to_ascii_lowercase() == config)
    {
        return Err(VerifyError::ConfigNotAllowed(config));
    }
    let pcrs = unhex("pcrs", &q.pcrs, Some(32 * NUM_PCRS))?;
    for (&idx, want) in &policy.pcrs {
        let i = idx as usize;
        if i >= NUM_PCRS {
            return Err(VerifyError::PcrIndexOutOfRange(idx));
        }
        let want = unhex(&format!("policy.pcrs[{idx}]"), want, Some(32))?;
        if pcrs[32 * i..32 * i + 32] != want[..] {
            return Err(VerifyError::PcrMismatch(idx));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Software issuer helpers (testing and demos only; not a device signer).
// ---------------------------------------------------------------------------

fn sec1(k: &SigningKey) -> Vec<u8> {
    k.verifying_key().to_encoded_point(true).as_bytes().to_vec()
}

/// Issues a certificate for `subject` signed by `issuer`.
pub fn issue_cert(issuer: &SigningKey, subject: &SigningKey) -> Cert {
    let pk = sec1(subject);
    let sig: Signature = issuer.sign(&cert_message(&pk));
    Cert {
        pubkey: hex::encode(&pk),
        sig: hex::encode(sig.to_bytes()),
    }
}

/// Builds a chain root -> ... -> leaf from signing keys (root self-signed).
pub fn build_chain(keys: &[&SigningKey]) -> Vec<Cert> {
    let mut chain = Vec::new();
    for (i, k) in keys.iter().enumerate() {
        let issuer = if i == 0 { *k } else { keys[i - 1] };
        chain.push(issue_cert(issuer, k));
    }
    chain
}

/// Hex SEC1 public key of a signing key.
pub fn pubkey_hex(k: &SigningKey) -> String {
    hex::encode(sec1(k))
}

/// Signs a quote over the given claims with `alias`.
pub fn sign_quote(
    alias: &SigningKey,
    nonce: &[u8; 32],
    pcrs: &[[u8; 32]; NUM_PCRS],
    model_digest: &[u8; 32],
    config_digest: &[u8; 32],
    timestamp: u64,
) -> Quote {
    let mut q = Quote {
        nonce: hex::encode(nonce),
        pcrs: hex::encode(pcrs.concat()),
        model_digest: hex::encode(model_digest),
        config_digest: hex::encode(config_digest),
        timestamp,
        sig: String::new(),
    };
    let t = transcript(&q).expect("well-formed by construction");
    let sig: Signature = alias.sign(&t);
    q.sig = hex::encode(sig.to_bytes());
    q
}

/// TPM-style extend: SHA-256(old || digest). Matches rtl/pcr_bank.v.
pub fn pcr_extend(old: &[u8; 32], digest: &[u8; 32]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(old);
    h.update(digest);
    h.finalize().into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(b: u8) -> SigningKey {
        SigningKey::from_bytes(&[b; 32].into()).unwrap()
    }

    struct Fx {
        root: SigningKey,
        alias: SigningKey,
        chain: Vec<Cert>,
        policy: Policy,
        nonce: [u8; 32],
        quote: Quote,
    }

    fn sha(s: &str) -> [u8; 32] {
        Sha256::digest(s.as_bytes()).into()
    }

    fn fixture() -> Fx {
        let root = key(1);
        let device = key(2);
        let alias = key(3);
        let chain = build_chain(&[&root, &device, &alias]);
        let mut pcrs = [[0u8; 32]; NUM_PCRS];
        for (i, l) in ["BL2", "U-Boot", "kernel", "weights", "config"]
            .iter()
            .enumerate()
        {
            pcrs[i] = pcr_extend(&[0; 32], &sha(l));
        }
        let model = sha("model-weights-v1");
        let config = sha("runtime-config-v1");
        let nonce = [0xA5u8; 32];
        let quote = sign_quote(&alias, &nonce, &pcrs, &model, &config, 1_000);
        let mut want = BTreeMap::new();
        want.insert(0u8, hex::encode(pcrs[0]));
        want.insert(4u8, hex::encode(pcrs[4]));
        let policy = Policy {
            trusted_roots: vec![pubkey_hex(&root)],
            allowed_models: vec![hex::encode(model)],
            allowed_configs: vec![hex::encode(config)],
            pcrs: want,
            max_skew_secs: 60,
        };
        Fx {
            root,
            alias,
            chain,
            policy,
            nonce,
            quote,
        }
    }

    fn run(f: &Fx) -> Result<(), VerifyError> {
        verify(&f.quote, &f.chain, &f.policy, &f.nonce, 1_030)
    }

    #[test]
    fn valid_quote_verifies() {
        assert_eq!(run(&fixture()), Ok(()));
    }

    #[test]
    fn pcr_extend_matches_rtl_vector() {
        // Same value the Verilator testbench prints for PCR4 ("config").
        let v = pcr_extend(&[0; 32], &sha("config"));
        assert_eq!(
            hex::encode(v),
            "82849956c36ce316c8fc2b43b48588f462683082c0edb1fcc4d0d6a9143eabe3"
        );
    }

    #[test]
    fn rejects_wrong_nonce() {
        let f = fixture();
        assert_eq!(
            verify(&f.quote, &f.chain, &f.policy, &[0u8; 32], 1_030),
            Err(VerifyError::NonceMismatch)
        );
    }

    #[test]
    fn rejects_stale_and_future_quotes() {
        let f = fixture();
        assert!(matches!(
            verify(&f.quote, &f.chain, &f.policy, &f.nonce, 2_000),
            Err(VerifyError::Stale { .. })
        ));
        assert!(matches!(
            verify(&f.quote, &f.chain, &f.policy, &f.nonce, 0),
            Err(VerifyError::Stale { .. })
        ));
    }

    #[test]
    fn rejects_tampered_claims() {
        let mut f = fixture();
        let mut b = hex::decode(&f.quote.pcrs).unwrap();
        b[100] ^= 1;
        f.quote.pcrs = hex::encode(b);
        assert_eq!(run(&f), Err(VerifyError::BadQuoteSignature));

        let mut f = fixture();
        f.quote.timestamp += 1;
        assert_eq!(run(&f), Err(VerifyError::BadQuoteSignature));
    }

    #[test]
    fn rejects_signature_from_other_key() {
        let mut f = fixture();
        let other = key(9);
        let pcrs: [[u8; 32]; NUM_PCRS] = {
            let b = hex::decode(&f.quote.pcrs).unwrap();
            let mut p = [[0u8; 32]; NUM_PCRS];
            for i in 0..NUM_PCRS {
                p[i].copy_from_slice(&b[32 * i..32 * i + 32]);
            }
            p
        };
        let m: [u8; 32] = hex::decode(&f.quote.model_digest)
            .unwrap()
            .try_into()
            .unwrap();
        let c: [u8; 32] = hex::decode(&f.quote.config_digest)
            .unwrap()
            .try_into()
            .unwrap();
        f.quote = sign_quote(&other, &f.nonce, &pcrs, &m, &c, 1_000);
        assert_eq!(run(&f), Err(VerifyError::BadQuoteSignature));
    }

    #[test]
    fn rejects_untrusted_root_and_empty_chain() {
        let mut f = fixture();
        f.policy.trusted_roots = vec![pubkey_hex(&key(7))];
        assert_eq!(run(&f), Err(VerifyError::UntrustedRoot));
        let mut f = fixture();
        f.chain.clear();
        assert_eq!(run(&f), Err(VerifyError::EmptyChain));
    }

    #[test]
    fn rejects_broken_chain_link() {
        let mut f = fixture();
        // replace the alias cert with one issued by the root instead of the device key
        f.chain[2] = issue_cert(&key(8), &f.alias);
        assert_eq!(run(&f), Err(VerifyError::BadCertSignature(2)));
        let _ = &f.root;
    }

    #[test]
    fn rejects_disallowed_model_and_config() {
        let mut f = fixture();
        f.policy.allowed_models = vec![hex::encode([0u8; 32])];
        assert!(matches!(run(&f), Err(VerifyError::ModelNotAllowed(_))));
        let mut f = fixture();
        f.policy.allowed_configs = vec![hex::encode([0u8; 32])];
        assert!(matches!(run(&f), Err(VerifyError::ConfigNotAllowed(_))));
    }

    #[test]
    fn rejects_pcr_mismatch_and_bad_index() {
        let mut f = fixture();
        f.policy.pcrs.insert(1, hex::encode([0u8; 32]));
        assert_eq!(run(&f), Err(VerifyError::PcrMismatch(1)));
        let mut f = fixture();
        f.policy.pcrs.insert(16, hex::encode([0u8; 32]));
        assert_eq!(run(&f), Err(VerifyError::PcrIndexOutOfRange(16)));
    }

    #[test]
    fn rejects_malformed_fields_without_panicking() {
        let mut f = fixture();
        f.quote.pcrs = "abcd".into();
        assert!(matches!(run(&f), Err(VerifyError::Malformed(_))));
        let mut f = fixture();
        f.quote.sig = "zz".into();
        assert!(matches!(run(&f), Err(VerifyError::Malformed(_))));
        let mut f = fixture();
        f.quote.nonce = "00".into();
        assert!(matches!(run(&f), Err(VerifyError::Malformed(_))));
    }

    #[test]
    fn json_round_trip() {
        let f = fixture();
        let s = serde_json::to_string(&f.quote).unwrap();
        let q: Quote = serde_json::from_str(&s).unwrap();
        assert_eq!(q, f.quote);
        let p: Policy = serde_json::from_str(&serde_json::to_string(&f.policy).unwrap()).unwrap();
        assert_eq!(p, f.policy);
    }
}
