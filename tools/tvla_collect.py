#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the Verilator TVLA harness in parallel chunks and merge the results.

usage: tvla_collect.py --bin build/obj_masked_v2/tvla_masked_v2
                       --caps build/tvla_masked_v2.caps --dut masked_v2
                       --mode fixed|null --n N --samples M --seed S
                       --out build/tvla/masked_v2_fixed [-j J] [--tau T]
                       [--noise SIGMA]

Each chunk gets its own seed (S*1000 + chunk) and n/J traces per group.
The merged trace set has exactly N traces per group. The harness's
functional check rows (output shares for the first traces) are verified
against Python a*b*2^-256 mod n, so a broken netlist or cell model fails
here before any statistics run.
"""
import argparse, json, os, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

P256_N = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
SHARES = {"plain": 1, "masked_v2": 2, "masked3": 3}


def verify_check(path, dut):
    k = SHARES[dut]
    rinv = pow(1 << 256, -1, P256_N)
    rows = 0
    for line in open(path):
        f = line.split()
        if not f:
            continue
        a, b = int(f[1], 16), int(f[2], 16)
        outs = [int(x, 16) for x in f[3:3 + k]]
        got = sum(outs) % P256_N
        want = a * b * rinv % P256_N
        if got != want:
            sys.exit(f"FUNCTIONAL MISMATCH in {path}: a*b*R^-1 want {want:x} got {got:x}")
        if k > 1 and want not in (0,) and any(o == want for o in outs):
            sys.exit(f"an output share equals the unmasked result in {path}")
        rows += 1
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", required=True); ap.add_argument("--caps", required=True)
    ap.add_argument("--dut", required=True, choices=sorted(SHARES))
    ap.add_argument("--mode", required=True, choices=["fixed", "null"])
    ap.add_argument("--n", type=int, required=True)
    ap.add_argument("--samples", type=int, required=True)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out", required=True)
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--tau", type=float, default=0.5)
    ap.add_argument("--noise", type=float, default=0.0)
    a = ap.parse_args()
    j = max(1, min(a.j, a.n))
    sizes = [a.n // j + (1 if i < a.n % j else 0) for i in range(j)]
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)

    def run(i):
        part = f"{a.out}.part{i}"
        cmd = [a.bin, "--mode", a.mode, "--n", str(sizes[i]), "--samples",
               str(a.samples), "--seed", str(a.seed * 1000 + i), "--out", part,
               "--caps", a.caps, "--tau", str(a.tau), "--noise", str(a.noise),
               "--check", "4"]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode:
            sys.stderr.write(r.stdout + r.stderr)
            raise SystemExit(f"harness chunk {i} failed with exit {r.returncode}")
        return part

    with ThreadPoolExecutor(j) as ex:
        parts = list(ex.map(run, range(j)))
    metas = [json.load(open(p + ".meta.json")) for p in parts]
    cycles = {m["cycles"] for m in metas}
    if len(cycles) != 1:
        sys.exit(f"chunks disagree on latency: {cycles} (data-dependent timing)")
    checked = 0
    for ext in (".f32", ".lbl"):
        with open(a.out + ext, "wb") as out:
            for p in parts:
                with open(p + ext, "rb") as f:
                    shutil.copyfileobj(f, out, 1 << 22)
    with open(a.out + ".check.txt", "w") as out:
        for p in parts:
            checked += verify_check(p + ".check.txt", a.dut)
            out.write(open(p + ".check.txt").read())
    for p in parts:
        for ext in (".f32", ".lbl", ".check.txt", ".cycles.f64", ".meta.json"):
            if os.path.exists(p + ext):
                os.remove(p + ext)
    meta = dict(metas[0])
    meta.update({"n_per_group": a.n, "chunks": j, "seed": a.seed, "dut": a.dut,
                 "functional_checks": checked})
    json.dump(meta, open(a.out + ".meta.json", "w"), indent=1)
    print(f"collect {a.dut} {a.mode}: {2*a.n} traces x {a.samples} samples, "
          f"{meta['cycles']} cycles, {checked} outputs verified against Python")


if __name__ == "__main__":
    main()
