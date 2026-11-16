#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail if the firmware register ABI (fw/id_engine_regs.h) and the RTL
decoder (rtl/apb_regfile.v, rtl/id_engine_top.v) disagree."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
hdr = (ROOT / "fw/id_engine_regs.h").read_text()
apb = (ROOT / "rtl/apb_regfile.v").read_text()
top = (ROOT / "rtl/id_engine_top.v").read_text()

regs = {n: int(v, 16) for n, v in re.findall(r"#define\s+(IE_REG_\w+)\s+0x([0-9A-Fa-f]+)", hdr)}
bits = {n: int(b) for n, b in re.findall(r"#define\s+(IE_ST_\w+)\s+\(1u << (\d+)\)", hdr)}

def decoded(block_start):
    i = apb.index(block_start)
    j = apb.index("endcase", i)
    return {int(a, 16) for a in re.findall(r"12'h([0-9A-Fa-f]{3}):", apb[i:j])}

wr = decoded("if (access && pwrite)")
rd = decoded("if (access && !pwrite)")
rtl = wr | rd
errors = []
for name, addr in sorted(regs.items(), key=lambda kv: kv[1]):
    if addr not in rtl:
        errors.append(f"{name}=0x{addr:03X} is not decoded by rtl/apb_regfile.v")
for addr in sorted(rtl - set(regs.values())):
    errors.append(f"RTL decodes 0x{addr:03X} but fw/id_engine_regs.h has no define")

m = re.search(r"wire \[15:0\]\s+status = \{([^}]*)\};", top)
fields = [f.strip() for f in m.group(1).replace("\n", " ").split(",")]
fields = [f for f in fields if not re.fullmatch(r"\d+'b0", f)]
fields.reverse()  # LSB first
want = {"1'b1": "IE_ST_READY", "pcr_busy": "IE_ST_PCR_BUSY", "cdi_valid": "IE_ST_CDI_VALID",
        "quote_done": "IE_ST_QUOTE_DONE", "unseal_ok": "IE_ST_UNSEAL_OK",
        "quote_err": "IE_ST_QUOTE_ERR", "cdi_busy": "IE_ST_CDI_BUSY", "uds_valid": "IE_ST_UDS_VALID"}
for bit, sig in enumerate(fields):
    name = want.get(sig)
    if name is None:
        errors.append(f"status bit {bit} ({sig}) has no firmware define")
    elif bits.get(name) != bit:
        errors.append(f"{name} is bit {bits.get(name)} in firmware but bit {bit} in RTL")

if errors:
    print("register map MISMATCH:\n  " + "\n  ".join(errors))
    sys.exit(1)
print(f"register map PASS ({len(regs)} registers, {len(fields)} status bits agree)")
