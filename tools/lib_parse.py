#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Minimal Liberty reader for the TVLA power model.

Extracts per-cell area and per-pin direction + capacitance (pF), the default
wire-load model and the nominal voltage. It tracks real brace depth, so pins
are attributed to the right cell. The bundled draft matched unquoted
`cell (name)` and missed every quoted sky130 cell.

usage: lib_parse.py LIB OUT.json
"""
import json, re, sys

GROUP_RE = re.compile(r'^\s*(\w+)\s*\(([^)]*)\)\s*\{')
ATTR_RE = re.compile(r'^\s*(\w+)\s*:\s*"?([^";]*)"?\s*;')
FANOUT_RE = re.compile(r'^\s*fanout_length\s*\(\s*(\d+)\s*,\s*([\d.eE+-]+)\s*\)')


def parse(path):
    lib = {"cells": {}, "wire_load": {}, "default_wire_load": None,
           "nom_voltage": None, "cap_unit_pf": 1.0}
    stack = []          # (group, name)
    for raw in open(path):
        line = raw.split("/*")[0]
        g = GROUP_RE.match(line)
        if g:
            kind = g.group(1)
            name = g.group(2).split(",")[0].strip().strip('"')
            stack.append((kind, name))
            if kind == "cell" and len(stack) == 2:
                lib["cells"][name] = {"area": 0.0, "pins": {}}
            elif kind == "pin" and len(stack) == 3 and stack[1][0] == "cell":
                lib["cells"][stack[1][1]]["pins"][name] = {"dir": "?", "cap": 0.0}
            elif kind == "wire_load" and len(stack) == 2:
                lib["wire_load"][name] = {"capacitance": 0.0, "slope": 0.0,
                                          "fanout_length": {}}
            if line.count("}") >= line.count("{"):
                stack.pop()
            continue
        f = FANOUT_RE.match(line)
        if f and stack and stack[-1][0] == "wire_load":
            lib["wire_load"][stack[-1][1]]["fanout_length"][int(f.group(1))] = float(f.group(2))
        a = ATTR_RE.match(line)
        if a and stack:
            key, val = a.group(1), a.group(2).strip()
            top = stack[-1]
            if len(stack) == 1:
                if key == "default_wire_load":
                    lib["default_wire_load"] = val
                elif key == "nom_voltage":
                    lib["nom_voltage"] = float(val)
            elif top[0] == "cell" and len(stack) == 2 and key == "area":
                lib["cells"][top[1]]["area"] = float(val)
            elif top[0] == "pin" and len(stack) == 3 and stack[1][0] == "cell":
                pin = lib["cells"][stack[1][1]]["pins"][top[1]]
                if key == "direction":
                    pin["dir"] = val
                elif key == "capacitance":
                    pin["cap"] = float(val)
            elif top[0] == "wire_load" and key in ("capacitance", "slope"):
                lib["wire_load"][top[1]][key] = float(val)
        if "capacitive_load_unit" in line and "ff" in line.lower():
            lib["cap_unit_pf"] = 1e-3
        for _ in range(line.count("}") - line.count("{")):
            if stack:
                stack.pop()
    return lib


def main():
    lib = parse(sys.argv[1])
    n_pins = sum(len(c["pins"]) for c in lib["cells"].values())
    if len(lib["cells"]) < 100 or n_pins < 300 or not lib["nom_voltage"]:
        sys.exit(f"lib_parse: implausible parse ({len(lib['cells'])} cells)")
    json.dump(lib, open(sys.argv[2], "w"))
    print(f"lib_parse: {len(lib['cells'])} cells, {n_pins} pins, "
          f"Vnom {lib['nom_voltage']} V, wire load {lib['default_wire_load']}")


if __name__ == "__main__":
    main()
