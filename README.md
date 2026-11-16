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

## Status

Research reference implementation, **not production-certified**. The
integrated engine and the software verifier run end to end; hardware quote
signing, the physical PUF and side-channel hardening are still blocked.
See [`docs/OPERATIONAL.md`](docs/OPERATIONAL.md) for exactly what works and
how it is tested, and [`docs/REMEDIATION.md`](docs/REMEDIATION.md) for the
open blockers.

## Repository layout

| Path | Contents |
|------|----------|
| `rtl/` | Verilog: `id_engine_top`, SHA-256/HMAC, PCR bank, DICE CDI, seal unit, key ladder, tamper control, ECC/BCH research blocks |
| `tb/` | Verilator end-to-end testbench (`tb_id_engine.cpp`) and Icarus unit testbenches |
| `test/`, `tools/` | Python math oracles, vector generators, PUF/TVLA harnesses, register-map check |
| `verifier/` | Rust library + CLI that verifies attestation quotes and key chains |
| `fw/` | Linux platform driver core and register ABI header |
| `formal/`, `constraints/`, `plat/` | Formal sketches, timing constraints, platform glue (not yet gated) |

## Quick start

Requirements: GNU make, Python 3 with `numpy`, Verilator 5, Icarus Verilog,
a C++ compiler, OpenSSL development headers and a Rust toolchain. On
Ubuntu/Debian:

```sh
sudo apt-get install -y make g++ verilator iverilog libssl-dev python3-numpy cargo
```

Run everything:

```sh
make test           # lint + sim + rtl-unit + regmap + verifier + PUF/TVLA harness checks
```

Or individually:

```sh
make lint           # Verilator -Wall lint, hardware and simulation builds
make sim            # end-to-end id_engine_top simulation checked against OpenSSL
make rtl-unit       # SHA-256, HMAC, Montgomery, mod-n, inverse and BCH KATs
make regmap         # firmware header vs RTL register decoder
make verifier       # Rust verifier unit and CLI tests
make -C fw          # build the Linux driver core (needs kernel headers)
```

Verify a quote with the CLI:

```sh
cd verifier
cargo run -- demo --out demo-out        # throwaway keys; writes quote/chain/policy JSON
cargo run -- verify --quote demo-out/quote.json --chain demo-out/chain.json \
                    --policy demo-out/policy.json --nonce <hex printed by demo>
```

`verify` prints `VERIFIED` and exits 0, or prints `REJECTED: <reason>` and
exits 1. The quote, chain and policy formats are documented in
`verifier/src/lib.rs`. No API keys or secrets are needed for anything in
this repository.
