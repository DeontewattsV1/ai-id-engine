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
	$(VERILATOR) --lint-only -Wall -Irtl +define+AI_ID_FAULT_DETECT $(VLT) $(RTL) --top-module id_engine_top
	$(VERILATOR) --lint-only -Wall -Irtl $(SIM_DEFS) +define+AI_ID_FAULT_DETECT $(VLT) $(RTL) --top-module id_engine_top
	for m in fault_alarm key_store_fd mont_mul_rc; do $(VERILATOR) --lint-only -Wall -Irtl $(VLT) $(RTL) --top-module $$m || exit 1; done
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

# Known-answer tests: NIST SHA-256 multi-block (incl. 1M x 'a'), HMAC RFC 4231
# TC1-5 on the RTL; ECDSA P-256 RFC 6979 on the SE model's OpenSSL and on the
# Rust p256 used by the verifier and aiid.
kat: kat-rtl
	cd verifier && $(CARGO) test --locked --test ecdsa_kat
	cd hwid && $(CARGO) test --locked --test ecdsa_kat

# RTL + OpenSSL part of `kat` (the Rust KATs already run under `verifier`/`hwid`).
kat-rtl:
	iverilog -g2012 -s tb_sha256_nist -o /tmp/ai-id-tb-nist rtl/sha256_compress.v tb/tb_sha256_nist.sv
	vvp -n /tmp/ai-id-tb-nist
	iverilog -g2012 -s tb_hmac_rfc4231 -o /tmp/ai-id-tb-4231 rtl/sha256_compress.v rtl/hmac_sha256.v tb/tb_hmac_rfc4231.sv
	vvp -n /tmp/ai-id-tb-4231
	$(CC) -O2 -Wall -Wno-deprecated-declarations -o /tmp/ai-id-ecdsa-kat test/kat/ecdsa_p256_kat.c -lcrypto
	/tmp/ai-id-ecdsa-kat

# Formal (SymbiYosys): gf_mult equivalence, OTP fuse semantics (OR-only,
# lock word, UDS unreadable), PCR bank extend-only (SHA core cut out).
formal-all: formal
	sby -f formal/otp_fuses.sby
	sby -f formal/pcr_bank.sby
	sby -f formal/fault_alarm.sby
	sby -f formal/key_store_fd.sby
	sby -f formal/key_store_nonint.sby
	sby -f formal/pcr_bank_fd.sby

.PHONY: kat kat-rtl formal-all

# ---------------------------------------------------------------------------
# TVLA: gate-level, sky130-mapped leakage evidence for the masked Montgomery
# multiplier (docs/TVLA.md, ADR-0001/0002). Simulated traces, not silicon.
#   make tvla [PROFILE=ci|local|signoff|smoke] [MASKED=masked_v2|masked3]
# ---------------------------------------------------------------------------
YOSYS ?= yosys
PROFILE ?= ci
MASKED ?= masked_v2
TVLA_J ?= $(shell nproc 2>/dev/null || echo 2)
PDK_DIR ?= build/pdk
LIB_NAME := sky130_fd_sc_hd__tt_025C_1v80
LIB_PATH ?= $(PDK_DIR)/$(LIB_NAME).lib
# Pinned: OpenROAD-flow-scripts platforms/sky130hd (SkyWater PDK, Apache-2.0).
LIB_URL := https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/2272e787c57c356364038c5809d0c81e9f7419ce/flow/platforms/sky130hd/lib/$(LIB_NAME).lib
LIB_SHA256 := ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9
TOML = python3 -c "import tomllib,sys;print(tomllib.load(open('config/tvla.toml','rb'))['$(PROFILE)']['$(1)'])"
T_N = $(shell $(call TOML,traces))
T_M = $(shell $(call TOML,samples))
T_ALPHA = $(shell $(call TOML,alpha))
T_POIS = $(shell $(call TOML,pois))
T_POS = $(shell $(call TOML,positive_traces))
T_TAU = $(shell $(call TOML,tau))
T_NOISE = $(shell $(call TOML,noise_pj))
TV := build/tvla
DUT_TOP_plain := mont_mul
DUT_TOP_masked_v2 := mont_mul_masked_v2
DUT_TOP_masked3 := mont_mul_masked3
DUT_KIND_plain := 0
DUT_KIND_masked_v2 := 1
DUT_KIND_masked3 := 2

