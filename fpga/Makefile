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
DEVICE  ?= 85k
PACKAGE ?= CABGA381
TOP     := ulx3s_top
# Engine RTL only (research/unit-test arithmetic blocks are not part of the chip).
CORE    := apb_regfile axil_to_apb dice_cdi hmac_drbg hmac_sha256 hwcp_rom id_engine_top \
           key_ladder otp_fuses pcr_bank quote_engine se_spi_master seal_unit \
           sha256_compress sha256_stream sram_puf tamper_ctrl tamper_mesh trng uart_apb_bridge
RTL     := $(addprefix ../rtl/,$(addsuffix .v,$(CORE)))
SRC     := ulx3s_top.v ro_entropy_ecp5.v $(RTL)
B       := build

all: $(B)/ai_id_engine_ulx3s.bit

$(B)/otp_image.vh:
	mkdir -p $(B)
	python3 -c "import secrets;print('\`define AIID_FPGA_UDS 256\'h'+secrets.token_hex(32));print('\`define AIID_FPGA_SERIAL 64\'h'+secrets.token_hex(8))" > $@

synth: $(B)/ai_id_engine.json
$(B)/ai_id_engine.json: $(SRC) $(B)/otp_image.vh
	yosys -l $(B)/yosys.log -p "read_verilog -DAI_ID_FUSE_UDS -I../rtl -I$(B) $(B)/otp_image.vh $(SRC); \
	  synth_ecp5 -top $(TOP) -json $@; \
	  tee -o $(B)/utilization_ecp5.txt stat; \
	  write_verilog -noattr $(B)/ai_id_engine_netlist.v" > /dev/null

$(B)/ai_id_engine.config: $(B)/ai_id_engine.json ulx3s.lpf
	nextpnr-ecp5 --$(DEVICE) --package $(PACKAGE) --json $< --lpf ulx3s.lpf \
	  --textcfg $@ --freq 25 --timing-allow-fail --ignore-loops --router router2 --seed 1 \
	  --report $(B)/nextpnr_report.json --log $(B)/nextpnr.log > /dev/null 2>&1 || \
	  (tail -40 $(B)/nextpnr.log; exit 1)

$(B)/ai_id_engine_ulx3s.bit: $(B)/ai_id_engine.config
	ecppack --compress $< $@
	@grep -E "Max frequency for clock|Info: Device utilisation|TRELLIS_COMB|TRELLIS_FF|DP16KD|MULT18X18D|TRELLIS_IO" $(B)/nextpnr.log | tail -14 | tee $(B)/summary.txt

ice40-stats: $(B)/otp_image.vh
	yosys -q -p "read_verilog -DAI_ID_FUSE_UDS -I../rtl $(filter-out %/uart_apb_bridge.v %/axil_to_apb.v,$(RTL)); \
	  synth_ice40 -top id_engine_top; tee -o $(B)/utilization_ice40.txt stat" > /dev/null

clean:
	rm -rf $(B)

.PHONY: all synth ice40-stats clean
