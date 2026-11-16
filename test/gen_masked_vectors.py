#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Vectors for the masked Montgomery multipliers (tb/tb_mont_mul_masked.sv).

Each line holds 20 hex fields, in the order tb_mont_mul_masked.sv reads them:
  m n0' a b  a0 a1 b0 b1  x0 x1 x2 y0 y1 y2  rp0 rp1 rc rs rt  expected
a0+a1 = a and b0+b1 = b (mod m) are the 2-share split; x0+x1+x2 = a and
y0+y1+y2 = b (mod m) are an independent 3-share split. expected = a*b*2^-256
mod m.
"""
import random, sys

P256_P = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
P256_N = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
R = 1 << 256


def mont(a, b, m):
    return a * b * pow(R, -1, m) % m


def main(out, count=24, seed=0x5EED):
    rng = random.Random(seed)
    rows = []
    for k in range(count):
        m = P256_N if k % 2 else P256_P
        n0 = (-pow(m, -1, 1 << 32)) % (1 << 32)
        edge = [0, 1, m - 1]
        a = edge[k % 3] if k < 6 else rng.randrange(m)
        b = edge[(k // 3) % 3] if k < 6 else rng.randrange(m)
        a0, b0 = rng.randrange(m), rng.randrange(m)
        a1, b1 = (a - a0) % m, (b - b0) % m
        # 3-share split (independent of the 2-share one)
        x0, x1, y0, y1 = (rng.randrange(m) for _ in range(4))
        x2, y2 = (a - x0 - x1) % m, (b - y0 - y1) % m
        rp0, rp1, rc = (rng.getrandbits(256) for _ in range(3))
        rs, rt = rng.randrange(m), rng.randrange(m)
        rows.append([m, n0, a, b, a0, a1, b0, b1, x0, x1, x2, y0, y1, y2,
                     rp0, rp1, rc, rs, rt, mont(a, b, m)])
    with open(out, "w") as f:
        for r in rows:
            f.write(" ".join(f"{v:064x}" for v in r) + "\n")
    print(f"wrote {len(rows)} masked Montgomery vectors to {out}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "test/masked_vectors.txt")
