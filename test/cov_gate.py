#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail when Verilator did not produce usable, nonzero coverage data."""
import sys
from pathlib import Path


def main(path):
    coverage = Path(path)
    if not coverage.is_file():
        raise SystemExit(f"coverage file not found: {coverage}")

    lines = coverage.read_text(encoding="latin-1").splitlines()
    if not lines or lines[0] != "# SystemC::Coverage-3":
        raise SystemExit(f"invalid Verilator coverage file: {coverage}")

    counters = [line.rsplit(" ", 1)[-1] for line in lines[1:] if line.startswith("C ")]
    if not counters or not any(int(count) > 0 for count in counters):
        raise SystemExit(f"coverage file has no nonzero counters: {coverage}")

    print(f"Coverage data contains {len(counters)} counters with executed activity.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: cov_gate.py COVERAGE_FILE")
    main(sys.argv[1])
