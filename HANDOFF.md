# HANDOFF: v0.2.0 work in progress (branch `wip/v0.2.0-handoff`)

Written 2026-11-16 at 01:25 PT. This branch is **WIP**. Do **not** open a PR from it: the auto-merger would merge it into main.
Split it into small PRs off `origin/main` instead.

The branch contains:
- origin/main, which includes PR #22
- PR #23 with its review fixes (feat/v0.2-masked-mont @ bdd004f)
- the local, unpushed PR3, PR4 and PR5 commits
- PR #24 (feat/si32-web)
- uncommitted fault-detection RTL

Deonte's spec files are in `docs/specs/`:
- `capmodel.txt`
- `makefile_gates.txt`
- `tvla_masked_v1.txt`
- `fc2b09ab-bundle-84-files.txt`: the 84-file bundle, split by `/workspace/bundle/unsplit_fixed.py`

The specs `0ef60f92*` (masked v2 with four random ports) and `40be6332*` (ADRs) were never on the box. Their content exists inside the bundle as files.
Out of scope, so do not add: `7d2c1956*.md`, `78068e7c*.txt`, `f78418f2*.html`.

## Rules
- **Auto-merge is on.** Run `make lint`, `make test` and `cargo test` (hwid/ and verifier/) locally and get them green **before every push**. Use small PRs, each on a fresh branch off origin/main.
- Use gh per process with `GH_TOKEN=$(gh auth token --user DeontewattsV1)`. Never run a global `gh auth switch`.
- TVLA here uses **simulated traces**, from a gate-level sky130 model with capacitance-weighted toggle energy.
  - It is **not silicon** and **not certification**.
  - Say "pre-silicon assessment, FPGA proxy". Never say "side-channel certified". Never call swtpm "hardware-rooted".
- **Never use the in-fabric signing path.** Bundle ecdsa_core, quote_signer, ec_arith and fp_ops were rejected: they leak the key and use the private key as the nonce. Quotes stay SE/TPM-signed.
- Do not tune the gate thresholds. They come from `tools/threshold.py`: 4.37 at M=4000, α=0.05, Bonferroni.
- Toolchain: `/tmp/oss-cad-suite/bin` (yosys, sby, verilator, iverilog).

## Done and verified (real numbers)
- **PR #22 (MERGED)**
  - KATs pass:
    - NIST SHA-256 multi-block (448/896-bit, 1M×'a') plus 3 single-block vectors
    - HMAC RFC 4231 TC1–5 (TC6/7 are excluded because of the 256-bit key port) and RFC 2104 ×6
    - ECDSA P-256 RFC 6979 A.2.5, on OpenSSL 3.5.7 and Rust p256, exact (r,s)
  - SBY: gf_mult PASS; otp_fuses PASS (2 mutants FAIL as intended); pcr_bank PASS by k-induction (~2m20s).
  - Windows soft-key race fixed.
- **PR #23 (OPEN, CI was running)**
  - `rtl/mont_mul_masked_v2.v`: 2-share with r_p0, r_p1, r_c and r_s.
  - `rtl/mont_mul_masked3.v`, `rtl/mont_mul_wrap.v`, plus TVLA statistics scripts and tests.
  - Merge it when green.
- **PR #24 (OPEN)**: Si-32 under `web/si32`.
  - Netlist: 18,237 NAND gates and 1,024 flip-flops.
  - Lockstep: 4 demos (382,402 instructions) plus 60 random programs (27,724 instructions) all match. Mutation test: 297/300 detected.
  - Pages is enabled with build_type=workflow; the URL after merge is https://deontewattsv1.github.io/ai-id-engine/si32/
  - `docs/SI32.md` explains why Si-32 is not the soft-core host.
- **TVLA** (ci profile, 4000 traces/group, M=4000; reproduced twice):

