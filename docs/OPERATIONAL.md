# What "operational" means for this repository (v0.1.0)

This repo is a **working prototype** of a DICE-style AI identity engine and
its host tooling. It is not certified silicon (see `LIMITATIONS.md`).
"Operational" means every piece runs end to end and every claim is checked by
an automated test against an independent implementation:

| # | Criterion | How it is checked |
|---|-----------|-------------------|
| 1 | All engine RTL lints with zero `-Wall` warnings in the hardware, simulation and fuse-UDS builds, plus both bus bridges | `make lint` |
| 2 | The integrated engine runs end to end: boot ROM banner/glyphs, OTP, PCR extend, streaming + DMA measurement (16 padding edges, real model weights), DICE CDI/device ID, key ladder, seal, TRNG→DRBG, SE public key over SPI, two AIQ2 quotes verified with OpenSSL, SE failure, tamper zeroize, TRNG stuck-at, power-on tamper refusal | `make sim` (192 checks; 196 with `SIM_ARGS=+weights=FILE`) |
| 3 | Unit KATs: SHA-256, HMAC-SHA256, HMAC-DRBG (Python SP 800-90A reference), TRNG health tests, AXI4-Lite and UART bridges, Montgomery, mod-n, inverse, BCH | `make rtl-unit` |
| 4 | Firmware register header and RTL decoder / STATUS bits agree | `make regmap` |
| 5 | The verifier accepts genuine software and RTL-produced hardware quotes and rejects replayed, stale, tampered, mis-signed, untrusted-root, wrong-model/config/PCR, tampered-device and wrong-lifecycle quotes | `make verifier` |
| 6 | Host tools: HWID, activation codes, TPM/software attestation, birth certificate create/verify and negative cases | `make hwid`; CI runs TPM tests against swtpm and builds on Linux, macOS and Windows |
| 7 | End-to-end demo on a real Hugging Face model | `make demo` |
| 8 | FPGA flow synthesizes, places and routes for the ULX3S (ECP5-85F) | `make fpga` (CI `fpga` job) |
| 9 | The Linux driver core compiles against real kernel headers | `make -C fw` |
| 10 | CI runs all of the above and is green | `.github/workflows/*.yml` |

Out of scope and still open: real PUF, physical-board bring-up with a real
secure element, AES-GCM sealing, side-channel evaluation, full-chip formal.
See `LIMITATIONS.md`.
