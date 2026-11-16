"use strict";
/* =====================================================================
   Si-32 core: a RISC-V (RV32I + MUL) processor described as NAND gates.
   Everything below the Circuit class is built from one primitive:
   c.nand(a, b). Flip-flops are clocked storage cells.
   ===================================================================== */

const ZERO = 0, ONE = 1;            // net 0 is tied low, net 1 is tied high

class Circuit {
  constructor() {
    this.A = []; this.B = []; this.O = []; this.G = [];   // gate inputs, output, block
    this.nNets = 2;
    this.blocks = ["Glue logic"]; this.cur = 0;
    this.dffQ = []; this.dffD = []; this.dffBlk = [];
    this.hash = new Map(); this.notOf = new Map();
  }
  setBlock(name) {
    let i = this.blocks.indexOf(name);
    if (i < 0) { i = this.blocks.length; this.blocks.push(name); }
    this.cur = i;
  }
  input() { return this.nNets++; }
  // The only logic primitive. Constant inputs and duplicate gates are folded
  // away, the way a synthesis tool would.
  nand(a, b) {
    if (a === ZERO || b === ZERO) return ONE;
    if (a === ONE && b === ONE) return ZERO;
    if (a === ONE) a = b;
    if (b === ONE) b = a;
    if (a === b && this.notOf.has(a)) return this.notOf.get(a);   // NOT(NOT x) = x
    if (a > b) { const t = a; a = b; b = t; }
    const key = a * 1048576 + b;
    const hit = this.hash.get(key);
    if (hit !== undefined) return hit;
    const o = this.nNets++;
    this.A.push(a); this.B.push(b); this.O.push(o); this.G.push(this.cur);
    this.hash.set(key, o);
    if (a === b) this.notOf.set(o, a);
    return o;
  }
  dff() {
    const q = this.nNets++;
    this.dffQ.push(q); this.dffD.push(-1); this.dffBlk.push(this.cur);
    return { q, idx: this.dffQ.length - 1 };
  }
  connect(ff, d) { this.dffD[ff.idx] = d; }
}

/* ---------- gates made of NAND ---------- */
function NOT(c, a) { return c.nand(a, a); }
function AND(c, a, b) { return NOT(c, c.nand(a, b)); }
function OR(c, a, b) { return c.nand(NOT(c, a), NOT(c, b)); }
function XOR(c, a, b) {
  const x = c.nand(a, b);
  return c.nand(c.nand(a, x), c.nand(b, x));
}
// 2-to-1 multiplexer: s ? b : a
function MUX(c, s, a, b, ns = NOT(c, s)) {
  return c.nand(c.nand(a, ns), c.nand(b, s));
}
function muxBus(c, s, A, B) { const ns = NOT(c, s); return A.map((a, i) => MUX(c, s, a, B[i], ns)); }
function andReduce(c, xs) { while (xs.length > 1) { const n = []; for (let i = 0; i < xs.length; i += 2) n.push(i + 1 < xs.length ? AND(c, xs[i], xs[i + 1]) : xs[i]); xs = n; } return xs[0]; }
function orReduce(c, xs) { while (xs.length > 1) { const n = []; for (let i = 0; i < xs.length; i += 2) n.push(i + 1 < xs.length ? OR(c, xs[i], xs[i + 1]) : xs[i]); xs = n; } return xs[0]; }
// true when the bits spell out `value`
function match(c, bits, value) { return andReduce(c, bits.map((b, i) => ((value >> i) & 1) ? b : NOT(c, b))); }

