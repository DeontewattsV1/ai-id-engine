#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Reproducible primitive narrow-sense binary BCH construction.

Default: BCH(2047,639), 1408 parity bits, designed t=171.
The previously stated t=128 yields degree 1232, not 1408.
bch_g.mem contains ONE 1409-bit hex word, alpha_pow.mem 2047 words.
"""
import argparse
from pathlib import Path
M=11; N=(1<<M)-1; T=171; K=639; PARITY_BITS=N-K
PRIM=(1<<M)|(1<<2)|1

def gf_mul(a,b):
    result=0
    for _ in range(M):
        if b&1: result^=a
        b>>=1; a<<=1
        if a&(1<<M): a^=PRIM
    return result&N

def powers():
    result=[]; x=1
    for _ in range(N):
        result.append(x)
        x=gf_mul(x,2)
    if x!=1 or len(set(result))!=N:
        raise ValueError("alpha not primitive")
    return result

def cosets(t):
    seen=set(); result=[]
    for i in range(1,2*t+1):
        if i in seen: continue
        orbit=[]; j=i
        while j not in seen:
            seen.add(j); orbit.append(j); j=2*j%N
        result.append(tuple(orbit))
    return result

def minimal_poly(exponents,apow):
    coeffs=[1]
    for i in exponents:
        root=apow[i]; nxt=[0]*(len(coeffs)+1)
        for j,c in enumerate(coeffs):
            nxt[j]^=gf_mul(c,root); nxt[j+1]^=c
        coeffs=nxt
    if any(c not in (0,1) for c in coeffs):
        raise AssertionError("minimal polynomial is not binary")
    return sum(c<<i for i,c in enumerate(coeffs))

def gf2_poly_mul(a,b):
    result=0
    while b:
        if b&1: result^=a
        a<<=1; b>>=1
    return result

def generator(t=T,alpha_pow=None):
    if not 1<=t<=N//2: raise ValueError("invalid strength")
    if alpha_pow is None: alpha_pow=powers()
    g=1
    for orbit in cosets(t):
        g=gf2_poly_mul(g,minimal_poly(orbit,alpha_pow))
    return g

def verify(g,t,apow):
    deg=sum(len(x) for x in cosets(t))
    if g.bit_length()-1!=deg or (g&1)!=1:
        raise AssertionError("wrong generator degree or constant")
    for i in range(1,2*t+1):
        x=apow[i%N]; val=0
        for j in range(deg,-1,-1):
            val=gf_mul(val,x)^((g>>j)&1)
        if val: raise AssertionError(f"root alpha^{i} does not vanish")

def write_roms(out,t=T):
    apow=powers(); g=generator(t,apow)
    verify(g,t,apow)
    degree=g.bit_length()-1
    out.mkdir(parents=True,exist_ok=True)
    (out/"bch_g.mem").write_text(f"{g:0{(degree+4)//4}x}\n",encoding="ascii")
    (out/"alpha_pow.mem").write_text("".join(f"{x:03x}\n" for x in apow),encoding="ascii")
    return degree

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out-dir",type=Path,default=Path("rtl"))
    p.add_argument("--t",type=int,default=T)
    a=p.parse_args()
    deg=write_roms(a.out_dir,a.t)
    print(f"BCH n={N}, t={a.t}, degree={deg}, dimension={N-deg}")
    if a.t==T and deg!=PARITY_BITS:
        raise AssertionError("RTL width mismatch")
if __name__=="__main__": main()
