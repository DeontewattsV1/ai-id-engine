// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vid_engine_top__pch.h"

//============================================================
// Constructors

Vid_engine_top::Vid_engine_top(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vid_engine_top__Syms(contextp(), _vcname__, this)}
    , pclk{vlSymsp->TOP.pclk}
    , presetn{vlSymsp->TOP.presetn}
    , puf_clk{vlSymsp->TOP.puf_clk}
    , psel{vlSymsp->TOP.psel}
    , penable{vlSymsp->TOP.penable}
    , pwrite{vlSymsp->TOP.pwrite}
    , pready{vlSymsp->TOP.pready}
    , tamper_sensors{vlSymsp->TOP.tamper_sensors}
    , zeroize_clear{vlSymsp->TOP.zeroize_clear}
    , dma_valid{vlSymsp->TOP.dma_valid}
    , dma_last{vlSymsp->TOP.dma_last}
    , dma_ready{vlSymsp->TOP.dma_ready}
    , se_cs_n{vlSymsp->TOP.se_cs_n}
    , se_sck{vlSymsp->TOP.se_sck}
    , se_mosi{vlSymsp->TOP.se_mosi}
    , se_miso{vlSymsp->TOP.se_miso}
    , paddr{vlSymsp->TOP.paddr}
    , pwdata{vlSymsp->TOP.pwdata}
    , prdata{vlSymsp->TOP.prdata}
    , dma_data{vlSymsp->TOP.dma_data}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vid_engine_top::Vid_engine_top(const char* _vcname__)
    : Vid_engine_top(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vid_engine_top::~Vid_engine_top() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vid_engine_top___024root___eval_debug_assertions(Vid_engine_top___024root* vlSelf);
#endif  // VL_DEBUG
void Vid_engine_top___024root___eval_static(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___eval_initial(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___eval_settle(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___eval(Vid_engine_top___024root* vlSelf);

void Vid_engine_top::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vid_engine_top::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vid_engine_top___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vid_engine_top___024root___eval_static(&(vlSymsp->TOP));
        Vid_engine_top___024root___eval_initial(&(vlSymsp->TOP));
        Vid_engine_top___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vid_engine_top___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vid_engine_top::eventsPending() { return false; }

uint64_t Vid_engine_top::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vid_engine_top::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vid_engine_top___024root___eval_final(Vid_engine_top___024root* vlSelf);

VL_ATTR_COLD void Vid_engine_top::final() {
    Vid_engine_top___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vid_engine_top::hierName() const { return vlSymsp->name(); }
const char* Vid_engine_top::modelName() const { return "Vid_engine_top"; }
unsigned Vid_engine_top::threads() const { return 1; }
void Vid_engine_top::prepareClone() const { contextp()->prepareClone(); }
void Vid_engine_top::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vid_engine_top::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vid_engine_top::trace()' called on model that was Verilated without --trace option");
}
