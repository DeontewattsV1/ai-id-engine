#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate deterministic hardware-unit known-answer vectors."""
from pathlib import Path
import random
from test_montgomery import P,N,R
from bch_roundtrip import K,PARITY_BITS,encode
HERE=Path(__file__).resolve().parent
rng=random.Random(0xA11D2026)
with (HERE/"mont_vectors.txt").open("w",encoding="ascii") as f:
    for p in (P,N):
        pairs=[(0,0),(1,1),(p-1,p-1),(0,p-1)]
        pairs += [(rng.randrange(p),rng.randrange(p)) for _ in range(12)]
        for a,b in pairs:
            f.write(f"{p:064x} {(-pow(p,-1,1<<32))&0xffffffff:08x} "
                    f"{a:064x} {b:064x} {a*b*pow(R,-1,p)%p:064x}\n")
with (HERE/"bch_vectors.txt").open("w",encoding="ascii") as f:
    for msg in [0,(1<<K)-1,1,1<<(K-1)] + [rng.getrandbits(K) for _ in range(8)]:
        f.write(f"{msg:0160x} {encode(msg)&((1<<PARITY_BITS)-1):0352x}\n")
print("Known-answer vectors written (32 Montgomery, 12 BCH)")
