# SPDX-License-Identifier: MIT
VERILATOR ?= verilator
RTL := $(wildcard rtl/*.v)

all: sim

obj_dir/Vid_engine_top: tb/tb_id_engine.cpp $(RTL)
	$(VERILATOR) --cc --exe --build --timing \
	  -Wno-fatal -Wno-lint -Wno-UNOPTFLAT \
	  --top-module id_engine_top \
	  -CFLAGS "-O2 -DVERILATOR" -LDFLAGS "-lcrypto" \
	  $(RTL) tb/tb_id_engine.cpp -o Vid_engine_top

sim: obj_dir/Vid_engine_top
	./obj_dir/Vid_engine_top

lint:
	$(VERILATOR) --lint-only -Wall $(RTL) --top-module id_engine_top

cov:
	$(VERILATOR) --cc --exe --build --coverage $(RTL) tb/tb_id_engine.cpp
	./obj_dir/Vid_engine_top && verilator_coverage --annotate cov/ logs/*.dat

formal:
	sby -f formal/sby.toml
	sby -f formal/sby_cover.toml

fuzz:
	python3 test/gen_vectors.py --n 5000 --out test/vectors/ && \
	python3 test/run_fuzz.py

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

.PHONY: math-oracle rtl-unit
