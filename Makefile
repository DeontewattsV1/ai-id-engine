# SPDX-License-Identifier: MIT
VERILATOR ?= verilator
RTL := $(sort $(wildcard rtl/*.v))

all: sim

obj_dir/Vid_engine_top: tb/tb_id_engine.cpp tb/ecdsa_dpi.cpp $(RTL)
	$(VERILATOR) --cc --exe --build --timing -Irtl \
	  -Wno-fatal -Wno-lint -Wno-UNOPTFLAT \
	  --top-module id_engine_top \
	  -CFLAGS "-O2 -DVERILATOR" -LDFLAGS "-lcrypto" \
	  $(RTL) tb/tb_id_engine.cpp tb/ecdsa_dpi.cpp -o Vid_engine_top

sim: obj_dir/Vid_engine_top
	./obj_dir/Vid_engine_top

lint:
	$(VERILATOR) --lint-only -Wall -Wno-fatal -Irtl $(RTL) --top-module id_engine_top

cov:
	rm -f coverage.dat
	$(VERILATOR) --cc --exe --build --coverage --timing -Irtl \
	  -Wno-fatal -Wno-lint -Wno-UNOPTFLAT --top-module id_engine_top \
	  -CFLAGS "-O2 -DVERILATOR" -LDFLAGS "-lcrypto" \
	  $(RTL) tb/tb_id_engine.cpp tb/ecdsa_dpi.cpp -o Vid_engine_top
	./obj_dir/Vid_engine_top
	@test -s coverage.dat

formal:
	sby -f formal/sby.toml
	sby -f formal/sby_cover.toml

fuzz:
	python3 test/bch_roundtrip.py
	python3 test/puf_characterize_test.py

.PHONY: all sim lint cov formal fuzz
