# SPDX-License-Identifier: MIT
VERILATOR ?= verilator
RTL := $(sort $(wildcard rtl/*.v))
VLT := rtl/lint_waivers.vlt
# Simulation-only: public test UDS and CDI readback. Never use for hardware.
SIM_DEFS := +define+AI_ID_SIM_PUF +define+AI_ID_DEBUG_READBACK
CARGO ?= cargo
VFLAGS := -Wno-fatal -Wno-lint -Wno-UNOPTFLAT
VCFLAGS := -CFLAGS "-O2 -DVERILATOR -Wno-deprecated-declarations" -LDFLAGS "-lcrypto"

all: sim

obj_dir/Vid_engine_top: tb/tb_id_engine.cpp tb/se_model.h $(RTL)
	$(VERILATOR) --cc --exe --build -j 0 $(VFLAGS) $(SIM_DEFS) \
	  --top-module id_engine_top $(VCFLAGS) \
	  -Irtl -Itb $(VLT) $(RTL) tb/tb_id_engine.cpp -o Vid_engine_top

# Full-chip simulation: PCRs, streaming measurement + DMA, DICE, key ladder,
# DRBG/TRNG, OTP, SE over SPI (OpenSSL model), AIQ2 quotes verified with
# OpenSSL, tamper zeroize, boot ROM banner. Pass SIM_ARGS="+weights=FILE"
# to measure real model weights through the DMA port.
sim: obj_dir/Vid_engine_top
	./obj_dir/Vid_engine_top $(SIM_ARGS)

lint:
	$(VERILATOR) --lint-only -Wall -Irtl $(VLT) $(RTL) --top-module id_engine_top
	$(VERILATOR) --lint-only -Wall -Irtl $(SIM_DEFS) $(VLT) $(RTL) --top-module id_engine_top
	$(VERILATOR) --lint-only -Wall -Irtl +define+AI_ID_FUSE_UDS $(VLT) $(RTL) --top-module id_engine_top
	$(VERILATOR) --lint-only -Wall -Irtl $(VLT) rtl/axil_to_apb.v --top-module axil_to_apb
	$(VERILATOR) --lint-only -Wall -Irtl $(VLT) rtl/uart_apb_bridge.v --top-module uart_apb_bridge

# Narrow legacy "signoff" gates (added by the CI-fixer). They are much
# narrower than their names suggest; see docs/OPERATIONAL.md:
#   cov    - coverage-instrumented id_engine_top sim; gate = non-empty counters
#   formal - SymbiYosys proof of gf_mult only (not the full chip)
#   fuzz   - PUF harness unit checks + exhaustive gf_mult simulation
cov:
	$(VERILATOR) --cc --exe --build -j 0 --coverage $(VFLAGS) $(SIM_DEFS) \
	  --top-module id_engine_top --Mdir obj_cov $(VCFLAGS) \
	  -Irtl -Itb $(VLT) $(RTL) tb/tb_id_engine.cpp -o Vid_engine_top
	./obj_cov/Vid_engine_top
	python3 test/cov_gate.py coverage.dat

formal:
	sby -f formal/gf_mult.sby

fuzz:
	PYTHONPATH=test python3 test/puf_characterize_test.py
	$(VERILATOR) --cc --exe --build --top-module gf_mult -Wno-fatal \
	  --Mdir obj_dir/gf_mult $(abspath rtl/gf_mult.v tb/tb_gf_mult.cpp) -o Vgf_mult
	./obj_dir/gf_mult/Vgf_mult

.PHONY: all sim lint cov formal fuzz


# Independently scoped correctness gates. These do not sign off the full chip.
math-oracle:
	python3 tools/gen_bch_poly.py
	python3 test/bch_roundtrip.py
	python3 test/test_montgomery.py

rtl-unit: math-oracle
	python3 test/gen_rtl_vectors.py
	iverilog -g2012 -s tb_mont_mul -o /tmp/ai-id-tb-mont rtl/mont_mul.v tb/tb_mont_mul.sv
	vvp /tmp/ai-id-tb-mont
	iverilog -g2012 -s tb_bch_enc -o /tmp/ai-id-tb-bch rtl/bch_enc.v tb/tb_bch_enc.sv
	vvp /tmp/ai-id-tb-bch
	iverilog -g2012 -s tb_sha256_core -o /tmp/ai-id-tb-sha rtl/sha256_compress.v rtl/sha256_core.v tb/tb_sha256_core.sv
	vvp /tmp/ai-id-tb-sha
	iverilog -g2012 -s tb_hmac_sha256 -o /tmp/ai-id-tb-hmac rtl/sha256_compress.v rtl/hmac_sha256.v tb/tb_hmac_sha256.sv
	vvp /tmp/ai-id-tb-hmac
	iverilog -g2012 -I rtl -s tb_mod_n_mul -o /tmp/ai-id-tb-nmod rtl/mont_mul.v rtl/mod_n_mul.v tb/tb_mod_n_mul.sv
	vvp /tmp/ai-id-tb-nmod
	iverilog -g2012 -I rtl -s tb_fp_inv -o /tmp/ai-id-tb-inv rtl/mont_mul.v rtl/fp_ops.v tb/tb_fp_inv.sv
	vvp /tmp/ai-id-tb-inv
	python3 test/gen_drbg_vectors.py obj_dir/drbg_vectors.svh
	iverilog -g2012 -I obj_dir -s tb_hmac_drbg -o /tmp/ai-id-tb-drbg rtl/sha256_compress.v rtl/hmac_sha256.v rtl/hmac_drbg.v tb/tb_hmac_drbg.sv
	vvp /tmp/ai-id-tb-drbg
	iverilog -g2012 -s tb_trng -o /tmp/ai-id-tb-trng rtl/trng.v tb/tb_trng.sv
	vvp /tmp/ai-id-tb-trng
	iverilog -g2012 -s tb_axil_to_apb -o /tmp/ai-id-tb-axil rtl/axil_to_apb.v tb/tb_axil_to_apb.sv
	vvp /tmp/ai-id-tb-axil
	iverilog -g2012 -s tb_uart_apb_bridge -o /tmp/ai-id-tb-uart rtl/uart_apb_bridge.v tb/tb_uart_apb_bridge.sv
	vvp /tmp/ai-id-tb-uart

.PHONY: math-oracle rtl-unit

# Firmware/RTL register ABI agreement.
regmap:
	python3 test/check_regmap.py

# Rust reference verifier (unit + CLI end-to-end tests).
verifier:
	cd verifier && $(CARGO) test --locked

# Host tools: hwid + aiid (unit + integration tests).
hwid:
	cd hwid && $(CARGO) test --locked

# Release binaries (static musl on Linux x86_64).
release-bins:
	cd hwid && $(CARGO) build --locked --release --target x86_64-unknown-linux-musl
	cd verifier && $(CARGO) build --locked --release --target x86_64-unknown-linux-musl

# End-to-end: RTL sim measures real model weights and signs an AIQ2 quote via
# the SE model -> Rust verifier -> AI Birth Certificate create/verify.
# MODEL=<dir|file> (default: downloads prajjwal1/bert-tiny, ~17 MB).
demo:
	./scripts/demo.sh

# FPGA bitstream for the ULX3S (ECP5-85F) with the OSS CAD Suite.
fpga:
	$(MAKE) -C fpga

# Everything that defines "operational" for this repo (see docs/OPERATIONAL.md).
test: lint sim rtl-unit regmap verifier hwid
	PYTHONPATH=test python3 test/puf_characterize_test.py
	PYTHONPATH=test python3 test/tvla_test.py
	@echo "ALL OPERATIONAL GATES PASS"

clean:
	rm -rf obj_dir obj_cov verifier/target verifier/demo-out hwid/target demo-out coverage.dat formal/gf_mult
	$(MAKE) -C fpga clean

.PHONY: regmap verifier hwid release-bins demo fpga test clean
