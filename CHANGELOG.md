# Changelog

## v0.2.0

- Masked Montgomery multipliers: `mont_mul_masked_v2` (2-share, four
  independent random ports) and `mont_mul_masked3` (3-share), plus the
  `mont_mul_wrap` MASK_EN wrapper. All three are verified against Python
  at RTL and at gate level.
- Gate-level TVLA on sky130_fd_sc_hd tt (Yosys `abc -liberty`): generated
  cell models, a capacitance-weighted toggle power model checked against
  Verilator waveforms, a null control and a positive control, first-order
  Welch and second-order centered-product tests, computed Bonferroni
  thresholds (ADR-0001), MDE, `gate.py`, `make tvla`, and a CI job at
  4000 traces/group.
- KATs: NIST SHA-256 multi-block (incl. 1M×'a'), HMAC RFC 4231, and
  ECDSA P-256 RFC 6979 on OpenSSL (SE model) and on Rust p256.
- Formal: OTP fuse semantics, PCR extend-only (SymbiYosys).
- Verifier: ADR-0003 ticket check with replay, skew and tamper tests.
- hwid: the software-attestation key is published without clobbering
  (hard link or exclusive create), fixing a Windows CI race.
- Docs: ADR-0001..0003, TVLA.md, certification scope, threat model, and
  the bundle review (adopted/fixed/rejected, with reasons).

## v0.1.0

Working prototype: SE-signed AIQ2 quotes, RTL id-engine, hwid/aiid,
`make demo`, and an ECP5 bitstream.
