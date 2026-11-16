# ai-id-engine
hardware/firmware source tree. It's a reference implementation of a DICE-based AI identity engine (Device Identifier Composition Engine — the industry-standard layered identity primitive, aligned with TCG DICE, IETF RATS/EAT, and SPDM).
Here's the AI identity framework visualized:
The Technical Architecture — Three nested layers with provenance chains binding each layer to the one below. The weight hash at the core is the only truly immutable property; everything else is assigned at deployment time.
The AI Birth Certificate — A conceptual document showing what an official AI identity record would contain. In practice, this would be a signed attestation combining the weight hash, deployment signature, and environment digest.
The key insight your breakdown captures: AI identity is verifiable, not intrinsic. Unlike biological entities with DNA, an AI's "self" is a stack of cryptographic attestations. Two instances are only "the same AI" if they share the full provenance chain from weights through configuration.
The D6 pattern you mentioned — treating runner identity and environment digests as the trust anchor — is the correct approach. The model weights are just the beginning; the running system's identity is the hash of (weights + deployment + configuration + environment).
hardware and software stack for AI identity attestation that can be deployed across existing systems. This requires secure enclaves, cryptographic hardware, and a verification protocol.
<img width="1536" height="864" alt="image" src="https://github.com/user-attachments/assets/1ed44a52-2a26-40f5-acd3-885e29f0dac0" />

visual representation of AI/AGI/LLM identity layers and a conceptual "birth certificate" ID for an AI system.
<img width="1536" height="1152" alt="image" src="https://github.com/user-attachments/assets/38d2c581-a2be-4763-8ca2-e6a9ba3dabaf" />

## Status — v0.1.0 working prototype

A working, tested prototype of the whole chain: **RTL identity engine →
hardware quote → Rust verifier → AI Birth Certificate**, plus a host HWID /
offline-activation / TPM attestation tool. Not production-certified — read
[`LIMITATIONS.md`](LIMITATIONS.md). Block-by-block map:
[`ARCHITECTURE.md`](ARCHITECTURE.md).

* **RTL** (`rtl/`): AXI4-Lite/APB register file with doorbell + IRQ, OTP fuse
  model, TRNG with SP 800-90B health tests, HMAC-DRBG key ladder into key
  SRAM, DICE CDI + public device ID, streaming SHA-256 weight measurement over
  DMA, 16-entry extend-only PCR bank, AIQ2 quote engine that gets an ECDSA
  P-256 signature from an attached **secure element over SPI** (the engine
  never holds the signing key), tamper mesh + zeroize, and a boot-ROM
  **hardware code page** (8×8 font + banner). Simulated with Verilator,
  synthesized with Yosys + nextpnr for the ULX3S (ECP5-85F).
* **`hwid`** (`hwid/`): privacy-preserving salted HWID (Linux/Windows/macOS)
  with the component list, offline-activation challenge/response codes with
  checksums (Ed25519), TPM 2.0 EK/AK quote via tpm2-tools or a clearly marked
  software fallback. Read-only: no spoofing, not for HWID bans/anti-cheat.
* **`aiid`** (`hwid/`): `aiid cert create --weights` → signed in-toto/DSSE
  AI Birth Certificate (weights SHA-256, architecture, checkpoint, instance
  ID, environment digest, HWID + attestation, optional engine quote) and
  `aiid cert verify` (signature, chain to the vendor CA, freshness, re-hash).
* **`ai-id-verifier`** (`verifier/`): appraises software and hardware (AIQ2)
  quotes.

## v0.2.0: masked multiplier + simulated TVLA

`make tvla` maps the plain and masked Montgomery multipliers onto sky130
(Yosys `abc -liberty`), simulates the gate-level netlists in Verilator with
a capacitance-weighted power model, and gates them with Welch TVLA. It
runs a null control first, then a positive control, then first-order and
second-order tests, with computed thresholds (4.37 at M=4000). Results,
including the honest ones, are in [docs/TVLA.md](docs/TVLA.md). The traces
are simulated, not silicon. `make kat` runs the NIST/RFC known-answer
tests, and `make formal-all` runs the SymbiYosys proofs. The 84-file
bundle review is in [docs/BUNDLE-REVIEW.md](docs/BUNDLE-REVIEW.md).

## Quick start

### Use the release binaries (Linux x86_64, static)

