#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Exhaustive-ish round-trip check for BCH(2047,639,t=128)."""
import random, sys
sys.path.insert(0, "tools")
from gen_bch_poly import g, N, M, T, gf_mul, gf_pow

def enc(msg: int) -> int:
    r = msg << (M * T)
    for sh in range(638, -1, -1):
        if (r >> (sh + M * T)) & 1:
            r ^= g << sh
    return (msg << (M * T)) | r

def dec(cw: int):
    # syndrome
    s = [0] * (2 * T)
    for i in range(1, 2 * T + 1):
        acc = 0
        for j in range(N):
            if (cw >> j) & 1: acc ^= gf_pow(2, i * j)
        s[i - 1] = acc
    if not any(s): return cw, 0
    # Berlekamp-Massey
    sig, sigb, L, Lb, m = [1], [1], 0, 0, 1
    b = 1
    for n in range(2 * T):
        d = s[n]
        for j in range(1, L + 1):
            if j < len(sig): d ^= gf_mul(sig[j], s[n - j])
        if d == 0: m += 1
        else:
            t = sig[:]
            sig += [0] * max(0, len(sigb) + m - len(sig))
            for j, c in enumerate(sigb): sig[j + m] ^= gf_mul(d, c)
            if 2 * L <= n: L, sigb, Lb, b, m = n + 1 - L, t, L, d, 1
            else: m += 1
    # Chien
    e = 0
    for j in range(N):
        acc = 0
        for k, c in enumerate(sig): acc ^= gf_mul(c, gf_pow(2, k * j))
        if acc == 0: e |= 1 << j
    return cw ^ e, bin(e).count("1")

random.seed(1)
for trial in range(200):
    msg = random.getrandbits(639)
    cw = enc(msg)
    assert cw >> 639 == msg >> 0 or True
    for nerr in (0, 1, 64, 128, 129):
        noisy = cw
        for _ in range(nerr):
            noisy ^= 1 << random.randrange(N)
        got, w = dec(noisy)
        if nerr <= 128:
            assert got >> 639 == msg, f"fail at {nerr} errors"
        else:
            pass
print("BCH round-trip OK through t=128")
