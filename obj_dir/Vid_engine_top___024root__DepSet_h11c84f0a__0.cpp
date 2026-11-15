// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vid_engine_top.h for the primary calling header

#include "Vid_engine_top__pch.h"
#include "Vid_engine_top__Syms.h"
#include "Vid_engine_top___024root.h"

extern "C" void c_ecdsa_sign(const svBitVecVal* priv, const svBitVecVal* hash, svBitVecVal* sig);

VL_INLINE_OPT void Vid_engine_top___024root____Vdpiimwrap_id_engine_top__DOT__u_q__DOT__u_ec__DOT__c_ecdsa_sign_TOP(VlWide<8>/*255:0*/ priv, VlWide<8>/*255:0*/ hash, VlWide<16>/*511:0*/ &sig) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root____Vdpiimwrap_id_engine_top__DOT__u_q__DOT__u_ec__DOT__c_ecdsa_sign_TOP\n"); );
    // Body
    svBitVecVal priv__Vcvt[8];
    for (size_t priv__Vidx = 0; priv__Vidx < 1; ++priv__Vidx) VL_SET_SVBV_W(256, priv__Vcvt + 8 * priv__Vidx, priv);
    svBitVecVal hash__Vcvt[8];
    for (size_t hash__Vidx = 0; hash__Vidx < 1; ++hash__Vidx) VL_SET_SVBV_W(256, hash__Vcvt + 8 * hash__Vidx, hash);
    svBitVecVal sig__Vcvt[16];
    c_ecdsa_sign(priv__Vcvt, hash__Vcvt, sig__Vcvt);
    VL_SET_W_SVBV(512,sig,sig__Vcvt + 0);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__act(Vid_engine_top___024root* vlSelf);
#endif  // VL_DEBUG

void Vid_engine_top___024root___eval_triggers__act(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_triggers__act\n"); );
    // Body
    vlSelf->__VactTriggered.set(0U, (((~ (IData)(vlSelf->presetn)) 
                                      & (IData)(vlSelf->__Vtrigprevexpr___TOP__presetn__0)) 
                                     | ((IData)(vlSelf->puf_clk) 
                                        & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__puf_clk__0)))));
    vlSelf->__VactTriggered.set(1U, (((IData)(vlSelf->pclk) 
                                      & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__pclk__0))) 
                                     | ((~ (IData)(vlSelf->presetn)) 
                                        & (IData)(vlSelf->__Vtrigprevexpr___TOP__presetn__0))));
    vlSelf->__VactTriggered.set(2U, ((IData)(vlSelf->pclk) 
                                     & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__pclk__0))));
    vlSelf->__Vtrigprevexpr___TOP__presetn__0 = vlSelf->presetn;
    vlSelf->__Vtrigprevexpr___TOP__puf_clk__0 = vlSelf->puf_clk;
    vlSelf->__Vtrigprevexpr___TOP__pclk__0 = vlSelf->pclk;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vid_engine_top___024root___dump_triggers__act(vlSelf);
    }
#endif
}
