#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# RTL -> sky130 gate-netlist equivalence with Yosys equiv_* (no eqy needed).
# usage: equiv_netlist.sh TOP NETLIST.v CELLS.v LOGDIR rtl.v [rtl.v ...]
# The gold design is the RTL (read with -DSYNTHESIS, as synth_sky130.sh does)
# taken through the same coarse `synth -run begin:fine` stage, which includes
# Yosys's FSM extraction/recoding: the recoded state register is the only
# state that changes name and width, so it must be the same on both sides.
# What is proven is therefore fine mapping (techmap, dfflibmap, abc -liberty)
# against word-level RTL after coarse optimisation; the FSM recode itself is
# not covered by this check.
# the gate design is the abc/dfflibmap netlist flattened through the
# generated cell models (the same models the TVLA traces run on). Flops keep
# their RTL names in the netlist, so equiv_make pairs state by name;
# equiv_simple proves each paired signal (combinational cones between
# registers, with -seq for short sequential cones), equiv_induct closes what
# is left by induction over the paired state. tools/equiv_check.py then gates
# on the equiv_status report (docs/EQUIVALENCE.md).
set -euo pipefail
top=$1 net=$2 cells=$3 out=$4; shift 4
YOSYS=${YOSYS:-yosys}
mkdir -p "$out"
"$YOSYS" -q -l "$out/equiv_$top.log" -p "
  read_verilog -DSYNTHESIS $*;
  synth -top $top -flatten -run begin:fine; async2sync; opt_clean;
  rename $top gold; design -stash gold;
  read_verilog $cells $net;
  hierarchy -top $top; flatten; proc; async2sync; opt_clean;
  rename $top gate; design -stash gate;
  design -copy-from gold -as gold gold;
  design -copy-from gate -as gate gate;
  equiv_make gold gate equiv;
  hierarchy -top equiv;
  equiv_simple -seq 5;
  equiv_induct -seq 5;
  tee -q -o $out/equiv_$top.txt equiv_status"
