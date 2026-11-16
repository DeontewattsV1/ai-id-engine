# Limitations (v0.1.0) — read before relying on any of this

v0.1.0 is a **working prototype**: everything below runs and is tested, but it
is not a certified security product. Nothing here has been through FIPS 140-3,
CAVP, Common Criteria, or an external security review.

## Hardware (RTL / FPGA)

* **ECDSA P-256 signing lives in an external secure element (SE), not in this
  RTL.** The engine hashes the 660-byte quote body and sends the digest over
  SPI; the SE returns r‖s. In simulation the SE is an OpenSSL model
  (`tb/se_model.h`). No off-the-shelf SE speaks this small SPI protocol
  (`0x01` GET_PUBKEY, `0x02` SIGN); on a board you need a microcontroller or
  SE adapter that implements it. The FPGA bitstream has the SE pins but has
  **not been run against a physical SE or on a physical ULX3S**.
* **The old in-RTL ECDSA is quarantined in `research/unsafe-ecdsa/`.** It used
  the private key as the nonce (`d = z/(s−r)` recovers the key from one
  signature), its "ladder" was not a scalar multiplication, and it needed a
  non-synthesizable 256×256 multiplier. Do not re-enable it.
* **No real PUF.** `AI_ID_SIM_PUF` uses a fixed, public test UDS (simulation
  only). The FPGA build takes the UDS from the OTP image, which is generated
  randomly at build time and **embedded in the bitstream** — anyone holding
  the bitstream holds the device secret (no bitstream encryption). Prototype
  identity only.
* **OTP is a model.** OR-only programming, lock bits and read protection are
  enforced in logic, but FPGA registers are not one-time-programmable fuses
  and the image resets on reconfiguration.
* **TRNG not characterized.** The ring-oscillator source on the ECP5 has not
  been measured (no SP 800-90B entropy assessment). The RCT/APT health tests
  assume H = 0.5 bit/sample. HMAC-DRBG is not CAVP-validated and limits
  provided data to 22 bytes per call (longer seeds take several updates).
* **Seal is not encryption-grade.** `seal_unit` enforces the PCR release
  policy, but the wrap is XOR with a derived key, not AES-GCM.
* **No side-channel or fault-injection hardening** (no masking, no DPA/TVLA on
  silicon, no glitch detectors). HMAC/SHA timing is data-independent by
  construction, but power/EM leakage is unassessed.
* **Tamper mesh is logical.** It detects open/short/swapped lines driven by an
  LFSR on four pins; it is not an active shield with analog sensing.
* **Quote time is host-supplied.** `TIME` is written by firmware; there is no
  secure clock. Verifiers must use their own nonce for freshness.
* **Timing.** The FPGA flow targets 25 MHz with `--timing-allow-fail`; see the
  release notes / `fpga/build/summary.txt` for the achieved Fmax. If the
  achieved Fmax is below 25 MHz the bitstream is for resource demonstration
  only. The design does **not** fit an iCE40 (`make -C fpga ice40-stats`).
* **Firmware.** The Linux driver core (`fw/`) builds but has not been
  extended to drive the new measurement, quote, OTP and RNG registers;
  `tools/aiid_uart.py` is the reference host flow (untested on hardware).
* Formal verification still covers only `gf_mult`; the coverage gate only
  requires non-empty counters.

## Host tools (`hwid`, `aiid`)

* **The HWID is an identifier, not a security boundary.** An administrator
  can change machine-id, DMI strings (in VMs), MAC addresses and so on.
  Containers and cloned VMs can share identifiers. Use `hwid match` for
  fuzzy matching; do not treat HWIDs as proof of anything without
  attestation. The tool only reads identifiers — it never changes or spoofs
  them, and it is not meant for HWID bans or anti-cheat systems.
* **Windows and macOS collectors** are compiled and smoke-tested in CI only;
  they have not been tested interactively on real Windows/macOS machines.
* **TPM attestation:**
  * The EK certificate is **not** validated against the TPM manufacturer's CA,
    so a verifier cannot tell a genuine TPM from a well-behaved emulator by
    the evidence alone. Simulated TPMs (swtpm/mssim) are detected by TCTI
    and vendor string and flagged as not hardware-backed — a heuristic, not a
    proof.
  * AK↔EK binding (MakeCredential/ActivateCredential) is performed locally at
    issue time and recorded; a remote verifier that needs it must repeat the
    challenge itself.
  * PCR values are checked against the quote digest but not appraised
    against reference values (no event-log replay).
* **Software fallback** keys live in a file (`$AIID_HOME` or the XDG data
  dir) and are labelled `hardware_backed: false` everywhere.
* **Offline activation** codes are long (the 68-byte Ed25519 response is 22
  groups of 5 characters). The challenge carries only the first 64 bits of
  the HWID. Vendor keys from `hwid license keygen` are plain files.

## AI Birth Certificates

* The **demo vendor CA is TEST-ONLY**: generated at run time, keys in plain
  0600 files, no HSM, no revocation, no transparency log.
* Architecture, checkpoint version and environment fields are **claims made
  by the issuer**. Only the weight digests are re-checked by `cert verify`;
  the environment digest is checked for internal consistency.
* The embedded engine quote's nonce is chosen by the issuer; its freshness is
  bounded by the issue time (±1 day). The quote binds the weights through
  `model_digest` and PCR2 = SHA-256(0³² ‖ weights digest), so it assumes the
  model was the first PCR2 event after reset.
* For multi-file models the certificate binds a manifest digest, while the
  engine measures one file per stream; the demo streams the single weight
  file.
* PNG output in the release was rendered from the SVG with headless Chrome;
  the tool itself emits SVG.

## Process

* No secrets are committed. `make demo` generates every key (SE key, CA keys,
  software attestation key) at run time under `demo-out/`. The fixture in
  `verifier/tests/fixtures/` contains only public keys and signatures; the
  matching private keys were thrown away.

## v0.2.0 additions (TVLA, masked multiplier, bundle integration)

* **TVLA traces are simulated** (zero-delay gate-level sky130 tt netlist,
  pre-layout capacitance model). They are not silicon, have no glitches
  and no noise. A TVLA "pass" is evidence at that trace count, not
  certification. See docs/TVLA.md and docs/certification-scope.md.
* **The 2-share masked multiplier (v2) has a second-order leak** at
  4000 traces/group (see docs/TVLA.md). That is expected for 2 shares, and
  the gate says to use 3 shares. The 3-share design costs 3.16x area and
  9x latency.
* **The masked multipliers are not connected to any signing path.** Signing
  is still done by the external secure element. They are evaluated
  standalone over the P-256 group order.
* **ADR-0003 tickets**: the verifier-side check is implemented and tested.
  The device-side ticket key derivation and generation are not.
* The PCR-bank extend-only proof cuts out the SHA-256 core. The proof is
  about the write path; SHA-256 correctness comes from the NIST KATs.
* HMAC RFC 4231 TC6/TC7 (131-byte keys) are outside the 256-bit key port.
  Longer keys must be pre-hashed by the caller.
* **Coded fault detection is opt-in and simulation-only evidence**
  (`AI_ID_FAULT_DETECT`, docs/FAULT-DETECTION.md). It covers PCR storage and
  the PCR controller in `id_engine_top`; the other blocks are not coded.
  It detects register bit flips (1-bit corrected, 2-bit detected per word);
  3+ bit upsets can escape, the residue check misses ~1 in 65535, and none of
  it is a side-channel countermeasure. Not exercised on an FPGA or under a
  real fault-injection rig, and off in the default FPGA build.
