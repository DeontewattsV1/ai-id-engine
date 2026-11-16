# SPDX-License-Identifier: MIT
# Open FPGA flow: Yosys -> nextpnr-ecp5 -> ecppack (ULX3S, LFE5U-85F).
# Requires the OSS CAD Suite (yosys, nextpnr-ecp5, ecppack) on PATH.
#
#   make -C fpga              bitstream + reports in fpga/build/
#   make -C fpga synth        synthesis, netlist and utilization only
#   make -C fpga ice40-stats  Yosys iCE40 statistics (the design does NOT fit an iCE40)
#
# A fresh random UDS + serial is written to build/otp_image.vh on a clean
# build. It is embedded in the bitstream: prototype identity only.
#
# Reproducible build (docs/REPRODUCIBLE.md):
#   make -C fpga repro B=build_a        REPRO=1 build + digests + toolchain fingerprint
#   make -C fpga repro-check B=build_a  compare with fpga/repro.sha256 / toolchain.lock
# REPRO=1 replaces the random UDS with a fixed, PUBLIC test value so that the
# bitstream is a pure function of the sources and the toolchain. A REPRO
# bitstream has a published identity: never use it as a device identity.
DEVICE  ?= 85k
PACKAGE ?= CABGA381
TOP     := ulx3s_top
# Engine RTL only (research/unit-test arithmetic blocks are not part of the chip).
CORE    := apb_regfile axil_to_apb dice_cdi hmac_drbg hmac_sha256 hwcp_rom id_engine_top \
           key_ladder otp_fuses pcr_bank quote_engine se_spi_master seal_unit \
           sha256_compress sha256_stream sram_puf tamper_ctrl tamper_mesh trng uart_apb_bridge
RTL     := $(addprefix ../rtl/,$(addsuffix .v,$(CORE)))
SRC     := ulx3s_top.v ro_entropy_ecp5.v $(RTL)
B       ?= build
REPRO   ?= 0
# Fixed public test identity for REPRO=1: SHA-256 of a fixed label.
REPRO_UDS    := $(shell printf 'ai-id-engine reproducible-build TEST UDS (public, not secret)' | sha256sum | cut -c1-64)
REPRO_SERIAL := 00000000000000a1

all: $(B)/ai_id_engine_ulx3s.bit

$(B)/otp_image.vh:
	mkdir -p $(B)
ifeq ($(REPRO),1)
	printf '`define AIID_FPGA_UDS 256%sh%s\n`define AIID_FPGA_SERIAL 64%sh%s\n' "'" $(REPRO_UDS) "'" $(REPRO_SERIAL) > $@
else
	python3 -c "import secrets;print('\`define AIID_FPGA_UDS 256\'h'+secrets.token_hex(32));print('\`define AIID_FPGA_SERIAL 64\'h'+secrets.token_hex(8))" > $@
endif

synth: $(B)/ai_id_engine.json
$(B)/ai_id_engine.json: $(SRC) $(B)/otp_image.vh
	yosys -l $(B)/yosys.log -p "read_verilog -DAI_ID_FUSE_UDS -I../rtl -I$(B) $(B)/otp_image.vh $(SRC); \
	  synth_ecp5 -top $(TOP) -json $@; \
	  tee -o $(B)/utilization_ecp5.txt stat; \
	  write_verilog -noattr $(B)/ai_id_engine_netlist.v" > /dev/null

$(B)/ai_id_engine.config: $(B)/ai_id_engine.json ulx3s.lpf
	nextpnr-ecp5 --$(DEVICE) --package $(PACKAGE) --json $< --lpf ulx3s.lpf \
	  --textcfg $@ --freq 25 --timing-allow-fail --ignore-loops --router router2 --seed 1 --threads 1 \
	  --report $(B)/nextpnr_report.json --log $(B)/nextpnr.log > /dev/null 2>&1 || \
	  (tail -40 $(B)/nextpnr.log; exit 1)

$(B)/ai_id_engine_ulx3s.bit: $(B)/ai_id_engine.config
	ecppack --compress $< $@
	@( grep -E "^Info:[[:space:]]+(TRELLIS_COMB|TRELLIS_FF|TRELLIS_IO|DP16KD|MULT18X18D|TRELLIS_RAMW):" $(B)/nextpnr.log; \
	   grep "Max frequency for clock" $(B)/nextpnr.log | tail -1 ) | tee $(B)/summary.txt

ice40-stats: $(B)/otp_image.vh
	yosys -q -p "read_verilog -DAI_ID_FUSE_UDS -I../rtl $(filter-out %/uart_apb_bridge.v %/axil_to_apb.v,$(RTL)); \
	  synth_ice40 -top id_engine_top; tee -o $(B)/utilization_ice40.txt stat" > /dev/null

# Digests of every build product, plus the toolchain fingerprint (versions
# and SHA-256 of the binaries actually on PATH).
repro:
	rm -rf $(B)
	$(MAKE) REPRO=1 B=$(B) $(B)/ai_id_engine_ulx3s.bit
	cd $(B) && sha256sum otp_image.vh ai_id_engine.json ai_id_engine.config ai_id_engine_ulx3s.bit > digests.txt
	{ for t in yosys nextpnr-ecp5 ecppack; do \
	    p=$$(command -v $$t); echo "$$t $$(sha256sum < $$(readlink -f $$p) | cut -c1-64) $$($$t --version 2>&1 | head -1)"; \
	  done; } > $(B)/toolchain.txt
	cat $(B)/digests.txt $(B)/toolchain.txt

# Fails on any digest or toolchain change against the committed expectations.
# Until they are committed (bootstrap), it prints what to commit and passes.
repro-check:
	@if [ -f repro.sha256 ]; then diff -u repro.sha256 $(B)/digests.txt && echo "repro: bitstream digests match fpga/repro.sha256"; \
	 else echo "repro: fpga/repro.sha256 not committed yet (bootstrap); expected digests:"; cat $(B)/digests.txt; fi
	@if [ -f toolchain.lock ]; then diff -u toolchain.lock $(B)/toolchain.txt && echo "repro: toolchain matches fpga/toolchain.lock"; \
	 else echo "repro: fpga/toolchain.lock not committed yet (bootstrap); toolchain:"; cat $(B)/toolchain.txt; fi

clean:
	rm -rf $(B)

.PHONY: all synth ice40-stats clean repro repro-check
