// SPDX-License-Identifier: MIT
use p256::ecdsa::{VerifyingKey, Signature, signature::Verifier};
use sha2::{Sha256, Digest};
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Deserialize)]
struct Quote {
    nonce: String,          // hex, 32 bytes
    pcr_digest: String,     // hex, 32 bytes
    model_digest: String,   // hex, 32 bytes
    config_digest: String,  // hex, 32 bytes
    timestamp: u64,
    sig: String,            // hex, 64 bytes
}

struct Policy {
    min_pcrs: HashMap<u8, String>,   // pcr -> expected digest
    allowed_models: Vec<String>,
    max_skew_secs: u64,
}

fn verify(q: &Quote, policy: &Policy, chain: &[VerifyingKey],
          nonce: &[u8], now: u64) -> Result<(), String> {
    // 1. nonce freshness (replay resistance)
    if hex::decode(&q.nonce).map_err(|e| e.to_string())? != nonce {
        return Err("nonce mismatch".into());
    }

    // 2. timestamp window
    if now.abs_diff(q.timestamp) > policy.max_skew_secs {
        return Err("quote stale".into());
    }

    // 3. recompute the signed transcript
    let mut h = Sha256::new();
    h.update(&q.nonce);
    h.update(&q.pcr_digest);
    h.update(&q.model_digest);
    h.update(&q.config_digest);
    h.update(q.timestamp.to_be_bytes());
    let transcript = h.finalize();

    // 4. verify signature against the leaf alias key
    let sig_bytes = hex::decode(&q.sig).map_err(|e| e.to_string())?;
    let sig = Signature::from_slice(&sig_bytes).map_err(|e| e.to_string())?;
    let leaf = chain.last().ok_or("empty chain")?;
    leaf.verify(&transcript, &sig).map_err(|_| "bad signature")?;

    // 5. validate the cert chain up to the vendor root
    for w in chain.windows(2) {
        w[1].verify_cert(&w[0])?;
    }

    // 6. policy: model allowlist
    if !policy.allowed_models.contains(&q.model_digest) {
        return Err(format!("model {} not allowed", q.model_digest));
    }

    // 7. policy: PCR state must match exactly
    for (pcr, want) in &policy.min_pcrs {
        let got = pcr_slice(&q.pcr_digest, *pcr);
        if got != *want { return Err(format!("PCR{pcr} mismatch")); }
    }

    Ok(())
}

fn pcr_slice(joined: &str, idx: u8) -> String {
    let off = idx as usize * 64;
    joined[off..off + 64].to_string()
}
