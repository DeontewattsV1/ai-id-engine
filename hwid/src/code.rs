// SPDX-License-Identifier: MIT
//! Human-readable codes: Crockford base32 (no I, L, O, U) with the
//! Crockford mod-37 check symbol, grouped with dashes. Decoding is
//! case-insensitive, maps I/L to 1 and O to 0, and ignores dashes/spaces.

const ALPHA: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const CHECK: &[u8; 37] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ*~$=U";

/// mod-37 of a big-endian byte string.
fn mod37(bytes: &[u8]) -> usize {
    bytes
        .iter()
        .fold(0usize, |acc, &b| (acc * 256 + b as usize) % 37)
}

/// Encodes bytes as base32 (5 bits per symbol, MSB first, zero-padded).
pub fn b32(bytes: &[u8]) -> String {
    let nbits = bytes.len() * 8;
    let nsym = nbits.div_ceil(5);
    let mut out = String::with_capacity(nsym);
    for i in 0..nsym {
        let mut v = 0u8;
        for j in 0..5 {
            let bit = i * 5 + j;
            let b = if bit < nbits {
                (bytes[bit / 8] >> (7 - bit % 8)) & 1
            } else {
                0
            };
            v = (v << 1) | b;
        }
        out.push(ALPHA[v as usize] as char);
    }
    out
}

fn sym_val(c: char) -> Option<u8> {
    let c = c.to_ascii_uppercase();
    let c = match c {
        'I' | 'L' => '1',
        'O' => '0',
        c => c,
    };
    ALPHA.iter().position(|&a| a as char == c).map(|p| p as u8)
}

/// Decodes `nbytes` bytes from base32 symbols.
pub fn unb32(s: &str, nbytes: usize) -> Result<Vec<u8>, String> {
    let vals: Vec<u8> = s
        .chars()
        .map(|c| sym_val(c).ok_or_else(|| format!("invalid code character {c:?}")))
        .collect::<Result<_, _>>()?;
    if vals.len() != (nbytes * 8).div_ceil(5) {
        return Err(format!(
            "code has {} symbols, expected {}",
            vals.len(),
            (nbytes * 8).div_ceil(5)
        ));
    }
    let mut out = vec![0u8; nbytes];
    for (i, v) in vals.iter().enumerate() {
        for j in 0..5 {
            let bit = i * 5 + j;
            if (v >> (4 - j)) & 1 == 1 {
                if bit >= nbytes * 8 {
                    return Err("non-zero padding bits in code".into());
                }
                out[bit / 8] |= 1 << (7 - bit % 8);
            }
        }
    }
    Ok(out)
}

/// Full code: base32 + check symbol, grouped by `group` with dashes.
pub fn encode(bytes: &[u8], group: usize) -> String {
    let mut s = b32(bytes);
    s.push(CHECK[mod37(bytes)] as char);
    let chars: Vec<char> = s.chars().collect();
    chars
        .chunks(group)
        .map(|c| c.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join("-")
}

/// Parses a code produced by [`encode`], verifying the check symbol.
pub fn decode(code: &str, nbytes: usize) -> Result<Vec<u8>, String> {
    let clean: String = code
        .chars()
        .filter(|c| !matches!(c, '-' | ' ' | '\n' | '\t'))
        .collect();
    let mut chars: Vec<char> = clean.chars().collect();
    let check = match chars.pop().ok_or("empty code")?.to_ascii_uppercase() {
        'O' => '0',
        'I' | 'L' => '1',
        c => c,
    };
    let body: String = chars.into_iter().collect();
    let bytes = unb32(&body, nbytes)?;
    let want = CHECK[mod37(&bytes)] as char;
    if check != want {
        return Err(format!(
            "check symbol mismatch (typo?): got {check}, expected {want}"
        ));
    }
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_and_check() {
        let data = [0x12u8, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x01, 0x23];
        let c = encode(&data, 4);
        assert_eq!(c.replace('-', "").len(), 17);
        assert_eq!(decode(&c, 10).unwrap(), data);
        assert_eq!(decode(&c.to_lowercase(), 10).unwrap(), data);
    }

    #[test]
    fn detects_single_symbol_typos() {
        let data = [9u8; 10];
        let c = encode(&data, 4);
        let mut chars: Vec<char> = c.chars().collect();
        chars[1] = if chars[1] == 'Z' { 'Y' } else { 'Z' };
        let bad: String = chars.into_iter().collect();
        assert!(decode(&bad, 10).is_err());
    }

    #[test]
    fn confusable_letters_are_normalised() {
        let data = [0u8; 10];
        let c = encode(&data, 4).replace('0', "O");
        assert_eq!(decode(&c, 10).unwrap(), data);
    }
}
