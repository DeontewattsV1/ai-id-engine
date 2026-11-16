#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Descriptive SRAM PUF repeatability gate; NOT a min-entropy certification.

Input: one EXACTLY 2047-bit binary line per cold boot, >=500 boots per die.
Enrollment baseline is the FIRST line for each die.
The implemented BCH(2047,639) designed correction t is 171.
Use independent temperature, voltage and aging campaigns for qualification.
"""
from pathlib import Path
import argparse
import itertools
import statistics
N=2047
T=171
MIN_BOOTS=500
def hd(a,b,n=N):
    return ((a^b)&((1<<n)-1)).bit_count()
def parse_boots(path):
    data=[]
    for number,line in enumerate(path.read_text(encoding="ascii").splitlines(),1):
        raw=line.strip()
        if not raw: continue
        if len(raw)!=N or any(bit not in "01" for bit in raw):
            raise ValueError(f"{path.name}:{number}: expected exactly {N} binary digits")
        data.append(int(raw,2))
    return data
def analyze(folder):
    files=sorted(Path(folder).glob("*.txt"))
    if not files: raise ValueError("no PUF die files")
    dies={}; maxima=[]
    for file in files:
        boots=parse_boots(file)
        if len(boots)<MIN_BOOTS:
            print(f"{file.stem}: INSUFFICIENT {len(boots)} boots (need {MIN_BOOTS})")
            continue
        ref=boots[0]
        distances=[hd(ref,b) for b in boots[1:]]
        distances.sort()
        maximum=distances[-1]
        mean=statistics.mean(distances)
        p99=distances[min(len(distances)-1,int(0.99*(len(distances)-1)))]
        maxima.append(maximum);dies[file.stem]=ref
        print(f"{file.stem}: mean intra-HD {mean:.2f} bits "
              f"({100*mean/N:.2f}%), p99 {p99}, observed max {maximum}")
        print(f"{file.stem}: BCH t={T} observed headroom {T-maximum} bits "
              f"({'WITHIN OBSERVED BOUND' if maximum<=T else 'FAIL'})")
    if not maxima: raise ValueError("no die has enough boots")
    worst=max(maxima)
    print(f"worst observed intra-die errors: {worst} / {N}")
    inter=[hd(a,b) for a,b in itertools.combinations(dies.values(),2)]
    if inter:
        print(f"inter-die enrolled reference mean HD: {statistics.mean(inter):.2f} bits")
    else:
        print("inter-die assessment: NOT RUN (requires >=2 qualified dies)")
    print("NIST SP 800-90B min-entropy assessment: NOT RUN")
    print("PUF qualification across operating conditions: NOT RUN")
    print(f"OBSERVED RECONSTRUCTION BOUND: {'FAIL' if worst>T else 'PASS (observed only)'}")
    return worst<=T
def main(folder):
    return analyze(folder)
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("die_dir",type=Path)
    args=parser.parse_args()
    try:
        raise SystemExit(0 if analyze(args.die_dir) else 1)
    except (OSError,ValueError) as exc:
        parser.error(str(exc))
