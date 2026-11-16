// SPDX-License-Identifier: MIT
//! `aiid` — AI Birth Certificates and the demo vendor CA.

use ai_id_host::cert::{self, CreateOpts, Envelope, VerifyOpts};
use ai_id_host::cli::{flag, opt, read, req};
use ai_id_host::{ca, hwid, now_secs, render};
use ai_id_verifier::{Cert, HwQuote};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const USAGE: &str = "aiid — AI Birth Certificate tool (ai-id-engine v0.1.0)

USAGE:
  aiid ca init --dir DIR [--name NAME]               generate a TEST-ONLY demo vendor CA
  aiid ca issue --dir DIR --pubkey HEX --out FILE    chain for a device/SE public key
  aiid cert create --weights PATH --ca DIR --out CERT.json
        [--name N] [--arch A] [--checkpoint V] [--instance-id ID] [--container-digest D]
        [--days 365] [--attest auto|tpm|software] [--salt S]
        [--engine-quote QUOTE.json --engine-chain CHAIN.json] [--svg OUT.svg]
  aiid cert verify --cert CERT.json (--ca DIR | --root HEX) [--weights PATH]
        [--max-age SECS] [--this-machine] [--require-tpm] [--svg OUT.svg]
  aiid cert show --cert CERT.json
  aiid cert render --cert CERT.json --out OUT.svg [--ca DIR | --root HEX]

Weights are streamed through SHA-256 (file, or every weight file in a
directory). Certificates are DSSE envelopes around in-toto Statement v1.";

fn load_env(p: &str) -> Result<Envelope, String> {
    serde_json::from_str(&read(p)?).map_err(|e| format!("{p}: {e}"))
}

fn root(a: &[String]) -> Result<String, String> {
    if let Some(r) = opt(a, "--root") {
        return Ok(r);
    }
    ca::root_pub(Path::new(
        &req(a, "--ca").map_err(|_| "need --ca DIR or --root HEX".to_string())?,
    ))
}

fn write_svg(env: &Envelope, out: &str, status: &str) -> Result<(), String> {
    let st = cert::statement(env)?;
    let kid = env
        .signatures
        .first()
        .map(|s| s.keyid.clone())
        .unwrap_or_default();
    std::fs::write(out, render::svg(&st, &kid, status)).map_err(|e| format!("{out}: {e}"))?;
    eprintln!("rendered {out}");
    Ok(())
}

fn verify_cmd(a: &[String], env: &Envelope) -> Result<bool, String> {
    let o = VerifyOpts {
        trusted_root: root(a)?,
        weights: opt(a, "--weights").map(PathBuf::from),
        now: now_secs(),
        max_age_secs: opt(a, "--max-age")
            .map(|v| v.parse().map_err(|e| format!("--max-age: {e}")))
            .transpose()?,
        check_this_machine: if flag(a, "--this-machine") {
            Some(opt(a, "--salt").unwrap_or_else(|| hwid::DEFAULT_SALT.into()))
        } else {
            None
        },
        require_hardware_attestation: flag(a, "--require-tpm"),
    };
    let checks = cert::verify(env, &o);
    let ok = !checks.is_empty() && checks.iter().all(|c| c.ok);
    for c in &checks {
        println!(
            "  [{}] {:<17} {}",
            if c.ok { " OK " } else { "FAIL" },
            c.name,
            c.detail
        );
    }
    Ok(ok)
}

