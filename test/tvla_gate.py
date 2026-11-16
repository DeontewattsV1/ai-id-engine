#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""First-order fixed-vs-random Welch TVLA over the FULL trace window.
POIs are not used here, so selection bias stays out of the pass/fail number
(ADR-0001). Exit 3 if max |t| >= t_crit(M = samples, alpha).

usage: tvla_gate.py PREFIX OUT.json [--alpha A]
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from threshold import thresh, mde
from tvla_stats import first_order, summary

ap = argparse.ArgumentParser()
ap.add_argument("prefix"); ap.add_argument("out")
ap.add_argument("--alpha", type=float, default=0.05)
a = ap.parse_args()
meta, g, t = first_order(a.prefix)
if meta.get("mode") != "fixed":
    sys.exit("tvla_gate: trace set was not generated with --mode fixed")
crit = thresh(len(t), a.alpha)
n = min(g[0].n, g[1].n)
res = summary(t, crit=crit, n=n, samples=len(t), alpha=a.alpha, mde=mde(crit, n),
              cycles=meta["cycles"], dut=meta.get("dut"),
              mean_energy_pj=float((g[0].mean.mean() + g[1].mean.mean()) / 2))
res["peak_cycle"] = int(res["idx"] * meta["cycles"] / len(t))
json.dump(res, open(a.out, "w"), indent=1)
print(f"1st-order ({meta.get('dut')}): |t|max {res['peak']:.2f} crit {crit:.2f} "
      f"(M={len(t)}, n={n}/group) at sample {res['idx']} (cycle ~{res['peak_cycle']}) "
      f"MDE {res['mde']:.4f} sigma")
sys.exit(0 if res["peak"] < crit else 3)
