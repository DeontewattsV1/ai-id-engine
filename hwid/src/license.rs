// SPDX-License-Identifier: MIT
//! Offline activation ("challenge code" / "response code").
//!
//! Challenge (10 bytes, 17 symbols): `ver:4 | product:12 | HWID[0..8]`,
//! shown as `XXXX-XXXX-XXXX-XXXX-C` (Crockford base32 + mod-37 check).
//! The user carries it to any online machine; the vendor signs
//!
//!   msg = "AIID-LIC-V1" || challenge(10) || expiry_day(u16 BE) || features(u16 BE)
//!
//! with Ed25519 and returns the response code = base32(expiry || features ||
//! signature) + check symbol (110 symbols, grouped by 5). The offline
//! machine verifies the signature with the vendor public key and that the
//! challenge equals the one recomputed from its own HWID. expiry_day counts
//! days since 2020-01-01 (0 = perpetual).

use crate::code;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};

pub const CHALLENGE_LEN: usize = 10;
pub const RESPONSE_LEN: usize = 68;
const PREFIX: &[u8] = b"AIID-LIC-V1";
const VERSION: u8 = 1;
/// 2020-01-01T00:00:00Z
pub const EPOCH_2020: u64 = 1_577_836_800;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Challenge {
    pub product: u16,
    pub hwid_prefix: [u8; 8],
}

impl Challenge {
    pub fn from_hwid(product: u16, hwid_hex: &str) -> Result<Self, String> {
        if product > 0x0FFF {
            return Err("product id must be <= 4095".into());
        }
        let h = hex::decode(hwid_hex).map_err(|e| format!("hwid: {e}"))?;
        if h.len() < 8 {
            return Err("hwid too short".into());
        }
        let mut p = [0u8; 8];
        p.copy_from_slice(&h[..8]);
        Ok(Challenge {
            product,
            hwid_prefix: p,
        })
    }

    pub fn bytes(&self) -> [u8; CHALLENGE_LEN] {
        let mut b = [0u8; CHALLENGE_LEN];
        let head = ((VERSION as u16) << 12) | self.product;
        b[..2].copy_from_slice(&head.to_be_bytes());
        b[2..].copy_from_slice(&self.hwid_prefix);
        b
    }

    pub fn code(&self) -> String {
        code::encode(&self.bytes(), 4)
    }

