// SPDX-License-Identifier: MIT
// Shows the lockstep check is not vacuous: each run rewires ONE gate of the
// netlist (its output is inverted, i.e. the NAND becomes an AND) and counts how
// many of those single-gate faults the reference-model comparison catches on
// the "hello" and "fact" demos plus a random program from lockstep.test.js.
"use strict";
const path = require("path");
const S = require(path.join(__dirname, "..", "si32-core.js"));
const { PROGRAMS } = require(path.join(__dirname, "..", "programs.js"));
const N = Number(process.argv[2] || 300);
let rng = 12345;
const rnd = n => { rng ^= rng << 13; rng >>>= 0; rng ^= rng >>> 17; rng ^= rng << 5; rng >>>= 0; return rng % n; };
const { randomProgram } = require(path.join(__dirname, "lockstep.test.js"));
const progs = [PROGRAMS.find(p => p.id === "fact").src, PROGRAMS.find(p => p.id === "hello").src, randomProgram(600)]
  .map(src => S.assemble(src).bytes);

function caught(gi) {
  for (const bytes of progs) {
    const bg = new S.Bus(), br = new S.Bus(); bg.load(bytes); br.load(bytes);
    const g = new S.GateCPU(bg), r = new S.RefCPU(br);
    const v = g.v, A = g.A, B = g.B, base = g.base;
    g.run = (lo, hi) => {                      // fault: gate gi computes AND
      for (let i = lo; i < hi; i++) v[base + i] = (1 ^ (v[A[i]] & v[B[i]])) ^ (i === gi ? 1 : 0);
    };
    for (let n = 0; n < 20000 && !r.halted; n++) {
      if (g.pcVal !== (r.pc >>> 0) || g.halted) return true;
      g.step(); r.step();
      for (let k = 1; k < 32; k++) if (g.reg(k) !== (r.x[k] >>> 0)) return true;
    }
    for (let a = 0; a < bg.mem.length; a++) if (bg.mem[a] !== br.mem[a]) return true;
  }
  return false;
}
const probe = new S.GateCPU(new S.Bus());
let hit = 0, tried = 0;
for (let i = 0; i < N; i++) {
  let gi; do { gi = rnd(probe.n); } while (probe.A[gi] === probe.B[gi]);   // skip inverters (fault would be a no-op)
  tried++; if (caught(gi)) hit++;
}
console.log(`mutation: ${hit}/${tried} single-gate faults detected by lockstep on hello+fact+random`);
if (hit < tried * 0.5) { console.log("FAIL: lockstep check looks insensitive"); process.exit(1); }
console.log("PASS mutation sensitivity (any undetected fault sits in logic this workload does not exercise)");