/* ---------- arithmetic ---------- */
function halfAdder(c, a, b) {
  const x = c.nand(a, b);
  return { s: c.nand(c.nand(a, x), c.nand(b, x)), co: NOT(c, x) };
}
// The classic nine-NAND full adder
function fullAdder(c, a, b, ci) {
  const t1 = c.nand(a, b);
  const t2 = c.nand(a, t1), t3 = c.nand(t1, b);
  const s1 = c.nand(t2, t3);                 // a XOR b
  const t4 = c.nand(s1, ci);
  const t5 = c.nand(s1, t4), t6 = c.nand(t4, ci);
  return { s: c.nand(t5, t6), co: c.nand(t1, t4) };
}
// Ripple-carry adder of any width; also reports the carry into the top bit (for overflow)
function rippleAdder(c, A, B, ci) {
  const S = []; let carry = ci, cMsb = ci;
  for (let i = 0; i < A.length; i++) {
    cMsb = carry;
    const r = fullAdder(c, A[i], B[i], carry);
    S.push(r.s); carry = r.co;
  }
  return { S, co: carry, cMsb };
}
// Logarithmic barrel shifter (right). Five stages shift by 1, 2, 4, 8, 16.
function shiftRight(c, X, amount, fill) {
  let cur = X;
  for (let k = 0; k < amount.length; k++) {
    const d = 1 << k, s = amount[k], ns = NOT(c, s);
    cur = cur.map((x, i) => MUX(c, s, x, i + d < cur.length ? cur[i + d] : fill, ns));
  }
  return cur;
}
// Array multiplier, low 32 bits of A*B: AND gates make partial products,
// one row of full adders per multiplier bit.
function multiplier(c, A, B) {
  let acc = A.map(a => AND(c, a, B[0]));
  for (let i = 1; i < B.length; i++) {
    const row = [];
    for (let j = 0; j < A.length - i; j++) row.push(AND(c, A[j], B[i]));
    acc = acc.slice(0, i).concat(rippleAdder(c, acc.slice(i), row, ZERO).S);
  }
  return acc;
}
// N-way bus multiplexer as a binary tree of 2-to-1 muxes
function muxN(c, buses, sel) {
  let cur = buses;
  for (let k = 0; k < sel.length; k++) {
    const s = sel[k], ns = NOT(c, s), next = [];
    for (let i = 0; i < cur.length; i += 2) next.push(cur[i].map((a, j) => MUX(c, s, a, cur[i + 1][j], ns)));
    cur = next;
  }
  return cur[0];
}
// 5-to-32 decoder with enable (one-hot write select for the register file)
function decoder5(c, sel, en) {
  const lo = [0, 1, 2, 3].map(v => match(c, sel.slice(0, 2), v));
  const hi = [0, 1, 2, 3, 4, 5, 6, 7].map(v => AND(c, match(c, sel.slice(2, 5), v), en));
  const out = [];
  for (let r = 0; r < 32; r++) out.push(AND(c, lo[r & 3], hi[r >> 2]));
  return out;
}
const fill = (n, x) => Array(n).fill(x);

/* =====================================================================
   The processor: single-cycle RV32I + MUL, 31 x 32-bit registers.
   ===================================================================== */
