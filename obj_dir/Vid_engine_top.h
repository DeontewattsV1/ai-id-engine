// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary model header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef VERILATED_VID_ENGINE_TOP_H_
#define VERILATED_VID_ENGINE_TOP_H_  // guard

#include "verilated.h"
#include "svdpi.h"

class Vid_engine_top__Syms;
class Vid_engine_top___024root;

// This class is the main interface to the Verilated model
class alignas(VL_CACHE_LINE_BYTES) Vid_engine_top VL_NOT_FINAL : public VerilatedModel {
  private:
    // Symbol table holding complete model state (owned by this class)
    Vid_engine_top__Syms* const vlSymsp;

  public:

    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(&pclk,0,0);
    VL_IN8(&presetn,0,0);
    VL_IN8(&puf_clk,0,0);
    VL_IN8(&psel,0,0);
    VL_IN8(&penable,0,0);
    VL_IN8(&pwrite,0,0);
    VL_OUT8(&pready,0,0);
    VL_IN8(&tamper_sensors,7,0);
    VL_IN8(&zeroize_clear,0,0);
    VL_IN8(&dma_valid,0,0);
    VL_IN8(&dma_last,0,0);
    VL_OUT8(&dma_ready,0,0);
    VL_OUT8(&se_cs_n,0,0);
    VL_OUT8(&se_sck,0,0);
    VL_OUT8(&se_mosi,0,0);
    VL_IN8(&se_miso,0,0);
    VL_IN16(&paddr,11,0);
    VL_IN(&pwdata,31,0);
    VL_OUT(&prdata,31,0);
    VL_INW(&dma_data,127,0,4);

    // CELLS
    // Public to allow access to /* verilator public */ items.
    // Otherwise the application code can consider these internals.

    // Root instance pointer to allow access to model internals,
    // including inlined /* verilator public_flat_* */ items.
    Vid_engine_top___024root* const rootp;

    // CONSTRUCTORS
    /// Construct the model; called by application code
    /// If contextp is null, then the model will use the default global context
    /// If name is "", then makes a wrapper with a
    /// single model invisible with respect to DPI scope names.
    explicit Vid_engine_top(VerilatedContext* contextp, const char* name = "TOP");
    explicit Vid_engine_top(const char* name = "TOP");
    /// Destroy the model; called (often implicitly) by application code
    virtual ~Vid_engine_top();
  private:
    VL_UNCOPYABLE(Vid_engine_top);  ///< Copying not allowed

  public:
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval() { eval_step(); }
    /// Evaluate when calling multiple units/models per time step.
    void eval_step();
    /// Evaluate at end of a timestep for tracing, when using eval_step().
    /// Application must call after all eval() and before time changes.
    void eval_end_step() {}
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    /// Are there scheduled events to handle?
    bool eventsPending();
    /// Returns time at next time slot. Aborts if !eventsPending()
    uint64_t nextTimeSlot();
    /// Trace signals in the model; called by application code
    void trace(VerilatedVcdC* tfp, int levels, int options = 0);
    /// Retrieve name of this model instance (as passed to constructor).
    const char* name() const;

    // Abstract methods from VerilatedModel
    const char* hierName() const override final;
    const char* modelName() const override final;
    unsigned threads() const override final;
    /// Prepare for cloning the model at the process level (e.g. fork in Linux)
    /// Release necessary resources. Called before cloning.
    void prepareClone() const;
    /// Re-init after cloning the model at the process level (e.g. fork in Linux)
    /// Re-allocate necessary resources. Called after cloning.
    void atClone() const;
};

#endif  // guard
