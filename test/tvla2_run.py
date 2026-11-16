#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Second-order fixed-vs-random TVLA, using the centered-product
preprocessing:
  * univariate: (x_s - mu_g,s)^2 at every sample s, which catches two
    shares switching in the same cycle;
  * bivariate:  (x_i - mu_g,i)(x_j - mu_g,j) for every POI pair i<j.
mu_g is each group's own mean. The threshold is computed from the total
number of tests: M2 = samples + P(P-1)/2.

usage: tvla2_run.py PREFIX POI.npy OUT.json [--alpha A]
"""
import argparse, json, os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from threshold import thresh, mde
from tvla_stats import second_order

ap = argparse.ArgumentParser()
ap.add_argument("prefix"); ap.add_argument("poi"); ap.add_argument("out")
ap.add_argument("--alpha", type=float, default=0.05)
a = ap.parse_args()
pois = np.load(a.poi)
try:
    meta, g, tu, tb, pairs = second_order(a.prefix, pois)
except (ValueError, OSError, KeyError) as e:
    print(f"2nd-order: unusable trace set ({e}) -> HARNESS FAILURE")
    sys.exit(5)
if np.isnan(tu).any() or (len(tb) and np.isnan(tb).any()):
    print("2nd-order: NaN statistics -> HARNESS FAILURE"); sys.exit(5)
if (np.count_nonzero(tu) == 0 and (len(tb) == 0 or np.count_nonzero(tb) == 0)):
    print("2nd-order: every statistic is 0 (constant or stuck traces) -> HARNESS FAILURE")
    sys.exit(5)
tests = len(tu) + len(tb)
crit = thresh(tests, a.alpha)
n = min(g[0].n, g[1].n)
pu = float(np.abs(tu).max()); iu = int(np.abs(tu).argmax())
pb = float(np.abs(tb).max()) if len(tb) else 0.0
ib = int(np.abs(tb).argmax()) if len(tb) else -1
res = {"peak": max(pu, pb), "crit": crit, "tests": tests, "n": n,
       "alpha": a.alpha, "mde": mde(crit, n), "dut": meta.get("dut"),
       "univariate": {"peak": pu, "idx": iu, "tests": len(tu)},
       "bivariate": {"peak": pb, "pair": [int(x) for x in pairs[ib]] if ib >= 0 else None,
                     "tests": len(tb), "pois": len(pois)}}
json.dump(res, open(a.out, "w"), indent=1)
print(f"2nd-order ({meta.get('dut')}): |t|max {res['peak']:.2f} crit {crit:.2f} "
      f"(univariate {pu:.2f} @ {iu}; bivariate {pb:.2f} over {len(tb)} POI pairs; n={n}/group)")
sys.exit(0 if res["peak"] < crit else 2)