function buildCPU() {
  const c = new Circuit();

  // ---- state ----
  c.setBlock("Program counter");
  const pcFF = Array.from({ length: 32 }, () => c.dff());
  const pc = pcFF.map(f => f.q);
  c.setBlock("Register file");
  const regFF = [null], Q = [fill(32, ZERO)];                 // x0 is hard-wired to zero
  for (let r = 1; r < 32; r++) { const ffs = Array.from({ length: 32 }, () => c.dff()); regFF.push(ffs); Q.push(ffs.map(f => f.q)); }

  // ---- pins to the memory bus ----
  const instr = Array.from({ length: 32 }, () => c.input());   // instruction word at PC
  const memR = Array.from({ length: 32 }, () => c.input());    // data word at the load address

  // ---- decode ----
  c.setBlock("Instruction decoder");
  const op = instr.slice(0, 7), rd = instr.slice(7, 12), f3 = instr.slice(12, 15);
  const rs1 = instr.slice(15, 20), rs2 = instr.slice(20, 25);
  const isLUI = match(c, op, 0x37), isAUIPC = match(c, op, 0x17), isJAL = match(c, op, 0x6F);
  const isJALR = match(c, op, 0x67), isBR = match(c, op, 0x63), isLD = match(c, op, 0x03);
  const isST = match(c, op, 0x23), isOPI = match(c, op, 0x13), isOP = match(c, op, 0x33);
  const isSYS = match(c, op, 0x73);
  const isArith = OR(c, isOP, isOPI);
  const g = f3.map(b => AND(c, b, isArith));                  // ALU function (ADD unless arithmetic)
  const g000 = match(c, g, 0), isSLT = match(c, g, 2), isSLTU = match(c, g, 3);
  const isLeft = match(c, g, 1), isSRx = match(c, g, 5);
  const isMul = AND(c, AND(c, isOP, instr[25]), g000);
  const doSub = OR(c, OR(c, isBR, AND(c, AND(c, isOP, instr[30]), g000)), OR(c, isSLT, isSLTU));

  // ---- immediates (pure wiring, then a select) ----
  c.setBlock("Immediate generator");
  const sgn = instr[31];
  const immI = [...instr.slice(20, 32), ...fill(20, sgn)];
  const immS = [...instr.slice(7, 12), ...instr.slice(25, 32), ...fill(20, sgn)];
  const immB = [ZERO, ...instr.slice(8, 12), ...instr.slice(25, 31), instr[7], ...fill(20, sgn)];
  const immU = [...fill(12, ZERO), ...instr.slice(12, 32)];
  const immJ = [ZERO, ...instr.slice(21, 31), instr[20], ...instr.slice(12, 20), ...fill(12, sgn)];
  let imm = muxBus(c, isST, immI, immS);
  imm = muxBus(c, isBR, imm, immB);
  imm = muxBus(c, OR(c, isLUI, isAUIPC), imm, immU);
  imm = muxBus(c, isJAL, imm, immJ);

  // ---- register reads ----
  c.setBlock("Register file");
  const rv1 = muxN(c, Q, rs1), rv2 = muxN(c, Q, rs2);

  // ---- ALU operands ----
  c.setBlock("ALU operand select");
  const notLUI = NOT(c, isLUI);
  const opA = muxBus(c, isAUIPC, rv1, pc).map(a => AND(c, a, notLUI));
  const opB = muxBus(c, OR(c, isOP, isBR), imm, rv2);

  // ---- adder / comparator ----
  c.setBlock("Adder & comparator");
  const add = rippleAdder(c, opA, opB.map(b => XOR(c, b, doSub)), doSub);
  const S = add.S;
  const V = XOR(c, add.co, add.cMsb);
  const Z = NOT(c, orReduce(c, S));
  const lt = XOR(c, S[31], V), ltu = NOT(c, add.co);

  // ---- shifter ----
  c.setBlock("Barrel shifter");
  const arith = AND(c, instr[30], isSRx);
  const shIn = muxBus(c, isLeft, opA, [...opA].reverse());
  const shR = shiftRight(c, shIn, opB.slice(0, 5), AND(c, arith, shIn[31]));
  const shOut = muxBus(c, isLeft, shR, [...shR].reverse());

  // ---- logic unit ----
  c.setBlock("Logic unit");
  const andB = opA.map((a, i) => AND(c, a, opB[i]));
  const orB = opA.map((a, i) => OR(c, a, opB[i]));
  const xorB = opA.map((a, i) => XOR(c, a, opB[i]));

  // ---- multiplier ----
  c.setBlock("Multiplier");
  const prod = multiplier(c, opA, opB);

  // ---- result select ----
  c.setBlock("ALU result mux");
  const r0 = muxBus(c, isMul, S, prod);
  const aluOut = muxN(c, [r0, shOut, [lt, ...fill(31, ZERO)], [ltu, ...fill(31, ZERO)], xorB, shOut, orB, andB], g);

  // ---- load / store ----
  c.setBlock("Load/store unit");
  const o0 = S[0], o1 = S[1];
  const s1 = muxBus(c, o1, memR, [...memR.slice(16), ...fill(16, ZERO)]);
  const s2 = muxBus(c, o0, s1, [...s1.slice(8), ...fill(8, ZERO)]);
  const isB = match(c, f3.slice(0, 2), 0), isW = f3[1], isH = AND(c, f3[0], NOT(c, f3[1]));
  const ext = AND(c, NOT(c, f3[2]), MUX(c, isB, s2[15], s2[7]));
  const ld = s2.map((b, i) => i < 8 ? b : i < 16 ? MUX(c, isB, b, ext) : MUX(c, isW, ext, b));
  const wd = rv2.slice(0, 8);
  for (let k = 0; k < 8; k++) wd[8 + k] = MUX(c, isB, rv2[8 + k], rv2[k]);
  for (let k = 0; k < 8; k++) wd[16 + k] = MUX(c, isW, rv2[k], rv2[16 + k]);
  for (let k = 0; k < 8; k++) wd[24 + k] = MUX(c, isW, wd[8 + k], rv2[24 + k]);
  const n0 = NOT(c, o0), n1 = NOT(c, o1);
  const lane = (hiSel, b0) => OR(c, isW, OR(c, AND(c, isH, hiSel), AND(c, isB, AND(c, hiSel, b0))));
  const mask = [lane(n1, n0), lane(n1, o0), lane(o1, n0), lane(o1, o0)];

  // ---- next PC ----
  c.setBlock("PC & branch unit");
  const pc4 = [pc[0], pc[1]];
  let carry = ONE;
  for (let i = 2; i < 32; i++) { const h = halfAdder(c, pc[i], carry); pc4.push(h.s); carry = h.co; }
  const target = rippleAdder(c, pc, imm, ZERO).S;
  const base = MUX(c, f3[2], Z, MUX(c, f3[1], lt, ltu));
  const taken = AND(c, isBR, XOR(c, base, f3[0]));
  let next = muxBus(c, OR(c, taken, isJAL), pc4, target);
  next = muxBus(c, isJALR, next, [ZERO, ...S.slice(1)]);
  next = muxBus(c, isSYS, next, pc);                          // ECALL/EBREAK halt the clock
  pcFF.forEach((f, i) => c.connect(f, next[i]));

  // ---- write back ----
  c.setBlock("Writeback");
  const regWrite = orReduce(c, [isLUI, isAUIPC, isOP, isOPI, isLD, isJAL, isJALR]);
  let wb = muxBus(c, isLD, aluOut, ld);
  wb = muxBus(c, OR(c, isJAL, isJALR), wb, pc4);
  c.setBlock("Register file");
  const we = decoder5(c, rd, regWrite);
  for (let r = 1; r < 32; r++) {
    const D = muxBus(c, we[r], Q[r], wb);
    regFF[r].forEach((f, i) => c.connect(f, D[i]));
  }

  return { c, pc, Q, instr, memR, addr: S, wdata: wd, mask, we: isST, re: isLD, halt: isSYS };
}

