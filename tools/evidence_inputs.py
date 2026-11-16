#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write the inputs file for `aiid evidence create` from a finished
`make tvla` run: which files identify the assessed model (netlists, the
power model, the cell library), which files define the stimulus, the
stimulus description (seeds, modes, counts) and the measurement envelope.

usage: evidence_inputs.py --profile ci --masked masked3 --dir build/tvla --out build/tvla/evidence_inputs.json
"""
import argparse, json, subprocess, tomllib

ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
ap.add_argument("--profile", required=True)
ap.add_argument("--masked", required=True)
ap.add_argument("--dir", default="build/tvla")
ap.add_argument("--out", required=True)
ap.add_argument("--yosys", default="yosys")
ap.add_argument("--verilator", default="verilator")
a = ap.parse_args()

prof = tomllib.load(open("config/tvla.toml", "rb"))[a.profile]


def version(cmd):
    try:
        out = subprocess.run([cmd, "--version" if "verilator" in cmd else "-V"],
                             capture_output=True, text=True, timeout=120).stdout
        return out.strip().splitlines()[0] if out.strip() else "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


lib = json.load(open("build/lib.json"))
m = a.masked
inputs = {
    "model_files": [
        "rtl/mont_mul.v", f"rtl/mont_mul_{m}.v",
        "build/sky130_plain.v", f"build/sky130_{m}.v",
        "build/tvla_plain.v", f"build/tvla_{m}.v",
        "build/tvla_plain.caps", f"build/tvla_{m}.caps",
        "sim/sky130_fd_sc_hd_cells.v", "build/pdk/sky130_fd_sc_hd__tt_025C_1v80.lib",
    ],
    "stimulus_files": [
        "config/tvla.toml", "tb/tvla_harness.cpp", "tools/tvla_collect.py",
        f"{a.dir}/{m}_fixed.meta.json", f"{a.dir}/plain_fixed.meta.json",
    ],
    "stimulus": {
        "null_control": {"dut": m, "mode": "null (random vs random)", "seed": 11,
                         "traces_per_group": prof["traces"]},
        "positive_control": {"dut": "plain", "mode": "fixed vs random", "seed": 13,
                             "traces_per_group": prof["positive_traces"]},
        "fixed_vs_random": {"dut": m, "mode": "fixed vs random", "seed": 17,
                            "traces_per_group": prof["traces"]},
        "chunk_seed_rule": "seed*1000 + chunk",
        "second_order_pois": prof["pois"],
    },
    "measurement_envelope": {
        "kind": "simulated gate-level power traces (pre-silicon assessment, FPGA proxy); not silicon, not certification",
        "library": "sky130_fd_sc_hd__tt_025C_1v80 (typical corner, 25 C, 1.8 V)",
        "wire_load_model": lib.get("default_wire_load") or "unknown",
        "power_model": "0.5*C*V^2 per net toggle, C = pin caps + wire-load model, summed per clock cycle inside Verilator",
        "measurement_chain": {"rc_tau_cycles": prof["tau"], "noise_pj": prof["noise_pj"]},
        "samples_per_trace": prof["samples"],
        "not_modelled": ["glitches (zero-delay cell models)", "coupling and IR drop",
                         "EM", "process variation", "placement and routing parasitics"],
        "tools": {"yosys": version(a.yosys), "verilator": version(a.verilator)},
    },
}
json.dump(inputs, open(a.out, "w"), indent=1)
print(f"wrote {a.out}")
