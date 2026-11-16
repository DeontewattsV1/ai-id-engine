#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""TVLA gate. It always prints every number, then returns one verdict.

usage: gate.py T1.json T2.json [--dir build/tvla] [--profile NAME]
reads DIR/null.json (mandatory null control), DIR/area.json,
      DIR/positive.json (plain-DUT positive control),
      DIR/<plain|masked>_fixed.meta.json (latency)

exit 5  harness failure: the null control found a "leak" in
        random-vs-random data, or the positive control (unmasked
        mont_mul) was NOT detected, so the harness cannot see leaks
exit 2  second-order leak in the 2-share design -> use 3 shares
        (rtl/mont_mul_masked3.v)
exit 3  first-order leak -> the masked datapath (CSA/accumulator) is
        incomplete
exit 4  area ratio above the limit -> share the multiplier
exit 0  PASS at this trace count. That is evidence, not certification.
        CI is not signoff.
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from threshold import mde

ap = argparse.ArgumentParser()
ap.add_argument("t1"); ap.add_argument("t2")
ap.add_argument("--dir", default="build/tvla")
ap.add_argument("--profile", default="?")
ap.add_argument("--masked", default="masked_v2")
a = ap.parse_args()
J = lambda n: json.load(open(os.path.join(a.dir, n)))
nul, area, pos = J("null.json"), J("area.json"), J("positive.json")
t1, t2 = json.load(open(a.t1)), json.load(open(a.t2))
lp = J("plain_fixed.meta.json")["cycles"] - 1
lm = J(f"{a.masked}_fixed.meta.json")["cycles"] - 1

pos_ok = pos["peak"] >= pos["crit"]
if nul["peak"] >= nul["crit"] or not pos_ok:
    verdict, code = "FAIL(harness): null control or positive control failed", 5
elif t2["peak"] >= t2["crit"]:
    verdict, code = "VERDICT 3-share (second-order leak in 2-share design)", 2
elif t1["peak"] >= t1["crit"]:
    verdict, code = "VERDICT masked CSA incomplete (first-order leak)", 3
elif area["ratio"] > area["limit"]:
    verdict, code = "VERDICT shared multiplier (area over limit)", 4
else:
    verdict, code = "PASS at this trace count (evidence, not certification; CI is not signoff)", 0

summary = {
    "profile": a.profile, "masked_dut": a.masked,
    "traces_per_group": t1["n"], "samples": t1["samples"], "alpha": t1["alpha"],
    "null_control": {"peak": nul["peak"], "crit": nul["crit"], "passed": nul["peak"] < nul["crit"]},
    "positive_control_plain": {"peak": pos["peak"], "crit": pos["crit"], "detected": pos_ok},
    "first_order": {"peak": t1["peak"], "crit": t1["crit"], "idx": t1["idx"]},
    "second_order": {"peak": t2["peak"], "crit": t2["crit"], "tests": t2["tests"],
                     "univariate": t2["univariate"]["peak"], "bivariate": t2["bivariate"]["peak"]},
    "mde_sigma": mde(t1["crit"], t1["n"]),
    "area": {"plain_um2": area["plain_um2"], "masked_um2": area["masked_um2"],
             "ratio": area["ratio"], "limit": area["limit"]},
    "latency_cycles": {"plain": lp, "masked": lm, "delta": lm - lp, "ratio": lm / lp},
    "verdict": verdict, "exit": code,
}
json.dump(summary, open(os.path.join(a.dir, "summary.json"), "w"), indent=1)
lines = [
    f"TVLA gate (profile {a.profile}, {t1['n']} traces/group, M={t1['samples']}, alpha={t1['alpha']})",
    f"  null control    |t|max {nul['peak']:.2f} / crit {nul['crit']:.2f}  {'ok' if nul['peak'] < nul['crit'] else 'FAIL'}",
    f"  positive ctrl   |t|max {pos['peak']:.2f} / crit {pos['crit']:.2f}  {'detected' if pos_ok else 'NOT DETECTED'} (unmasked mont_mul)",
    f"  1st order       |t|max {t1['peak']:.2f} / crit {t1['crit']:.2f}",
    f"  2nd order       |t|max {t2['peak']:.2f} / crit {t2['crit']:.2f}  (univariate {t2['univariate']['peak']:.2f}, bivariate {t2['bivariate']['peak']:.2f}; {t2['tests']} tests)",
    f"  MDE             {summary['mde_sigma']:.4f} sigma (1st order)",
    f"  area            {area['plain_um2']:.0f} -> {area['masked_um2']:.0f} um2 = {area['ratio']:.2f}x (limit {area['limit']:.2f}x)",
    f"  latency         {lp} -> {lm} cycles (+{lm - lp}, {lm / lp:.2f}x)",
    f"  {verdict}",
]
open(os.path.join(a.dir, "summary.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(code)
