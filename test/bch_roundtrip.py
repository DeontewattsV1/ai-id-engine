#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""BCH(2047,639,t=171) math reference; does not certify RTL BCH decoder."""
import random,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from gen_bch_poly import N,K,T,PARITY_BITS,generator,powers,verify
APOW=powers()
LOG={v:i for i,v in enumerate(APOW)}
G=generator(T,APOW)
def field_mul(a,b):
    return APOW[(LOG[a]+LOG[b])%N] if a and b else 0
def field_div(a,b):
    if not b: raise ZeroDivisionError
    return APOW[(LOG[a]-LOG[b])%N] if a else 0
def encode(message):
    if not 0<=message<(1<<K): raise ValueError("invalid message")
    rem=message<<PARITY_BITS
    for shift in range(K-1,-1,-1):
        if (rem>>(shift+PARITY_BITS))&1:
            rem^=G<<shift
    return (message<<PARITY_BITS)|rem
def syndrome(word):
    positions=[]
    while word:
        low=word&-word; positions.append(low.bit_length()-1); word^=low
    return [fold_syndrome(positions,i) for i in range(1,2*T+1)]
def fold_syndrome(positions,i):
    out=0
    for j in positions: out^=APOW[(i*j)%N]
    return out
def decode(word):
    if not 0<=word<(1<<N): raise ValueError("invalid codeword")
    s=syndrome(word)
    if not any(s): return word>>PARITY_BITS,0
    c=[1]+[0]*(2*T); bpoly=c[:]
    L=0; shift=1; b=1
    for n in range(2*T):
        d=s[n]
        for j in range(1,L+1): d^=field_mul(c[j],s[n-j])
        if d==0:
            shift+=1;continue
        old=c[:]; scale=field_div(d,b)
        for j in range(2*T+1-shift):
            c[j+shift]^=field_mul(scale,bpoly[j])
        if 2*L<=n:
            L=n+1-L; bpoly,b,shift=old,d,1
        else: shift+=1
    if L>T: raise ValueError("locator exceeds t")
    error_pos=[]
    for j in range(N):
        x=APOW[(-j)%N]; y=0
        for coefficient in reversed(c[:L+1]):
            y=field_mul(y,x)^coefficient
        if y==0: error_pos.append(j)
    if len(error_pos)!=L or len(error_pos)>T:
        raise ValueError("locator root count mismatch")
    for j in error_pos: word^=1<<j
    if any(syndrome(word)): raise ValueError("corrected syndrome nonzero")
    return word>>PARITY_BITS,len(error_pos)
def main():
    assert generator(128,APOW).bit_length()-1==1232
    assert G.bit_length()-1==1408==PARITY_BITS
    verify(G,T,APOW)
    random_gen=random.Random(0xBACE)
    for case,message in enumerate((0,(1<<K)-1,random_gen.getrandbits(K))):
        codeword=encode(message)
        assert not any(syndrome(codeword))
        for nerr in (0,1,128,171):
            flip=sum(1<<j for j in random_gen.sample(range(N),nerr))
            decoded,corrected=decode(codeword^flip)
            assert decoded==message and corrected==nerr,(case,nerr)
    print("BCH math oracle PASS (12 deterministic round-trip cases)")
if __name__=="__main__":main()
