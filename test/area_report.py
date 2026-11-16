#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Area ratio masked/plain from Yosys `stat -liberty` (sky130 tt .lib).
It reads the 'Chip area for module' line. The bundled draft summed
per-cell lines with a regex that misses Yosys's 1.23E+03 notation.

usage: area_report.py PLAIN.txt MASKED.txt OUT.json [--limit 3.60]
Exit 4 if the ratio exceeds the limit.
"""
import argparse, json, re, sys

def area(p):
    m = re.search(r"Chip area for module '\\?(\S+?)':\s*([\d.]+)", open(p).read())
    if not m:
        sys.exit(f"no 'Chip area' line in {p}")
    seq = re.search(r"sequential elements:\s*([\d.]+)", open(p).read())
    return m.group(1), float(m.group(2)), float(seq.group(1)) if seq else None

ap = argparse.ArgumentParser()
ap.add_argument("plain"); ap.add_argument("masked"); ap.add_argument("out")
ap.add_argument("--limit", type=float, default=3.60)
a = ap.parse_args()
(tp, ap_, sp), (tm, am, sm) = area(a.plain), area(a.masked)
r = am / ap_
json.dump({"plain_module": tp, "masked_module": tm, "plain_um2": ap_,
           "masked_um2": am, "plain_seq_um2": sp, "masked_seq_um2": sm,
           "ratio": r, "limit": a.limit,
           "lib": "sky130_fd_sc_hd__tt_025C_1v80"}, open(a.out, "w"), indent=1)
print(f"area {tp} {ap_:.1f} um2, {tm} {am:.1f} um2, ratio {r:.2f}x (limit {a.limit:.2f}x)")
sys.exit(0 if r <= a.limit else 4)
