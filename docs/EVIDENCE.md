# Evidence reports (`aiid-evidence/v1`)

`make evidence` (after `make tvla`) writes `build/tvla/evidence.json`: a
signed record of one pre-silicon TVLA assessment. It is evidence about a
simulated gate-level design (pre-silicon assessment, FPGA proxy). It is not
a certification and not a silicon measurement, and the report says so in
its own `measurement_envelope`.

```sh
make tvla PROFILE=ci MASKED=masked3
make evidence PROFILE=ci MASKED=masked3 ATTEST=auto     # auto | tpm | software
aiid evidence verify --report build/tvla/evidence.json [--require-hardware]
```

## Schema

A report is `{body, body_sha256, attestation}`. `body` is
`{schema: "aiid-evidence/v1", created, fields: [...]}`, and every field is
`{name, class, value}` with `class` one of:

- `identity`: identifies what was assessed or who signed;
- `behavior`: a measured outcome;
- `neither`: the conditions of the measurement.

| Field | Class | Content |
|---|---|---|
| `provenance` | identity | what signed the report (below); **mandatory** |
| `hwid` | identity | salted HWID of the signing host |
| `model_digest` | identity | SHA-256 of the RTL, the sky130 netlists, the TVLA power-model netlists and caps, the cell models and the `.lib` |
| `stimulus_set` | neither | SHA-256 of `config/tvla.toml`, the harness and the collector, plus seeds, modes and trace counts |
| `tvla_parameters` | neither | profile, DUT, traces/group, samples, alpha, first- and second-order thresholds, number of tests |
| `measurement_envelope` | neither | corner, wire-load model, power model, RC tau, noise, what is *not* modelled, tool versions |
| `tvla_result` | behavior | null and positive controls, first- and second-order peaks, MDE, verdict, gate exit code |
| `area`, `latency_cycles` | behavior | from `test/gate.py` |
| `tvla_summary_sha256` | neither | hash of the `summary.json` the report was built from |

`aiid evidence verify` fails a report if:

- any field has no class or an unknown one;
- a required field is missing or has the wrong class;
- a field name is duplicated;
- `provenance.root` is not `hardware` or `software`;
- the body hash, the attestation signature or the provenance does not match.

## Provenance and signing

- The provenance is read before signing, using `TPM2_GetCapability` (manufacturer and vendor string) through tpm2-tools.
- `root` is `hardware` only for a physical TPM. **A software TPM (swtpm/mssim) or the software-fallback key gives `root: "software"`.**
- The body is hashed as `SHA-256("AIID-EVIDENCE-V1" || compact JSON body)`. That hash is the nonce for the existing `attest::attest`, so a TPM quote, or the fallback Ed25519 key, signs it, and the provenance is covered by the signature.
- `verify` recomputes the provenance from the attestation and rejects any mismatch, for example a body that claims `hardware` over a swtpm quote.

**Limits:**

- The provenance is what tpm2-tools reported to the host. It is bound by the AK signature, but not vouched for by an EK certificate chain, so a compromised host can lie about the TPM vendor.
- The CI report uses `ATTEST=software`, so its root is `software`.
- Quotes from the engine itself stay SE/TPM-signed. The evidence path never uses in-fabric signing.
