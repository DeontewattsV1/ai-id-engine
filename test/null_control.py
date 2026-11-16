#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Mandatory null control (ADR-0001): random-vs-random first-order Welch on
the masked DUT. It runs before the real test. If its max |t| reaches the
computed threshold, the harness or statistics are broken: exit 5, which is
a harness failure, not a leakage verdict.

usage: null_control.py PREFIX OUT.json [--alpha A]
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
if meta.get("mode") != "null":
    sys.exit("null_control: trace set was not generated with --mode null")
crit = thresh(len(t), a.alpha)
n = min(g[0].n, g[1].n)
res = summary(t, crit=crit, n=n, samples=len(t), alpha=a.alpha, mde=mde(crit, n),
              passed=bool(abs(t).max() < crit), dut=meta.get("dut"))
json.dump(res, open(a.out, "w"), indent=1)
print(f"null control (random vs random, {meta.get('dut')}): |t|max {res['peak']:.2f} "
      f"/ crit {crit:.2f} at sample {res['idx']} -> {'ok' if res['passed'] else 'HARNESS FAILURE'}")
sys.exit(0 if res["passed"] else 5)
