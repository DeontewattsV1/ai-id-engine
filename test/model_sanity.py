#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Sanity-check the per-net capacitance model: enough nets, a realistic
spread (a flat model would weight every toggle equally), and no zero-cap
switching nets."""
import json, sys

m = json.load(open(sys.argv[1]))
caps = m["caps_pf"]
nz = [c for c in caps if c > 0]
spread = max(nz) / min(nz)
zero = len(caps) - len(nz)
print(f"model {m['top']}: {m['nets']} nets, {m['cells']} cells, cap "
      f"{min(nz)*1e3:.2f}..{max(nz)*1e3:.1f} fF (spread {spread:.0f}x), "
      f"{zero} zero-cap nets, Vdd {m['vdd']} V")
ok = len(nz) >= 2000 and spread >= 8 and zero <= len(caps) * 0.05
if not ok:
    print("FAIL: capacitance model is flat, too small, or mostly zero")
sys.exit(0 if ok else 1)
