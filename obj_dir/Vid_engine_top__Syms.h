// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VID_ENGINE_TOP__SYMS_H_
#define VERILATED_VID_ENGINE_TOP__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vid_engine_top.h"

// INCLUDE MODULE CLASSES
#include "Vid_engine_top___024root.h"
#include "Vid_engine_top___024unit.h"

// DPI TYPES for DPI Export callbacks (Internal use)

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vid_engine_top__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vid_engine_top* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vid_engine_top___024root       TOP;

    // CONSTRUCTORS
    Vid_engine_top__Syms(VerilatedContext* contextp, const char* namep, Vid_engine_top* modelp);
    ~Vid_engine_top__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard
