#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Host side of rtl/uart_apb_bridge.v: drive the AI identity engine on a
ULX3S (fpga/) over its USB-UART (115200 8N1). Requires pyserial.

  aiid_uart.py --port /dev/ttyUSB0 info
  aiid_uart.py --port /dev/ttyUSB0 measure model.safetensors      # SHA-256 in the FPGA, extends PCR2
  aiid_uart.py --port /dev/ttyUSB0 quote --nonce HEX --out q.json   # needs an SPI secure element wired to the SE pins

Register map: fw/id_engine_regs.h. The UART path moves ~16 KB/s, so large
weights take minutes; production hosts use the AXI/DMA port instead."""
import argparse
import hashlib
import json
import struct
import sys
import time

REG = dict(ID=0x000, STATUS=0x004, VERSION=0x008, HWINFO=0x00C, PCR_SEL=0x020, PCR_READ=0x028,
           MEAS_CTRL=0x030, MEAS_DATA=0x034, MEAS_FINAL=0x038, MEAS_TAIL=0x03C, MEAS_DIGEST=0x040,
           CDI_LABEL=0x060, CDI_START=0x06C, DEVICE_ID=0x074, NONCE=0x080, CONFIG=0x084, TIME=0x088,
           QUOTE_CTRL=0x0A0, QUOTE_LEN=0x0A4, QUOTE_SIG=0x0A8, QUOTE_HDR=0x0AC, SE_PUB=0x0B0,
           QUOTE_DIGEST=0x0B8, TAMPER=0x0F0, BANNER=0x108)
ST = dict(cdi_busy=1 << 6, cdi_valid=1 << 2, quote_busy=1 << 8, quote_done=1 << 3, quote_err=1 << 5,
          meas_busy=1 << 9, pub_valid=1 << 14)
LABEL = b"ai-id-engine-v1\x00"


class Engine:
    def __init__(self, port, baud=115200):
        import serial  # pyserial
        self.s = serial.Serial(port, baud, timeout=2)
        self.last = None

    def w(self, a, v):
        self.s.write(struct.pack(">cHI", b"W", a, v & 0xFFFFFFFF))
        if self.s.read(1) != b"K":
            raise IOError(f"write 0x{a:03x}: no ack")
        self.last = a

    def r(self, a):
        self.s.write(struct.pack(">cH", b"R", a))
        d = self.s.read(4)
        if len(d) != 4:
            raise IOError(f"read 0x{a:03x}: timeout")
        self.last = a
        return struct.unpack(">I", d)[0]

    def words(self, a, n):
        self.r(REG["ID"])  # touch another address: restart the word index
        return b"".join(struct.pack(">I", self.r(a)) for _ in range(n))

    def put(self, a, data):
        self.r(REG["ID"])
        for i in range(0, len(data), 4):
            self.w(a, struct.unpack(">I", data[i:i + 4])[0])

    def wait_clear(self, bit, t=30):
        end = time.time() + t
        while self.r(REG["STATUS"]) & bit:
            if time.time() > end:
                raise TimeoutError("engine busy")


def info(e):
    banner = e.words(REG["BANNER"], 8).decode("ascii", "replace")
    hw = e.r(REG["HWINFO"])
    print(f"banner   {banner!r}")
    print(f"id       0x{e.r(REG['ID']):08x}  version 0x{e.r(REG['VERSION']):08x}")
    print(f"hw_rev   {bytes([hw >> 24, (hw >> 16) & 0xFF]).decode()}  lifecycle {(hw >> 8) & 0xFF}")
    print(f"status   0x{e.r(REG['STATUS']):08x}  tamper 0x{e.r(REG['TAMPER']):02x}")
    e.put(REG["CDI_LABEL"], LABEL)
    e.w(REG["PCR_SEL"], 2)
    e.w(REG["CDI_START"], 1)
    e.wait_clear(ST["cdi_busy"])
    print(f"device   {e.words(REG['DEVICE_ID'], 8).hex()}")


def measure(e, path):
    data = open(path, "rb").read()
    e.w(REG["MEAS_CTRL"], 1 | (2 << 4) | 0x100)
    full = len(data) // 4
    for i in range(full):
        e.w(REG["MEAS_DATA"], struct.unpack(">I", data[4 * i:4 * i + 4])[0])
        if i % 4096 == 0:
            print(f"\r{4 * i}/{len(data)} bytes", end="", file=sys.stderr)
    tail = data[4 * full:]
    e.w(REG["MEAS_TAIL"], int.from_bytes(tail.ljust(4, b"\0"), "big"))
    e.w(REG["MEAS_FINAL"], len(tail))
    e.wait_clear(ST["meas_busy"])
    dig = e.words(REG["MEAS_DIGEST"], 8)
    print(f"\nfpga sha256 {dig.hex()}\nhost sha256 {hashlib.sha256(data).hexdigest()}")
    return dig.hex() == hashlib.sha256(data).hexdigest()


def quote(e, nonce, out):
    e.put(REG["NONCE"], bytes.fromhex(nonce))
    t = int(time.time())
    e.r(REG["ID"]); e.w(REG["TIME"], t >> 32); e.w(REG["TIME"], t)
    e.w(REG["QUOTE_CTRL"], 2)
    time.sleep(0.5)
    e.w(REG["QUOTE_CTRL"], 1)
    time.sleep(0.5)
    e.wait_clear(ST["quote_busy"])
    st = e.r(REG["STATUS"])
    if st & ST["quote_err"]:
        raise SystemExit(f"quote refused, error code {(st >> 20) & 0xF} (1 no-id 2 tamper 3 lifecycle 4 SE 5 zeroized)")
    hdr = e.words(REG["QUOTE_HDR"], 5)
    sig = e.words(REG["QUOTE_SIG"], 16)
    pub = e.words(REG["SE_PUB"], 16)
    pcrs = b""
    for i in range(16):
        e.w(REG["PCR_SEL"], i)
        pcrs += e.words(REG["PCR_READ"], 8)
    q = {"format": "AIQ2", "source": "fpga ulx3s over uart", "hw_rev": hdr[4:6].decode(),
         "lifecycle": hdr[6], "tamper": hdr[7], "counter": int.from_bytes(hdr[8:12], "big"),
         "timestamp": int.from_bytes(hdr[12:20], "big"), "device_id": e.words(REG["DEVICE_ID"], 8).hex(),
         "nonce": nonce, "pcrs": pcrs.hex(), "model_digest": e.words(REG["MEAS_DIGEST"], 8).hex(),
         "config_digest": "00" * 32, "sig": sig.hex(), "se_pubkey": "04" + pub.hex(),
         "body_sha256": e.words(REG["QUOTE_DIGEST"], 8).hex()}
    json.dump(q, open(out, "w"), indent=2)
    print(f"wrote {out}; verify with: ai-id-verifier verify-hw --quote {out} ...")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", required=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("info")
    m = sub.add_parser("measure"); m.add_argument("file")
    q = sub.add_parser("quote"); q.add_argument("--nonce", required=True); q.add_argument("--out", default="fpga_quote.json")
    a = ap.parse_args()
    e = Engine(a.port)
    if a.cmd == "info":
        info(e)
    elif a.cmd == "measure":
        sys.exit(0 if measure(e, a.file) else 1)
    else:
        quote(e, a.nonce, a.out)


if __name__ == "__main__":
    main()
