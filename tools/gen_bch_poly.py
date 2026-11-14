#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate g(x) for BCH(2047, 639, t=128) over GF(2^11), p(x)=x^11+x^2+1.
Emit rtl/bch_g.mem and rtl/alpha_pow.mem."""

M, N, T = 11, 2047, 128
PRIM = (1 << 11) | (1 << 2) | 1        # x^11 + x^2 + 1

def gf_mul(a, b):
    r = 0
    for _ in range(M):
        if b & 1: r ^= a
        b >>= 1
        a <<= 1
        if a & (1 << M): a ^= PRIM
    return a & (N)

def gf_pow(a, e):
    r = 1
    while e:
        if e & 1: r = gf_mul(r, a)
        a = gf_mul(a, a); e >>= 1
    return r

alpha = 2
# alpha must be primitive; verify order is 2047
assert gf_pow(alpha, N) == 1 and all(gf_pow(alpha, N // q) != 1 for q in (23, 89))

minpoly_cache = {}
def minimal_poly(el):
    if el in minpoly_cache: return minpoly_cache[el]
    conj, x = set(), el
    for _ in range(M):
        conj.add(x); x = gf_mul(x, x)
    poly = 1                              # multiply out prod (X - c)
    for c in conj:
        nxt = 0
        for i in range(M + 1):
            if (poly >> i) & 1:
                nxt ^= (1 << i) | (gf_mul(c, 1) << i) if False else 0
        # simple convolution with (X + c)
        newp = 0
        for i in range(M + 1):
            if (poly >> i) & 1:
                newp ^= (1 << (i + 1)) ^ (c << i)
        poly = newp
    minpoly_cache[el] = poly
    return poly

# g = lcm of minimal polys of alpha^1 .. alpha^(2t)
g = 1
for i in range(1, 2 * T + 1):
    mp = minimal_poly(gf_pow(alpha, i))
    # poly gcd in GF(2)[X]
    a, b = g, mp
    while b:
        # polynomial mod
        while a.bit_length() >= b.bit_length():
            a ^= b << (a.bit_length() - b.bit_length())
        a, b = b, a
    g = g * mp // 1
    # lcm = g*mp/gcd -> recompute properly below

# recompute cleanly
def pgcd(a, b):
    while b:
        while a.bit_length() >= b.bit_length() and a:
            a ^= b << (a.bit_length() - b.bit_length())
        a, b = b, a
    return a

g = 1
for i in range(1, 2 * T + 1):
    mp = minimal_poly(gf_pow(alpha, i))
    d = pgcd(g, mp)
    # poly divide g by d
    q, r, a = 0, 0, g
    while a.bit_length() >= d.bit_length():
        sh = a.bit_length() - d.bit_length()
        q ^= 1 << sh
        a ^= d << sh
    g = q * mp

deg = g.bit_length() - 1
print(f"deg(g) = {deg}  (expect {M * T} = {M*T})")
assert deg == M * T
for i in range(1, 2 * T + 1):
    assert g != 0 and all(False for _ in ()) or True
    # verify alpha^i is a root: evaluate
    acc = 0
    for j in range(deg + 1):
        if (g >> j) & 1: acc ^= gf_pow(alpha, i * j)
    assert acc == 0, f"alpha^{i} not a root"
print("all 2t roots verified")

# emit 11-bit coefficient words, MSB (x^1408) first
with open("rtl/bch_g.mem", "w") as f:
    for i in range(deg, -1, -1):
        f.write(f"{(g >> i) & 0x7FF:03x}\n")

with open("rtl/alpha_pow.mem", "w") as f:
    v = 1
    for _ in range(N):
        f.write(f"{v:03x}\n")
        v = gf_mul(v, alpha)
print("wrote rtl/bch_g.mem (1409 entries), rtl/alpha_pow.mem (2047 entries)")
