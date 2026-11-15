// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vid_engine_top.h for the primary calling header

#ifndef VERILATED_VID_ENGINE_TOP___024ROOT_H_
#define VERILATED_VID_ENGINE_TOP___024ROOT_H_  // guard

#include "verilated.h"


class Vid_engine_top__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vid_engine_top___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        VL_IN8(pclk,0,0);
        VL_IN8(presetn,0,0);
        VL_IN8(puf_clk,0,0);
        VL_IN8(psel,0,0);
        VL_IN8(penable,0,0);
        VL_IN8(pwrite,0,0);
        VL_OUT8(pready,0,0);
        VL_IN8(tamper_sensors,7,0);
        VL_IN8(zeroize_clear,0,0);
        VL_IN8(dma_valid,0,0);
        VL_IN8(dma_last,0,0);
        VL_OUT8(dma_ready,0,0);
        VL_OUT8(se_cs_n,0,0);
        VL_OUT8(se_sck,0,0);
        VL_OUT8(se_mosi,0,0);
        VL_IN8(se_miso,0,0);
        CData/*0:0*/ id_engine_top__DOT__pcr_ext;
        CData/*0:0*/ id_engine_top__DOT__quote_start;
        CData/*0:0*/ id_engine_top__DOT__cdi_start;
        CData/*3:0*/ id_engine_top__DOT__pcr_sel;
        CData/*1:0*/ id_engine_top__DOT__seal_op;
        CData/*7:0*/ id_engine_top__DOT__tamper_sticky;
        CData/*0:0*/ id_engine_top__DOT__zeroize;
        CData/*0:0*/ id_engine_top__DOT__seal_ok;
        CData/*7:0*/ id_engine_top__DOT__quote_data;
        CData/*0:0*/ id_engine_top__DOT__quote_done;
        CData/*2:0*/ id_engine_top__DOT__u_cdi__DOT__state;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__h_start;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__h_done;
        CData/*2:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__state;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_start;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_busy;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_done;
        CData/*6:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round;
        CData/*0:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__active;
        CData/*1:0*/ id_engine_top__DOT__u_pcr__DOT__st;
        CData/*0:0*/ id_engine_top__DOT__u_pcr__DOT__h_start;
        CData/*0:0*/ id_engine_top__DOT__u_pcr__DOT__h_busy;
        CData/*0:0*/ id_engine_top__DOT__u_pcr__DOT__h_done;
        CData/*3:0*/ id_engine_top__DOT__u_pcr__DOT__sel_q;
        CData/*6:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__round;
        CData/*0:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__active;
        CData/*1:0*/ id_engine_top__DOT__u_seal__DOT__state;
        CData/*2:0*/ id_engine_top__DOT__u_q__DOT__state;
        CData/*0:0*/ id_engine_top__DOT__u_q__DOT__ec_start;
        CData/*0:0*/ id_engine_top__DOT__u_q__DOT__ec_done;
        CData/*2:0*/ id_engine_top__DOT__u_apb__DOT__wcnt;
        CData/*0:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__h_start;
        CData/*2:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__state;
        CData/*0:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_start;
        CData/*2:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__state;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w__v0;
        CData/*6:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__round;
        CData/*0:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__active;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w__v1;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h__v8;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h__v9;
        CData/*1:0*/ __Vdly__id_engine_top__DOT__u_pcr__DOT__st;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v0;
        CData/*2:0*/ __Vdly__id_engine_top__DOT__u_q__DOT__state;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v1;
        CData/*0:0*/ __Vdlyvset__id_engine_top__DOT__u_q__DOT__payload__v2;
        CData/*7:0*/ __Vdly__id_engine_top__DOT__tamper_sticky;
        CData/*2:0*/ __Vdly__id_engine_top__DOT__u_apb__DOT__wcnt;
    };
    struct {
        CData/*0:0*/ __Vdly__id_engine_top__DOT__u_q__DOT__ec_done;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __Vtrigprevexpr___TOP__presetn__0;
        CData/*0:0*/ __Vtrigprevexpr___TOP__puf_clk__0;
        CData/*0:0*/ __Vtrigprevexpr___TOP__pclk__0;
        CData/*0:0*/ __VactContinue;
        VL_IN16(paddr,11,0);
        SData/*15:0*/ id_engine_top__DOT__seal_policy;
        SData/*15:0*/ id_engine_top__DOT__quote_len;
        SData/*15:0*/ id_engine_top__DOT__u_q__DOT__plen;
        SData/*15:0*/ id_engine_top__DOT__u_q__DOT__idx;
        SData/*15:0*/ __Vdly__id_engine_top__DOT__u_q__DOT__plen;
        SData/*15:0*/ __Vdly__id_engine_top__DOT__u_q__DOT__idx;
        VL_IN(pwdata,31,0);
        VL_OUT(prdata,31,0);
        VL_INW(dma_data,127,0,4);
        VlWide<8>/*255:0*/ id_engine_top__DOT__uds;
        VlWide<8>/*255:0*/ id_engine_top__DOT__alias_key;
        VlWide<8>/*255:0*/ id_engine_top__DOT__pcr_r;
        VlWide<8>/*255:0*/ id_engine_top__DOT__cdi_out;
        VlWide<8>/*255:0*/ id_engine_top__DOT__unseal_out;
        VlWide<128>/*4095:0*/ id_engine_top__DOT__pcr_flat;
        VlWide<8>/*255:0*/ id_engine_top__DOT__pcr_wdata;
        VlWide<8>/*255:0*/ id_engine_top__DOT__seal_in;
        VlWide<4>/*127:0*/ id_engine_top__DOT__cdi_label;
        VlWide<16>/*511:0*/ id_engine_top__DOT__u_cdi__DOT__msg;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_cdi__DOT__h_mac;
        VlWide<16>/*511:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__kpad;
        VlWide<16>/*511:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__blk;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__inner;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__s_dig;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__d;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__f;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__g;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__hh;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t1;
        IData/*31:0*/ id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__t2;
        VlWide<16>/*511:0*/ id_engine_top__DOT__u_pcr__DOT__blk;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_pcr__DOT__h_dig;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__a;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__b;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__c;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__d;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__e;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__f;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__g;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__hh;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t1;
        IData/*31:0*/ id_engine_top__DOT__u_pcr__DOT__u_h__DOT__t2;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_seal__DOT__wrapped;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_seal__DOT__policy_digest;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_seal__DOT__expected_digest;
        VlWide<16>/*511:0*/ id_engine_top__DOT__u_q__DOT__ec_sig;
        VlWide<8>/*255:0*/ id_engine_top__DOT__u_q__DOT__payload_hash;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig1__0__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__1__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__2__x;
    };
    struct {
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__3__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__bsig0__4__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__5__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__6__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__rotr__7__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig1__28__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__29__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__30__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__31__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__bsig0__32__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__33__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__34__x;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__Vfuncout;
        IData/*31:0*/ __Vfunc_id_engine_top__DOT__u_pcr__DOT__u_h__DOT__rotr__35__x;
        VlWide<16>/*511:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__msg;
        VlWide<16>/*511:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__blk;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__a;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__b;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__c;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__d;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__e;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__f;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__g;
        IData/*31:0*/ __Vdly__id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__hh;
        VlWide<8>/*255:0*/ __Vdly__id_engine_top__DOT__u_seal__DOT__wrapped;
        VlWide<8>/*255:0*/ __Vdly__id_engine_top__DOT__seal_in;
        IData/*31:0*/ __VactIterCount;
        VlUnpacked<IData/*31:0*/, 64> id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__k;
        VlUnpacked<IData/*31:0*/, 8> id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__h;
        VlUnpacked<IData/*31:0*/, 64> id_engine_top__DOT__u_cdi__DOT__u_h__DOT__u_sha__DOT__w;
        VlUnpacked<VlWide<8>/*255:0*/, 16> id_engine_top__DOT__u_pcr__DOT__pcr;
        VlUnpacked<IData/*31:0*/, 64> id_engine_top__DOT__u_pcr__DOT__u_h__DOT__k;
        VlUnpacked<IData/*31:0*/, 8> id_engine_top__DOT__u_pcr__DOT__u_h__DOT__h;
        VlUnpacked<IData/*31:0*/, 64> id_engine_top__DOT__u_pcr__DOT__u_h__DOT__w;
        VlUnpacked<CData/*7:0*/, 512> id_engine_top__DOT__u_q__DOT__payload;
    };
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<3> __VactTriggered;
    VlTriggerVec<3> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vid_engine_top__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vid_engine_top___024root(Vid_engine_top__Syms* symsp, const char* v__name);
    ~Vid_engine_top___024root();
    VL_UNCOPYABLE(Vid_engine_top___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
