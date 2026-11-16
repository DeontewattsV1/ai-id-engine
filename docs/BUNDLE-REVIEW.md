# Review of the 84-file bundle (fc2b09ab….txt, "ai-id-engine v0.1.0")

How it was processed: the bundle's own `unsplit.py` was run in a scratch
directory (never over the repo). It printed "split ok" but wrote **0 files**,
because the bundle's `=== FILE: … ===` markers are wrapped in backticks and
the script's regex does not allow for that. A minimal fixed splitter wrote
all 84 files into the scratch tree. Each file was diffed against the repo,
the RTL was linted with `verilator --lint-only -Wall`, and the bundle's
SHA-256/HMAC cores were run against this repo's KAT testbenches.

Rule: adopt if it builds and passes. Where a bundle file is broken or
weaker than the working repo version, keep or fix the working version.

## Adopted (as-is or in substance)

| Bundle file | Where it landed | Notes |
|---|---|---|
| docs/adr/0001-ci-trace-counts.md | docs/adr/0001 | Decision kept. Corrected "4.11 local" (the threshold depends on M, not traces). Second-order M defined. Positive control added. |
| docs/adr/0002-vendor-sim-models.md | docs/adr/0002 | Decision kept. The implementation generates models from the pinned .lib. |
| docs/adr/0003-attestation-contract.md | docs/adr/0003 | Decision kept. Cycle figures for the removed in-fabric ECDSA dropped. Status says the device side is not built. |
| docs/certification-scope.md, docs/threat-model.md | docs/ | Rewritten to match what the repo actually does (SE signing, simulated-only TVLA). |
| config/tvla.toml | config/tvla.toml | ci 4000 / local 20000 / signoff 1e6, alpha 0.05, M 4000, require_null. Adds pois, tau, noise and a smoke profile. |
| tools/threshold.py | tools/threshold.py | Same formula; input validation added. 4.37 @ M=4000, 3.36 @ M=64, MDE 0.098 @ n=4000 (unit-tested). |
| test/null_control.py, tvla_gate.py, poi_select.py, tvla2_run.py, gate.py, area_report.py, model_sanity.py; tools/vendor_check.py | same paths | **Fixed**, see below. Exit codes 2/3/4/5 kept exactly. |
| rtl/mont_mul_masked_v2.v, mont_mul_masked3.v, mont_mul_wrap.v | same paths | **Rewritten**, see below. Interface ideas kept (four independent random ports, 3-share variant, MASK_EN wrapper). |
| .github/workflows/tvla.yml | `tvla` job in ci.yml | Pinned OSS CAD Suite instead of apt yosys/verilator. |
| verifier/src/ticket.rs | verifier/src/ticket.rs | **Fixed**: replay (counter never advanced), no domain separation, truncated body hash. Tests added. |
| sim/VENDOR.md | sim/VENDOR.md | Rewritten with a real, checked pin (URL + SHA-256). |

## Fixed (bundle defect → what changed)

- **mont_mul_masked_v2.v**: the multiplier did not compute a·b. It XORed
  partial products, so r0^r1 ≠ a·b mod m. `a0i/b0j` were declared before
  the `i/j` regs. The i/j counters came from a W-word draft. There were
  variable part-selects. The "random" ports were derived from one word XOR
  constants in the wrapper, and the wrapper tied a1=b1=0, which removes
  masking entirely. Now: arithmetic 2-share masking mod m, one time-shared
  radix-2 Montgomery datapath (the same recurrence as `mont_mul`), refresh
  mask r_s, three precharge randoms (r_p0, r_p1, r_c), AND-gated one-hot
  share selection, and a default in every case. Verified against Python on
  P-256 p and n at RTL and at gate level. Lints clean with `-Wall`.
- **mont_mul_masked3.v**: same issues, and the 3-share sums were XORs of
  9 partial products. Rewritten the same way, with 9 cross products and
  masks summing to 0.
