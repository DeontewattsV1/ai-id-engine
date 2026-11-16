// SPDX-License-Identifier: MIT
//! ECDSA P-256/SHA-256 known answers (RFC 6979 A.2.5) for the p256 crate that
//! aiid uses for DSSE birth-certificate and CA signatures.
use p256::ecdsa::signature::{Signer, Verifier};
use p256::ecdsa::{Signature, SigningKey, VerifyingKey};

fn h(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

const X: &str = "c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721";
const UXY: &str = "0460fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299";
const V: [(&str, &str, &str); 2] = [
    (
        "sample",
        "efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716",
        "f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8",
    ),
    (
        "test",
        "f1abb023518351cd71d881567b1ea663ed3efcf6c5132b354f28d3b0b7d38367",
        "019f4113742a2b14bd25926b49c649155f267e60d3814b4c0cc84250e46f0083",
    ),
];

#[test]
fn rfc6979_p256_sha256() {
    let sk = SigningKey::from_slice(&h(X)).unwrap();
    let vk = VerifyingKey::from_sec1_bytes(&h(UXY)).unwrap();
    assert_eq!(sk.verifying_key(), &vk, "public key");
    for (msg, r, s) in V {
        let want = Signature::from_scalars(
            <[u8; 32]>::try_from(h(r)).unwrap(),
            <[u8; 32]>::try_from(h(s)).unwrap(),
        )
        .unwrap();
        let got: Signature = sk.sign(msg.as_bytes());
        assert_eq!(got, want, "deterministic signature for {msg}");
        assert!(vk.verify(msg.as_bytes(), &want).is_ok());
        assert!(vk.verify(b"tampered", &want).is_err());
    }
}
