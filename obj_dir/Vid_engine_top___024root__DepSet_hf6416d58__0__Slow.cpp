// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vid_engine_top.h for the primary calling header

#include "Vid_engine_top__pch.h"
#include "Vid_engine_top___024root.h"

VL_ATTR_COLD void Vid_engine_top___024root___eval_static(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_static\n"); );
}

VL_ATTR_COLD void Vid_engine_top___024root___eval_initial__TOP(Vid_engine_top___024root* vlSelf);

VL_ATTR_COLD void Vid_engine_top___024root___eval_initial(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_initial\n"); );
    // Body
    Vid_engine_top___024root___eval_initial__TOP(vlSelf);
    vlSelf->__Vtrigprevexpr___TOP__presetn__0 = vlSelf->presetn;
    vlSelf->__Vtrigprevexpr___TOP__puf_clk__0 = vlSelf->puf_clk;
    vlSelf->__Vtrigprevexpr___TOP__pclk__0 = vlSelf->pclk;
}

VL_ATTR_COLD void Vid_engine_top___024root___eval_initial__TOP(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_initial__TOP\n"); );
    // Body
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0U] = 0x428a2f98U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[1U] = 0x71374491U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[2U] = 0xb5c0fbcfU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[3U] = 0xe9b5dba5U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[4U] = 0x3956c25bU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[5U] = 0x59f111f1U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[6U] = 0x923f82a4U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[7U] = 0xab1c5ed5U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[8U] = 0xd807aa98U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[9U] = 0x12835b01U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xaU] = 0x243185beU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xbU] = 0x550c7dc3U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xcU] = 0x72be5d74U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xdU] = 0x80deb1feU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xeU] = 0x9bdc06a7U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0xfU] = 0xc19bf174U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x10U] = 0xe49b69c1U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x11U] = 0xefbe4786U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x12U] = 0xfc19dc6U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x13U] = 0x240ca1ccU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x14U] = 0x2de92c6fU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x15U] = 0x4a7484aaU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x16U] = 0x5cb0a9dcU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x17U] = 0x76f988daU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x18U] = 0x983e5152U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x19U] = 0xa831c66dU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1aU] = 0xb00327c8U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1bU] = 0xbf597fc7U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1cU] = 0xc6e00bf3U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1dU] = 0xd5a79147U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1eU] = 0x6ca6351U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x1fU] = 0x14292967U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x20U] = 0x27b70a85U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x21U] = 0x2e1b2138U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x22U] = 0x4d2c6dfcU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x23U] = 0x53380d13U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x24U] = 0x650a7354U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x25U] = 0x766a0abbU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x26U] = 0x81c2c92eU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x27U] = 0x92722c85U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x28U] = 0xa2bfe8a1U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x29U] = 0xa81a664bU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2aU] = 0xc24b8b70U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2bU] = 0xc76c51a3U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2cU] = 0xd192e819U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2dU] = 0xd6990624U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2eU] = 0xf40e3585U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x2fU] = 0x106aa070U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x30U] = 0x19a4c116U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x31U] = 0x1e376c08U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x32U] = 0x2748774cU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x33U] = 0x34b0bcb5U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x34U] = 0x391c0cb3U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x35U] = 0x4ed8aa4aU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x36U] = 0x5b9cca4fU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x37U] = 0x682e6ff3U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x38U] = 0x748f82eeU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x39U] = 0x78a5636fU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3aU] = 0x84c87814U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3bU] = 0x8cc70208U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3cU] = 0x90befffaU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3dU] = 0xa4506cebU;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3eU] = 0xbef9a3f7U;
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[0x3fU] = 0xc67178f2U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0U] = 0x428a2f98U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[1U] = 0x71374491U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[2U] = 0xb5c0fbcfU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[3U] = 0xe9b5dba5U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[4U] = 0x3956c25bU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[5U] = 0x59f111f1U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[6U] = 0x923f82a4U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[7U] = 0xab1c5ed5U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[8U] = 0xd807aa98U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[9U] = 0x12835b01U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xaU] = 0x243185beU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xbU] = 0x550c7dc3U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xcU] = 0x72be5d74U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xdU] = 0x80deb1feU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xeU] = 0x9bdc06a7U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0xfU] = 0xc19bf174U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x10U] = 0xe49b69c1U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x11U] = 0xefbe4786U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x12U] = 0xfc19dc6U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x13U] = 0x240ca1ccU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x14U] = 0x2de92c6fU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x15U] = 0x4a7484aaU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x16U] = 0x5cb0a9dcU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x17U] = 0x76f988daU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x18U] = 0x983e5152U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x19U] = 0xa831c66dU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1aU] = 0xb00327c8U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1bU] = 0xbf597fc7U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1cU] = 0xc6e00bf3U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1dU] = 0xd5a79147U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1eU] = 0x6ca6351U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x1fU] = 0x14292967U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x20U] = 0x27b70a85U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x21U] = 0x2e1b2138U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x22U] = 0x4d2c6dfcU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x23U] = 0x53380d13U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x24U] = 0x650a7354U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x25U] = 0x766a0abbU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x26U] = 0x81c2c92eU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x27U] = 0x92722c85U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x28U] = 0xa2bfe8a1U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x29U] = 0xa81a664bU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2aU] = 0xc24b8b70U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2bU] = 0xc76c51a3U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2cU] = 0xd192e819U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2dU] = 0xd6990624U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2eU] = 0xf40e3585U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x2fU] = 0x106aa070U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x30U] = 0x19a4c116U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x31U] = 0x1e376c08U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x32U] = 0x2748774cU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x33U] = 0x34b0bcb5U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x34U] = 0x391c0cb3U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x35U] = 0x4ed8aa4aU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x36U] = 0x5b9cca4fU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x37U] = 0x682e6ff3U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x38U] = 0x748f82eeU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x39U] = 0x78a5636fU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3aU] = 0x84c87814U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3bU] = 0x8cc70208U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3cU] = 0x90befffaU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3dU] = 0xa4506cebU;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3eU] = 0xbef9a3f7U;
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[0x3fU] = 0xc67178f2U;
}

