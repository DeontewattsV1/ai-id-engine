# RTL to gate-netlist equivalence

`make equiv` checks that the sky130 netlist the TVLA flow measures
(`build/sky130_<dut>.v`, from `tools/synth_sky130.sh`) implements the RTL it
was synthesized from. It uses Yosys's `equiv_*` passes (no eqy needed):

1. **Gold:** the RTL, read with `-DSYNTHESIS` and taken through the same
   coarse `synth -run begin:fine` stage as the netlist. That stage includes
   Yosys's FSM extraction and recoding. The recoded `state` register is the
   only state that changes width and encoding (2 bits in RTL, 3-bit one-hot
   in the netlist), so it must be identical on both sides to be paired.
2. **Gate:** the netlist, flattened through the generated cell models
   (`sim/sky130_fd_sc_hd_cells.v`, the same models the TVLA traces run on).
3. Both sides get `async2sync`. Flops keep their RTL names in the netlist,
   so `equiv_make` pairs state by name. `equiv_simple -seq 5` proves each
   paired bit from the paired bits around it; `equiv_induct -seq 5` tries
   to close what is left by induction.
4. `tools/equiv_check.py` reads `equiv_status` and fails if any signal
   outside `config/equiv_known.txt` has an unproven bit.

## What is proven, and what is not

`mont_mul` (plain Montgomery multiplier):

| Signal | Bits | Status |
|---|---|---|
| `r` (output) | 256 | proven |
| `aa`, `bb`, `nn` (operand registers) | 768 | proven |
| `state` (recoded, one-hot) | 3 | proven |
| `done` | 1 | proven |
| `t` (accumulator) | 257 | **not proven** |
| `bit_index` | 8 | **not proven** |

About 1030 of 1295 paired bits are proven. `t` and `bit_index` do not close
under `equiv_simple`/`equiv_induct`, and still do not with `rst_n` tied high,
so reset handling is not the cause. The induction step fails at every depth
tried, which points to state that is not paired one-to-one (for example the
RTL's 258-bit `t` against the netlist's 257 `t` flops). A bounded
counterexample search from reset (`equiv_miter` + `sat`) ran out of memory
under YoWASP and has not been completed. **This is a gap in the proof, not
a known bug**: `tools/tvla_collect.py` checks the netlist's outputs against
Python `a*b*R^-1 mod n` on every TVLA run, and `r` is proven equivalent
given the paired state. A netlist that differed in `t` or `bit_index`
would have to do so without ever changing `r` on those runs.

**Scope limits:**

- FSM recoding itself is not covered (it happens on both sides).
- `mont_mul_masked_v2` and `mont_mul_masked3` are not checked yet.
- Zero-delay cell models: glitches and timing are out of scope, as for TVLA.

**Regression value today:** any change that makes `r`, the operand
registers, `state` or `done` unprovable fails `make equiv`. As a sanity
check, swapping the D inputs of two `r` flops in the netlist makes it fail.

## Next steps

- Pair or constrain `t[257]`, then retry `equiv_induct`; failing that, run
  eqy with a partitioned strategy or an SBY miter with `abc pdr`.
- Extend to the masked multipliers.
- Then delete the entries from `config/equiv_known.txt`.
