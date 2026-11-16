# ADR-0001 TVLA thresholds, null control and trace counts

Status: accepted (implemented in v0.2.0)

## Context

The earlier gate, `gate_t1 = 5.0`, was a guess and sat about at the null
peak, so it tested almost nothing. The gate is applied to a maximum over M
simultaneous tests, so it has to come from the null distribution of that
maximum (Bonferroni bound, two-sided):

    t_crit(M, alpha) = Phi^-1(1 - alpha/(2M))

    M=4000, alpha=0.05 -> 4.37
    M=64,   alpha=0.05 -> 3.36

Sensitivity (smallest detectable standardised mean difference, n traces
per group): MDE = t_crit * sqrt(2/n). n=4000 -> 0.098 sigma;
n=1e6 -> 0.0062 sigma.

## Decision

1. The gate is computed from M and alpha (`tools/threshold.py`), never
   typed. The first-order test uses M = samples per trace. The second-order
   test uses M = samples + P(P-1)/2: univariate centered squares at every
   sample, plus bivariate centered products over P POI pairs.
2. A null control (random vs random, masked DUT) runs first and is
   mandatory. If it fails, that is a harness failure (gate exit 5), not a
   leakage verdict. v0.2.0 also adds a positive control: the unmasked
   `mont_mul` must be detected, otherwise exit 5 as well.
3. CI uses 4000 traces/group and M = 4000 -> gate 4.37. The first-order
   pass/fail runs over the full window, not POIs, so selection bias stays
   out of the number. Second-order POIs are chosen from the null-control
   data set, never from the labelled data they are tested on.

## Consequences

All profiles (`config/tvla.toml`) have M = 4000, so the first-order gate is
4.37 for ci, local and signoff. The draft of this ADR said "4.11 local",
but the threshold depends on M, not on the trace count; only the MDE
changes (0.098 / 0.044 / 0.0062 sigma). A green CI run resolves only leaks
above about 0.1 sigma.
