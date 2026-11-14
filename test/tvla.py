#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Welch t-test on power traces. Gate: |t| < 4.5 over the whole window."""
import numpy as np

def welch_t(g0, g1):
    n0, n1 = len(g0), len(g1)
    m0, m1 = g0.mean(0), g1.mean(0)
    v0, v1 = g0.var(0, ddof=1), g1.var(0, ddof=1)
    return (m0 - m1) / np.sqrt(v0 / n0 + v1 / n1)

def report(name, t):
    peak = np.nanmax(np.abs(t))
    idx = int(np.nanargmax(np.abs(t)))
    status = "PASS" if peak < 4.5 else "FAIL"
    print(f"{name:28s} |t|max={peak:6.2f} @ {idx:5d}  {status}")
    return peak < 4.5

def main():
    tr = np.load("captures/traces.npy")      # (n, samples)
    meta = np.load("captures/meta.npy")      # (n, 2) = [group, bit]
    ok = True
    ok &= report("ecdsa ladder", welch_t(tr[meta[:, 0] == 0], tr[meta[:, 0] == 1]))
    ok &= report("bch chien",    welch_t(tr[meta[:, 1] == 0], tr[meta[:, 1] == 1]))
    print("TVLA", "PASS" if ok else "FAIL")
    return 0 if ok else 1

if __name__ == "__main__":
    raise SystemExit(main())