| | masked_v2 | masked3 |
|---|---|---|
| null \|t\|max (crit 4.37) | 3.30 ok | 3.66 ok |
| positive control, plain mont_mul (1000/group) | 82.37 | 82.37 |
| 1st order \|t\|max | 2.98 | 4.22 |
| 2nd order \|t\|max (crit 4.46, 6016 tests) | **26.37** (bivariate 1001/1998) | 3.47 |
| MDE | 0.0977σ (1st) / 0.0997σ (2nd) | 0.0977σ |
| area vs plain 80,357 µm² | 182,752 (2.27×) | 254,149 (3.16×) |
| latency vs plain 258 cycles | 1042 | 2343 |
| gate exit | 2 (second-order leak; use 3-share) | 0 (pass at this trace count) |

  - Smoke profile (300/group): null 3.20, positive 46.35, 1st 3.47, 2nd 5.65, exit 2.
- **Fault-detection RTL** (this branch only, unpushed elsewhere). Results from `tb/tb_fault_detect.sv` under iverilog, ~13 s:
  - SEC-DED(39,32): single flips corrected 2496/2496; double flips detected 47424/47424.
  - fault_alarm: set by a fault; survives rst_n; a single-latch upset re-sets the latch.
  - HD3 FSM (Hamming(7,4) codes): 1- and 2-bit state upsets detected 35/35.
  - Key store: single-bit word upsets corrected 312/312; double-bit upsets cause zeroize 48/48.
  - mont_mul_rc (residue mod 65535): 40 clean runs with 0 false alarms. Of 400 random single-bit upsets, 307 were effective, 307 detected, 0 escaped and 93 had no effect.
  - Testbench mutation check: disabling each detector makes the TB FAIL (rc, fsm, alarm and ded mutants).
  - SBY:
    - `formal/fault_alarm.sby` PASS (sticky)
    - `formal/key_store_fd.sby` PASS (FSM legal, words valid, zeroize gates key_out)
    - `formal/key_store_nonint.sby` PASS by k-induction, ~40 s (two-copy miter: the key never reaches status, zeroize or key_valid)
    - At depth 6, the leak and illegal-state mutants FAIL.
  - All 5 new modules pass `verilator --lint-only -Wall` clean.

## Partial (file paths)
- **PR3: TVLA flow** (`tools/*.py`, `tools/synth_sky130.sh`, `tb/tvla_harness.cpp`, `sim/sky130_fd_sc_hd_cells.v` + `sim/VENDOR.md` (Apache-2.0), `config/tvla.toml`, `docs/TVLA.md`, `docs/adr/0001-0003`, the Makefile `tvla*` targets and the ci `tvla` job)
  - Written and run locally, but never pushed as its own PR.
  - The area_report `--plain-top/--masked-top` change is included here.
  - To do: re-run `make test`, `make tvla-xcheck` and `make tvla PROFILE=ci MASKED=masked_v2`, then open the PR.
- **PR4**: `verifier/src/ticket.rs` (ADR-0003 replay-safe ticket). Local only.
- **PR5**: `docs/BUNDLE-REVIEW.md` (the adopt/fix/reject table for all 84 files), `CHANGELOG.md`, and version 0.2.0 in the Cargo files. Local only.
- **Fault detection**: `rtl/secded39_{enc,dec}.v`, `rtl/secded39_fn.vh`, `rtl/fault_alarm.v`, `rtl/key_store_fd.v`, `rtl/mont_mul_rc.v`, `tb/tb_fault_detect.sv`, `formal/{fault_alarm,key_store_fd,key_store_nonint}.sby`, `formal/key_store_nonint.sv`. Still missing:
  - Makefile targets (`fault-test`; add the sby files to `formal-all`; lint lines)
  - a CI step
  - `docs/FAULT-DETECTION.md`, which must say that coding detects faults and does not protect against side channels; that HD3 codes are used because one-hot only gives HD 2; and the 1/65535 residue escape rate
  - integration into `pcr_bank` / `id_engine_top` (SEC-DED on PCR state; mont_mul_rc rc_err → alarm), behind a define
  - adding `formal/key_store_fd/` etc. to `make clean`

