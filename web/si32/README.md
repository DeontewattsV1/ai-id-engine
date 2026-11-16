# Si-32: a gate-level RISC-V core in the browser

`index.html` is a single, self-contained page by Deonte Watts. It builds a
32-bit RISC-V (RV32I + `mul`) processor out of two-input NAND gates and
clocked flip-flops (`buildCPU()` in `si32-core.js`), then simulates every
gate on every clock tick. Memory and I/O are a behavioural bus model.

Live page (GitHub Pages): https://deontewattsv1.github.io/ai-id-engine/si32/

## Tests (Node 18+, no dependencies)

    node web/si32/test/page.test.js       # inline copies == tested files; app parses
    node web/si32/test/lockstep.test.js   # gate model vs reference model
    node web/si32/test/mutation.test.js   # the comparison catches single-gate faults

Measured on the build box (Node 24):

| Item | Result |
|---|---|
| Netlist | 18,237 NAND gates, 1,024 flip-flops, 14 blocks |
| Demos (hello, primes, fact, mandel) | 382,402 instructions, all halt on `ebreak`, every register matches after every instruction, memory and UART identical |
| Random programs | 60 programs (seed 1), 27,724 instructions, all match |
| Fault sensitivity | 297 of 300 randomly chosen single-gate inversions detected |

The random programs cover every implemented instruction (ALU, shifts, `mul`,
`lui`/`auipc`, aligned loads and stores of every width, all six branches,
`jal`). They do not cover `jalr` with computed targets or self-modifying code.

## How it relates to the id-engine

Si-32 is a teaching and visualisation model. It is not part of the
id-engine RTL and it is not a soft-core host for it; see
`docs/SI32.md` for why and for what would be needed.

## Limits

Functional simulation in JavaScript, not a fabricated or synthesised chip.
Single-cycle, ripple-carry, no CSRs, interrupts, division, `mulh`, or
misaligned accesses. Flip-flops are modelled as clocked cells, each standing
for a six-NAND edge-triggered flip-flop.