- **Power model** (`lib_parse.py`, `net_power.py`): the regex matched
  `cell (name)` but sky130 uses `cell ("name")`, so it parsed 0 cells. Groups
  like `ff ("IQ","IQ_N")` desynchronised the brace depth. Vdd was 0.9 V (the
  tt_025C_1v80 corner is 1.8 V). The wire load was a made-up 0.0031 pF per
  fanout. Now: a brace-tracking parser (428 cells), pin caps plus the
  .lib's own default wire_load ("Small"), and Vdd from nom_voltage.
- **Traces**: the draft dumped one FST and parsed it in Python through a
  ctypes libfst binding, with a made-up "slew" term. The second-order run
  launched one simulator process per trace. Now the netlist is
  instrumented (`tools/tvla_netlist.py`) and the Verilator harness
  (`tb/tvla_harness.cpp`) computes 0.5·C·V² per toggled net in-simulation.
  `make tvla-xcheck` recomputes the same energies independently from a
  Verilator VCD/FST waveform. They match to 2.5e-14 relative.
- **synth/*.ys**: the "sim" netlist was mapped to generic gates, not
  sky130, so the traces did not come from the netlist whose area was
  reported. `synth-area` `sed`-edited the tracked .ys in place. Now one
  script (`tools/synth_sky130.sh`) maps each DUT with dfflibmap + `abc
  -liberty`, and the same netlist feeds both the area and the traces.
  OpenROAD-style dont_use cells are excluded.
- **area_report.py** summed per-cell lines with a regex that misses Yosys's
  `1.23E+03` format. It now reads the "Chip area for module" line.
- **null_control / tvla_gate / poi_select**: `tr[:n][12:]` dropped 12
  *traces*, not 12 samples. The draft also loaded everything into RAM.
  POIs were picked from the same labelled data they were tested on
  (selection bias). Now: streaming Chan/Welford moments, POIs chosen from
  the independent null-control set, and the second-order test is the real
  centered-product test (the draft compared variances).
- **gate.py**: exit-code order kept (5 null, 2 second order, 3 first
  order, 4 area, 0 pass). Every number is now printed before the verdict,
  and an undetected positive control also counts as a harness failure.
- **mont_params.vh**: the bundle's N_N0 = 0xffff3c4f is wrong. The repo
  value 0xee00bc4f = -n^-1 mod 2^32 is kept.

## Rejected (repo version kept), with reasons

| Bundle file(s) | Reason |
|---|---|
| rtl/ecdsa_core.v, ecdsa_p256_sign.v, quote_signer.v, ec_arith.v, fp_ops.v | **Key-leaking**: `ecdsa_core` uses the private key as the nonce (`inv_in <= priv`), so d = z/(s−r). Does not build: modules are called as functions (`fp_sub`…), `%` and 256×256 `*`. Lint fails. v0.1.0 signs in an SE; no in-fabric ECDSA is re-enabled. |
| rtl/seal_unit.v | **XOR "sealing" keyed only by public PCRs**: wrapped = secret ⊕ XOR(PCRs). Anyone who knows the PCRs unwraps it. The repo keeps its own seal unit; LIMITATIONS covers it. |
| rtl/sha256_core.v, hmac_sha256.v | **Fail the NIST/RFC KATs**: outputs are X on the empty-message vector in this repo's testbenches. |
| rtl/dice_cdi.v | Exposes `alias_key` on a port. `msg_bits=384` silently truncates the last 96 bits of the measurement. |
| rtl/id_engine_top.v (55 lines), apb_regfile.v, key_ladder.v, pcr_bank.v, tamper_ctrl.v, bch_*.v, fuzzy_extract.v, gf_mult.v, mont_mul.v | Weaker than the integrated repo versions. id_engine_top has BLKSEQ, SYNCASYNCNET, UNDRIVEN. gf_mult has 19 MULTIDRIVEN. bch_* and fuzzy_extract are missing `gf_mult` as a function. mont_mul has SELRANGE/BLKSEQ and 3-bit i/j counters. |
| rtl/mont_mul_masked.v (v1) | Superseded by v2; same non-functional XOR datapath. |
| rtl/rnd_expand.v | "Trivium-like", not Trivium (wrong taps/feedback). The repo has an HMAC-DRBG behind SP 800-90B health tests. |
| tb/tb_id_engine.cpp (48 lines), tb/tvla_gate.cpp | Much weaker than the repo's 595-line full-chip test. tvla_gate.cpp drove ports the netlist did not have. |
| fw/attd.c, measure_agent.c, id_engine.c/.h, Kbuild, .lds, id_engine_regs.h | Does not compile: `crypto_shash_hmac` is not a kernel API. The ticket key is never seeded (all zeros, so tags are forgeable). Timestamps in µs vs the verifier's ms. The register map disagrees with the RTL. The repo's driver core (built in CI against kernel headers) and the regmap check are kept. |
| verifier/src/policy.rs | **Fail-open**: `platform_ok()` always returns true. The repo's `hw.rs` verifies the SE signature, chain, nonce, PCRs and hw_rev, with negative tests. |
| verifier/src/decision.rs | Signs `verdict‖weight‖deployment‖counter` with no length framing, which is ambiguous. Not needed. |
| verifier/src/main.rs, Cargo.toml (crate "verify") | A toy main that would replace the repo's CLI. |
| formal/sby.toml, sby_fe64.toml, fe64.sv, fe64_sva.sv, fuzzy_bind.sv, ecdsa_sva.sv, id_engine_sva.sv | Not valid SymbiYosys files (`.toml` with a `[tasks]` section). `fe64` is a stub that does no BCH decoding, so proving it proves nothing. `ecdsa_sva` targets the rejected core. Replaced by real proofs (below). |
| test/template_attack.py | Profiles 256 "classes" from fixed/random labels; not a template attack. |
| test/policy_negative.py, test/map_check.py | Read inputs nothing produces (`cases` JSON, a linker map with `__id_engine_text_*`). |
| tools/spice_cal/* (ngspice) | Netlist references an undefined `inv` subckt. **ngspice is optional** and not used for the gate; see docs/TVLA.md. |
| tools/fst_acc.py, pyfst.py, net_power.py | Replaced (see Fixed). |
| tools/gen_mont_constants.py, gen_bch_poly.py, test/bch_roundtrip.py, test/puf_characterize.py | The repo's versions are longer and are the ones the tests use. |
| Makefile, README.md, .gitignore, LICENSE, unsplit.py | The repo's versions are kept and extended. unsplit.py did not work on its own bundle. |

## Formal and KAT results (v0.2.0)

- SBY `formal/gf_mult.sby`: PASS (unchanged).
- SBY `formal/otp_fuses.sby`: **PASS** (k-induction) for: bits never go
  1→0, locked words are frozen, UDS words (5..12) always read 0 and every
  other word reads back its value. The UDS check uses an address decode
  written independently of the RTL's `secret` signal, and UDS words can
  be programmed non-zero. Mutants that write `wdata` instead of `f|wdata`,
  or decode the UDS range as `addr >= 6`, both **FAIL**, so the proof is
  not vacuous.
- SBY `formal/pcr_bank.sby`: **PASS** (k-induction, SHA core cut to free
  outputs). A PCR changes only when an extend completes, only the
  selected PCR changes, and it takes the hash output. A mutant that writes
  `digest_in` directly did not finish within 600 s (inconclusive, not a
  pass).
- KAT: SHA-256 NIST multi-block (448-bit, 896-bit, 1,000,000×'a') PASS.
  SHA-256 single-block NIST (3) PASS. HMAC-SHA256 RFC 4231 TC1–TC5 PASS
  (TC6/7 need >32-byte keys, which the 256-bit key port excludes).
  HMAC RFC 2104 (6) PASS. ECDSA P-256 RFC 6979 A.2.5 ("sample", "test"):
  OpenSSL (the SE model's library) pubkey + deterministic (r,s) + verify +
  tamper-reject PASS; Rust p256 (verifier and aiid) exact (r,s) PASS.
  OpenSSL older than 3.2 (e.g. the Ubuntu 24.04 CI runner) skips only the
  deterministic-(r,s) step; the Rust KATs check exact (r,s) everywhere.