$(LIB_PATH):
	mkdir -p $(PDK_DIR)
	curl -sSfL --retry 3 -o $@.tmp $(LIB_URL)
	echo "$(LIB_SHA256)  $@.tmp" | sha256sum -c -
	mv $@.tmp $@

lib: build/lib.json
build/lib.json: $(LIB_PATH) tools/lib_parse.py
	python3 tools/lib_parse.py $(LIB_PATH) $@

# Yosys synth + dfflibmap/abc -liberty onto sky130 tt for both plain and masked.
build/sky130_%.json: rtl/mont_mul.v rtl/mont_mul_masked_v2.v rtl/mont_mul_masked3.v $(LIB_PATH) tools/synth_sky130.sh
	YOSYS=$(YOSYS) tools/synth_sky130.sh $* $(DUT_TOP_$*) $(LIB_PATH) build rtl/$(DUT_TOP_$*).v

synth-area: build/sky130_plain.json build/sky130_masked_v2.json build/sky130_masked3.json

# Cell models are generated from the same .lib (functions/ff groups), checked
# in under sim/ (ADR-0002), and must cover every cell abc picked.
cells: synth-area
	YOSYS=$(YOSYS) python3 tools/gen_cell_models.py $(LIB_PATH) sim/sky130_fd_sc_hd_cells.v build/sky130_plain.v build/sky130_masked_v2.v build/sky130_masked3.v
cells-check: synth-area
	python3 tools/vendor_check.py sim/sky130_fd_sc_hd_cells.v build/sky130_plain.v build/sky130_masked_v2.v build/sky130_masked3.v

build/tvla_%.v: build/sky130_%.json build/lib.json tools/tvla_netlist.py
	python3 tools/tvla_netlist.py $< build/lib.json $@ build/tvla_$*.json
	python3 test/model_sanity.py build/tvla_$*.json

build/obj_%/tvla: build/tvla_%.v sim/sky130_fd_sc_hd_cells.v tb/tvla_harness.cpp
	$(VERILATOR) --cc --exe --build -j 0 -O3 --x-assign fast --x-initial fast \
	  -Wno-fatal -Wno-lint -Wno-style --top-module tvla_dut \
	  -CFLAGS "-O2 -DDUT_KIND=$(DUT_KIND_$*)" -Mdir build/obj_$* -o tvla \
	  $(abspath build/tvla_$*.v sim/sky130_fd_sc_hd_cells.v tb/tvla_harness.cpp)

COLLECT = python3 tools/tvla_collect.py -j $(TVLA_J) --samples $(T_M) --tau $(T_TAU) --noise $(T_NOISE)

