// SPDX-License-Identifier: MIT
//! ADR-0003 per-request tickets (verifier side).
//!
//! The device is attested once with a full AIQ2 quote (`hw.rs`). After that,
//! each request carries an HMAC-SHA256 ticket under a per-enrolment ticket
//! key. The verifier accepts a ticket only if the counter strictly
//! increases, the timestamp is within the skew window, and the tag matches
//! in constant time. Accepting a ticket advances the stored counter, so a
//! replay of the same ticket is rejected.
//!
//! Fixes relative to the bundled draft: the MAC input is domain-separated
//! and has fixed-width fields, it binds the enrolment key id and the full
//! body digest, and `accept` mutates the stored counter. The draft only
//! compared counters and never advanced them, so every ticket could be
//! replayed. The device-side ticket generator is not in the RTL yet; see
//! LIMITATIONS.md.
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

type HmacSha256 = Hmac<Sha256>;
const TAG: &[u8; 16] = b"AIID-TICKET-V1\0\0";
pub const MAX_SKEW_MS: u64 = 5_000;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Ticket {
    pub ctr: u64,
    pub ts_ms: u64,
    pub req_id: [u8; 16],
    pub tag: [u8; 32],
}

#[derive(Clone, Debug)]
pub struct Enrolment {
    pub key_id: [u8; 16],
    pub ticket_key: [u8; 32],
    pub last_ctr: u64,
}

#[derive(Debug, PartialEq, Eq)]
pub enum TicketError {
    Replay,
    Skew,
    BadTag,
}

fn mac_input(key_id: &[u8; 16], ctr: u64, ts_ms: u64, req_id: &[u8; 16], body: &[u8]) -> Vec<u8> {
    let mut m = Vec::with_capacity(16 + 16 + 8 + 8 + 16 + 32);
    m.extend_from_slice(TAG);
    m.extend_from_slice(key_id);
    m.extend_from_slice(&ctr.to_be_bytes());
    m.extend_from_slice(&ts_ms.to_be_bytes());
    m.extend_from_slice(req_id);
    m.extend_from_slice(&Sha256::digest(body));
    m
}

/// Device/reference side: compute a ticket (used by tests and host tools).
pub fn issue(e: &Enrolment, ctr: u64, ts_ms: u64, req_id: [u8; 16], body: &[u8]) -> Ticket {
    let mut m = HmacSha256::new_from_slice(&e.ticket_key).expect("any key length");
    m.update(&mac_input(&e.key_id, ctr, ts_ms, &req_id, body));
    Ticket {
        ctr,
        ts_ms,
        req_id,
        tag: m.finalize().into_bytes().into(),
    }
}

impl Enrolment {
    /// Verify a ticket for `body` at verifier time `now_ms`. On success
    /// advance the counter so the same ticket can never be accepted twice.
    pub fn accept(&mut self, t: &Ticket, now_ms: u64, body: &[u8]) -> Result<(), TicketError> {
        if t.ctr <= self.last_ctr {
            return Err(TicketError::Replay);
        }
        if now_ms.abs_diff(t.ts_ms) > MAX_SKEW_MS {
            return Err(TicketError::Skew);
        }
        let mut m = HmacSha256::new_from_slice(&self.ticket_key).expect("any key length");
        m.update(&mac_input(&self.key_id, t.ctr, t.ts_ms, &t.req_id, body));
        m.verify_slice(&t.tag).map_err(|_| TicketError::BadTag)?; // constant time
        self.last_ctr = t.ctr;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn enr() -> Enrolment {
        Enrolment {
            key_id: [7; 16],
            ticket_key: [0x42; 32],
            last_ctr: 0,
        }
    }

    #[test]
    fn accepts_then_rejects_replay() {
        let mut e = enr();
        let t = issue(&e, 1, 1_000, [1; 16], b"body");
        assert_eq!(e.accept(&t, 1_200, b"body"), Ok(()));
        assert_eq!(e.accept(&t, 1_200, b"body"), Err(TicketError::Replay));
        let t2 = issue(&e, 2, 1_300, [2; 16], b"body");
        assert_eq!(e.accept(&t2, 1_300, b"body"), Ok(()));
    }

    #[test]
    fn rejects_skew_tamper_wrong_key_and_rollback() {
        let mut e = enr();
        let t = issue(&e, 5, 10_000, [1; 16], b"body");
        assert_eq!(e.accept(&t, 16_001, b"body"), Err(TicketError::Skew));
        assert_eq!(e.accept(&t, 10_000, b"other"), Err(TicketError::BadTag));
        let mut forged = t.clone();
        forged.ctr = 6;
        assert_eq!(e.accept(&forged, 10_000, b"body"), Err(TicketError::BadTag));
        let mut other = enr();
        other.key_id = [8; 16];
        let t_other = issue(&other, 5, 10_000, [1; 16], b"body");
        assert_eq!(
            e.accept(&t_other, 10_000, b"body"),
            Err(TicketError::BadTag)
        );
        assert_eq!(e.accept(&t, 10_000, b"body"), Ok(()));
        let old = issue(&e, 4, 10_000, [1; 16], b"body");
        assert_eq!(e.accept(&old, 10_000, b"body"), Err(TicketError::Replay));
    }
}
