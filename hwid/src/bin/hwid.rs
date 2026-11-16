// SPDX-License-Identifier: MIT
//! `hwid` — privacy-preserving hardware ID, offline activation and host
//! attestation. Reads identifiers only; it never modifies or spoofs them.

use ai_id_host::cli::{flag, opt, read, req};
use ai_id_host::{attest, hwid, license, now_secs};
use std::process::ExitCode;

const USAGE: &str = "hwid — privacy-preserving hardware ID tool (ai-id-engine v0.1.0)

USAGE:
  hwid show [--salt S] [--reveal] [--json]          HWID + the component list it is built from
  hwid challenge [--product N] [--salt S]            offline-activation challenge code
  hwid license keygen --out vendor.key              TEST vendor Ed25519 key (prints public key)
  hwid license issue --key vendor.key --challenge CODE [--days N] [--features N]
  hwid license verify --pub HEX --response CODE [--product N] [--salt S] [--challenge CODE]
  hwid attest [--nonce HEX] [--mode auto|tpm|software] [--salt S] [--out FILE]
  hwid verify-attest --in FILE --nonce HEX [--hwid HEX] [--soft-key HEX]
  hwid match --ref FILE [--salt S] [--min N]         fuzzy compare with a saved `show --json`

The salt makes IDs unlinkable across products (default: ai-id-engine/default).
Raw identifiers are only printed with --reveal. TPM 2.0 is used via tpm2-tools
when present (TPM2TOOLS_TCTI respected); otherwise a clearly marked software
fallback key is used.";

fn salt(a: &[String]) -> String {
    opt(a, "--salt").unwrap_or_else(|| hwid::DEFAULT_SALT.into())
}

fn product(a: &[String]) -> Result<u16, String> {
    opt(a, "--product")
        .map(|p| p.parse::<u16>().map_err(|e| format!("--product: {e}")))
        .unwrap_or(Ok(1))
}

