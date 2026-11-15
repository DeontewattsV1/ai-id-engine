// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Prototypes for DPI import and export functions.
//
// Verilator includes this file in all generated .cpp files that use DPI functions.
// Manually include this file where DPI .c import functions are declared to ensure
// the C functions match the expectations of the DPI imports.

#ifndef VERILATED_VID_ENGINE_TOP__DPI_H_
#define VERILATED_VID_ENGINE_TOP__DPI_H_  // guard

#include "svdpi.h"

#ifdef __cplusplus
extern "C" {
#endif


    // DPI IMPORTS
    // DPI import at rtl/ecdsa_p256_sign.v:12:34
    extern void c_ecdsa_sign(const svBitVecVal* priv, const svBitVecVal* hash, svBitVecVal* sig);

#ifdef __cplusplus
}
#endif

#endif  // guard