VL_ATTR_COLD void Vid_engine_top___024root___eval_final(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_final\n"); );
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__stl(Vid_engine_top___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vid_engine_top___024root___eval_phase__stl(Vid_engine_top___024root* vlSelf);

VL_ATTR_COLD void Vid_engine_top___024root___eval_settle(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_settle\n"); );
    // Init
    IData/*31:0*/ __VstlIterCount;
    CData/*0:0*/ __VstlContinue;
    // Body
    __VstlIterCount = 0U;
    vlSelf->__VstlFirstIteration = 1U;
    __VstlContinue = 1U;
    while (__VstlContinue) {
        if (VL_UNLIKELY((0x64U < __VstlIterCount))) {
#ifdef VL_DEBUG
            Vid_engine_top___024root___dump_triggers__stl(vlSelf);
#endif
            VL_FATAL_MT("rtl/id_engine_top.v", 5, "", "Settle region did not converge.");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        __VstlContinue = 0U;
        if (Vid_engine_top___024root___eval_phase__stl(vlSelf)) {
            __VstlContinue = 1U;
        }
        vlSelf->__VstlFirstIteration = 0U;
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__stl(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VstlTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        VL_DBG_MSGF("         'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vid_engine_top___024root___stl_sequent__TOP__0(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___stl_sequent__TOP__0\n"); );
    // Body
    vlSelf->id_engine_top__DOT__pcr_flat[0U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[1U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[2U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[3U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[4U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[5U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[6U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[7U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[8U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[9U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xaU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xbU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xcU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xdU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xeU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0xfU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [1U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x10U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x11U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x12U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x13U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x14U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x15U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x16U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x17U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [2U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x18U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x19U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x1fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [3U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x20U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x21U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x22U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x23U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x24U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x25U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x26U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x27U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [4U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x28U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x29U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x2fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [5U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x30U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x31U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x32U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x33U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x34U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x35U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x36U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x37U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [6U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x38U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x39U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x3fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [7U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x40U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x41U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x42U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x43U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x44U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x45U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x46U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x47U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [8U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x48U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x49U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x4fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [9U][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x50U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x51U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x52U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x53U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x54U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x55U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x56U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x57U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xaU][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x58U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x59U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x5fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xbU][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x60U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x61U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x62U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x63U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x64U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x65U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x66U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x67U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xcU][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x68U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x69U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x6fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xdU][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x70U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x71U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x72U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x73U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x74U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x75U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x76U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x77U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xeU][7U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x78U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][0U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x79U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][1U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7aU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][2U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7bU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][3U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7cU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][4U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7dU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][5U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7eU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][6U];
    vlSelf->id_engine_top__DOT__pcr_flat[0x7fU] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [0xfU][7U];
    vlSelf->id_engine_top__DOT__pcr_r[0U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][0U];
    vlSelf->id_engine_top__DOT__pcr_r[1U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][1U];
    vlSelf->id_engine_top__DOT__pcr_r[2U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][2U];
    vlSelf->id_engine_top__DOT__pcr_r[3U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][3U];
    vlSelf->id_engine_top__DOT__pcr_r[4U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][4U];
    vlSelf->id_engine_top__DOT__pcr_r[5U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][5U];
    vlSelf->id_engine_top__DOT__pcr_r[6U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][6U];
    vlSelf->id_engine_top__DOT__pcr_r[7U] = vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr
        [vlSelf->id_engine_top__DOT__pcr_sel][7U];
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t2 
        = (([&]() {
                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x 
                    = vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a;
                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__Vfuncout 
                    = ((([&]() {
                                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__x 
                                    = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x;
                                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__Vfuncout 
                                    = ((vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__x 
                                        >> 2U) | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__x, 0x1eU));
                            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__Vfuncout) 
                        ^ ([&]() {
                                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__x 
                                    = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x;
                                vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__Vfuncout 
                                    = ((vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__x 
                                        >> 0xdU) | 
                                       VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__x, 0x13U));
                            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__Vfuncout)) 
                       ^ ([&]() {
                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__x 
                                = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x;
                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__Vfuncout 
                                = ((vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__x 
                                    >> 0x16U) | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__x, 0xaU));
                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__Vfuncout));
            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__Vfuncout) 
           + (((vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a 
                & vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b) 
               ^ (vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a 
                  & vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c)) 
              ^ (vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b 
                 & vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c)));
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t2 
        = (([&]() {
                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x 
                    = vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__a;
                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__Vfuncout 
                    = ((([&]() {
                                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__x 
                                    = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x;
                                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__Vfuncout 
                                    = ((vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__x 
                                        >> 2U) | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__x, 0x1eU));
                            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__Vfuncout) 
                        ^ ([&]() {
                                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__x 
                                    = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x;
                                vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__Vfuncout 
                                    = ((vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__x 
                                        >> 0xdU) | 
                                       VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__x, 0x13U));
                            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__Vfuncout)) 
                       ^ ([&]() {
                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__x 
                                = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x;
                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__Vfuncout 
                                = ((vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__x 
                                    >> 0x16U) | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__x, 0xaU));
                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__Vfuncout));
            }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__Vfuncout) 
           + (((vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__a 
                & vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__b) 
               ^ (vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__a 
                  & vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__c)) 
              ^ (vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__b 
                 & vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__c)));
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t1 
        = ((((vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__hh 
              + ([&]() {
                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x 
                                = vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e;
                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__Vfuncout 
                                = ((([&]() {
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__x 
                                                = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x;
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__Vfuncout 
                                                = (
                                                   (vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__x 
                                                    >> 6U) 
                                                   | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__x, 0x1aU));
                                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__Vfuncout) 
                                    ^ ([&]() {
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__x 
                                                = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x;
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__Vfuncout 
                                                = (
                                                   (vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__x 
                                                    >> 0xbU) 
                                                   | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__x, 0x15U));
                                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__Vfuncout)) 
                                   ^ ([&]() {
                                        vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__x 
                                            = vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x;
                                        vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__Vfuncout 
                                            = ((vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__x 
                                                >> 0x19U) 
                                               | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__x, 7U));
                                    }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__Vfuncout));
                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__Vfuncout)) 
             + ((vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e 
                 & vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__f) 
                ^ ((~ vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e) 
                   & vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__g))) 
            + vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k
            [(0x3fU & (IData)(vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round))]) 
           + vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w
           [(0x3fU & (IData)(vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round))]);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t1 
        = ((((vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__hh 
              + ([&]() {
                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x 
                                = vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__e;
                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__Vfuncout 
                                = ((([&]() {
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__x 
                                                = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x;
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__Vfuncout 
                                                = (
                                                   (vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__x 
                                                    >> 6U) 
                                                   | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__x, 0x1aU));
                                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__Vfuncout) 
                                    ^ ([&]() {
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__x 
                                                = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x;
                                            vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__Vfuncout 
                                                = (
                                                   (vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__x 
                                                    >> 0xbU) 
                                                   | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__x, 0x15U));
                                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__Vfuncout)) 
                                   ^ ([&]() {
                                        vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__x 
                                            = vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x;
                                        vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__Vfuncout 
                                            = ((vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__x 
                                                >> 0x19U) 
                                               | VL_SHIFTL_III(32,32,32, vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__x, 7U));
                                    }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__Vfuncout));
                        }(), vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__Vfuncout)) 
             + ((vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__e 
                 & vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__f) 
                ^ ((~ vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__e) 
                   & vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__g))) 
            + vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k
            [(0x3fU & (IData)(vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__round))]) 
           + vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__w
           [(0x3fU & (IData)(vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__round))]);
}

VL_ATTR_COLD void Vid_engine_top___024root___eval_stl(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_stl\n"); );
    // Body
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        Vid_engine_top___024root___stl_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD void Vid_engine_top___024root___eval_triggers__stl(Vid_engine_top___024root* vlSelf);

VL_ATTR_COLD bool Vid_engine_top___024root___eval_phase__stl(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_phase__stl\n"); );
    // Init
    CData/*0:0*/ __VstlExecute;
    // Body
    Vid_engine_top___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = vlSelf->__VstlTriggered.any();
    if (__VstlExecute) {
        Vid_engine_top___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__act(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VactTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 0 is active: @(negedge presetn or posedge puf_clk)\n");
    }
    if ((2ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 1 is active: @(posedge pclk or negedge presetn)\n");
    }
    if ((4ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 2 is active: @(posedge pclk)\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__nba(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___dump_triggers__nba\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VnbaTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 0 is active: @(negedge presetn or posedge puf_clk)\n");
    }
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 1 is active: @(posedge pclk or negedge presetn)\n");
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 2 is active: @(posedge pclk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vid_engine_top___024root___ctor_var_reset(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___ctor_var_reset\n"); );
    // Body
    vlSelf->pclk = VL_RAND_RESET_I(1);
    vlSelf->presetn = VL_RAND_RESET_I(1);
    vlSelf->psel = VL_RAND_RESET_I(1);
    vlSelf->penable = VL_RAND_RESET_I(1);
    vlSelf->pwrite = VL_RAND_RESET_I(1);
    vlSelf->paddr = VL_RAND_RESET_I(12);
    vlSelf->pwdata = VL_RAND_RESET_I(32);
    vlSelf->prdata = VL_RAND_RESET_I(32);
    vlSelf->pready = VL_RAND_RESET_I(1);
    vlSelf->puf_clk = VL_RAND_RESET_I(1);
    vlSelf->tamper_sensors = VL_RAND_RESET_I(8);
    vlSelf->zeroize_clear = VL_RAND_RESET_I(1);
    vlSelf->dma_valid = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(128, vlSelf->dma_data);
    vlSelf->dma_last = VL_RAND_RESET_I(1);
    vlSelf->dma_ready = VL_RAND_RESET_I(1);
    vlSelf->se_cs_n = VL_RAND_RESET_I(1);
    vlSelf->se_sck = VL_RAND_RESET_I(1);
    vlSelf->se_mosi = VL_RAND_RESET_I(1);
    vlSelf->se_miso = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__uds);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__alias_key);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__pcr_r);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__cdi_out);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__unseal_out);
    VL_RAND_RESET_W(4096, vlSelf->id_engine_top__DOT__pcr_flat);
    vlSelf->id_engine_top__DOT__pcr_ext = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__quote_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__cdi_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__pcr_sel = VL_RAND_RESET_I(4);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__pcr_wdata);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__seal_in);
    VL_RAND_RESET_W(128, vlSelf->id_engine_top__DOT__cdi_label);
    vlSelf->id_engine_top__DOT__seal_policy = VL_RAND_RESET_I(16);
    vlSelf->id_engine_top__DOT__seal_op = VL_RAND_RESET_I(2);
    vlSelf->id_engine_top__DOT__tamper_sticky = VL_RAND_RESET_I(8);
    vlSelf->id_engine_top__DOT__zeroize = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__seal_ok = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__quote_data = VL_RAND_RESET_I(8);
    vlSelf->id_engine_top__DOT__quote_len = VL_RAND_RESET_I(16);
    vlSelf->id_engine_top__DOT__quote_done = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(512, vlSelf->id_engine_top__DOT__u_cdi__DOT__msg);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__state = VL_RAND_RESET_I(3);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__h_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__h_done = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_cdi__DOT__h_mac);
    VL_RAND_RESET_W(512, vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__kpad);
    VL_RAND_RESET_W(512, vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__blk);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__inner);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__state = VL_RAND_RESET_I(3);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_busy = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_done = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_dig);
    for (int __Vi0 = 0; __Vi0 < 64; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k[__Vi0] = VL_RAND_RESET_I(32);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h[__Vi0] = VL_RAND_RESET_I(32);
    }
    for (int __Vi0 = 0; __Vi0 < 64; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w[__Vi0] = VL_RAND_RESET_I(32);
    }
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__d = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__f = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__g = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__hh = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round = VL_RAND_RESET_I(7);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__active = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t1 = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t2 = VL_RAND_RESET_I(32);
    for (int __Vi0 = 0; __Vi0 < 16; ++__Vi0) {
        VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_pcr__DOT__pcr[__Vi0]);
    }
    VL_RAND_RESET_W(512, vlSelf->id_engine_top__DOT__u_pcr__DOT__blk);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__st = VL_RAND_RESET_I(2);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__h_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__h_busy = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__h_done = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_pcr__DOT__h_dig);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__sel_q = VL_RAND_RESET_I(4);
    for (int __Vi0 = 0; __Vi0 < 64; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k[__Vi0] = VL_RAND_RESET_I(32);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__h[__Vi0] = VL_RAND_RESET_I(32);
    }
    for (int __Vi0 = 0; __Vi0 < 64; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__w[__Vi0] = VL_RAND_RESET_I(32);
    }
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__a = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__b = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__c = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__d = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__e = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__f = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__g = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__hh = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__round = VL_RAND_RESET_I(7);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__active = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t1 = VL_RAND_RESET_I(32);
    vlSelf->id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t2 = VL_RAND_RESET_I(32);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_seal__DOT__wrapped);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_seal__DOT__policy_digest);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_seal__DOT__expected_digest);
    vlSelf->id_engine_top__DOT__u_seal__DOT__state = VL_RAND_RESET_I(2);
    vlSelf->id_engine_top__DOT__u_q__DOT__state = VL_RAND_RESET_I(3);
    for (int __Vi0 = 0; __Vi0 < 512; ++__Vi0) {
        vlSelf->id_engine_top__DOT__u_q__DOT__payload[__Vi0] = VL_RAND_RESET_I(8);
    }
    vlSelf->id_engine_top__DOT__u_q__DOT__plen = VL_RAND_RESET_I(16);
    vlSelf->id_engine_top__DOT__u_q__DOT__idx = VL_RAND_RESET_I(16);
    vlSelf->id_engine_top__DOT__u_q__DOT__ec_start = VL_RAND_RESET_I(1);
    vlSelf->id_engine_top__DOT__u_q__DOT__ec_done = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(512, vlSelf->id_engine_top__DOT__u_q__DOT__ec_sig);
    VL_RAND_RESET_W(256, vlSelf->id_engine_top__DOT__u_q__DOT__payload_hash);
    vlSelf->id_engine_top__DOT__u_apb__DOT__wcnt = VL_RAND_RESET_I(3);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__x = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__Vfuncout = VL_RAND_RESET_I(32);
    vlSelf->__Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__x = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__h_start = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(512, vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__msg);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__state = VL_RAND_RESET_I(3);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_start = VL_RAND_RESET_I(1);
    VL_RAND_RESET_W(512, vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__blk);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__state = VL_RAND_RESET_I(3);
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w__v0 = 0;
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__d = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__f = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__g = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__hh = VL_RAND_RESET_I(32);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round = VL_RAND_RESET_I(7);
    vlSelf->__Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__active = VL_RAND_RESET_I(1);
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w__v1 = 0;
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h__v8 = 0;
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h__v9 = 0;
    vlSelf->__Vdly__id_engine_top__DOT__u_pcr__DOT__st = VL_RAND_RESET_I(2);
    VL_RAND_RESET_W(256, vlSelf->__Vdly__id_engine_top__DOT__u_seal__DOT__wrapped);
    vlSelf->__Vdly__id_engine_top__DOT__u_q__DOT__plen = VL_RAND_RESET_I(16);
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v0 = 0;
    vlSelf->__Vdly__id_engine_top__DOT__u_q__DOT__state = VL_RAND_RESET_I(3);
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v1 = 0;
    vlSelf->__Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v2 = 0;
    vlSelf->__Vdly__id_engine_top__DOT__u_q__DOT__idx = VL_RAND_RESET_I(16);
    vlSelf->__Vdly__id_engine_top__DOT__tamper_sticky = VL_RAND_RESET_I(8);
    vlSelf->__Vdly__id_engine_top__DOT__u_apb__DOT__wcnt = VL_RAND_RESET_I(3);
    VL_RAND_RESET_W(256, vlSelf->__Vdly__id_engine_top__DOT__seal_in);
    vlSelf->__Vdly__id_engine_top__DOT__u_q__DOT__ec_done = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__presetn__0 = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__puf_clk__0 = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__pclk__0 = VL_RAND_RESET_I(1);
}
