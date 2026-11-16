// SPDX-License-Identifier: MIT
//! Verification of AIQ2 quotes produced by the RTL engine (`rtl/quote_engine.v`).
//!
//! The engine builds a 660-byte body in hardware and an attached secure
//! element signs SHA-256(body) with its ECDSA P-256 device key. The device
//! key is certified by the vendor CA using the same `{pubkey, sig}` chain
//! format as software quotes (`chain[0]` = self-signed root, last = SE key).
//!
//! Body layout (big-endian):
//! `"AIQ2" | hw_rev[2] | lifecycle | tamper | counter u32 | timestamp u64 |
//!  device_id[32] | nonce[32] | PCR0..15 [512] | model_digest[32] | config_digest[32]`

use crate::{parse_sig, unhex, verify_chain, Cert, Policy, VerifyError, NUM_PCRS};
use p256::ecdsa::signature::Verifier;
use p256::ecdsa::{Signature, SigningKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// Length of the AIQ2 body that the secure element signs.
pub const HW_BODY_LEN: usize = 660;
/// Lifecycle values (OTP word 1) that may produce quotes.
pub const LIFECYCLE_DEV: u8 = 0x02;
pub const LIFECYCLE_PROD: u8 = 0x03;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HwQuote {
    pub format: String,
    /// Two-character hardware revision code from OTP (e.g. "A1").
    pub hw_rev: String,
    pub lifecycle: u8,
    pub tamper: u8,
    pub counter: u32,
    pub timestamp: u64,
    pub device_id: String,
    pub nonce: String,
    pub pcrs: String,
    pub model_digest: String,
    pub config_digest: String,
    /// ECDSA P-256 r||s over SHA-256(body).
    pub sig: String,
    /// SE public key as read from the engine (SEC1, hex). Informational:
    /// trust comes from the chain, but it must match the chain leaf.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub se_pubkey: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub body_sha256: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
}

/// Policy for hardware quotes: the software-quote policy plus device rules.
/// Serialized flat (the `Policy` fields next to the device fields).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct HwPolicy {
    pub base: Policy,
    /// Enrolled device IDs (hex). Empty = any device with a trusted SE key.
    pub allowed_device_ids: Vec<String>,
    /// Accepted hardware revision codes. Empty = any.
    pub allowed_hw_revs: Vec<String>,
    /// Reject DEV-lifecycle parts.
    pub require_production: bool,
}

#[derive(Serialize, Deserialize, Default)]
struct HwExtra {
    #[serde(default)]
    allowed_device_ids: Vec<String>,
    #[serde(default)]
    allowed_hw_revs: Vec<String>,
    #[serde(default)]
    require_production: bool,
}

// Hand-written instead of `#[serde(flatten)]`: flatten cannot decode the
// integer-keyed `pcrs` map from JSON.
impl Serialize for HwPolicy {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        use serde::ser::Error;
        let mut v = serde_json::to_value(&self.base).map_err(S::Error::custom)?;
        let x = serde_json::to_value(HwExtra {
            allowed_device_ids: self.allowed_device_ids.clone(),
            allowed_hw_revs: self.allowed_hw_revs.clone(),
            require_production: self.require_production,
        })
        .map_err(S::Error::custom)?;
        if let (Some(m), Some(e)) = (v.as_object_mut(), x.as_object()) {
            m.extend(e.clone());
        }
        v.serialize(s)
    }
}

impl<'de> Deserialize<'de> for HwPolicy {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        use serde::de::Error;
        let v = serde_json::Value::deserialize(d)?;
        let base: Policy = serde_json::from_value(v.clone()).map_err(D::Error::custom)?;
        let x: HwExtra = serde_json::from_value(v).map_err(D::Error::custom)?;
        Ok(HwPolicy {
            base,
            allowed_device_ids: x.allowed_device_ids,
            allowed_hw_revs: x.allowed_hw_revs,
            require_production: x.require_production,
        })
    }
}

