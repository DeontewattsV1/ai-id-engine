# Reproducible FPGA bitstream

`make -C fpga repro B=<dir>` builds the ULX3S (ECP5-85F) bitstream so that
it is a pure function of the sources and the toolchain:

- **`REPRO=1`** replaces the per-build random UDS and serial with fixed
  **public** test values: the UDS is SHA-256 of a fixed label, and the serial
  is `0xa1`. A REPRO bitstream therefore has a published identity. Use it to
  check the build; never deploy it as a device. A normal `make -C fpga`
  still embeds a fresh random UDS.
- **Pinned randomness:** nextpnr runs with `--seed 1 --threads 1`.
- **Pinned toolchain:** CI pins the OSS CAD Suite release through
  `OSS_CAD_SUITE_VERSION` in `.github/workflows/ci.yml`. `repro` records each
  tool's version and the SHA-256 of the binary on `PATH` in
  `toolchain.txt`. With the OSS CAD Suite these are its wrapper scripts, so
  the release date is the real pin.
- **Outputs:** `digests.txt` holds the SHA-256 of `otp_image.vh`, the Yosys
  JSON netlist, the nextpnr config and the `.bit`.

## CI

The `repro` job builds twice, from clean and separate directories, and
fails if the two `digests.txt` files differ. `make -C fpga repro-check` then
compares the build with the committed `fpga/repro.sha256` and
`fpga/toolchain.lock`, and fails on any change.

**Bootstrap:** only CI's toolchain can produce the reference digests, so the
first run cannot be checked against them. Until both files are committed,
`repro-check` prints the digests to commit and passes. Copy them from the
job summary or the `repro-digests` artifact into a follow-up PR.

**Changing on purpose:** an RTL change, an FPGA-top change or an OSS CAD
Suite bump changes the digests. Update `repro.sha256` and `toolchain.lock`
in the same PR, so the change is reviewed rather than silent.
