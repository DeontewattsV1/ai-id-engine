#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Synthetic tests ONLY; do not cite as physical TVLA evidence."""
import tempfile
from pathlib import Path
import numpy as np
from tvla import welch_t,evaluate,InvalidTVLA,main
rng=np.random.default_rng(0x7A1A)
n=260
meta=np.array([[i%2,i%2] for i in range(n)],dtype=np.int64)
tr=rng.standard_normal((n,12))
assert evaluate(tr,meta,min_traces=100,threshold=8.0)
leaky=tr.copy()
leaky[meta[:,0]==1,3]+=3.0
assert not evaluate(leaky,meta,min_traces=100)
for invalid in [
    np.zeros((n,12)),
    np.full((n,12),np.nan),
]:
    try: evaluate(invalid,meta,min_traces=100)
    except InvalidTVLA: pass
    else: raise AssertionError("degenerate/NaN capture incorrectly passed")
try: evaluate(tr,meta[:4],min_traces=100)
except InvalidTVLA: pass
else: raise AssertionError("missing labels accepted")
try: welch_t(tr[:1],tr[1:],min_traces=100)
except InvalidTVLA: pass
else: raise AssertionError("insufficient traces accepted")
print("TVLA validation and synthetic leakage detection PASS; physical TVLA NOT RUN")