/* =====================================================================
   Levelized simulator: gates were created in dependency order, so one
   pass evaluates the whole combinational network each clock cycle.
   ===================================================================== */
class GateCPU {
  constructor(bus) {
    this.bus = bus;
    this.net = buildCPU();
    const c = this.net.c;
    const n = c.A.length;
    // Gates downstream of the memory data pins must wait for the read.
    const late = new Uint8Array(c.nNets);
    this.net.memR.forEach(x => { late[x] = 1; });
    const pre = [], post = [];
    for (let i = 0; i < n; i++) {
      if (late[c.A[i]] || late[c.B[i]]) { late[c.O[i]] = 1; post.push(i); } else pre.push(i);
    }
    if (this.net.addr.some(x => late[x])) throw new Error("address depends on memory data");
    const order = pre.concat(post);
    this.split = pre.length; this.n = n;
    // Renumber nets: constants, then flip-flop outputs and pins, then gate outputs in
    // evaluation order, so each gate writes to the next slot in memory.
    const map = new Int32Array(c.nNets).fill(-1);
    map[0] = 0; map[1] = 1; let k = 2;
    for (const q of c.dffQ) map[q] = k++;
    for (const x of this.net.instr.concat(this.net.memR)) map[x] = k++;
    this.base = k;
    order.forEach((gi, i) => { map[c.O[gi]] = k + i; });
    const M = x => map[x];
    this.A = Int32Array.from(order, i => map[c.A[i]]);
    this.B = Int32Array.from(order, i => map[c.B[i]]);
    this.Gb = Uint8Array.from(order, i => c.G[i]);
    this.Q = Int32Array.from(c.dffQ, M); this.D = Int32Array.from(c.dffD, M);
    const N = this.net;
    for (const key of ["pc", "instr", "memR", "addr", "wdata", "mask"]) N[key] = N[key].map(M);
    N.Q = N.Q.map(bus => bus.map(M));
    for (const key of ["we", "re", "halt"]) N[key] = M(N[key]);
    this.nNets = k + n;
    this.tmp = new Uint8Array(this.Q.length);
    this.v = new Uint8Array(this.nNets);
    this.blocks = c.blocks;
    this.reset();
  }
  reset() { this.v.fill(0); this.v[1] = 1; this.halted = false; this.cycles = 0; }
  get(nets) { let x = 0; const v = this.v; for (let i = nets.length - 1; i >= 0; i--) x = (x << 1) | v[nets[i]]; return x >>> 0; }
  set(nets, x) { const v = this.v; for (let i = 0; i < nets.length; i++) v[nets[i]] = (x >>> i) & 1; }
  run(lo, hi) {
    const v = this.v, A = this.A, B = this.B, base = this.base;
    for (let i = lo; i < hi; i++) v[base + i] = 1 ^ (v[A[i]] & v[B[i]]);
  }
  get pcVal() { return this.get(this.net.pc); }
  reg(r) { return r === 0 ? 0 : this.get(this.net.Q[r]); }
  step() {
    if (this.halted) return false;
    const N = this.net, v = this.v, bus = this.bus;
    this.set(N.instr, bus.read32(this.get(N.pc)));
    this.run(0, this.split);
    const addr = this.get(N.addr);
    this.set(N.memR, v[N.re] ? bus.read32(addr) : 0);
    this.run(this.split, this.n);
    if (v[N.we]) bus.write(addr, this.get(N.wdata), this.get(N.mask));
    if (v[N.halt]) this.halted = true;
    // rising clock edge: every flip-flop captures its D input at once
    const Qa = this.Q, Da = this.D, t = this.tmp;
    for (let k = 0; k < Qa.length; k++) t[k] = v[Da[k]];
    for (let k = 0; k < Qa.length; k++) v[Qa[k]] = t[k];
    this.cycles++;
    return true;
  }
}

/* =====================================================================
   Memory bus (outside the chip): RAM, framebuffer and I/O ports
   ===================================================================== */
