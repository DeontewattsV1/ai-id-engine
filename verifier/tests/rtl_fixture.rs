// SPDX-License-Identifier: MIT
//! A quote produced by the RTL (Verilator simulation of id_engine_top) must
//! verify with the Rust verifier, and any edit must be rejected.

use ai_id_verifier::{verify_hw, Cert, HwPolicy, HwQuote, Policy, VerifyError};
use std::collections::BTreeMap;

fn fixture() -> (HwQuote, Vec<Cert>, HwPolicy, Vec<u8>) {
    let v: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/rtl_aiq2_quote.json")).unwrap();
    let q: HwQuote = serde_json::from_value(v["quote"].clone()).unwrap();
    let chain: Vec<Cert> = serde_json::from_value(v["chain"].clone()).unwrap();
    let mut pcrs = BTreeMap::new();
    pcrs.insert(2u8, v["pcr2_expected"].as_str().unwrap().to_string());
    let pol = HwPolicy {
        base: Policy {
            trusted_roots: vec![v["root"].as_str().unwrap().to_string()],
            allowed_models: vec![q.model_digest.clone()],
            allowed_configs: vec![],
            pcrs,
            max_skew_secs: 300,
        },
        allowed_hw_revs: vec!["A1".into()],
        ..Default::default()
    };
    let nonce = hex::decode(&q.nonce).unwrap();
    (q, chain, pol, nonce)
}

#[test]
fn rtl_quote_verifies() {
    let (q, chain, pol, nonce) = fixture();
    assert_eq!(
        q.source.as_deref(),
        Some("rtl-sim id_engine_top (Verilator)")
    );
    verify_hw(&q, &chain, &pol, &nonce, q.timestamp).unwrap();
}

#[test]
fn rtl_quote_rejects_edits() {
    let (q, chain, pol, nonce) = fixture();
    let mut bad = q.clone();
    bad.counter += 1;
    assert!(verify_hw(&bad, &chain, &pol, &nonce, q.timestamp).is_err());
    let mut bad = q.clone();
    bad.tamper = 1;
    assert!(verify_hw(&bad, &chain, &pol, &nonce, q.timestamp).is_err());
    assert_eq!(
        verify_hw(&q, &chain, &pol, &[0u8; 32], q.timestamp),
        Err(VerifyError::NonceMismatch)
    );
    assert!(matches!(
        verify_hw(&q, &chain, &pol, &nonce, q.timestamp + 3600),
        Err(VerifyError::Stale { .. })
    ));
    let mut p2 = pol.clone();
    p2.require_production = true;
    assert!(matches!(
        verify_hw(&q, &chain, &p2, &nonce, q.timestamp),
        Err(VerifyError::Lifecycle(2))
    ));
}
