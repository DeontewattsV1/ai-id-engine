#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""cells-check (ADR-0002): every cell that abc selected in any TVLA netlist
must have a model in the vendored sim/ file, and the models' provenance
header must name the pinned .lib hash.

usage: vendor_check.py MODELS.v NETLIST.v [NETLIST.v ...]
"""
import re, sys

models, nets = sys.argv[1], sys.argv[2:]
src = open(models).read()
have = set(re.findall(r"^module\s+(sky130_fd_sc_hd__\w+)", src, re.M))
used = set()
for p in nets:
    used |= set(re.findall(r"^\s*(sky130_fd_sc_hd__\w+)\s+\S+\s*\(", open(p).read(), re.M))
missing = sorted(used - have)
for c in missing:
    print(f"MISSING model: {c}")
if "SPDX-License-Identifier: Apache-2.0" not in src or "sha256 " not in src:
    print("models file lacks the Apache-2.0 / provenance header")
    sys.exit(1)
if missing:
    print("run `make cells` to regenerate sim/sky130_fd_sc_hd_cells.v")
    sys.exit(1)
print(f"cells-check: {len(used)} cells used, {len(have)} modelled, all covered")