# Order matters (ADR-0001): null control first, reported separately; then the
# positive control (unmasked) proves the harness can see a leak; then the
# real fixed-vs-random run on the masked DUT. Every number is reported, then
# gate.py returns a single verdict and exit code.
tvla: cells-check build/obj_plain/tvla build/obj_$(MASKED)/tvla
	mkdir -p $(TV) && rm -f $(TV)/gate.rc
	@echo "== TVLA profile $(PROFILE): $(T_N) traces/group, M=$(T_M), alpha=$(T_ALPHA), masked DUT $(MASKED)"
	python3 tools/threshold.py --samples $(T_M) --traces $(T_N) --alpha $(T_ALPHA)
	python3 test/area_report.py build/area_plain.txt build/area_$(MASKED).txt $(TV)/area.json --plain-top mont_mul --masked-top $(DUT_TOP_$(MASKED)) || true
	$(COLLECT) --bin build/obj_$(MASKED)/tvla --caps build/tvla_$(MASKED).caps --dut $(MASKED) --mode null --n $(T_N) --seed 11 --out $(TV)/$(MASKED)_null
	python3 test/null_control.py $(TV)/$(MASKED)_null $(TV)/null.json --alpha $(T_ALPHA) || true
	$(COLLECT) --bin build/obj_plain/tvla --caps build/tvla_plain.caps --dut plain --mode fixed --n $(T_POS) --seed 13 --out $(TV)/plain_fixed
	python3 test/tvla_gate.py $(TV)/plain_fixed $(TV)/positive.json --alpha $(T_ALPHA) || true
	$(COLLECT) --bin build/obj_$(MASKED)/tvla --caps build/tvla_$(MASKED).caps --dut $(MASKED) --mode fixed --n $(T_N) --seed 17 --out $(TV)/$(MASKED)_fixed
	python3 test/tvla_gate.py $(TV)/$(MASKED)_fixed $(TV)/tvla1.json --alpha $(T_ALPHA) || true
	python3 test/poi_select.py $(TV)/$(MASKED)_null $(TV)/poi.npy --count $(T_POIS)
	python3 test/tvla2_run.py $(TV)/$(MASKED)_fixed $(TV)/poi.npy $(TV)/tvla2.json --alpha $(T_ALPHA) || true
	python3 test/gate.py $(TV)/tvla1.json $(TV)/tvla2.json --dir $(TV) --profile $(PROFILE) --masked $(MASKED); \
	  rc=$$?; echo $$rc > $(TV)/gate.rc; exit $$rc

# Keep generated netlists/objects between runs.
.SECONDARY:

# Plumbing check: any gate VERDICT (0/2/3/4) is fine, harness failure (5) is not.
tvla-smoke:
	-$(MAKE) tvla PROFILE=smoke TV=build/tvla_smoke
	@rc=$$(cat build/tvla_smoke/gate.rc); echo "smoke gate exit $$rc"; case $$rc in 0|2|3|4) ;; *) exit 1 ;; esac

# Cross-check: recompute the cap-weighted energy of 2 plain traces from a
# Verilator waveform dump and compare it with the harness's in-sim sums.
# TRACE_FMT=fst needs liblz4-dev for Verilator's FST writer; vcd needs nothing.
TRACE_FMT ?= vcd
TRACE_FLAG_vcd := --trace
TRACE_FLAG_fst := --trace-fst
build/obj_$(TRACE_FMT)/tvla_plain_wave: build/tvla_plain.v sim/sky130_fd_sc_hd_cells.v tb/tvla_harness.cpp
	$(VERILATOR) --cc --exe --build -j 0 -O2 $(TRACE_FLAG_$(TRACE_FMT)) -Wno-fatal -Wno-lint -Wno-style \
	  --top-module tvla_dut -CFLAGS "-O2 -DDUT_KIND=0" -Mdir build/obj_$(TRACE_FMT) -o tvla_plain_wave \
	  $(abspath build/tvla_plain.v sim/sky130_fd_sc_hd_cells.v tb/tvla_harness.cpp)
tvla-xcheck: build/obj_$(TRACE_FMT)/tvla_plain_wave
	mkdir -p $(TV)
	build/obj_$(TRACE_FMT)/tvla_plain_wave --mode fixed --n 1 --samples 400 --caps build/tvla_plain.caps --out $(TV)/xcheck --fst $(TV)/xcheck.$(TRACE_FMT) --fst-traces 2 --check 2
	python3 tools/fst_xcheck.py $(TV)/xcheck.$(TRACE_FMT) build/tvla_plain.json $(TV)/xcheck.cycles.f64

.PHONY: lib synth-area cells cells-check tvla tvla-smoke tvla-xcheck

