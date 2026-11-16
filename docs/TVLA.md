# TVLA: simulated gate-level leakage evidence (v0.2.0)

> **Simulated traces are not silicon.** A pass is evidence at the stated
> trace count and model fidelity, not a certification. CI is not signoff.
> See [certification-scope.md](certification-scope.md).

## Pipeline (`make tvla PROFILE=ci|local|signoff|smoke [MASKED=masked_v2|masked3]`)

1. **Library**: `sky130_fd_sc_hd__tt_025C_1v80.lib`, downloaded and checked
   against a pinned SHA-256 (`make lib`; ADR-0002). `tools/lib_parse.py`
   extracts cell areas, input-pin capacitances, the default wire-load
   model and Vdd = 1.8 V.
2. **Synthesis** (`tools/synth_sky130.sh`): Yosys `synth -flatten`, then
   `dfflibmap -liberty` and `abc -liberty` for both the plain `mont_mul`
   and the masked DUT. The same mapped netlist gives the area
   (`stat -liberty`) and the traces.
3. **Cell models**: `sim/sky130_fd_sc_hd_cells.v` is generated from the
   .lib functions. `make cells-check` fails on any unmodelled cell.
4. **Power model** (`tools/tvla_netlist.py`): every net gets
   C = sum of its fanout input-pin caps + wire_load("Small")(fanout), plus
   5 fF on primary outputs. `test/model_sanity.py` rejects flat or tiny
   models.
5. **Traces** (`tb/tvla_harness.cpp`, Verilator): each cycle,
   E = 0.5 * Vdd^2 * sum(C_net over nets that toggled). The waveform is
   low-pass filtered (single pole, tau = 0.5 cycle) and resampled to exactly
   M = 4000 samples per trace. Groups are randomly interleaved. Masked DUTs
   get fresh shares and fresh randomness on every trace. Latency must be
   constant (data-dependent timing aborts the run). The first output
   shares are checked against Python a*b*R^-1 mod n.
   `make tvla-xcheck` recomputes the energies from a Verilator VCD (or FST
   with `TRACE_FMT=fst`, needs liblz4-dev) net by net and requires a match.
6. **Statistics** (`tools/tvla_stats.py`, streaming): Welch t per sample.
   - **Null control** (random vs random, masked DUT) runs **first**.
   - **Positive control**: the unmasked `mont_mul` must be detected.
   - **First order**: fixed vs random over all M samples, gate
     t_crit(M=4000, alpha=0.05) = **4.37** (ADR-0001, `tools/threshold.py`).
   - **Second order**: centered squares at every sample (univariate) and
     centered products over P=64 POI pairs (bivariate). POIs are chosen
     from the null-control data, so the test labels are never used for
     selection. Gate t_crit(M = 4000 + 2016) = 4.46.
7. **Gate** (`test/gate.py`): always prints the null peak, positive
   control, |t|max (1st/2nd), MDE, area ratio and latency delta, then
   returns exit 5 (harness), 2 (2nd-order leak → 3 shares), 3 (1st-order
   leak), 4 (area > 3.6x → share the multiplier) or 0.

Profiles (`config/tvla.toml`, traces per group): smoke 300, **ci 4000**,
local 20000, signoff 1,000,000 (≈16 GB of float32 per run; the statistics
stream). MDE at gate 4.37: 0.098 σ (ci), 0.044 σ (local), 0.0062 σ (signoff).

ngspice is **optional** and is not part of the gate. To calibrate the
0.5·C·V² energy per toggle against transistor-level simulation, run any
sky130 inverter-chain deck through ngspice with the sky130 SPICE models
from open_pdks. The bundled draft deck was rejected (undefined subckt).
Calibration rescales all traces by one constant, so it cannot change any
t-statistic.

## What the model does and does not capture

Captured: data-dependent switching of every net in the mapped netlist,
weighted by pre-layout capacitance, including combinational nets (zero
delay), registers and I/O.

Not captured: **glitches** (the main reason masked hardware leaks on
silicon), timing, coupling, IR drop, leakage current, EM, process
variation and measurement noise (noise_pj = 0, the worst case for the
designer). Real devices can leak where this model does not.

## Designs

| DUT | file | shares | latency (cycles) | area (µm², sky130 tt) |
|---|---|---|---|---|
| plain | rtl/mont_mul.v | 1 | 258 | 80,357 |
| v2 (DUT under test) | rtl/mont_mul_masked_v2.v | 2 (arithmetic mod n) | 1042 | 182,752 (2.27x) |
| 3-share | rtl/mont_mul_masked3.v | 3 | 2343 | 254,149 (3.16x) |

## Results

Simulated, gate-level, noise-free traces on sky130_fd_sc_hd tt_025C_1v80
(Yosys `abc -liberty`, cap-weighted toggle energy, RC tau 0.5 cycle).
**These are simulation results, not silicon measurements, and they are
evidence, not certification.** Profile `ci`: 4000 traces per group,
M = 4000 samples, alpha = 0.05 (Bonferroni, ADR-0001). Reproduce with
`make tvla PROFILE=ci MASKED=masked_v2` / `MASKED=masked3`.

| Metric | masked_v2 (2-share, DUT) | masked3 (3-share) |
|---|---|---|
| Null control \|t\|max (crit 4.37) | 3.30 ok | 3.66 ok |
| Positive control, plain mont_mul (1000/group) | 82.37 detected | 82.37 detected |
| 1st order \|t\|max (crit 4.37) | 2.98 | 4.22 |
| 2nd order \|t\|max (crit 4.46; 6016 tests) | **26.37** (bivariate; univariate 3.63) | 3.47 (univariate 3.47, bivariate 3.29) |
| MDE (1st order) | 0.0977 sigma | 0.0977 sigma |
| Area vs plain 80,357 um2 | 182,752 um2 = 2.27x | 254,149 um2 = 3.16x |
| Latency vs plain 258 cycles | 1042 (+784, 4.04x) | 2343 (+2085, 9.08x) |
| gate.py verdict | exit 2: use 3 shares | exit 0: PASS at this trace count |

The 2-share v2 design is first-order clean but leaks at second order as
expected for two shares in a noise-free model; the 3-share design passes both
orders at 4000 traces/group. Neither result says anything about the 1e6
`signoff` profile (configured, not run in CI) or about fabricated silicon.
Wall time for the masked3 ci profile on the 8-vCPU build box: ~16 min.
