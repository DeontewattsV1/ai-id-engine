# Threat model (v0.2.0)

## In scope

- Substituted model weights at rest (the measured digest goes into PCR2 and
  the birth certificate).
- Boot-chain tampering (bootloader, kernel measured into PCR0/1/4).
- Replay of an old quote (verifier nonce + timestamp skew) and replay of a
  ticket (ADR-0003, strictly increasing counter).
- Rollback to a previously valid deployment (policy + counters).
- Key extraction through the signing path. v0.1.0 removed the in-fabric
  ECDSA that leaked the key and signs in an attached secure element.
- First/second-order power side channels on the masked Montgomery
  multiplier (simulated evidence only, see certification-scope.md).
- Tamper mesh breach, which zeroizes the key material.

## Out of scope

- Decapsulation, FIB, probing inside the SE.
- Fault injection (voltage, clock, laser).
- Supply-chain compromise of the PDK, FPGA toolchain or SE.
- Compromise of the verifier host.
- A malicious model whose weights are correctly measured. Identity is not
  behaviour.

## Trust assumptions

- The vendor CA root is trusted. The demo CA is TEST-ONLY.
- The SE keeps its private key, and its ECDSA is correct (RFC 6979 KATs
  pass on the OpenSSL model).
- The OTP lock word is programmed at production. Fuses are OR-only
  (formally proven on the model).
- On the FPGA prototype the UDS is a public build constant, NOT a secret.

## Acceptance argument

A quote is accepted only if the SE signature chains to a trusted root, the
nonce is fresh, the timestamp is within skew, PCRs match policy (PCR2 =
the model weights), the hardware revision is allowed, and the lifecycle and tamper fields pass
policy (DEV parts can be rejected). Each check is enforced in
`verifier/src/hw.rs` and has a negative test.
