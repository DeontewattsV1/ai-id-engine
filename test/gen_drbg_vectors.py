#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Reference HMAC_DRBG (SP 800-90A 10.1.2, HMAC-SHA256) for tb/tb_hmac_drbg.sv.

Writes `define constants for a fixed op sequence: init(seed1), gen, gen,
update(seed2), gen, update(no data), gen. Provided data is 22 bytes, as
in rtl/hmac_drbg.v."""
import hashlib
import hmac
import pathlib
import sys

def H(k, m):
    return hmac.new(k, m, hashlib.sha256).digest()

class Drbg:
    def update(self, d):
        self.K = H(self.K, self.V + b"\x00" + (d or b""))
        self.V = H(self.K, self.V)
        if d:
            self.K = H(self.K, self.V + b"\x01" + d)
            self.V = H(self.K, self.V)

    def init(self, d):
        self.K, self.V = b"\x00" * 32, b"\x01" * 32
        self.update(d)

    def gen(self):
        self.V = H(self.K, self.V)
        out = self.V
        self.update(None)
        return out

seed1 = bytes(range(0x10, 0x10 + 22))
seed2 = hashlib.sha256(b"reseed").digest()[:22]
d = Drbg()
d.init(seed1)
g1 = d.gen(); g2 = d.gen()
d.update(seed2)
g3 = d.gen()
d.update(None)
g4 = d.gen()
out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "obj_dir/drbg_vectors.svh")
out.parent.mkdir(parents=True, exist_ok=True)
lines = [f"`define DRBG_SEED1 176'h{seed1.hex()}", f"`define DRBG_SEED2 176'h{seed2.hex()}"]
for i, g in enumerate([g1, g2, g3, g4], 1):
    lines.append(f"`define DRBG_G{i} 256'h{g.hex()}")
out.write_text("\n".join(lines) + "\n")
print(f"HMAC_DRBG reference vectors written to {out}")
