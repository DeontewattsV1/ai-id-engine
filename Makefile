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
