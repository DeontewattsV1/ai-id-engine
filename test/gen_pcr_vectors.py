#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""PCR extend reference for tb/tb_pcr_bank_fd.sv: PCR <- SHA-256(PCR || d).
Writes one line per extend: sel (1 hex digit), digest_in, expected PCR."""
import hashlib
import random
import sys

out = sys.argv[1] if len(sys.argv) > 1 else "obj_dir/pcr_vectors.hex"
rng = random.Random(20261116)
pcr = [bytes(32)] * 16
lines = []
for _ in range(24):
    sel = rng.randrange(16)
    d = rng.randbytes(32)
    pcr[sel] = hashlib.sha256(pcr[sel] + d).digest()
    lines.append(f"{sel:01x}{d.hex()}{pcr[sel].hex()}")
with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {len(lines)} PCR extend vectors to {out}")