const MEM = { SIZE: 0x20000, FB: 0x10000, FBW: 64, FBH: 64, UART: 0x1F000, PRINT: 0x1F004, CYCLES: 0x1F008 };
class Bus {
  constructor(out) { this.mem = new Uint8Array(MEM.SIZE); this.out = out || (() => {}); this.cycles = () => 0; this.fbDirty = true; }
  load(bytes) { this.mem.fill(0); this.mem.set(bytes, 0); this.fbDirty = true; }
  read32(addr) {
    const a = (addr >>> 0) & ~3;
    if (a === MEM.CYCLES) return this.cycles() >>> 0;
    if (a + 3 >= MEM.SIZE) return 0;
    const m = this.mem;
    return (m[a] | (m[a + 1] << 8) | (m[a + 2] << 16) | (m[a + 3] << 24)) >>> 0;
  }
  write(addr, data, mask) {
    const a = (addr >>> 0) & ~3;
    if (a === MEM.UART) { for (let k = 0; k < 4; k++) if (mask & (1 << k)) { this.out(String.fromCharCode((data >>> (8 * k)) & 255)); break; } return; }
    if (a === MEM.PRINT) { if (mask === 15) this.out(String(data | 0)); return; }
    if (a + 3 >= MEM.SIZE || a >= 0x1F000) return;
    for (let k = 0; k < 4; k++) if (mask & (1 << k)) this.mem[a + k] = (data >>> (8 * k)) & 255;
    if (a >= MEM.FB && a < MEM.FB + MEM.FBW * MEM.FBH) this.fbDirty = true;
  }
}

/* =====================================================================
   Reference model: the same ISA written as ordinary software.
   The gate-level chip is checked against it, instruction by instruction.
   ===================================================================== */
class RefCPU {
  constructor(bus) { this.bus = bus; this.x = new Int32Array(32); this.reset(); }
  reset() { this.x.fill(0); this.pc = 0; this.halted = false; }
  step() {
    if (this.halted) return false;
    const bus = this.bus, x = this.x, ins = bus.read32(this.pc);
    const op = ins & 0x7F, rd = (ins >>> 7) & 31, f3 = (ins >>> 12) & 7, r1 = (ins >>> 15) & 31, r2 = (ins >>> 20) & 31, f7 = ins >>> 25;
    const a = x[r1], b = x[r2];
    const iI = ins >> 20;
    const iS = ((ins >> 25) << 5) | ((ins >>> 7) & 31);
    const iB = ((ins >> 31) << 12) | (((ins >>> 7) & 1) << 11) | (((ins >>> 25) & 63) << 5) | (((ins >>> 8) & 15) << 1);
    const iU = ins & 0xFFFFF000;
    const iJ = ((ins >> 31) << 20) | (ins & 0xFF000) | (((ins >>> 20) & 1) << 11) | (((ins >>> 21) & 1023) << 1);
    let next = (this.pc + 4) >>> 0, w = null;
    const alu = (f, p, q, alt) => {
      switch (f) {
        case 0: return alt ? (p - q) | 0 : (p + q) | 0;
        case 1: return p << (q & 31);
        case 2: return p < q ? 1 : 0;
        case 3: return (p >>> 0) < (q >>> 0) ? 1 : 0;
        case 4: return p ^ q;
        case 5: return alt ? p >> (q & 31) : (p >>> (q & 31)) | 0;
        case 6: return p | q;
        default: return p & q;
      }
    };
    switch (op) {
      case 0x37: w = iU | 0; break;
      case 0x17: w = (this.pc + iU) | 0; break;
      case 0x6F: w = next | 0; next = (this.pc + iJ) >>> 0; break;
      case 0x67: w = next | 0; next = ((a + iI) & ~1) >>> 0; break;
      case 0x63: {
        const c = [a === b, a !== b, false, false, a < b, a >= b, (a >>> 0) < (b >>> 0), (a >>> 0) >= (b >>> 0)][f3];
        if (c) next = (this.pc + iB) >>> 0; break;
      }
      case 0x03: {
        const ad = (a + iI) >>> 0, v = bus.read32(ad) >>> (8 * (ad & 3));
        const sz = f3 & 3, sx = !(f3 & 4);
        if (sz === 0) w = sx ? (v << 24) >> 24 : v & 255;
        else if (sz === 1) w = sx ? (v << 16) >> 16 : v & 0xFFFF;
        else w = v | 0;
        break;
      }
      case 0x23: {
        const ad = (a + iS) >>> 0, o = ad & 3, sz = f3 & 3;
        let d = b >>> 0, m = 15;
        if (sz === 0) { d = (b & 255) * 0x01010101; m = 1 << o; }
        else if (sz === 1) { d = ((b & 0xFFFF) * 0x10001) >>> 0; m = (o & 2) ? 12 : 3; }
        bus.write(ad, d >>> 0, m); break;
      }
      case 0x13: w = alu(f3, a, f3 === 1 || f3 === 5 ? iI & 31 : iI, f3 === 5 && (ins >>> 30) & 1); break;
      case 0x33:
        if (f7 === 1) { if (f3 !== 0) throw new Error("unsupported M instruction"); w = Math.imul(a, b); }
        else w = alu(f3, a, b, (ins >>> 30) & 1);
        break;
      case 0x73: this.halted = true; next = this.pc; break;
      default: break;
    }
    if (w !== null && rd) x[rd] = w;
    this.pc = next;
    return true;
  }
}