# Masked Montgomery multipliers (2-share v2, 3-share, MASK_EN wrapper) checked
# against Python over P-256 p and n, plus the TVLA statistics unit tests.
tvla-test:
	python3 test/test_tvla_stats.py
	python3 test/gen_masked_vectors.py
	iverilog -g2012 -s tb_mont_mul_masked -o /tmp/ai-id-tb-masked rtl/mont_mul.v rtl/mont_mul_masked_v2.v rtl/mont_mul_masked3.v rtl/mont_mul_wrap.v tb/tb_mont_mul_masked.sv
	vvp -n /tmp/ai-id-tb-masked
	$(VERILATOR) --lint-only -Wall -Irtl $(VLT) rtl/mont_mul_masked_v2.v --top-module mont_mul_masked_v2
	$(VERILATOR) --lint-only -Wall -Irtl $(VLT) rtl/mont_mul_masked3.v --top-module mont_mul_masked3
	for m in 0 1 2; do $(VERILATOR) --lint-only -Wall -Irtl $(VLT) rtl/mont_mul.v rtl/mont_mul_masked_v2.v rtl/mont_mul_masked3.v rtl/mont_mul_wrap.v --top-module mont_mul_wrap -GMASK_EN=$$m || exit 1; done

.PHONY: tvla-test

# Coded fault detection (docs/FAULT-DETECTION.md): exhaustive/random bit-flip
# injection on the SEC-DED code, sticky alarm, HD3 FSM, key store and
# residue-checked mont_mul; pcr_bank and the full chip with AI_ID_FAULT_DETECT.
fault-test: obj_fd/Vid_engine_top
	iverilog -g2012 -I rtl -s tb_fault_detect -o /tmp/ai-id-tb-fd rtl/secded39_enc.v rtl/secded39_dec.v \
	  rtl/fault_alarm.v rtl/mont_mul.v rtl/mont_mul_rc.v rtl/key_store_fd.v tb/tb_fault_detect.sv
	vvp -n /tmp/ai-id-tb-fd
	mkdir -p obj_dir && python3 test/gen_pcr_vectors.py obj_dir/pcr_vectors.hex
	iverilog -g2012 -DAI_ID_FAULT_DETECT -I rtl -s tb_pcr_bank_fd -o /tmp/ai-id-tb-pcrfd rtl/sha256_compress.v \
	  rtl/secded39_dec.v rtl/fault_alarm.v rtl/pcr_bank.v tb/tb_pcr_bank_fd.sv
	vvp -n /tmp/ai-id-tb-pcrfd
	./obj_fd/Vid_engine_top $(SIM_ARGS)

obj_fd/Vid_engine_top: tb/tb_id_engine.cpp tb/se_model.h $(RTL)
	$(VERILATOR) --cc --exe --build -j 0 $(VFLAGS) $(SIM_DEFS) +define+AI_ID_FAULT_DETECT \
	  --top-module id_engine_top --Mdir obj_fd $(VCFLAGS) \
	  -Irtl -Itb $(VLT) $(RTL) $(abspath tb/tb_id_engine.cpp) -o Vid_engine_top

.PHONY: fault-test

# Everything that defines "operational" for this repo (see docs/OPERATIONAL.md).
test: lint sim rtl-unit regmap verifier hwid kat-rtl tvla-test fault-test
	PYTHONPATH=test python3 test/puf_characterize_test.py
	PYTHONPATH=test python3 test/tvla_test.py
	@echo "ALL OPERATIONAL GATES PASS"

clean:
	rm -rf build obj_dir obj_cov obj_fd verifier/target verifier/demo-out hwid/target demo-out coverage.dat \
	  formal/gf_mult formal/otp_fuses formal/pcr_bank formal/pcr_bank_fd formal/fault_alarm \
	  formal/key_store_fd formal/key_store_nonint
	$(MAKE) -C fpga clean

.PHONY: regmap verifier hwid release-bins demo fpga test clean
