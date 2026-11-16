#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Map one TVLA DUT to sky130_fd_sc_hd (tt_025C_1v80) with Yosys abc -liberty.
# usage: synth_sky130.sh NAME TOP LIB OUTDIR rtl.v [rtl.v ...]
# Writes OUTDIR/sky130_NAME.v (netlist), OUTDIR/area_NAME.txt (stat -liberty)
# OUTDIR/sky130_NAME.json (same netlist, for the power model) and
# OUTDIR/synth_NAME.log.
set -euo pipefail
name=$1 top=$2 lib=$3 out=$4; shift 4
YOSYS=${YOSYS:-yosys}
# Cells the OpenROAD sky130hd platform also marks dont_use (power-gating,
# probe, physical-only cells): they are not ordinary logic.
DU="-dont_use *lpflow* -dont_use *probe* -dont_use *diode* -dont_use *tap* -dont_use *fill* -dont_use *decap* -dont_use *clkdly*"
mkdir -p "$out"
"$YOSYS" -q -l "$out/synth_$name.log" -p "
  read_verilog -DSYNTHESIS $*;
  synth -top $top -flatten;
  dfflibmap $DU -liberty $lib;
  abc $DU -liberty $lib;
  opt_clean;
  tee -q -o $out/area_$name.txt stat -liberty $lib;
  write_verilog -noattr -noexpr $out/sky130_$name.v;
  write_json $out/sky130_$name.json"
grep -E "Chip area for module" "$out/area_$name.txt"