fn run(a: &[String]) -> Result<(), String> {
    let (c1, c2) = (
        a.first().map(String::as_str).unwrap_or(""),
        a.get(1).map(String::as_str).unwrap_or(""),
    );
    match (c1, c2) {
        ("ca", "init") => {
            let dir = req(a, "--dir")?;
            let r = ca::init(
                Path::new(&dir),
                &opt(a, "--name").unwrap_or_else(|| "AI-ID Demo Vendor CA (TEST-ONLY)".into()),
            )?;
            println!("{r}");
            eprintln!("TEST-ONLY CA created in {dir} (ca.key/issuer.key are 0600; never commit them). Root public key above.");
            Ok(())
        }
        ("ca", "issue") => {
            let ch = ca::issue(
                Path::new(&req(a, "--dir")?),
                &req(a, "--pubkey")?,
                Path::new(&req(a, "--out")?),
            )?;
            eprintln!("chain of {} certs written", ch.len());
            Ok(())
        }
        ("cert", "create") => {
            let dir = PathBuf::from(req(a, "--ca")?);
            let chain: Vec<Cert> =
                serde_json::from_str(&read(&dir.join("issuer.chain.json").to_string_lossy())?)
                    .map_err(|e| e.to_string())?;
            let ca_meta: serde_json::Value =
                serde_json::from_str(&read(&dir.join("ca.json").to_string_lossy())?)
                    .unwrap_or_default();
            let engine_quote = match (opt(a, "--engine-quote"), opt(a, "--engine-chain")) {
                (Some(q), Some(c)) => {
                    let q: HwQuote =
                        serde_json::from_str(&read(&q)?).map_err(|e| format!("{q}: {e}"))?;
                    let c: Vec<Cert> =
                        serde_json::from_str(&read(&c)?).map_err(|e| e.to_string())?;
                    Some((q, c))
                }
                (None, None) => None,
                _ => return Err("--engine-quote and --engine-chain go together".into()),
            };
            let out = req(a, "--out")?;
            let weights = PathBuf::from(req(a, "--weights")?);
            eprintln!("hashing {} …", weights.display());
            let env = cert::create(CreateOpts {
                weights,
                name: opt(a, "--name"),
                arch: opt(a, "--arch"),
                checkpoint: opt(a, "--checkpoint"),
                instance_id: opt(a, "--instance-id"),
                container_digest: opt(a, "--container-digest"),
                issuer_key: ca::load_key(&dir.join("issuer.key"))?,
                issuer_chain: chain,
                issuer_name: ca_meta["name"]
                    .as_str()
                    .unwrap_or("AI-ID Demo Vendor CA (TEST-ONLY)")
                    .to_string(),
                validity_days: opt(a, "--days")
                    .map(|d| d.parse().map_err(|e| format!("--days: {e}")))
                    .unwrap_or(Ok(365))?,
                attest_mode: opt(a, "--attest").unwrap_or_else(|| "auto".into()),
                hwid_salt: opt(a, "--salt").unwrap_or_else(|| hwid::DEFAULT_SALT.into()),
                engine_quote,
                now: now_secs(),
            })?;
            std::fs::write(
                &out,
                serde_json::to_string_pretty(&env).map_err(|e| e.to_string())? + "\n",
            )
            .map_err(|e| format!("{out}: {e}"))?;
            let st = cert::statement(&env)?;
            let p = &st["predicate"];
            println!(
                "{} written to {out}",
                p["certificate_id"].as_str().unwrap_or("")
            );
            println!(
                "  model        {} ({})",
                p["model"]["name"].as_str().unwrap_or(""),
                p["model"]["architecture"].as_str().unwrap_or("")
            );
            println!(
                "  weights      sha256:{}  ({} bytes)",
                p["model"]["weights_sha256"].as_str().unwrap_or(""),
                p["model"]["weights_total_bytes"]
            );
            println!(
                "  instance     {}",
                p["deployment"]["instance_id"].as_str().unwrap_or("")
            );
            println!(
                "  environment  {}",
                p["environment"]["digest"].as_str().unwrap_or("")
            );
            println!(
                "  hwid         {}",
                p["hardware"]["hwid_short"].as_str().unwrap_or("")
            );
            println!(
                "  attestation  {}{}",
                p["hardware"]["attestation"]["kind"].as_str().unwrap_or(""),
                if p["hardware"]["attestation"]["hardware_backed"] == true {
                    ""
                } else if p["hardware"]["attestation"]["kind"] == "tpm2-quote" {
                    "  (SIMULATED TPM, not hardware-backed)"
                } else {
                    "  (SOFTWARE FALLBACK, not hardware-backed)"
                }
            );
            if !p["engine_quote"].is_null() {
                println!(
                    "  engine quote AIQ2 from device {}",
                    p["engine_quote"]["quote"]["device_id"]
                        .as_str()
                        .unwrap_or("")
                );
            }
            if let Some(svg) = opt(a, "--svg") {
                write_svg(&env, &svg, "SIGNED")?;
            }
            Ok(())
        }
        ("cert", "verify") => {
            let path = req(a, "--cert")?;
            let env = load_env(&path)?;
            println!("Verifying {path}");
            let ok = verify_cmd(a, &env)?;
            if let Some(svg) = opt(a, "--svg") {
                write_svg(&env, &svg, if ok { "VERIFIED" } else { "INVALID" })?;
            }
            if ok {
                println!("CERTIFICATE VALID");
                Ok(())
            } else {
                Err("CERTIFICATE INVALID".into())
            }
        }
        ("cert", "show") => {
            let env = load_env(&req(a, "--cert")?)?;
            println!(
                "{}",
                serde_json::to_string_pretty(&cert::statement(&env)?).map_err(|e| e.to_string())?
            );
            Ok(())
        }
        ("cert", "render") => {
            let env = load_env(&req(a, "--cert")?)?;
            let status = if opt(a, "--ca").is_some() || opt(a, "--root").is_some() {
                if verify_cmd(a, &env)? {
                    "VERIFIED"
                } else {
                    "INVALID"
                }
            } else {
                "UNVERIFIED"
            };
            write_svg(&env, &req(a, "--out")?, status)
        }
        ("-h" | "--help" | "help" | "", _) => {
            println!("{USAGE}");
            Ok(())
        }
        ("--version" | "version", _) => {
            println!("aiid {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        _ => Err(format!("unknown command {:?}\n\n{USAGE}", a.join(" "))),
    }
}

fn main() -> ExitCode {
    let a: Vec<String> = std::env::args().skip(1).collect();
    match run(&a) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("aiid: {e}");
            ExitCode::FAILURE
        }
    }
}
