#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Independent algorithmic test of 256-cycle bit-serial Montgomery multiply."""
import random
P=(1<<256)-(1<<224)+(1<<192)+(1<<96)-1
N=0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
R=1<<256
def mont_bitserial(a,b,p):
    assert p&1 and 0<=a<p and 0<=b<p
    t=0
    for i in range(256):
        t+=a*((b>>i)&1)
        t+=p*(t&1)
        t>>=1
    return t-p if t>=p else t
def main():
    rng=random.Random(0xAD1D); total=0
    for p in (P,N):
        cases=[(0,0),(0,p-1),(1,1),(p-1,p-1),(1,p-1)]
        cases += [(rng.randrange(p),rng.randrange(p)) for _ in range(25)]
        for a,b in cases:
            assert mont_bitserial(a,b,p)==a*b*pow(R,-1,p)%p
            total+=1
        a=rng.randrange(p);b=rng.randrange(p)
        assert mont_bitserial(mont_bitserial(a,b,p),R*R%p,p)==a*b%p
    print(f"Montgomery math oracle PASS ({total} cases over P and N)")
if __name__=="__main__":main()
