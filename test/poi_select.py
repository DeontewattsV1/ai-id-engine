#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Select second-order points of interest from the NULL-control traces.
That is an independent data set, so choosing POIs never looks at the
fixed-vs-random labels it is later tested on. POIs are the highest-variance
samples, kept at least `gap` samples apart.

usage: poi_select.py NULL_PREFIX OUT.npy [--count 64] [--gap G]
"""
import argparse, json, os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from tvla_stats import select_pois

ap = argparse.ArgumentParser()
ap.add_argument("prefix"); ap.add_argument("out")
ap.add_argument("--count", type=int, default=64)
ap.add_argument("--gap", type=int, default=None, help="default: ~2 clock cycles")
a = ap.parse_args()
meta = json.load(open(a.prefix + ".meta.json"))
if meta.get("mode") != "null":
    print("poi_select: POIs must come from a --mode null trace set (independent of the tested labels)")
    sys.exit(5)
if a.gap is not None and a.gap < 0:
    sys.exit("poi_select: --gap must be >= 0")
gap = a.gap if a.gap is not None else max(1, int(round(2 * meta["samples"] / meta["cycles"])))
pois = select_pois(a.prefix, a.count, gap)
np.save(a.out, pois)
print(f"{len(pois)} POIs from null-control variance (gap {gap} samples)")
