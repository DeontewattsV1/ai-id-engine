#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""TVLA thresholds computed from the number of tests (ADR-0001).

The gate is applied to max |t| over M simultaneous tests, so it comes from
the null distribution of that maximum, using a Bonferroni bound on a
two-sided normal:

    t_crit(M, alpha) = Phi^-1(1 - alpha / (2 M))

The Welch t is treated as normal; with thousands of traces per group the
Student-t correction is negligible. MDE is the smallest standardised
mean difference (in units of the pooled per-sample sigma) that reaches
t_crit with n traces per group: MDE = t_crit * sqrt(2 / n).
"""
import argparse
from statistics import NormalDist


def thresh(m, alpha=0.05):
    if m < 1 or not 0 < alpha < 1:
        raise ValueError("need M >= 1 and 0 < alpha < 1")
    return NormalDist().inv_cdf(1 - alpha / (2 * m))


def mde(t, n):
    if n < 2:
        raise ValueError("need n >= 2 traces per group")
    return t * (2.0 / n) ** 0.5


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--samples", type=int, required=True, help="number of tests M")
    p.add_argument("--traces", type=int, required=True, help="traces per group n")
    p.add_argument("--alpha", type=float, default=0.05)
    a = p.parse_args()
    t = thresh(a.samples, a.alpha)
    print(f"threshold {t:.2f}  MDE {mde(t, a.traces):.4f} sigma")