/// Reconstructs the exact signed body from the quote fields.
pub fn hw_body(q: &HwQuote) -> Result<Vec<u8>, VerifyError> {
    if q.format != "AIQ2" {
        return Err(VerifyError::Malformed(format!(
            "format {:?} is not AIQ2",
            q.format
        )));
    }
    let rev = q.hw_rev.as_bytes();
    if rev.len() != 2 {
        return Err(VerifyError::Malformed(
            "hw_rev must be 2 ASCII characters".into(),
        ));
    }
    let mut b = Vec::with_capacity(HW_BODY_LEN);
    b.extend_from_slice(b"AIQ2");
    b.extend_from_slice(rev);
    b.push(q.lifecycle);
    b.push(q.tamper);
    b.extend_from_slice(&q.counter.to_be_bytes());
    b.extend_from_slice(&q.timestamp.to_be_bytes());
    b.extend(unhex("device_id", &q.device_id, Some(32))?);
    b.extend(unhex("nonce", &q.nonce, Some(32))?);
    b.extend(unhex("pcrs", &q.pcrs, Some(32 * NUM_PCRS))?);
    b.extend(unhex("model_digest", &q.model_digest, Some(32))?);
    b.extend(unhex("config_digest", &q.config_digest, Some(32))?);
    debug_assert_eq!(b.len(), HW_BODY_LEN);
    Ok(b)
}

fn eq_hex(a: &str, b: &str) -> bool {
    a.eq_ignore_ascii_case(b)
}

/// Full appraisal of a hardware quote.
pub fn verify_hw(
    q: &HwQuote,
    chain: &[Cert],
    policy: &HwPolicy,
    expected_nonce: &[u8],
    now: u64,
) -> Result<(), VerifyError> {
    let body = hw_body(q)?;
    // 1. freshness
    if unhex("nonce", &q.nonce, Some(32))? != expected_nonce {
        return Err(VerifyError::NonceMismatch);
    }
    let skew = now.abs_diff(q.timestamp);
    if skew > policy.base.max_skew_secs {
        return Err(VerifyError::Stale {
            skew,
            max: policy.base.max_skew_secs,
        });
    }
    // 2. signer: vendor CA -> SE device key, signature over SHA-256(body)
    let leaf = verify_chain(chain, &policy.base)?;
    if let Some(pk) = &q.se_pubkey {
        let claimed = p256::ecdsa::VerifyingKey::from_sec1_bytes(&unhex("se_pubkey", pk, None)?)
            .map_err(|_| VerifyError::Malformed("se_pubkey: bad P-256 key".into()))?;
        if claimed != leaf {
            return Err(VerifyError::Malformed(
                "se_pubkey does not match the chain leaf".into(),
            ));
        }
    }
    let sig = parse_sig("sig", &q.sig)?;
    leaf.verify(&body, &sig)
        .map_err(|_| VerifyError::BadQuoteSignature)?;
    if let Some(d) = &q.body_sha256 {
        if !eq_hex(d, &hex::encode(Sha256::digest(&body))) {
            return Err(VerifyError::Malformed(
                "body_sha256 does not match the body".into(),
            ));
        }
    }
    // 3. device state
    if q.tamper != 0 {
        return Err(VerifyError::Tampered(q.tamper));
    }
    let lc_ok = q.lifecycle == LIFECYCLE_PROD
        || (q.lifecycle == LIFECYCLE_DEV && !policy.require_production);
    if !lc_ok {
        return Err(VerifyError::Lifecycle(q.lifecycle));
    }
    if !policy.allowed_hw_revs.is_empty() && !policy.allowed_hw_revs.iter().any(|r| r == &q.hw_rev)
    {
        return Err(VerifyError::HwRevNotAllowed(q.hw_rev.clone()));
    }
    if !policy.allowed_device_ids.is_empty()
        && !policy
            .allowed_device_ids
            .iter()
            .any(|d| eq_hex(d, &q.device_id))
    {
        return Err(VerifyError::DeviceNotAllowed(q.device_id.clone()));
    }
    // 4. claims
    if !policy
        .base
        .allowed_models
        .iter()
        .any(|m| eq_hex(m, &q.model_digest))
    {
        return Err(VerifyError::ModelNotAllowed(q.model_digest.clone()));
    }
    if !policy.base.allowed_configs.is_empty()
        && !policy
            .base
            .allowed_configs
            .iter()
            .any(|c| eq_hex(c, &q.config_digest))
    {
        return Err(VerifyError::ConfigNotAllowed(q.config_digest.clone()));
    }
    let pcrs = unhex("pcrs", &q.pcrs, Some(32 * NUM_PCRS))?;
    for (idx, want) in &policy.base.pcrs {
        let i = *idx as usize;
        if i >= NUM_PCRS {
            return Err(VerifyError::PcrIndexOutOfRange(*idx));
        }
        let w = unhex(&format!("policy.pcrs[{idx}]"), want, Some(32))?;
        if pcrs[32 * i..32 * i + 32] != w[..] {
            return Err(VerifyError::PcrMismatch(*idx));
        }
    }
    Ok(())
}

