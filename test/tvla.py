#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail-closed first-order Welch TVLA screen for PROVIDED power traces.

No trace collection is performed here. Absence of capture data is NOT RUN,
not PASS. First-order TVLA alone never establishes resistance to DPA/CPA,
higher-order leakage, fault injection or masking correctness.

Trace file: (n_traces,n_samples) float; meta: (n_traces,2) 0/1 labels for
ecdsa fixed/random and BCH fixed/random. Use independently acquired labels.
"""
import argparse
import sys
from pathlib import Path
import numpy as np

class InvalidTVLA(ValueError):
    pass

def welch_t(g0,g1,min_traces=100):
    a=np.asarray(g0,dtype=np.float64)
    b=np.asarray(g1,dtype=np.float64)
    if a.ndim!=2 or b.ndim!=2 or a.shape[1]!=b.shape[1]:
        raise InvalidTVLA("groups require equal-width 2D traces")
    if a.shape[0]<min_traces or b.shape[0]<min_traces or a.shape[1]<1:
        raise InvalidTVLA(f"each group requires >= {min_traces} traces and >=1 sample")
    if not (np.isfinite(a).all() and np.isfinite(b).all()):
        raise InvalidTVLA("non-finite sample present")
    m0=a.mean(axis=0)
    m1=b.mean(axis=0)
    v0=a.var(axis=0,ddof=1)
    v1=b.var(axis=0,ddof=1)
    den=np.sqrt(v0/len(a)+v1/len(b))
    if np.all(den==0):
        raise InvalidTVLA("all samples have zero within-group variance")
    out=np.zeros_like(den)
    np.divide(m0-m1,den,out=out,where=(den!=0))
    # Equal constant groups at a sample carry no discriminative evidence;
    # different constants reveal a deterministic difference.
    out[(den==0)&(m0!=m1)]=np.inf
    return out

def report(name,tt,threshold=4.5):
    if tt.ndim!=1 or not len(tt) or np.isnan(tt).any():
        raise InvalidTVLA("invalid t-value array")
    idx=int(np.argmax(np.abs(tt)))
    peak=float(np.abs(tt[idx]))
    passed=peak<threshold
    print(f"{name}: peak |t|={peak:.3f} sample={idx} "
          f"{'SCREEN PASS' if passed else 'LEAKAGE FLAG'}")
    return passed

def evaluate(tr,meta,min_traces=100,threshold=4.5):
    tr=np.asarray(tr,dtype=np.float64)
    meta=np.asarray(meta)
    if tr.ndim!=2 or meta.ndim!=2 or meta.shape!=(tr.shape[0],2):
        raise InvalidTVLA("traces must be 2D, metadata Nx2")
    if not np.isfinite(tr).all() or not np.isin(meta,[0,1]).all():
        raise InvalidTVLA("non-finite trace or nonbinary group label")
    result=True
    for col,name in enumerate(("ECDSA ladder","BCH Chien")):
        t=welch_t(tr[meta[:,col]==0],tr[meta[:,col]==1],min_traces)
        result=report(name,t,threshold) and result
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures",type=Path,default=Path("captures"))
    parser.add_argument("--min-traces",type=int,default=100)
    args=parser.parse_args()
    if args.min_traces<2: parser.error("at least 2 traces required")
    try:
        tr=np.load(args.captures/"traces.npy",allow_pickle=False)
        meta=np.load(args.captures/"meta.npy",allow_pickle=False)
        passed=evaluate(tr,meta,args.min_traces)
    except (OSError,ValueError,InvalidTVLA) as exc:
        print(f"TVLA NOT RUN / INVALID: {exc}",file=sys.stderr)
        return 2
    print("TVLA FIRST-ORDER SCREEN:", "PASS (not a security proof)" if passed else "FAIL")
    return 0 if passed else 1

if __name__=="__main__":
    raise SystemExit(main())
