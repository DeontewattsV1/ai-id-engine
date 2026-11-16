// SPDX-License-Identifier: MIT
// End-to-end CLI test: demo writes quote/chain/policy JSON, then the
// `verify` subcommand must accept them and reject a tampered quote.
use std::process::Command;

fn bin() -> Command {
    Command::new(env!("CARGO_BIN_EXE_ai-id-verifier"))
}

#[test]
fn demo_then_verify_via_files() {
    let dir = std::env::temp_dir().join(format!("ai-id-cli-{}", std::process::id()));
    let out = bin().args(["demo", "--out"]).arg(&dir).output().unwrap();
    let stdout = String::from_utf8_lossy(&out.stdout).to_string();
    assert!(out.status.success(), "demo failed: {stdout}");
    assert!(stdout.contains("genuine quote:  VERIFIED"));
    assert!(stdout.contains("tampered quote: REJECTED"));
    let nonce = stdout
        .lines()
        .find_map(|l| l.strip_prefix("nonce "))
        .expect("nonce line")
        .to_string();
    let p = |n: &str| dir.join(n).display().to_string();

    let ok = bin()
        .args(["verify", "--quote", &p("quote.json"), "--chain", &p("chain.json")])
        .args(["--policy", &p("policy.json"), "--nonce", &nonce])
        .output()
        .unwrap();
    assert!(ok.status.success());
    assert_eq!(String::from_utf8_lossy(&ok.stdout).trim(), "VERIFIED");

    // tamper with the quote file on disk
    let q = std::fs::read_to_string(dir.join("quote.json")).unwrap();
    let mut v: serde_json::Value = serde_json::from_str(&q).unwrap();
    v["timestamp"] = serde_json::json!(v["timestamp"].as_u64().unwrap() + 1);
    std::fs::write(dir.join("bad.json"), v.to_string()).unwrap();
    let bad = bin()
        .args(["verify", "--quote", &p("bad.json"), "--chain", &p("chain.json")])
        .args(["--policy", &p("policy.json"), "--nonce", &nonce])
        .output()
        .unwrap();
    assert_eq!(bad.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&bad.stdout).starts_with("REJECTED"));

    let usage = bin().output().unwrap();
    assert_eq!(usage.status.code(), Some(2));
    let _ = std::fs::remove_dir_all(&dir);
}