/// Issues a chain certificate for a raw SEC1 public key (e.g. read from an SE).
pub fn issue_cert_for_pubkey(issuer: &SigningKey, pubkey_sec1: &[u8]) -> Result<Cert, VerifyError> {
    use p256::ecdsa::signature::Signer;
    let vk = p256::ecdsa::VerifyingKey::from_sec1_bytes(pubkey_sec1)
        .map_err(|_| VerifyError::Malformed("subject: bad P-256 key".into()))?;
    let pk = vk.to_encoded_point(true).as_bytes().to_vec();
    let sig: Signature = issuer.sign(&crate::cert_message(&pk));
    Ok(Cert {
        pubkey: hex::encode(&pk),
        sig: hex::encode(sig.to_bytes()),
    })
}

/// Software model of the engine+SE signer, for tests and demos.
pub fn sign_hw_quote(se_key: &SigningKey, q: &mut HwQuote) -> Result<(), VerifyError> {
    use p256::ecdsa::signature::Signer;
    let body = hw_body(q)?;
    let sig: Signature = se_key.sign(&body);
    q.sig = hex::encode(sig.to_bytes());
    q.body_sha256 = Some(hex::encode(Sha256::digest(&body)));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{build_chain, pubkey_hex};
    use std::collections::BTreeMap;

    fn key(b: u8) -> SigningKey {
        let mut s = [0u8; 32];
        s[31] = b;
        s[0] = 0x11;
        SigningKey::from_slice(&s).unwrap()
    }

    struct Fx {
        q: HwQuote,
        chain: Vec<Cert>,
        policy: HwPolicy,
        nonce: [u8; 32],
        now: u64,
    }

    fn fixture() -> Fx {
        let root = key(1);
        let se = key(2);
        let nonce = [7u8; 32];
        let mut q = HwQuote {
            format: "AIQ2".into(),
            hw_rev: "A1".into(),
            lifecycle: LIFECYCLE_DEV,
            tamper: 0,
            counter: 3,
            timestamp: 1_000_000,
            device_id: hex::encode([0xD1u8; 32]),
            nonce: hex::encode(nonce),
            pcrs: hex::encode([0u8; 512]),
            model_digest: hex::encode([0x4Du8; 32]),
            config_digest: hex::encode([0u8; 32]),
            sig: String::new(),
            se_pubkey: Some(hex::encode(
                se.verifying_key().to_encoded_point(false).as_bytes(),
            )),
            body_sha256: None,
            source: None,
        };
        sign_hw_quote(&se, &mut q).unwrap();
        let policy = HwPolicy {
            base: Policy {
                trusted_roots: vec![pubkey_hex(&root)],
                allowed_models: vec![hex::encode([0x4Du8; 32])],
                allowed_configs: vec![],
                pcrs: BTreeMap::new(),
                max_skew_secs: 60,
            },
            allowed_device_ids: vec![hex::encode([0xD1u8; 32])],
            allowed_hw_revs: vec!["A1".into()],
            require_production: false,
        };
        Fx {
            q,
            chain: build_chain(&[&root, &se]),
            policy,
            nonce,
            now: 1_000_010,
        }
    }

    fn run(f: &Fx) -> Result<(), VerifyError> {
        verify_hw(&f.q, &f.chain, &f.policy, &f.nonce, f.now)
    }

    #[test]
    fn hw_quote_verifies() {
        let f = fixture();
        assert_eq!(hw_body(&f.q).unwrap().len(), HW_BODY_LEN);
        assert_eq!(run(&f), Ok(()));
    }

    #[test]
    fn hw_rejects_tamper_lifecycle_device_and_rev() {
        let se = key(2);
        let mut f = fixture();
        f.q.tamper = 0x01;
        sign_hw_quote(&se, &mut f.q).unwrap();
        assert_eq!(run(&f), Err(VerifyError::Tampered(1)));

        let mut f = fixture();
        f.policy.require_production = true;
        assert_eq!(run(&f), Err(VerifyError::Lifecycle(LIFECYCLE_DEV)));

        let mut f = fixture();
        f.policy.allowed_device_ids = vec![hex::encode([0xEEu8; 32])];
        assert!(matches!(run(&f), Err(VerifyError::DeviceNotAllowed(_))));

        let mut f = fixture();
        f.policy.allowed_hw_revs = vec!["B2".into()];
        assert!(matches!(run(&f), Err(VerifyError::HwRevNotAllowed(_))));
    }

    #[test]
    fn hw_rejects_modified_body_and_wrong_se_key() {
        let mut f = fixture();
        f.q.counter += 1; // any body change breaks the SE signature
        assert_eq!(run(&f), Err(VerifyError::BadQuoteSignature));

        let mut f = fixture();
        f.q.se_pubkey = Some(hex::encode(
            key(9).verifying_key().to_encoded_point(false).as_bytes(),
        ));
        assert!(matches!(run(&f), Err(VerifyError::Malformed(_))));

        let mut f = fixture();
        let other = key(5);
        f.chain = build_chain(&[&key(1), &other]);
        f.q.se_pubkey = None;
        assert_eq!(run(&f), Err(VerifyError::BadQuoteSignature));
    }

    #[test]
    fn hw_rejects_replay_and_staleness() {
        let f = fixture();
        assert_eq!(
            verify_hw(&f.q, &f.chain, &f.policy, &[0u8; 32], f.now),
            Err(VerifyError::NonceMismatch)
        );
        assert!(matches!(
            verify_hw(&f.q, &f.chain, &f.policy, &f.nonce, f.now + 3600),
            Err(VerifyError::Stale { .. })
        ));
    }

    #[test]
    fn issue_cert_for_raw_pubkey_chains() {
        let root = key(1);
        let se = key(2);
        let raw = se.verifying_key().to_encoded_point(false);
        let chain = vec![
            crate::issue_cert(&root, &root),
            issue_cert_for_pubkey(&root, raw.as_bytes()).unwrap(),
        ];
        let f = fixture();
        assert_eq!(verify_hw(&f.q, &chain, &f.policy, &f.nonce, f.now), Ok(()));
    }

    #[test]
    fn policy_json_round_trip_with_pcrs() {
        let j = r#"{"trusted_roots":["00"],"allowed_models":["11"],"pcrs":{"2":"22"},
                   "max_skew_secs":60,"allowed_hw_revs":["A1"],"require_production":true}"#;
        let p: HwPolicy = serde_json::from_str(j).unwrap();
        assert_eq!(p.base.pcrs.get(&2).map(String::as_str), Some("22"));
        assert_eq!(p.allowed_hw_revs, vec!["A1".to_string()]);
        assert!(p.require_production && p.allowed_device_ids.is_empty());
        let back: HwPolicy = serde_json::from_str(&serde_json::to_string(&p).unwrap()).unwrap();
        assert_eq!(back, p);
    }
}
