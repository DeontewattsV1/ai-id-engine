# Certification scope of the TVLA evidence

## What this is

Simulated leakage evidence for arithmetically masked Montgomery multipliers
(2-share `mont_mul_masked_v2`, 3-share `mont_mul_masked3`) over the P-256
group order. It comes from a fixed-vs-random TVLA harness on the
**sky130-mapped gate-level netlist**, with a mandatory null control, a
positive control and computed family-wise thresholds (ADR-0001).

## What this is not

- Not a certificate, and not a claim of DPA resistance.
- Not silicon. Traces come from zero-delay gate-level simulation at TT/25C,
  1.8 V. Every toggling net is weighted by its pre-layout capacitance.
  There are no glitches, timing, coupling, IR drop or EM.
- No order above 2, no profiled/template attack, no fault injection.
- TRNG entropy validation (SP 800-90B) is out of scope here.
- The masked multiplier is not yet wired into a signing path. The device
  signs with an external secure element (v0.1.0).

## Mapping

| Standard | Evidence supplied | Gap |
|---|---|---|
| ISO/IEC 17825 | Method, counts, computed gate, null + positive controls, reproducible pack | silicon traces, EM, lab |
| FIPS 140-3 (non-invasive) | Mitigation rationale, simulated TVLA | lab validation on the module |
| CC AVA_VAN | Harness, POI method | evaluator, device, attacks |

## To become certification evidence

1. Silicon traces at corners (Vmin/hot, Vmax/cold), 1e6 per group.
2. Glitch-aware simulation (timing-annotated) or post-layout power.
3. EM campaign, near-field.
4. Third-order TVLA for the 3-share design.
5. Profiled attack on the same die.
6. An independent evaluator.
