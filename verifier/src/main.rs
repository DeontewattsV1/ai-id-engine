// SPDX-License-Identifier: MIT
//! CLI for the AI identity quote verifier.
//!
//!   ai-id-verifier verify --quote Q.json --chain C.json --policy P.json \
//!                         --nonce HEX [--now UNIX_SECS]
//!   ai-id-verifier verify-hw --quote Q.json --chain C.json --policy P.json \
//!                            --nonce HEX [--now UNIX_SECS]
//!   ai-id-verifier demo [--out DIR]
//!
//! `verify` exits 0 and prints `VERIFIED` on success, exits 1 and prints
//! `REJECTED: <reason>` on any failure. `demo` generates a throwaway root,
//! device and alias key, signs a quote in software, writes the JSON files
//! and verifies them (plus a tampered copy, which must be rejected).

use ai_id_verifier::*;
use p256::ecdsa::SigningKey;
use rand_core::{OsRng, RngCore};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::{SystemTime, UNIX_EPOCH};

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

fn read_json<T: serde::de::DeserializeOwned>(path: &str) -> Result<T, String> {
    let s = std::fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    serde_json::from_str(&s).map_err(|e| format!("{path}: {e}"))
}

fn cmd_verify(args: &[String]) -> Result<(), String> {
    let need = |n: &str| arg(args, n).ok_or_else(|| format!("missing {n}"));
    let quote_path = need("--quote")?;
    // An AIQ2 hardware quote also parses as a software `Quote` (serde
    // ignores the extra fields) and then fails with a misleading
    // "signature invalid". Name the right subcommand instead.
    let raw: serde_json::Value = read_json(&quote_path)?;
    if raw.get("format").and_then(|f| f.as_str()) == Some("AIQ2") {
        return Err("AIQ2 hardware quote: verify it with `verify-hw`".into());
    }
    let quote: Quote = serde_json::from_value(raw).map_err(|e| format!("{quote_path}: {e}"))?;
    let chain: Vec<Cert> = read_json(&need("--chain")?)?;
    let policy: Policy = read_json(&need("--policy")?)?;
    let nonce = hex::decode(need("--nonce")?).map_err(|e| format!("--nonce: {e}"))?;
    let now = match arg(args, "--now") {
        Some(s) => s.parse().map_err(|e| format!("--now: {e}"))?,
        None => now_secs(),
    };
    verify(&quote, &chain, &policy, &nonce, now).map_err(|e| e.to_string())
}

fn cmd_verify_hw(args: &[String]) -> Result<String, String> {
    let need = |n: &str| arg(args, n).ok_or_else(|| format!("missing {n}"));
    let quote: HwQuote = read_json(&need("--quote")?)?;
    let chain: Vec<Cert> = read_json(&need("--chain")?)?;
    let policy: HwPolicy = read_json(&need("--policy")?)?;
    let nonce = hex::decode(need("--nonce")?).map_err(|e| format!("--nonce: {e}"))?;
    let now = match arg(args, "--now") {
        Some(s) => s.parse().map_err(|e| format!("--now: {e}"))?,
        None => now_secs(),
    };
    verify_hw(&quote, &chain, &policy, &nonce, now).map_err(|e| e.to_string())?;
    Ok(format!(
        "device {} rev {} counter {} model {}",
        &quote.device_id[..16],
        quote.hw_rev,
        quote.counter,
        &quote.model_digest[..16]
    ))
}

fn write(dir: &Path, name: &str, v: &impl serde::Serialize) -> Result<String, String> {
    let p = dir.join(name);
    let s = serde_json::to_string_pretty(v).map_err(|e| e.to_string())?;
    std::fs::write(&p, s + "\n").map_err(|e| format!("{}: {e}", p.display()))?;
    Ok(p.display().to_string())
}

fn cmd_demo(args: &[String]) -> Result<(), String> {
    let dir = PathBuf::from(arg(args, "--out").unwrap_or_else(|| "demo-out".into()));
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let root = SigningKey::random(&mut OsRng);
    let device = SigningKey::random(&mut OsRng);
    let alias = SigningKey::random(&mut OsRng);
    let chain = build_chain(&[&root, &device, &alias]);

    let mut pcrs = [[0u8; 32]; NUM_PCRS];
    for (i, layer) in ["BL2", "U-Boot", "kernel", "weights", "config"]
        .iter()
        .enumerate()
    {
        let d: [u8; 32] = Sha256::digest(layer.as_bytes()).into();
        pcrs[i] = pcr_extend(&[0; 32], &d);
    }
    let model: [u8; 32] = Sha256::digest(b"example model weights").into();
    let config: [u8; 32] = Sha256::digest(b"example runtime config").into();
    let mut nonce = [0u8; 32];
    OsRng.fill_bytes(&mut nonce);
    let ts = now_secs();
    let quote = sign_quote(&alias, &nonce, &pcrs, &model, &config, ts);

    let mut want = BTreeMap::new();
    for (i, p) in pcrs.iter().enumerate().take(5) {
        want.insert(i as u8, hex::encode(p));
    }
    let policy = Policy {
        trusted_roots: vec![pubkey_hex(&root)],
        allowed_models: vec![hex::encode(model)],
        allowed_configs: vec![hex::encode(config)],
        pcrs: want,
        max_skew_secs: 300,
    };
    println!("wrote {}", write(&dir, "quote.json", &quote)?);
    println!("wrote {}", write(&dir, "chain.json", &chain)?);
    println!("wrote {}", write(&dir, "policy.json", &policy)?);
    println!("nonce {}", hex::encode(nonce));

    verify(&quote, &chain, &policy, &nonce, ts).map_err(|e| format!("genuine quote: {e}"))?;
    println!("genuine quote:  VERIFIED");

    let mut forged = quote.clone();
    forged.model_digest = hex::encode([0x66u8; 32]);
    match verify(&forged, &chain, &policy, &nonce, ts) {
        Err(e) => println!("tampered quote: REJECTED ({e})"),
        Ok(()) => return Err("tampered quote was accepted".into()),
    }
    match verify(&quote, &chain, &policy, &[0u8; 32], ts) {
        Err(e) => println!("replayed quote: REJECTED ({e})"),
        Ok(()) => return Err("replayed quote was accepted".into()),
    }
    Ok(())
}

fn usage() -> ExitCode {
    eprintln!(
        "usage:\n  ai-id-verifier verify --quote Q.json --chain C.json --policy P.json --nonce HEX [--now SECS]\n  ai-id-verifier verify-hw --quote Q.json --chain C.json --policy P.json --nonce HEX [--now SECS]\n  ai-id-verifier demo [--out DIR]"
    );
    ExitCode::from(2)
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("verify") => match cmd_verify(&args[2..]) {
            Ok(()) => {
                println!("VERIFIED");
                ExitCode::SUCCESS
            }
            Err(e) => {
                println!("REJECTED: {e}");
                ExitCode::from(1)
            }
        },
        Some("verify-hw") => match cmd_verify_hw(&args[2..]) {
            Ok(info) => {
                println!("VERIFIED hardware quote: {info}");
                ExitCode::SUCCESS
            }
            Err(e) => {
                println!("REJECTED: {e}");
                ExitCode::from(1)
            }
        },
        Some("demo") => match cmd_demo(&args[2..]) {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => {
                eprintln!("demo failed: {e}");
                ExitCode::from(1)
            }
        },
        _ => usage(),
    }
}
