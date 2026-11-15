// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vid_engine_top.h for the primary calling header

#ifndef VERILATED_VID_ENGINE_TOP___024UNIT_H_
#define VERILATED_VID_ENGINE_TOP___024UNIT_H_  // guard

#include "verilated.h"


class Vid_engine_top__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vid_engine_top___024unit final : public VerilatedModule {
  public:

    // INTERNAL VARIABLES
    Vid_engine_top__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vid_engine_top___024unit(Vid_engine_top__Syms* symsp, const char* v__name);
    ~Vid_engine_top___024unit();
    VL_UNCOPYABLE(Vid_engine_top___024unit);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
