// SPDX-License-Identifier: MIT
//! Host-side tools for the AI identity engine.
//!
//! * [`hwid`]    privacy-preserving machine hardware ID (salted SHA-256)
//! * [`code`]    Crockford base32 codes with a mod-37 check symbol
//! * [`license`] offline-activation challenge / signed response codes (Ed25519)
//! * [`attest`]  TPM 2.0 quote (EK/AK via tpm2-tools) or software fallback
//! * [`ca`]      demo vendor CA (TEST-ONLY keys generated at runtime)
//! * [`envinfo`] runtime environment digest
//! * [`cert`]    AI Birth Certificate: in-toto statement in a DSSE envelope
//! * [`render`]  SVG rendering of a certificate
//!
//! Identification and attestation only: nothing here alters, hides or
//! spoofs hardware identifiers.

pub mod attest;
pub mod ca;
pub mod cert;
pub mod cli;
pub mod code;
pub mod envinfo;
pub mod hwid;
pub mod license;
pub mod render;

use sha2::{Digest, Sha256};

/// SHA-256 helper.
pub fn sha256(data: &[u8]) -> [u8; 32] {
    Sha256::digest(data).into()
}

/// Seconds since the Unix epoch.
pub fn now_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// RFC 3339 UTC timestamp for a Unix time (no external date crate).
pub fn rfc3339(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (y, m, d) = civil_from_days(days);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3600,
        (rem / 60) % 60,
        rem % 60
    )
}

/// Howard Hinnant's days -> civil date algorithm.
pub fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// Writes a file readable only by the owner (best effort on non-Unix).
pub fn write_private(path: &std::path::Path, data: &[u8]) -> std::io::Result<()> {
    #[cfg(unix)]
    {
        use std::io::Write;
        use std::os::unix::fs::OpenOptionsExt;
        let mut f = std::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(path)?;
        f.write_all(data)
    }
    #[cfg(not(unix))]
    {
        std::fs::write(path, data)
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn rfc3339_known_dates() {
        assert_eq!(super::rfc3339(0), "1970-01-01T00:00:00Z");
        assert_eq!(super::rfc3339(1_763_270_000), "2025-11-16T05:13:20Z");
        assert_eq!(super::rfc3339(951_782_400), "2000-02-29T00:00:00Z");
    }
}
