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
- Coded fault detection (`AI_ID_FAULT_DETECT`): SEC-DED (39,32) words,
  Hamming(7,4) FSM codes, a residue-checked `mont_mul_rc`, and a duplicated
  sticky alarm. `pcr_bank` stores PCRs coded and `id_engine_top` zeroizes on
  a fault (status bits 24/25). Bit-flip injection testbenches (`make
  fault-test`) and SymbiYosys proofs, including key non-interference for
  the reference key store. Detection only, not side-channel hardening.
- RTL -> sky130 netlist equivalence (`make equiv`, Yosys `equiv_*`) for
  `mont_mul`: output, operand registers, FSM and `done` proven; the `t`
  accumulator and `bit_index` are an open proof gap listed in
  `config/equiv_known.txt` (docs/EQUIVALENCE.md).
- Signed evidence reports (`aiid evidence create|verify`, `make evidence`,
  schema `aiid-evidence/v1`): every field classed identity/behavior/neither,
  mandatory provenance (swtpm and the software key are `software`), model,
  stimulus and TVLA parameters bound under the TPM/software signature
  (docs/EVIDENCE.md).
- Reproducible FPGA bitstream (`make -C fpga repro`, `REPRO=1` with a
  public test UDS, nextpnr `--seed 1 --threads 1`): CI builds twice and
  fails on any digest difference, then checks `fpga/repro.sha256` and
  `fpga/toolchain.lock` (docs/REPRODUCIBLE.md).
- Verifier: ADR-0003 ticket check with replay, skew and tamper tests.
- hwid: the software-attestation key is published without clobbering
  (hard link or exclusive create), fixing a Windows CI race.
- Docs: ADR-0001..0003, TVLA.md, certification scope, threat model, and
  the bundle review (adopted/fixed/rejected, with reasons).

## v0.1.0

Working prototype: SE-signed AIQ2 quotes, RTL id-engine, hwid/aiid,
`make demo`, and an ECP5 bitstream.
