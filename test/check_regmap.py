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

errors = []
regs = {n: int(v, 16) for n, v in re.findall(r"#define\s+(IE_REG_\w+)\s+0x([0-9A-Fa-f]+)", hdr)}
bits = {n: int(b) for n, b in re.findall(r"#define\s+(IE_ST_\w+)\s+\(1u << (\d+)\)", hdr)}


def bits_shift():
    return int(re.search(r"#define\s+IE_ST_QERR_SHIFT\s+(\d+)", hdr).group(1))

def decoded(block_start):
    i = apb.index(block_start)
    j = apb.index("endcase", i)
    return {int(a, 16) for a in re.findall(r"12'h([0-9A-Fa-f]{3}):", apb[i:j])}

wr = decoded("if (access && pwrite)")
rd = decoded("if (access && !pwrite)")
rtl = wr | rd
for name, addr in sorted(regs.items(), key=lambda kv: kv[1]):
    if addr not in rtl:
        errors.append(f"{name}=0x{addr:03X} is not decoded by rtl/apb_regfile.v")
for addr in sorted(rtl - set(regs.values())):
    errors.append(f"RTL decodes 0x{addr:03X} but fw/id_engine_regs.h has no define")

m = re.search(r"wire \[31:0\]\s+status = \{([^;]*)\};", top)
fields = [f.strip() for f in m.group(1).replace("\n", " ").split(",")]
# expand to one entry per bit, LSB first
bitlist = []
for f in reversed(fields):
    z = re.fullmatch(r"(\d+)'b0", f)
    if z:
        bitlist += [None] * int(z.group(1))
    elif f == "q_code":
        if len(bitlist) != bits_shift():
            errors.append(f"q_code starts at bit {len(bitlist)}, firmware says {bits_shift()}")
        bitlist += ["q_code"] * 4
    else:
        bitlist.append(f)
want = {"1'b1": "IE_ST_READY", "pcr_busy": "IE_ST_PCR_BUSY", "cdi_valid": "IE_ST_CDI_VALID",
        "q_done": "IE_ST_QUOTE_DONE", "unseal_ok": "IE_ST_UNSEAL_OK",
        "q_err": "IE_ST_QUOTE_ERR", "cdi_busy": "IE_ST_CDI_BUSY", "uds_valid": "IE_ST_UDS_VALID",
        "quote_busy": "IE_ST_QUOTE_BUSY", "m_busy": "IE_ST_MEAS_BUSY", "m_valid_dig": "IE_ST_MEAS_VALID",
        "keys_ready": "IE_ST_KEYS_READY", "rng_have": "IE_ST_RNG_READY", "trng_fail": "IE_ST_TRNG_FAIL",
        "pub_valid": "IE_ST_SE_PUB_VALID", "zeroized": "IE_ST_ZEROIZED", "otp_prog_err": "IE_ST_OTP_PROG_ERR",
        "mesh_breach": "IE_ST_MESH_BREACH"}
if len(bitlist) != 32:
    errors.append(f"status is {len(bitlist)} bits, expected 32")
fields = [b for b in bitlist if b]
for bit, sig in enumerate(bitlist):
    if sig is None or sig == "q_code":
        continue
    name = want.get(sig)
    if name is None:
        errors.append(f"status bit {bit} ({sig}) has no firmware define")
    elif bits.get(name) != bit:
        errors.append(f"{name} is bit {bits.get(name)} in firmware but bit {bit} in RTL")

if errors:
    print("register map MISMATCH:\n  " + "\n  ".join(errors))
    sys.exit(1)
print(f"register map PASS ({len(regs)} registers, {len(fields)} status bits agree)")
