// SPDX-License-Identifier: MIT
//! End-to-end birth-certificate flows using the library (software attestation).

use ai_id_host::{ca, cert, hwid, now_secs};
use ai_id_verifier::{issue_cert, pcr_extend, sign_hw_quote, Cert, HwQuote};
use p256::ecdsa::SigningKey;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard};

// Tests set the process-global AIID_HOME; serialize them so one test never
// reads the software-attestation key another test is still writing.
static ENV_LOCK: Mutex<()> = Mutex::new(());

fn env_lock() -> MutexGuard<'static, ()> {
    ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner())
}

fn tmp(name: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("aiid-test-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn setup(name: &str) -> (PathBuf, PathBuf) {
    let d = tmp(name);
    std::env::set_var("AIID_HOME", d.join("home"));
    let model = d.join("model");
    std::fs::create_dir_all(&model).unwrap();
    std::fs::write(model.join("model.safetensors"), vec![7u8; 300_000]).unwrap();
    std::fs::write(
        model.join("config.json"),
        r#"{"architectures":["TinyNet"],"hidden_size":8}"#,
    )
    .unwrap();
    ca::init(&d.join("ca"), "Test CA").unwrap();
    (d, model)
}

fn create(
    d: &Path,
    model: &Path,
    engine: Option<(HwQuote, Vec<Cert>)>,
    now: u64,
) -> cert::Envelope {
    let chain: Vec<Cert> =
        serde_json::from_str(&std::fs::read_to_string(d.join("ca/issuer.chain.json")).unwrap())
            .unwrap();
    cert::create(cert::CreateOpts {
        weights: model.to_path_buf(),
        name: None,
        arch: None,
        checkpoint: Some("v1".into()),
        instance_id: Some("inst-test".into()),
        container_digest: Some("sha256:abc".into()),
        issuer_key: ca::load_key(&d.join("ca/issuer.key")).unwrap(),
        issuer_chain: chain,
        issuer_name: "Test CA".into(),
        validity_days: 30,
        attest_mode: "software".into(),
        hwid_salt: hwid::DEFAULT_SALT.into(),
        engine_quote: engine,
        now,
    })
    .unwrap()
}

fn vopts(d: &Path, weights: Option<PathBuf>, now: u64) -> cert::VerifyOpts {
    cert::VerifyOpts {
        trusted_root: ca::root_pub(&d.join("ca")).unwrap(),
        weights,
        now,
        max_age_secs: None,
        check_this_machine: Some(hwid::DEFAULT_SALT.into()),
        require_hardware_attestation: false,
    }
}

fn all_ok(c: &[cert::Check]) -> bool {
    c.iter().all(|x| x.ok)
}

fn failed(c: &[cert::Check]) -> Vec<String> {
    c.iter().filter(|x| !x.ok).map(|x| x.name.clone()).collect()
}

#[test]
fn create_verify_and_negative_cases() {
    let _env = env_lock();
    let (d, model) = setup("flow");
    let now = now_secs();
    let env = create(&d, &model, None, now);
    let st = cert::statement(&env).unwrap();
    assert_eq!(st["predicate"]["model"]["architecture"], "TinyNet");
    assert_eq!(st["subject"].as_array().unwrap().len(), 1);
    let r = cert::verify(&env, &vopts(&d, Some(model.clone()), now));
    assert!(all_ok(&r), "{:?}", failed(&r));

    // require TPM -> software fallback must fail
    let mut o = vopts(&d, None, now);
    o.require_hardware_attestation = true;
    assert_eq!(failed(&cert::verify(&env, &o)), vec!["host attestation"]);

    // expired
    assert_eq!(
        failed(&cert::verify(&env, &vopts(&d, None, now + 31 * 86_400))),
        vec!["freshness"]
    );

    // modified weights
    std::fs::write(model.join("model.safetensors"), vec![8u8; 300_000]).unwrap();
    assert_eq!(
        failed(&cert::verify(&env, &vopts(&d, Some(model.clone()), now))),
        vec!["weights"]
    );

    // untrusted root
    ca::init(&d.join("ca2"), "Other").unwrap();
    let mut o = vopts(&d, None, now);
    o.trusted_root = ca::root_pub(&d.join("ca2")).unwrap();
    assert_eq!(failed(&cert::verify(&env, &o)), vec!["signature"]);

    // edited payload
    let mut bad = env.clone();
    let mut v = st.clone();
    v["predicate"]["deployment"]["instance_id"] = "inst-evil".into();
    use base64::Engine;
    bad.payload = base64::engine::general_purpose::STANDARD.encode(serde_json::to_vec(&v).unwrap());
    assert_eq!(
        failed(&cert::verify(&bad, &vopts(&d, None, now))),
        vec!["signature"]
    );
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn engine_quote_is_checked() {
    let _env = env_lock();
    let (d, model) = setup("engine");
    let now = now_secs();
    let (_, wsha, _) = cert::hash_weights(&model).unwrap();
    let mut wd = [0u8; 32];
    hex::decode_to_slice(&wsha, &mut wd).unwrap();
    let mut pcrs = vec![0u8; 32 * 16];
    pcrs[64..96].copy_from_slice(&pcr_extend(&[0u8; 32], &wd));
    let root = ca::load_key(&d.join("ca/ca.key")).unwrap();
    let se = SigningKey::random(&mut rand_core::OsRng);
    let chain = vec![issue_cert(&root, &root), issue_cert(&root, &se)];
    let mk = |model_digest: &str, pcrs: &[u8]| {
        let mut q = HwQuote {
            format: "AIQ2".into(),
            hw_rev: "A1".into(),
            lifecycle: 2,
            tamper: 0,
            counter: 1,
            timestamp: now,
            device_id: hex::encode([0x42u8; 32]),
            nonce: hex::encode([9u8; 32]),
            pcrs: hex::encode(pcrs),
            model_digest: model_digest.into(),
            config_digest: hex::encode([0u8; 32]),
            sig: String::new(),
            se_pubkey: None,
            body_sha256: None,
            source: None,
        };
        sign_hw_quote(&se, &mut q).unwrap();
        q
    };
    let env = create(&d, &model, Some((mk(&wsha, &pcrs), chain.clone())), now);
    let r = cert::verify(&env, &vopts(&d, Some(model.clone()), now));
    assert!(all_ok(&r), "{:?}", failed(&r));
    assert!(r.iter().any(|c| c.name == "engine quote"));

    // engine measured different weights
    let env = create(
        &d,
        &model,
        Some((mk(&hex::encode([1u8; 32]), &pcrs), chain.clone())),
        now,
    );
    assert_eq!(
        failed(&cert::verify(&env, &vopts(&d, None, now))),
        vec!["engine quote"]
    );

    // PCR2 does not reflect the weights
    let env = create(&d, &model, Some((mk(&wsha, &vec![0u8; 512]), chain)), now);
    assert_eq!(
        failed(&cert::verify(&env, &vopts(&d, None, now))),
        vec!["engine quote"]
    );
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn multi_file_manifest_digest() {
    let _env = env_lock();
    let d = tmp("multi");
    std::fs::write(d.join("a.bin"), b"aaa").unwrap();
    std::fs::write(d.join("b.safetensors"), b"bbb").unwrap();
    std::fs::write(d.join("README.md"), b"ignored").unwrap();
    let (files, agg, total) = cert::hash_weights(&d).unwrap();
    assert_eq!(files.len(), 2);
    assert_eq!(total, 6);
    let manifest: String = files
        .iter()
        .map(|f| format!("{}  {}\n", f.sha256, f.name))
        .collect();
    use sha2::Digest;
    assert_eq!(agg, hex::encode(sha2::Sha256::digest(manifest.as_bytes())));
    let _ = std::fs::remove_dir_all(&d);
}
