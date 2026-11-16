// SPDX-License-Identifier: MIT
// Headless lockstep check: the NAND-gate Si-32 netlist against the
// independent software reference model. PC and all 31 registers are compared
// after every instruction, and all of memory plus the UART output when the
// program stops. Usage: node test/lockstep.test.js [--random N] [--seed S]
"use strict";
const path = require("path");
const S = require(path.join(__dirname, "..", "si32-core.js"));
const { PROGRAMS } = require(path.join(__dirname, "..", "programs.js"));

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? Number(args[i + 1]) : d; };
const N_RANDOM = opt("--random", 60), SEED = opt("--seed", 1), MAX_CYCLES = opt("--max-cycles", 3_000_000);

let rng = SEED >>> 0 || 1;
const rnd = n => { rng ^= rng << 13; rng >>>= 0; rng ^= rng >>> 17; rng ^= rng << 5; rng >>>= 0; return rng % n; };

function lockstep(name, bytes) {
  let outG = "", outR = "";
  const bg = new S.Bus(s => { outG += s; }), br = new S.Bus(s => { outR += s; });
  bg.load(bytes); br.load(bytes);
  const g = new S.GateCPU(bg), r = new S.RefCPU(br);
  bg.cycles = () => g.cycles; let rc = 0; br.cycles = () => rc;
  let n = 0;
  while (!g.halted || !r.halted) {
    if (n >= MAX_CYCLES) return { name, ok: true, n, halted: false, out: outG };
    const pc = g.pcVal;
    if (pc !== (r.pc >>> 0)) throw new Error(`${name}: PC mismatch at instr ${n}: gate ${pc.toString(16)} ref ${(r.pc >>> 0).toString(16)}`);
    g.step(); r.step(); rc++; n++;
    for (let k = 1; k < 32; k++) {
      if (g.reg(k) !== (r.x[k] >>> 0))
        throw new Error(`${name}: x${k} mismatch after instr ${n} (pc ${pc.toString(16)}): gate ${g.reg(k).toString(16)} ref ${(r.x[k] >>> 0).toString(16)}`);
    }
    if (g.halted !== r.halted) throw new Error(`${name}: halt mismatch after instr ${n}`);
  }
  for (let a = 0; a < bg.mem.length; a++)
    if (bg.mem[a] !== br.mem[a]) throw new Error(`${name}: memory mismatch at 0x${a.toString(16)}`);
  if (outG !== outR) throw new Error(`${name}: UART output differs`);
  return { name, ok: true, n, halted: true, out: outG };
}

// Random straight-line + forward-branch programs over the whole ISA the core
// implements (RV32I + MUL, aligned loads/stores into a scratch region).
function randomProgram(len) {
  const R = () => 1 + rnd(27);              // x1..x27; x28 = data base
  const imm12 = () => rnd(4096) - 2048;
  const L = ["  li x28, 0x8000"];
  for (let k = 1; k < 28; k++) L.push(`  li x${k}, ${(rnd(0x100000000) | 0)}`);
  const rr = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and", "mul"];
  const ri = ["addi", "slti", "sltiu", "xori", "ori", "andi"];
  const sh = ["slli", "srli", "srai"];
  const br = ["beq", "bne", "blt", "bge", "bltu", "bgeu"];
  let lbl = 0;
  for (let i = 0; i < len; i++) {
    const t = rnd(100);
    if (t < 35) L.push(`  ${rr[rnd(rr.length)]} x${R()}, x${R()}, x${R()}`);
    else if (t < 55) L.push(`  ${ri[rnd(ri.length)]} x${R()}, x${R()}, ${imm12()}`);
    else if (t < 63) L.push(`  ${sh[rnd(3)]} x${R()}, x${R()}, ${rnd(32)}`);
    else if (t < 67) L.push(`  lui x${R()}, ${rnd(1 << 20)}`);
    else if (t < 69) L.push(`  auipc x${R()}, ${rnd(1 << 20)}`);
    else if (t < 75) { const w = rnd(3); const off = (rnd(256) - 128) & ~((1 << w) - 1); L.push(`  ${["sb", "sh", "sw"][w]} x${R()}, ${off}(x28)`); }
    else if (t < 85) { const k = rnd(5); const w = [0, 1, 2, 0, 1][k]; const off = (rnd(256) - 128) & ~((1 << w) - 1); L.push(`  ${["lb", "lh", "lw", "lbu", "lhu"][k]} x${R()}, ${off}(x28)`); }
    else if (t < 95) { const l = `f${lbl++}`; L.push(`  ${br[rnd(br.length)]} x${R()}, x${R()}, ${l}`); for (let j = rnd(4); j > 0; j--) L.push(`  addi x${R()}, x${R()}, ${imm12()}`); L.push(`${l}:`); }
    else { const l = `j${lbl++}`; L.push(`  jal x${R()}, ${l}`); L.push(`  addi x${R()}, x0, 1`); L.push(`${l}:`); }
  }
  L.push("  ebreak");
  return L.join("\n");
}

function asm(name, src) {
  const a = S.assemble(src);
  if (a.errors.length) throw new Error(`${name}: assembler: ${JSON.stringify(a.errors.slice(0, 3))}`);
  return a.bytes;
}

module.exports = { randomProgram, lockstep };
if (require.main !== module) return;
const t0 = Date.now();
const net = S.buildCPU();
const gates = net.c.A.length, ffs = net.c.dffQ.length;
console.log(`netlist: ${gates} NAND gates, ${ffs} flip-flops, ${net.c.blocks.length} blocks`);
let total = 0;
for (const p of PROGRAMS) {
  const r = lockstep(p.id, asm(p.id, p.src));
  total += r.n;
  console.log(`demo ${p.id.padEnd(7)} ${String(r.n).padStart(9)} instructions  ${r.halted ? "halted (ebreak)" : `stopped at --max-cycles`}  match`);
}
let rtotal = 0;
for (let i = 0; i < N_RANDOM; i++) {
  const r = lockstep(`random#${i}`, asm(`random#${i}`, randomProgram(200 + rnd(400))));
  if (!r.halted) throw new Error(`random#${i} did not halt`);
  rtotal += r.n;
}
console.log(`random: ${N_RANDOM} programs (seed ${SEED}), ${rtotal} instructions, all match`);
console.log(`PASS lockstep: ${total + rtotal} instructions compared register-by-register (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
console.log(JSON.stringify({ gates, flip_flops: ffs, demo_instructions: total, random_programs: N_RANDOM, random_instructions: rtotal, seed: SEED }));