fn run(a: &[String]) -> Result<(), String> {
    let cmd = a.first().map(String::as_str).unwrap_or("");
    match cmd {
        "show" => {
            let h = hwid::this_machine(&salt(a), flag(a, "--reveal"))?;
            if flag(a, "--json") {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&h).map_err(|e| e.to_string())?
                );
                return Ok(());
            }
            println!("HWID       {}", h.hwid);
            println!("Short      {}", h.short);
            println!(
                "OS         {}   salt-id {}   format v{}",
                h.os, h.salt_id, h.version
            );
            println!("Components ({}):", h.components.len());
            for c in &h.components {
                let v = c
                    .value
                    .as_deref()
                    .map(|v| format!("  = {v}"))
                    .unwrap_or_default();
                println!("  {:<24} {}…  [{}]{}", c.name, &c.hash[..16], c.source, v);
            }
            println!("Raw values are salted+hashed; pass --reveal to print them locally.");
            Ok(())
        }
        "challenge" => {
            let h = hwid::this_machine(&salt(a), false)?;
            let ch = license::Challenge::from_hwid(product(a)?, &h.hwid)?;
            println!("{}", ch.code());
            eprintln!(
                "Send this code to the vendor; enter the response with `hwid license verify`."
            );
            Ok(())
        }
        "license" => match a.get(1).map(String::as_str).unwrap_or("") {
            "keygen" => {
                let out = req(a, "--out")?;
                let k = ed25519_dalek::SigningKey::generate(&mut rand_core::OsRng);
                ai_id_host::write_private(
                    std::path::Path::new(&out),
                    hex::encode(k.to_bytes()).as_bytes(),
                )
                .map_err(|e| format!("{out}: {e}"))?;
                println!("{}", hex::encode(k.verifying_key().to_bytes()));
                eprintln!("TEST vendor key written to {out} (0600); public key above.");
                Ok(())
            }
            "issue" => {
                let k = license::parse_vendor_key(read(&req(a, "--key")?)?.trim())?;
                let ch = license::Challenge::parse(&req(a, "--challenge")?)?;
                let days: u64 = opt(a, "--days")
                    .map(|d| d.parse().map_err(|e| format!("--days: {e}")))
                    .unwrap_or(Ok(365))?;
                let feat: u16 = opt(a, "--features")
                    .map(|d| d.parse().map_err(|e| format!("--features: {e}")))
                    .unwrap_or(Ok(1))?;
                let exp = if days == 0 {
                    0
                } else {
                    license::expiry_in(now_secs(), days)
                };
                let l = license::issue(&k, &ch, exp, feat);
                println!("{}", l.code());
                eprintln!(
                    "product {} · expires {} · features {:#06x}",
                    ch.product,
                    l.expiry_string(),
                    feat
                );
                Ok(())
            }
            "verify" => {
                let vk = license::parse_vendor_pub(&req(a, "--pub")?)?;
                let l = license::License::parse(&req(a, "--response")?)?;
                let ch = match opt(a, "--challenge") {
                    Some(c) => license::Challenge::parse(&c)?,
                    None => license::Challenge::from_hwid(
                        product(a)?,
                        &hwid::this_machine(&salt(a), false)?.hwid,
                    )?,
                };
                l.verify(&vk, &ch, now_secs())?;
                println!(
                    "LICENSE OK  product {}  expires {}  features {:#06x}",
                    ch.product,
                    l.expiry_string(),
                    l.features
                );
                Ok(())
            }
            _ => Err("usage: hwid license keygen|issue|verify".into()),
        },
        "attest" => {
            let h = hwid::this_machine(&salt(a), false)?;
            let nonce = match opt(a, "--nonce") {
                Some(n) => hex::decode(n).map_err(|e| format!("--nonce: {e}"))?,
                None => {
                    let mut n = [0u8; 32];
                    rand_core::RngCore::fill_bytes(&mut rand_core::OsRng, &mut n);
                    n.to_vec()
                }
            };
            let mode = opt(a, "--mode").unwrap_or_else(|| "auto".into());
            let at = attest::attest(&nonce, &h.hwid, &mode)?;
            if let Some(w) = &at.warning {
                eprintln!("WARNING: {w}");
            }
            let s = serde_json::to_string_pretty(&at).map_err(|e| e.to_string())?;
            match opt(a, "--out") {
                Some(o) => {
                    std::fs::write(&o, s + "\n").map_err(|e| format!("{o}: {e}"))?;
                    eprintln!("{} evidence written to {o} (nonce {})", at.kind, at.nonce);
                }
                None => println!("{s}"),
            }
            Ok(())
        }
        "verify-attest" => {
            let at: attest::Attestation =
                serde_json::from_str(&read(&req(a, "--in")?)?).map_err(|e| e.to_string())?;
            let nonce = hex::decode(req(a, "--nonce")?).map_err(|e| format!("--nonce: {e}"))?;
            let hw = opt(a, "--hwid").unwrap_or_else(|| at.hwid.clone());
            let d = attest::verify(&at, &nonce, &hw, opt(a, "--soft-key").as_deref())?;
            println!("ATTESTATION OK  {d}");
            if !at.hardware_backed {
                println!(
                    "NOTE: not hardware-backed ({})",
                    at.warning.as_deref().unwrap_or(&at.kind)
                );
            }
            Ok(())
        }
        "match" => {
            let r: hwid::Hwid =
                serde_json::from_str(&read(&req(a, "--ref")?)?).map_err(|e| e.to_string())?;
            let cur = hwid::this_machine(&salt(a), false)?;
            if r.salt_id != cur.salt_id {
                return Err("reference was made with a different salt".into());
            }
            let (m, n) = hwid::similarity(&r, &cur);
            let min: usize = opt(a, "--min")
                .map(|v| v.parse().unwrap_or(n))
                .unwrap_or(n.div_ceil(2).max(1));
            println!(
                "{m}/{n} components match (exact HWID {})",
                if r.hwid == cur.hwid {
                    "equal"
                } else {
                    "differs"
                }
            );
            if m >= min {
                println!("MATCH");
                Ok(())
            } else {
                Err(format!("NO MATCH (need {min})"))
            }
        }
        "-h" | "--help" | "help" | "" => {
            println!("{USAGE}");
            Ok(())
        }
        "--version" | "version" => {
            println!("hwid {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        other => Err(format!("unknown command {other:?}\n\n{USAGE}")),
    }
}

fn main() -> ExitCode {
    let a: Vec<String> = std::env::args().skip(1).collect();
    match run(&a) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("hwid: {e}");
            ExitCode::FAILURE
        }
    }
}