/* =====================================================================
   Assembler (RV32I + MUL, common pseudo-instructions)
   ===================================================================== */
const REGNAMES = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"];
function assemble(src) {
  const lines = src.split("\n");
  const errors = [], syms = Object.create(null), out = [];
  const lineOf = new Map();
  const R = { add: [0, 0], sub: [0, 32], sll: [1, 0], slt: [2, 0], sltu: [3, 0], xor: [4, 0], srl: [5, 0], sra: [5, 32], or: [6, 0], and: [7, 0], mul: [0, 1] };
  const I = { addi: 0, slti: 2, sltiu: 3, xori: 4, ori: 6, andi: 7 };
  const SH = { slli: [1, 0], srli: [5, 0], srai: [5, 32] };
  const LD = { lb: 0, lh: 1, lw: 2, lbu: 4, lhu: 5 }, ST = { sb: 0, sh: 1, sw: 2 };
  const BR = { beq: 0, bne: 1, blt: 4, bge: 5, bltu: 6, bgeu: 7 };
  const BRSWAP = { bgt: "blt", ble: "bge", bgtu: "bltu", bleu: "bgeu" };
  const BRZ = { beqz: ["beq", 0], bnez: ["bne", 0], bltz: ["blt", 0], bgez: ["bge", 0], blez: ["bge", 1], bgtz: ["blt", 1] };

  function stripComment(s) {
    let q = null;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (q) { if (ch === "\\") i++; else if (ch === q) q = null; continue; }
      if (ch === '"' || ch === "'") q = ch;
      else if (ch === "#" || (ch === "/" && s[i + 1] === "/")) return s.slice(0, i);
    }
    return s;
  }
  function splitArgs(s) {
    const r = []; let cur = "", q = null;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (q) { cur += ch; if (ch === "\\") { cur += s[++i] || ""; } else if (ch === q) q = null; continue; }
      if (ch === '"' || ch === "'") { q = ch; cur += ch; continue; }
      if (ch === ",") { r.push(cur.trim()); cur = ""; continue; }
      cur += ch;
    }
    if (cur.trim() !== "" || r.length) r.push(cur.trim());
    return r;
  }
  const unesc = s => s.replace(/\\(.)/g, (m, ch) => ({ n: "\n", t: "\t", "0": "\0", r: "\r" }[ch] ?? ch));
  function reg(t) {
    t = t.trim().toLowerCase();
    if (t === "fp") return 8;
    let i = REGNAMES.indexOf(t);
    if (i >= 0) return i;
    const m = /^x(\d+)$/.exec(t);
    if (m && +m[1] < 32) return +m[1];
    throw new Error(`unknown register "${t}"`);
  }
  function value(t, strict) {
    t = t.trim();
    if (!t) throw new Error("missing value");
    if (/^'(\\.|.)'$/.test(t)) return unesc(t.slice(1, -1)).charCodeAt(0);
    const parts = t.replace(/\s+/g, "").match(/[+-]?[^+-]+/g);
    if (!parts) throw new Error(`bad expression "${t}"`);
    let total = 0;
    for (let p of parts) {
      let sign = 1;
      if (p[0] === "-") { sign = -1; p = p.slice(1); } else if (p[0] === "+") p = p.slice(1);
      let v;
      if (/^0x[0-9a-f]+$/i.test(p)) v = parseInt(p.slice(2), 16);
      else if (/^0b[01]+$/i.test(p)) v = parseInt(p.slice(2), 2);
      else if (/^\d+$/.test(p)) v = parseInt(p, 10);
      else if (/^'(\\.|.)'$/.test(p)) v = unesc(p.slice(1, -1)).charCodeAt(0);
      else if (/^[A-Za-z_.][\w.]*$/.test(p)) {
        if (p in syms) v = syms[p];
        else if (strict) throw new Error(`undefined symbol "${p}"`);
        else return null;
      } else throw new Error(`bad value "${p}"`);
      total += sign * v;
    }
    return total;
  }
  let FINAL = false;
  const val = t => { const v = value(t, FINAL); return v === null ? 0 : v; };
  const fitsI = v => v >= -2048 && v <= 2047;
  function liParts(v) {
    v |= 0;
    if (fitsI(v)) return [null, v];
    const lo = ((v & 0xFFF) ^ 0x800) - 0x800;
    return [((v - lo) >>> 12) & 0xFFFFF, lo];
  }
  // encoders
  const encR = (f7, r2, r1, f3, rd, op) => ((f7 << 25) | (r2 << 20) | (r1 << 15) | (f3 << 12) | (rd << 7) | op) >>> 0;
  const encI = (imm, r1, f3, rd, op) => { if (!fitsI(imm)) throw new Error(`immediate ${imm} out of range (−2048…2047)`); return (((imm & 0xFFF) << 20) | (r1 << 15) | (f3 << 12) | (rd << 7) | op) >>> 0; };
  const encS = (imm, r2, r1, f3) => { if (!fitsI(imm)) throw new Error(`offset ${imm} out of range`); return ((((imm >> 5) & 127) << 25) | (r2 << 20) | (r1 << 15) | (f3 << 12) | ((imm & 31) << 7) | 0x23) >>> 0; };
  const encB = (off, r1, r2, f3) => {
    if (off & 1 || off < -4096 || off > 4094) throw new Error(`branch target out of range (${off} bytes)`);
    return ((((off >> 12) & 1) << 31) | (((off >> 5) & 63) << 25) | (r2 << 20) | (r1 << 15) | (f3 << 12) | (((off >> 1) & 15) << 8) | (((off >> 11) & 1) << 7) | 0x63) >>> 0;
  };
  const encU = (imm, rd, op) => (((imm & 0xFFFFF) << 12) | (rd << 7) | op) >>> 0;
  const encJ = (off, rd) => {
    if (off & 1 || off < -(1 << 20) || off >= (1 << 20)) throw new Error("jump target out of range");
    return ((((off >> 20) & 1) << 31) | (((off >> 1) & 1023) << 21) | (((off >> 11) & 1) << 20) | (((off >> 12) & 255) << 12) | (rd << 7) | 0x6F) >>> 0;
  };
  function memArg(t) {
    const m = /^(.*)\((\s*\w+\s*)\)$/.exec(t.trim());
    if (!m) throw new Error(`expected offset(register), got "${t}"`);
    return [m[1].trim() === "" ? 0 : val(m[1]), reg(m[2])];
  }

  // returns list of words (pass 2) or count (pass 1)
  function instr(mn, a, pc, final) {
    const need = n => { if (a.length !== n) throw new Error(`${mn} takes ${n} operand${n === 1 ? "" : "s"}`); };
    const tgt = t => { const v = value(t, final); return v === null ? 0 : v - pc; };
    if (mn in R) { need(3); const [f3, f7] = R[mn]; return [encR(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33)]; }
    if (mn in I) { need(3); return [encI(val(a[2]), reg(a[1]), I[mn], reg(a[0]), 0x13)]; }
    if (mn in SH) { need(3); const s = val(a[2]); if (s < 0 || s > 31) throw new Error("shift amount must be 0…31"); return [encI(s | (SH[mn][1] << 5), reg(a[1]), SH[mn][0], reg(a[0]), 0x13)]; }
    if (mn in LD) { need(2); const [o, r] = memArg(a[1]); return [encI(o, r, LD[mn], reg(a[0]), 0x03)]; }
    if (mn in ST) { need(2); const [o, r] = memArg(a[1]); return [encS(o, reg(a[0]), r, ST[mn])]; }
    if (mn in BR) { need(3); return [encB(final ? tgt(a[2]) : 0, reg(a[0]), reg(a[1]), BR[mn])]; }
    if (mn in BRSWAP) { need(3); return [encB(final ? tgt(a[2]) : 0, reg(a[1]), reg(a[0]), BR[BRSWAP[mn]])]; }
    if (mn in BRZ) { need(2); const [b, swap] = BRZ[mn]; const r = reg(a[0]); return [encB(final ? tgt(a[1]) : 0, swap ? 0 : r, swap ? r : 0, BR[b])]; }
    switch (mn) {
      case "lui": need(2); return [encU(val(a[1]), reg(a[0]), 0x37)];
      case "auipc": need(2); return [encU(val(a[1]), reg(a[0]), 0x17)];
      case "jal": if (a.length === 1) return [encJ(final ? tgt(a[0]) : 0, 1)]; need(2); return [encJ(final ? tgt(a[1]) : 0, reg(a[0]))];
      case "jalr":
        if (a.length === 1) return [encI(0, reg(a[0]), 0, 1, 0x67)];
        if (a.length === 2) { const [o, r] = memArg(a[1]); return [encI(o, r, 0, reg(a[0]), 0x67)]; }
        need(3); return [encI(val(a[2]), reg(a[1]), 0, reg(a[0]), 0x67)];
      case "j": need(1); return [encJ(final ? tgt(a[0]) : 0, 0)];
      case "call": need(1); return [encJ(final ? tgt(a[0]) : 0, 1)];
      case "jr": need(1); return [encI(0, reg(a[0]), 0, 0, 0x67)];
      case "ret": need(0); return [encI(0, 1, 0, 0, 0x67)];
      case "nop": need(0); return [encI(0, 0, 0, 0, 0x13)];
      case "mv": need(2); return [encI(0, reg(a[1]), 0, reg(a[0]), 0x13)];
      case "not": need(2); return [encI(-1, reg(a[1]), 4, reg(a[0]), 0x13)];
      case "neg": need(2); return [encR(32, reg(a[1]), 0, 0, reg(a[0]), 0x33)];
      case "seqz": need(2); return [encI(1, reg(a[1]), 3, reg(a[0]), 0x13)];
      case "snez": need(2); return [encR(0, reg(a[1]), 0, 3, reg(a[0]), 0x33)];
      case "li": {
        need(2);
        let v;
        try { v = value(a[1], true); } catch (e) { throw new Error(/undefined/.test(e.message) ? e.message + " (li needs a constant defined above it; use la for labels)" : e.message); }
        const rd = reg(a[0]);
        if (v < -2147483648 || v > 4294967295) throw new Error("value does not fit in 32 bits");
        const [hi, lo] = liParts(v);
        if (hi === null) return [encI(lo, 0, 0, rd, 0x13)];
        return lo ? [encU(hi, rd, 0x37), encI(lo, rd, 0, rd, 0x13)] : [encU(hi, rd, 0x37)];
      }
      case "la": {
        need(2);
        const v = value(a[1], final), rd = reg(a[0]);
        const [hi, lo] = liParts(v === null ? 0 : v);
        return [encU(hi === null ? 0 : hi, rd, 0x37), encI(lo, rd, 0, rd, 0x13)];
      }
      case "ecall": need(0); return [0x00000073];
      case "ebreak": need(0); return [0x00100073];
      case "fence": return [0x0FF0000F];
    }
    throw new Error(`unknown instruction "${mn}"`);
  }

  function passes(final) {
    FINAL = final;
    let pc = 0; const bytes = [];
    const emit8 = b => { bytes[pc] = b & 255; pc++; };
    for (let ln = 0; ln < lines.length; ln++) {
      let s = stripComment(lines[ln]).trim();
      try {
        let m;
        while ((m = /^([A-Za-z_.][\w.]*)\s*:/.exec(s))) {
          if (!final) { if (m[1] in syms) throw new Error(`label "${m[1]}" defined twice`); syms[m[1]] = pc; }
          s = s.slice(m[0].length).trim();
        }
        if (!s) continue;
        const sp = s.search(/\s/);
        const mn = (sp < 0 ? s : s.slice(0, sp)).toLowerCase();
        const rest = sp < 0 ? "" : s.slice(sp + 1).trim();
        const args = rest ? splitArgs(rest) : [];
        if (mn[0] === ".") {
          switch (mn) {
            case ".equ": case ".set": if (!final) syms[args[0]] = value(args[1], true); break;
            case ".text": case ".data": case ".globl": case ".global": case ".section": break;
            case ".word": args.forEach(t => { const v = final ? value(t, true) : 0; for (let k = 0; k < 4; k++) emit8(v >>> (8 * k)); }); break;
            case ".half": args.forEach(t => { const v = final ? value(t, true) : 0; emit8(v); emit8(v >>> 8); }); break;
            case ".byte": args.forEach(t => emit8(final ? value(t, true) : 0)); break;
            case ".string": case ".asciz": case ".ascii": {
              const mm = /^"((?:\\.|[^"\\])*)"$/.exec(rest);
              if (!mm) throw new Error("expected a quoted string");
              for (const ch of unesc(mm[1])) emit8(ch.charCodeAt(0));
              if (mn !== ".ascii") emit8(0);
              break;
            }
            case ".zero": case ".space": { const n = value(args[0], true); for (let k = 0; k < n; k++) emit8(0); break; }
            case ".align": { const n = 1 << value(args[0], true); while (pc % n) emit8(0); break; }
            default: throw new Error(`unknown directive "${mn}"`);
          }
          continue;
        }
        if (pc & 3) throw new Error("instruction is not word-aligned (add .align 2)");
        const words = instr(mn, args, pc, final);
        for (const w of words) { if (final) lineOf.set(pc, ln); for (let k = 0; k < 4; k++) emit8(w >>> (8 * k)); }
      } catch (e) {
        errors.push({ line: ln + 1, msg: e.message });
      }
      if (pc > 0xF000) { errors.push({ line: ln + 1, msg: "program is larger than 60 KiB" }); break; }
    }
    return bytes;
  }
  passes(false);
  if (errors.length) return { errors, bytes: null };
  const bytes = passes(true);
  const img = new Uint8Array(bytes.length);
  bytes.forEach((b, i) => { img[i] = b || 0; });
  return { errors, bytes: img, lineOf, syms, lines };
}

if (typeof module !== "undefined") module.exports = { Circuit, buildCPU, GateCPU, Bus, RefCPU, assemble, MEM, REGNAMES, fullAdder, rippleAdder, shiftRight, multiplier, muxN, NOT, AND, OR, XOR, MUX };