    pub fn parse(c: &str) -> Result<Self, String> {
        let b = code::decode(c, CHALLENGE_LEN)?;
        let head = u16::from_be_bytes([b[0], b[1]]);
        if (head >> 12) as u8 != VERSION {
            return Err(format!("unsupported challenge version {}", head >> 12));
        }
        let mut p = [0u8; 8];
        p.copy_from_slice(&b[2..]);
        Ok(Challenge {
            product: head & 0x0FFF,
            hwid_prefix: p,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct License {
    pub expiry_day: u16,
    pub features: u16,
    pub sig: [u8; 64],
}

fn message(ch: &Challenge, expiry_day: u16, features: u16) -> Vec<u8> {
    let mut m = PREFIX.to_vec();
    m.extend_from_slice(&ch.bytes());
    m.extend_from_slice(&expiry_day.to_be_bytes());
    m.extend_from_slice(&features.to_be_bytes());
    m
}

/// Vendor side: sign a response for a challenge.
pub fn issue(vendor: &SigningKey, ch: &Challenge, expiry_day: u16, features: u16) -> License {
    let sig = vendor.sign(&message(ch, expiry_day, features));
    License {
        expiry_day,
        features,
        sig: sig.to_bytes(),
    }
}

impl License {
    pub fn code(&self) -> String {
        let mut b = Vec::with_capacity(RESPONSE_LEN);
        b.extend_from_slice(&self.expiry_day.to_be_bytes());
        b.extend_from_slice(&self.features.to_be_bytes());
        b.extend_from_slice(&self.sig);
        code::encode(&b, 5)
    }

    pub fn parse(c: &str) -> Result<Self, String> {
        let b = code::decode(c, RESPONSE_LEN)?;
        let mut sig = [0u8; 64];
        sig.copy_from_slice(&b[4..]);
        Ok(License {
            expiry_day: u16::from_be_bytes([b[0], b[1]]),
            features: u16::from_be_bytes([b[2], b[3]]),
            sig,
        })
    }

    /// Verifies the vendor signature for `ch` and the expiry at `now`.
    pub fn verify(&self, vendor: &VerifyingKey, ch: &Challenge, now: u64) -> Result<(), String> {
        let sig = Signature::from_bytes(&self.sig);
        vendor
            .verify(&message(ch, self.expiry_day, self.features), &sig)
            .map_err(|_| {
                "response code was not issued for this machine/product by this vendor key"
                    .to_string()
            })?;
        if self.expiry_day != 0 {
            let today = (now.saturating_sub(EPOCH_2020) / 86_400) as u16;
            if today > self.expiry_day {
                return Err(format!(
                    "license expired (day {} > {})",
                    today, self.expiry_day
                ));
            }
        }
        Ok(())
    }

    pub fn expiry_string(&self) -> String {
        if self.expiry_day == 0 {
            "perpetual".into()
        } else {
            crate::rfc3339(EPOCH_2020 + self.expiry_day as u64 * 86_400)[..10].to_string()
        }
    }
}

/// Days-since-2020 for "now + days".
pub fn expiry_in(now: u64, days: u64) -> u16 {
    ((now.saturating_sub(EPOCH_2020)) / 86_400 + days).min(u16::MAX as u64) as u16
}

pub fn parse_vendor_pub(hex_str: &str) -> Result<VerifyingKey, String> {
    let b = hex::decode(hex_str.trim()).map_err(|e| format!("vendor public key: {e}"))?;
    let a: [u8; 32] = b
        .try_into()
        .map_err(|_| "vendor public key must be 32 bytes".to_string())?;
    VerifyingKey::from_bytes(&a).map_err(|e| format!("vendor public key: {e}"))
}

pub fn parse_vendor_key(hex_str: &str) -> Result<SigningKey, String> {
    let line = hex_str
        .lines()
        .find(|l| !l.starts_with('#') && !l.trim().is_empty())
        .unwrap_or("");
    let b = hex::decode(line.trim()).map_err(|e| format!("vendor key: {e}"))?;
    let a: [u8; 32] = b
        .try_into()
        .map_err(|_| "vendor key must be 32 bytes".to_string())?;
    Ok(SigningKey::from_bytes(&a))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vendor() -> SigningKey {
        SigningKey::from_bytes(&[7u8; 32])
    }
    const HWID: &str = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90";

    #[test]
    fn challenge_round_trip() {
        let c = Challenge::from_hwid(42, HWID).unwrap();
        let code = c.code();
        assert_eq!(code.len(), 21); // 17 symbols + 4 dashes
        assert_eq!(Challenge::parse(&code).unwrap(), c);
    }

    #[test]
    fn response_verifies_only_for_matching_machine() {
        let c = Challenge::from_hwid(42, HWID).unwrap();
        let now = EPOCH_2020 + 2000 * 86_400;
        let lic = issue(&vendor(), &c, expiry_in(now, 30), 0x0003);
        let parsed = License::parse(&lic.code()).unwrap();
        assert_eq!(parsed, lic);
        assert!(parsed.verify(&vendor().verifying_key(), &c, now).is_ok());
        let other = Challenge::from_hwid(42, &HWID.replace('a', "b")).unwrap();
        assert!(parsed
            .verify(&vendor().verifying_key(), &other, now)
            .is_err());
        let other_product = Challenge::from_hwid(43, HWID).unwrap();
        assert!(parsed
            .verify(&vendor().verifying_key(), &other_product, now)
            .is_err());
    }

    #[test]
    fn expiry_and_wrong_vendor() {
        let c = Challenge::from_hwid(1, HWID).unwrap();
        let now = EPOCH_2020 + 100 * 86_400;
        let lic = issue(&vendor(), &c, expiry_in(now, 1), 0);
        assert!(lic
            .verify(&vendor().verifying_key(), &c, now + 3 * 86_400)
            .is_err());
        let evil = SigningKey::from_bytes(&[9u8; 32]);
        assert!(lic.verify(&evil.verifying_key(), &c, now).is_err());
        let perpetual = issue(&vendor(), &c, 0, 0);
        assert!(perpetual
            .verify(&vendor().verifying_key(), &c, u64::MAX / 2)
            .is_ok());
    }

    #[test]
    fn tampered_feature_bits_fail() {
        let c = Challenge::from_hwid(1, HWID).unwrap();
        let mut lic = issue(&vendor(), &c, 0, 0x0001);
        lic.features = 0xFFFF;
        assert!(lic.verify(&vendor().verifying_key(), &c, 0).is_err());
    }
}
