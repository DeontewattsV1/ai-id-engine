// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vid_engine_top__pch.h"
#include "Vid_engine_top.h"
#include "Vid_engine_top___024root.h"
#include "Vid_engine_top___024unit.h"

// FUNCTIONS
Vid_engine_top__Syms::~Vid_engine_top__Syms()
{
}

Vid_engine_top__Syms::Vid_engine_top__Syms(VerilatedContext* contextp, const char* namep, Vid_engine_top* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
{
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    // Setup export functions
    for (int __Vfinal = 0; __Vfinal < 2; ++__Vfinal) {
    }
}
