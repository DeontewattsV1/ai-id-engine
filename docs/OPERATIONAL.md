# What "operational" means for this repository

This repo is a **research reference implementation** of a DICE-style AI
identity engine (see `docs/REMEDIATION.md`, status RESEARCH HOLD). It is not
production-certified silicon. "Operational" is therefore defined as the
integrated design and its software verifier working end to end, with every
claim checked by an automated test against an independent implementation:

| # | Criterion | How it is checked |
|---|-----------|-------------------|
| 1 | The full RTL (`id_engine_top` and every file in `rtl/`) elaborates and lints with zero `-Wall` warnings, in both the hardware build and the simulation build | `make lint` |
| 2 | The integrated engine runs end to end in simulation: PCR extend, DICE CDI derivation, PCR-bound seal/unseal, fail-closed quoting and tamper zeroize, each compared bit-exactly with OpenSSL | `make sim` (35 checks) |
| 3 | Arithmetic and hash units pass known-answer tests (SHA-256, HMAC-SHA256, Montgomery, mod-n, field inverse, BCH encoder) | `make math-oracle rtl-unit` |
| 4 | The firmware register header and the RTL decoder agree | `make regmap` |
| 5 | The quote verifier builds, verifies genuine quotes and rejects replayed, stale, tampered, mis-signed, untrusted-root, wrong-model, wrong-config and wrong-PCR quotes | `make verifier` (13 tests) and `cargo run -- demo` |
| 6 | The Linux driver core compiles against real kernel headers | `make -C fw` (CI `driver` job) |
| 7 | CI runs all of the above on every push and pull request and is green | `ci.yml`, `signoff.yml`, `arithmetic-reference.yml`, `Verilog Compiler.yml` |
| 8 | The README run instructions are accurate | this file and README "Quick start" are exercised by CI commands |

## Explicitly out of scope (still blocked, see REMEDIATION.md)

* **Hardware quote signing.** `quote_signer` stays fail-closed: `ecdsa_core`
  can expose the signing key. The verifier is exercised with software-signed
  quotes instead.
* **Real PUF.** `rtl/sram_puf.v` is a placeholder. The hardware build outputs
  no UDS (fail closed); only the simulation build (`AI_ID_SIM_PUF`) uses a
  fixed, public test UDS.
* **Seal confidentiality.** `seal_unit` models the PCR release policy; the
  XOR wrap is not AES-GCM.
* **Full-chip formal, fuzzing and a coverage threshold.** The `signoff`
  workflow's gates are narrow: `make formal` proves only `gf_mult`,
  `make cov` only requires non-empty coverage counters (the original 95 %
  threshold is not met or enforced), and `make fuzz` is the PUF harness unit
  test plus an exhaustive `gf_mult` simulation. The SVA in `formal/*.sv` for
  the engine and fuzzy extractor is still not wired into any proof.
* **TVLA on silicon, timing/area closure.** Not run.
* **Streaming measurement engine, weight DMA, quote FIFO, OTP.** Not in RTL;
  the driver returns `-EOPNOTSUPP`. `fw/attd.c` and `fw/measure_agent.c` are
  design sketches and are not built.