```sh
curl -LO https://github.com/DeontewattsV1/ai-id-engine/releases/download/v0.1.0/aiid-v0.1.0-linux-x86_64.tar.gz
tar xzf aiid-v0.1.0-linux-x86_64.tar.gz && cd aiid-v0.1.0-linux-x86_64
./hwid show                      # HWID + components (salted hashes)
./hwid challenge                 # offline-activation code, e.g. 200Q-KD6C-8PGX-KSJG-9
./aiid ca init --dir ca          # TEST-ONLY demo vendor CA
./aiid cert create --weights path/to/model --ca ca --out cert.json --svg cert.svg
./aiid cert verify --cert cert.json --ca ca --weights path/to/model
```

### Build and run everything from source

Requirements: make, a C++ compiler, OpenSSL headers, Python 3 (+ numpy),
Rust (stable), Verilator ≥ 5.020 and Icarus Verilog (the CI uses the
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), which also
provides Yosys/nextpnr for the FPGA flow). Optional: `tpm2-tools` (+ `swtpm`
to test without a TPM).

```sh
make demo     # RTL sim measures a real Hugging Face model (prajjwal1/bert-tiny) and signs
              # an AIQ2 quote via the SE model -> Rust verifier -> aiid cert create/verify
make test     # lint + full-chip sim + RTL unit tests + regmap + verifier + hwid tests
make fpga     # ULX3S bitstream + utilization/timing reports in fpga/build/
```

Individual targets:

```sh
make lint         # Verilator -Wall: hardware, simulation and fuse-UDS builds + bridges
make sim          # id_engine_top end-to-end (192 checks vs OpenSSL); SIM_ARGS="+weights=FILE"
make rtl-unit     # SHA-256, HMAC, HMAC-DRBG, TRNG, AXI/UART bridges, Montgomery, BCH KATs
make regmap       # fw/id_engine_regs.h vs RTL decoder and STATUS bits
make verifier     # Rust verifier (incl. a quote produced by the RTL)
make hwid         # hwid/aiid unit + integration tests
```

### Offline activation round trip

```sh
hwid license keygen --out vendor.key            # vendor (TEST key); prints public key
hwid challenge --product 7                      # customer -> vendor
hwid license issue --key vendor.key --challenge <CODE> --days 365
hwid license verify --pub <PUBHEX> --response <RESPONSE> --product 7
```

### Hardware quote

```sh
ai-id-verifier verify-hw --quote engine_quote.json --chain engine_chain.json \
                         --policy hw_policy.json --nonce <hex>
```

AIQ2 quotes from the engine are checked with `verify-hw`. Plain `verify` is
for the software-signed quotes from `ai-id-verifier demo` and turns AIQ2
quotes away. The verifier rejects quotes older than the policy's skew window
(600 s in the samples), so to check a saved quote later, pass the time it
was made: `--now` with the quote's `timestamp`. For the sample files attached
to a release:

```sh
ai-id-verifier verify-hw --quote sample-engine-quote.json \
  --chain sample-engine-chain.json --policy sample-hw-policy.json \
  --nonce "$(jq -r .nonce sample-engine-quote.json)" \
  --now   "$(jq -r .timestamp sample-engine-quote.json)"
# VERIFIED hardware quote: device 9f49a8182594c76d rev A1 counter 1 model dab2c2bddcfb48ea
```

`make demo` writes all of these files to `demo-out/`. No API keys or secrets
are needed for anything in this repository; every key is generated at run
time and the demo CA is TEST-ONLY.

## Repository layout

| Path | Contents |
|------|----------|
| `rtl/` | Verilog engine (see ARCHITECTURE.md) plus ECC/BCH research blocks |
| `tb/` | Verilator full-chip testbench + SE model, Icarus unit testbenches |
| `fpga/` | ULX3S top, pin constraints, ring-oscillator entropy, Yosys/nextpnr flow |
| `hwid/` | Rust host tools `hwid` and `aiid` |
| `verifier/` | Rust quote verifier library + CLI |
| `scripts/demo.sh` | `make demo` |
| `test/`, `tools/` | Python oracles, vector generators, regmap check, ROM generator, UART host tool |
| `fw/` | Linux platform driver core and register ABI header |
| `research/unsafe-ecdsa/` | Quarantined key-leaking ECDSA (do not use) |
| `docs/` | Operational gates and remediation history |