## Not started
- Reproducible bitstream: pin toolchain hashes, fix the nextpnr seed, add an expected-digest file, and add a CI job that rebuilds and fails on any digest change. Do this after the RTL changes to the FPGA top.
- RTL→netlist equivalence with Yosys `equiv_*` or eqy (start with mont_mul / masked3 vs the sky130 netlist).
- Evidence report schema:
  - every field tagged identity / behavior / neither
  - mandatory signed `provenance` from TPM GetCapability (swtpm → `software`; the schema fails if it is missing)
  - bind the model digest, stimulus set and TVLA parameters
  - record the measurement envelope
  - Suggested approach: an `aiid evidence` subcommand reusing `attest::attest` with nonce = report hash.
- Wording sweep across all docs.
- v0.2.0 release once main is green:
  - musl binaries via `make release-bins`
  - a TVLA evidence tarball
  - SHA256SUMS
  - notes in the v0.1.0 style

## Known bugs / caveats
- masked_v2 fails second-order TVLA (|t| 26.37). This is expected for 2-share. masked3 passes at only 4000 traces; 1M traces (`PROFILE=signoff`) has not been run.
- Second-order TVLA is validated only by synthetic tests (`test/test_tvla_stats.py`). `gate.py` reports exit 2 before exit 3 and appends "ALSO first-order leak".
- The pcr_bank async-reset `f_past_valid` variant stalled in SBY (>6 min) and was reverted. The SBY checks rely on async2sync semantics.
- Firmware build checks run only in CI (no kernel headers on the box). The bundle firmware was rejected because it does not compile.
- In formal, hierarchical references in a miter don't connect (they become free wires). Expose signals through ports instead.
- `key_store_fd` is a reference composition and is not yet wired into `id_engine_top`.
- The bundle's `mont_params` N_N0 is wrong (0xffff3c4f); the repo keeps 0xee00bc4f.

## Build and test
```sh
export PATH=/tmp/oss-cad-suite/bin:$PATH
make lint && make test                 # all operational gates (includes kat-rtl, tvla-test)
(cd hwid && cargo test) && (cd verifier && cargo test)
make kat formal-all                    # KATs + SBY (gf_mult, otp_fuses, pcr_bank)
for s in fault_alarm key_store_fd key_store_nonint; do sby -f formal/$s.sby; done
iverilog -g2012 -I rtl -s tb_fault_detect -o /tmp/tbfd rtl/secded39_enc.v rtl/secded39_dec.v \
  rtl/fault_alarm.v rtl/mont_mul.v rtl/mont_mul_rc.v rtl/key_store_fd.v tb/tb_fault_detect.sv && vvp -n /tmp/tbfd
make tvla-xcheck                       # VCD vs in-sim energy cross-check (2.5e-14 rel)
make tvla PROFILE=ci MASKED=masked_v2  # ~9 min incl. synth; exit 2 expected
make tvla PROFILE=ci MASKED=masked3    # ~9 min; exit 0
make tvla PROFILE=smoke                # CI smoke
(cd web/si32 && node test/lockstep.test.js && node test/mutation.test.js && node test/page.test.js)
```

## Remaining tasks, in priority order
1. **TVLA pipeline.** Merge PR #23 when green. Push PR3 (TVLA flow) and then PR4 as separate PRs.
2. **Bundle merge.** PR5 (`docs/BUNDLE-REVIEW.md`, CHANGELOG, version bump).
3. **Si-32.** Merge PR #24 and confirm that https://deontewattsv1.github.io/ai-id-engine/si32/ loads.
4. **Coded fault detection.** Finish the Makefile, CI and docs work above; integrate behind a define; open a PR.
5. **Reproducible build.**
6. **Equivalence** (RTL→netlist) plus the SBY "illegal FSM unreachable" property for the main controllers.
7. **Evidence schema** plus the signed report with provenance.
8. Wording sweep, then cut the v0.2.0 release with SHA256SUMS.
