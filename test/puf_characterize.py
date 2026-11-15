#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Analyze SRAM PUF dumps. Input: one 2047-bit line per cold boot, per die.
Usage: puf_characterize.py raw/<die>.txt"""
import sys, itertools, statistics
from pathlib import Path

def hd(a: int, b: int, n=2047) -> int:
    return bin((a ^ b) & ((1 << n) - 1)).count("1")

def main(die_dir):
    dies = {}
    for f in Path(die_dir).glob("*.txt"):
        boots = [int(l.strip(), 2) for l in f.read_text().splitlines() if l.strip()]
        if len(boots) < 500:
            print(f"{f.stem}: only {len(boots)} boots, need 500"); continue
        dies[f.stem] = boots

    intra = []
    for name, boots in dies.items():
        ref = boots[0]
        d = [hd(ref, b) for b in boots[1:]]
        intra.append(statistics.mean(d))
        p99 = sorted(d)[int(0.99 * len(d))]
        print(f"{name}: mean intra-HD {statistics.mean(d):.2f} bits "
              f"({100*statistics.mean(d)/2047:.2f}%)  p99 {p99}  max {max(d)}")

    inter = []
    names = list(dies)
    for a, b in itertools.combinations(names, 2):
        inter.append(hd(dies[a][0], dies[b][0]))
    mi = statistics.mean(inter)
    print(f"\ninter-die mean HD {mi:.2f} bits ({100*mi/2047:.2f}%)")

    worst = max(intra)
    print(f"\nworst intra-die {worst} bits = {100*worst/2047:.2f}%")
    print(f"BCH t=128 headroom: {128 - worst} bits "
          f"({'OK' if worst < 128 else 'FAIL - raise t'})")
    print(f"separability margin: {mi - worst:.1f} bits "
          f"({'OK' if mi - worst > 200 else 'WEAK'})")

    # min-entropy estimate (per SP 800-90B, most-common-value)
    for name, boots in dies.items():
        bits = [sum((b >> j) & 1 for b in boots) for j in range(2047)]
        p = max(sum(1 for c in bits if c > len(boots)//2),
                sum(1 for c in bits if c <= len(boots)//2)) / 2047
        print(f"{name}: MCV min-entropy ~{(-__import__('math').log2(p)):.2f} bits/cell")

if __name__ == "__main__":
    main(sys.argv[1])
