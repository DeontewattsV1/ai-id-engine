# ADR-0003 Attestation contract: attest once, ticket thereafter

Status: accepted. Verifier side implemented in v0.2.0
(`verifier/src/ticket.rs`); the device-side ticket generator is NOT
implemented yet.

## Context

A full AIQ2 quote involves an SE ECDSA signature over SPI plus host
verification of the chain and policy. Doing that per inference request
costs too much. (The draft's cycle numbers referred to an in-fabric ECDSA
core that was removed in v0.1.0 because it leaked the key, so they are not
repeated here.)

## Decision

- Enrol once: the verifier checks a full quote (`hw.rs` policy), then
  stores `{key_id, ticket_key, last_ctr}`.
- Per request: an HMAC-SHA256 ticket over
  `"AIID-TICKET-V1" || key_id || ctr_be64 || ts_ms_be64 || req_id[16] || SHA-256(body)`.
- The verifier requires a strictly increasing ctr, |ts - now| <= 5 s and a
  constant-time tag match, and **advances last_ctr on accept**. The draft
  never advanced it, so tickets were replayable.

## Consequences

- Tamper/zeroize invalidates the ticket key, so clients re-enrol.
- Open: deriving the ticket key from the CDI inside the engine and handing
  it to the verifier at enrolment (e.g. encrypted to the verifier) is not
  built yet. Until it is, tickets authenticate whoever holds ticket_key.
