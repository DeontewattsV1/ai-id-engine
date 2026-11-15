// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vid_engine_top.h for the primary calling header

#include "Vid_engine_top__pch.h"
#include "Vid_engine_top___024root.h"

extern const VlUnpacked<CData/*0:0*/, 4> Vid_engine_top__ConstPool__TABLE_ha9fc40c0_0;
extern const VlUnpacked<VlWide<8>/*255:0*/, 4> Vid_engine_top__ConstPool__TABLE_h9c041c32_0;

VL_INLINE_OPT void Vid_engine_top___024root___nba_sequent__TOP__3(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___nba_sequent__TOP__3\n"); );
    // Init
    CData/*1:0*/ __Vtableidx1;
    __Vtableidx1 = 0;
    // Body
    __Vtableidx1 = (((IData)(vlSelf->id_engine_top__DOT__zeroize) 
                     << 1U) | (IData)(vlSelf->presetn));
    if (Vid_engine_top__ConstPool__TABLE_ha9fc40c0_0
        [__Vtableidx1]) {
        vlSelf->id_engine_top__DOT__uds[0U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][0U];
        vlSelf->id_engine_top__DOT__uds[1U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][1U];
        vlSelf->id_engine_top__DOT__uds[2U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][2U];
        vlSelf->id_engine_top__DOT__uds[3U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][3U];
        vlSelf->id_engine_top__DOT__uds[4U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][4U];
        vlSelf->id_engine_top__DOT__uds[5U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][5U];
        vlSelf->id_engine_top__DOT__uds[6U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][6U];
        vlSelf->id_engine_top__DOT__uds[7U] = Vid_engine_top__ConstPool__TABLE_h9c041c32_0
            [__Vtableidx1][7U];
    }
}

VL_INLINE_OPT void Vid_engine_top___024root___nba_sequent__TOP__4(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___nba_sequent__TOP__4\n"); );
    // Body
    vlSelf->id_engine_top__DOT__u_q__DOT__ec_done = vlSelf->__Vdly__id_engine_top__DOT__u_q__DOT__ec_done;
}

VL_INLINE_OPT void Vid_engine_top___024root___nba_sequent__TOP__5(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___nba_sequent__TOP__5\n"); );
    // Body
    if (vlSelf->presetn) {
        vlSelf->id_engine_top__DOT__zeroize = 0U;
        vlSelf->__Vdly__id_engine_top__DOT__tamper_sticky 
            = ((IData)(vlSelf->id_engine_top__DOT__tamper_sticky) 
               | (IData)(vlSelf->tamper_sensors));
        if ((0U != ((IData)(vlSelf->tamper_sensors) 
                    & (~ (IData)(vlSelf->id_engine_top__DOT__tamper_sticky))))) {
            vlSelf->id_engine_top__DOT__zeroize = 1U;
        }
        if ((0U != (1U & (IData)(vlSelf->tamper_sensors)))) {
            vlSelf->id_engine_top__DOT__zeroize = 1U;
        }
        if (vlSelf->zeroize_clear) {
            vlSelf->__Vdly__id_engine_top__DOT__tamper_sticky = 0U;
        }
    } else {
        vlSelf->__Vdly__id_engine_top__DOT__tamper_sticky = 0xffU;
        vlSelf->id_engine_top__DOT__zeroize = 1U;
    }
    vlSelf->id_engine_top__DOT__tamper_sticky = vlSelf->__Vdly__id_engine_top__DOT__tamper_sticky;
}

void Vid_engine_top___024root___nba_sequent__TOP__0(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___nba_sequent__TOP__1(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___nba_sequent__TOP__2(Vid_engine_top___024root* vlSelf);

void Vid_engine_top___024root___eval_nba(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_nba\n"); );
    // Body
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__0(vlSelf);
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__1(vlSelf);
    }
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__2(vlSelf);
    }
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__3(vlSelf);
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__4(vlSelf);
    }
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vid_engine_top___024root___nba_sequent__TOP__5(vlSelf);
    }
}

void Vid_engine_top___024root___eval_triggers__act(Vid_engine_top___024root* vlSelf);
void Vid_engine_top___024root___eval_act(Vid_engine_top___024root* vlSelf);

bool Vid_engine_top___024root___eval_phase__act(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<3> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vid_engine_top___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vid_engine_top___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vid_engine_top___024root___eval_phase__nba(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vid_engine_top___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__nba(Vid_engine_top___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vid_engine_top___024root___dump_triggers__act(Vid_engine_top___024root* vlSelf);
#endif  // VL_DEBUG

void Vid_engine_top___024root___eval(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vid_engine_top___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("rtl/id_engine_top.v", 5, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vid_engine_top___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("rtl/id_engine_top.v", 5, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vid_engine_top___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vid_engine_top___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vid_engine_top___024root___eval_debug_assertions(Vid_engine_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vid_engine_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vid_engine_top___024root___eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((vlSelf->pclk & 0xfeU))) {
        Verilated::overWidthError("pclk");}
    if (VL_UNLIKELY((vlSelf->presetn & 0xfeU))) {
        Verilated::overWidthError("presetn");}
    if (VL_UNLIKELY((vlSelf->psel & 0xfeU))) {
        Verilated::overWidthError("psel");}
    if (VL_UNLIKELY((vlSelf->penable & 0xfeU))) {
        Verilated::overWidthError("penable");}
    if (VL_UNLIKELY((vlSelf->pwrite & 0xfeU))) {
        Verilated::overWidthError("pwrite");}
    if (VL_UNLIKELY((vlSelf->paddr & 0xf000U))) {
        Verilated::overWidthError("paddr");}
    if (VL_UNLIKELY((vlSelf->puf_clk & 0xfeU))) {
        Verilated::overWidthError("puf_clk");}
    if (VL_UNLIKELY((vlSelf->zeroize_clear & 0xfeU))) {
        Verilated::overWidthError("zeroize_clear");}
    if (VL_UNLIKELY((vlSelf->dma_valid & 0xfeU))) {
        Verilated::overWidthError("dma_valid");}
    if (VL_UNLIKELY((vlSelf->dma_last & 0xfeU))) {
        Verilated::overWidthError("dma_last");}
    if (VL_UNLIKELY((vlSelf->se_miso & 0xfeU))) {
        Verilated::overWidthError("se_miso");}
}
#endif  // VL_DEBUG
