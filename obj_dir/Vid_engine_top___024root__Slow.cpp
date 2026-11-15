// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vid_engine_top.h for the primary calling header

#include "Vid_engine_top__pch.h"
#include "Vid_engine_top__Syms.h"
#include "Vid_engine_top___024root.h"

void Vid_engine_top___024root___ctor_var_reset(Vid_engine_top___024root* vlSelf);

Vid_engine_top___024root::Vid_engine_top___024root(Vid_engine_top__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vid_engine_top___024root___ctor_var_reset(this);
}

void Vid_engine_top___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vid_engine_top___024root::~Vid_engine_top___024root() {
}
