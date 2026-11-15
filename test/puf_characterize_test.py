#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Boundary checks for SRAM PUF characterization."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory

from puf_characterize import hd, main


def characterize(noise_bits):
    with TemporaryDirectory() as directory:
        path = Path(directory)
        noisy = format((1 << noise_bits) - 1, "b")
        distant = format((1 << 328) - 1, "b")
        (path / "noisy.txt").write_text("0\n" + (noisy + "\n") * 499)
        (path / "distant.txt").write_text((distant + "\n") * 500)
        (path / "short.txt").write_text("0\n" * 499)
        output = StringIO()
        with redirect_stdout(output):
            main(path)
        return output.getvalue()


assert hd(0, (1 << 2046) | (1 << 2047)) == 1
assert hd(0b1010, 0b0101, n=3) == 3

within = characterize(127)
assert "short: only 499 boots, need 500" in within
assert "noisy: mean intra-HD 127.00 bits" in within
assert "inter-die mean HD 328.00 bits" in within
assert "BCH t=128 headroom: 1 bits (OK)" in within
assert "separability margin: 201.0 bits (OK)" in within

boundary = characterize(128)
assert "noisy: mean intra-HD 128.00 bits" in boundary
assert "BCH t=128 headroom: 0 bits (FAIL - raise t)" in boundary
assert "separability margin: 200.0 bits (WEAK)" in boundary

print("PUF characterization boundary checks passed")
