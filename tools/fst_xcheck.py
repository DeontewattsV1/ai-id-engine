#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Independent cross-check of the harness power model against Verilator's
own waveform (VCD directly, or FST through fst2vcd).

The harness computes per-cycle energy inside the simulation from pw_bits.
This script ignores pw_bits. It reads every individual net n<id> of
tvla_dut from the waveform, takes the net values at each clk=1 dump,
weights each net that toggled by its capacitance (build/tvla_<dut>.json),
multiplies by 0.5*Vdd^2, and requires a match with PREFIX.cycles.f64.

usage: fst_xcheck.py TRACE.{fst,vcd} NETLIST_META.json CYCLES.f64
"""
import json, shutil, subprocess, sys
import numpy as np


def read_vcd(path):
    if path.endswith(".vcd"):
        return open(path).read().splitlines()
    tool = shutil.which("fst2vcd")
    if not tool:
        sys.exit("fst2vcd not found (OSS CAD Suite / gtkwave)")
    return subprocess.run([tool, path], capture_output=True, text=True,
                          check=True).stdout.splitlines()


def main():
    wave, metaf, cyf = sys.argv[1:4]
    meta = json.load(open(metaf))
    caps = np.array(meta["caps_pf"])
    index = {f"n{b}": i for i, b in enumerate(meta["bits"])}
    lines = read_vcd(wave)
    code_nets, clk_code, scope, i = {}, None, [], 0
    for i, line in enumerate(lines):
        f = line.split()
        if not f:
            continue
        if f[0] == "$scope":
            scope.append(f[2])
        elif f[0] == "$upscope":
            scope.pop()
        elif f[0] == "$var" and len(scope) == 2 and scope[1] == "tvla_dut":
            code, name = f[3], f[4]
            if name in index:
                code_nets.setdefault(code, []).append(index[name])
            if name == "clk":
                clk_code = code
        elif f[0] == "$enddefinitions":
            break
    covered = sum(len(v) for v in code_nets.values())
    if clk_code is None or covered != len(caps):
        sys.exit(f"waveform covers {covered}/{len(caps)} nets (clk {'ok' if clk_code else 'missing'})")
    code_idx = {c: np.array(v) for c, v in code_nets.items()}
    val = np.zeros(len(caps), dtype=np.uint8)
    clk, snaps, have_t = 0, [], False
    for line in lines[i + 1:]:
        if not line:
            continue
        c0 = line[0]
        if c0 == "#":
            if have_t and clk == 1:
                snaps.append(val.copy())
            have_t = True
            continue
        if c0 in "01xz" and len(line) > 1:
            code = line[1:]
            bit = 1 if c0 == "1" else 0
            if code == clk_code:
                clk = bit
            idx = code_idx.get(code)
            if idx is not None:
                val[idx] = bit
    if have_t and clk == 1:
        snaps.append(val.copy())
    vdd = meta["vdd"]
    e = np.array([(caps * (snaps[k] ^ snaps[k - 1])).sum() * 0.5 * vdd * vdd
                  for k in range(1, len(snaps))])
    ref = np.fromfile(cyf, dtype=np.float64)[1:]   # first cycle has no clk=1 predecessor
    m = min(len(ref), len(e))
    if m < 100:
        sys.exit(f"too few cycles to compare ({m})")
    d = np.abs(e[-m:] - ref[-m:])
    rel = d.max() / max(ref[-m:].max(), 1e-30)
    print(f"xcheck: {m} cycles, {len(caps)} nets from the waveform; max |dE| "
          f"{d.max():.3e} pJ (rel {rel:.1e}); mean {ref[-m:].mean():.3f} pJ/cycle")
    sys.exit(0 if rel < 1e-9 else 1)


if __name__ == "__main__":
    main()
