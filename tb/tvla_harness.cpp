// SPDX-License-Identifier: MIT
// Gate-level TVLA trace generator (Verilator) for the sky130-mapped
// Montgomery multipliers.
//
// The simulated DUT is build/tvla_<dut>.v. tools/tvla_netlist.py generates it
// from the sky130 netlist and adds an output vector pw_bits with one bit per
// net. Each cycle the harness XORs pw_bits with its previous settled value
// and weights every toggling net by its capacitance (pF, from the .lib). The
// per-cycle energy is E = 0.5 * C * Vdd^2 per toggle, in pJ. That
// Hamming-distance waveform is low-pass filtered (an RC/probe model, time
// constant tau cycles) and resampled to exactly `samples` points per trace.
//
// Zero-delay simulation: no glitches, no timing, no coupling, no supply
// noise unless --noise is set. These are simulated traces, not silicon.
//
// DUT_KIND: 0 = plain mont_mul, 1 = mont_mul_masked_v2, 2 = mont_mul_masked3
//
// usage: tvla_<dut> --mode fixed|null --n N --samples M --out PREFIX
//                   [--seed S] [--tau T] [--noise SIGMA_PJ] [--check K]
//                   [--fst FILE --fst-traces K] --caps FILE
//   --fst writes a waveform of the first K traces: FST if built with
//   --trace-fst, VCD if built with --trace (tools/fst_xcheck.py reads both).
//   fixed: fixed-vs-random. Group 0 gets a fixed (a, b), group 1 a uniform
//          random (a, b), randomly interleaved; masked DUTs get fresh shares
//          and fresh randomness on every trace in both groups.
//   null : random-vs-random control. Both groups uniform random; any
//          detected "leak" is a harness or statistics failure.
#include "Vtvla_dut.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
typedef VerilatedFstC TraceFile;
#elif VM_TRACE
#include "verilated_vcd_c.h"
typedef VerilatedVcdC TraceFile;
#endif
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#ifndef DUT_KIND
#define DUT_KIND 1
#endif

struct U256 { uint64_t w[4]; };   // little-endian limbs

static const U256 P256_N = {{0xf3b9cac2fc632551ULL, 0xbce6faada7179e84ULL,
                             0xffffffffffffffffULL, 0xffffffff00000000ULL}};
static const uint32_t N_N0 = 0xee00bc4fu;   // -n^-1 mod 2^32
// Fixed operands for group 0 (arbitrary values below n).
static const U256 A_FIX = {{0x0123456789abcdefULL, 0xfedcba9876543210ULL,
                            0x0f1e2d3c4b5a6978ULL, 0x5a5a5a5aa5a5a5a5ULL}};
static const U256 B_FIX = {{0x1111111122222222ULL, 0x3333333344444444ULL,
                            0x5555555566666666ULL, 0x7777777788888888ULL}};

static int cmp(const U256 &a, const U256 &b) {
    for (int i = 3; i >= 0; --i) {
        if (a.w[i] != b.w[i]) return a.w[i] < b.w[i] ? -1 : 1;
    }
    return 0;
}
static U256 sub(const U256 &a, const U256 &b) {
    U256 r; unsigned __int128 br = 0;
    for (int i = 0; i < 4; ++i) {
        unsigned __int128 d = (unsigned __int128)a.w[i] - b.w[i] - br;
        r.w[i] = (uint64_t)d; br = (d >> 64) & 1;
    }
    return r;
}
static U256 add(const U256 &a, const U256 &b, uint64_t *carry) {
    U256 r; unsigned __int128 c = 0;
    for (int i = 0; i < 4; ++i) {
        c += (unsigned __int128)a.w[i] + b.w[i];
        r.w[i] = (uint64_t)c; c >>= 64;
    }
    *carry = (uint64_t)c; return r;
}
static U256 msub(const U256 &a, const U256 &b, const U256 &m) {   // (a-b) mod m
    if (cmp(a, b) >= 0) return sub(a, b);
    uint64_t c; return add(sub(m, b), a, &c);
}
static U256 rnd_full(std::mt19937_64 &g) {
    U256 r; for (auto &x : r.w) x = g(); return r;
}
static U256 rnd_mod(std::mt19937_64 &g, const U256 &m) {
    for (;;) { U256 r = rnd_full(g); if (cmp(r, m) < 0) return r; }
}
template <class W> static void put(W &port, const U256 &v) {
    for (int i = 0; i < 8; ++i) port[i] = (uint32_t)(v.w[i / 2] >> (32 * (i % 2)));
}
template <class W> static U256 get(const W &port) {
    U256 v{};
    for (int i = 0; i < 8; ++i) v.w[i / 2] |= (uint64_t)port[i] << (32 * (i % 2));
    return v;
}
static void hex(FILE *f, const U256 &v) {
    fprintf(f, "%016llx%016llx%016llx%016llx ", (unsigned long long)v.w[3],
            (unsigned long long)v.w[2], (unsigned long long)v.w[1],
            (unsigned long long)v.w[0]);
}

struct Args {
    std::string mode = "fixed", out = "build/tvla/run", fst, caps;
    long n = 100; int samples = 4000; uint64_t seed = 1;
    double tau = 0.5, noise = 0.0; int check = 8, fst_traces = 0;
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Args A;
    for (int i = 1; i + 1 < argc; i += 2) {
        std::string k = argv[i], v = argv[i + 1];
        if (k == "--mode") A.mode = v;
        else if (k == "--n") A.n = atol(v.c_str());
        else if (k == "--samples") A.samples = atoi(v.c_str());
        else if (k == "--out") A.out = v;
        else if (k == "--seed") A.seed = strtoull(v.c_str(), 0, 0);
        else if (k == "--tau") A.tau = atof(v.c_str());
        else if (k == "--noise") A.noise = atof(v.c_str());
        else if (k == "--check") A.check = atoi(v.c_str());
        else if (k == "--fst") A.fst = v;
        else if (k == "--fst-traces") A.fst_traces = atoi(v.c_str());
        else if (k == "--caps") A.caps = v;
        else { fprintf(stderr, "unknown arg %s\n", k.c_str()); return 2; }
    }
    if (A.mode != "fixed" && A.mode != "null") { fprintf(stderr, "bad --mode\n"); return 2; }
    if (A.caps.empty()) { fprintf(stderr, "--caps FILE (float64 per pw_bits bit) required\n"); return 2; }

    // Per-net capacitance (pF) in pw_bits order, and Vdd.
    FILE *cf = fopen(A.caps.c_str(), "rb");
    if (!cf) { perror(A.caps.c_str()); return 2; }
    double vdd = 0; uint64_t nbits = 0;
    if (fread(&vdd, 8, 1, cf) != 1 || fread(&nbits, 8, 1, cf) != 1) return 2;
    std::vector<double> caps(nbits);
    if (fread(caps.data(), 8, nbits, cf) != nbits) { fprintf(stderr, "short caps\n"); return 2; }
    fclose(cf);

    auto *dut = new Vtvla_dut;
    const size_t NW = sizeof(dut->pw_bits) / sizeof(dut->pw_bits[0]);
    if ((nbits + 31) / 32 != NW) {
        fprintf(stderr, "caps file has %llu bits but pw_bits has %zu words\n",
                (unsigned long long)nbits, NW);
        return 2;
    }
    std::vector<uint32_t> prev(NW, 0);
    const double e_per_pf = 0.5 * vdd * vdd;   // pJ per pF per toggle
    auto energy = [&]() {
        double e = 0;
        for (size_t w = 0; w < NW; ++w) {
            uint32_t cur = dut->pw_bits[w], x = cur ^ prev[w];
            prev[w] = cur;
            while (x) {
                int b = __builtin_ctz(x); x &= x - 1;
                e += caps[w * 32 + b];
            }
        }
        return e * e_per_pf;
    };

#if VM_TRACE
    TraceFile *tfp = nullptr;
    if (!A.fst.empty() && A.fst_traces > 0) {
        Verilated::traceEverOn(true);
        tfp = new TraceFile; dut->trace(tfp, 99); tfp->open(A.fst.c_str());
    }
#else
    if (!A.fst.empty()) { fprintf(stderr, "built without --trace/--trace-fst\n"); return 2; }
#endif
    uint64_t simtime = 0;
    long fst_left = A.fst_traces;
    auto tick = [&](bool sample, double *e) {
        dut->clk = 1; dut->eval();
#if VM_TRACE
        if (tfp && fst_left > 0) tfp->dump(simtime);
#endif
        simtime += 5;
        if (sample) *e = energy();
        dut->clk = 0; dut->eval();
#if VM_TRACE
        if (tfp && fst_left > 0) tfp->dump(simtime);
#endif
        simtime += 5;
    };

    std::mt19937_64 g(A.seed);
    std::normal_distribution<double> noise(0.0, A.noise > 0 ? A.noise : 1.0);
    put(dut->modulus, P256_N); dut->n0prime = N_N0;
    dut->start = 0; dut->rst_n = 0; dut->clk = 0; dut->eval();
    double dummy;
    for (int i = 0; i < 4; ++i) tick(false, &dummy);
    dut->rst_n = 1; dut->eval();
    for (int i = 0; i < 2; ++i) tick(false, &dummy);
    energy();   // initialise prev[]

    std::string tr_path = A.out + ".f32", lb_path = A.out + ".lbl",
                ck_path = A.out + ".check.txt", cy_path = A.out + ".cycles.f64";
    FILE *ft = fopen(tr_path.c_str(), "wb"), *fl = fopen(lb_path.c_str(), "wb");
    FILE *fk = fopen(ck_path.c_str(), "w"), *fc = fopen(cy_path.c_str(), "wb");
    if (!ft || !fl || !fk || !fc) { perror("open outputs"); return 2; }

    std::vector<double> cyc;     // per-cycle energy of one trace
    std::vector<float> row(A.samples);
    long latency = -1, total = 2 * A.n, counts[2] = {0, 0};
    for (long t = 0; t < total; ++t) {
        // Balanced random interleaving: exactly n traces per group.
        long left0 = A.n - counts[0], left1 = A.n - counts[1];
        int grp = (std::uniform_int_distribution<long>(0, left0 + left1 - 1)(g) < left0) ? 0 : 1;
        counts[grp]++;
        U256 a, b;
        if (A.mode == "fixed" && grp == 0) { a = A_FIX; b = B_FIX; }
        else { a = rnd_mod(g, P256_N); b = rnd_mod(g, P256_N); }
#if DUT_KIND == 0
        put(dut->a, a); put(dut->b, b);
#elif DUT_KIND == 1
        U256 a0 = rnd_mod(g, P256_N), b0 = rnd_mod(g, P256_N);
        put(dut->a0, a0); put(dut->a1, msub(a, a0, P256_N));
        put(dut->b0, b0); put(dut->b1, msub(b, b0, P256_N));
        put(dut->r_p0, rnd_full(g)); put(dut->r_p1, rnd_full(g));
        put(dut->r_c, rnd_full(g)); put(dut->r_s, rnd_mod(g, P256_N));
#else
        U256 a0 = rnd_mod(g, P256_N), a1 = rnd_mod(g, P256_N);
        U256 b0 = rnd_mod(g, P256_N), b1 = rnd_mod(g, P256_N);
        put(dut->a0, a0); put(dut->a1, a1);
        put(dut->a2, msub(msub(a, a0, P256_N), a1, P256_N));
        put(dut->b0, b0); put(dut->b1, b1);
        put(dut->b2, msub(msub(b, b0, P256_N), b1, P256_N));
        put(dut->r_p0, rnd_full(g)); put(dut->r_p1, rnd_full(g));
        put(dut->r_c, rnd_full(g)); put(dut->r_s, rnd_mod(g, P256_N));
        put(dut->r_t, rnd_mod(g, P256_N));
#endif
        dut->start = 1; dut->eval();
        cyc.clear();
        double e;
        tick(true, &e); cyc.push_back(e);
        dut->start = 0; dut->eval();
        long guard = 0;
        while (!dut->done) {
            tick(true, &e); cyc.push_back(e);
            if (++guard > 100000) { fprintf(stderr, "DUT never finished\n"); return 3; }
        }
        tick(true, &e); cyc.push_back(e);   // one settle cycle after done
        if (latency < 0) latency = (long)cyc.size();
        else if ((long)cyc.size() != latency) {
            fprintf(stderr, "FAIL: data-dependent latency (%zu vs %ld cycles)\n",
                    cyc.size(), latency);
            return 4;
        }
#if VM_TRACE
        if (fst_left > 0) --fst_left;
#endif
        if (t < A.check) {
            fprintf(fk, "%d ", grp); hex(fk, a); hex(fk, b);
#if DUT_KIND == 0
            hex(fk, get(dut->r));
#elif DUT_KIND == 1
            hex(fk, get(dut->r0)); hex(fk, get(dut->r1));
#else
            hex(fk, get(dut->r0)); hex(fk, get(dut->r1)); hex(fk, get(dut->r2));
#endif
            fprintf(fk, "\n");
            fwrite(cyc.data(), sizeof(double), cyc.size(), fc);
        }
        // Low-pass (single-pole RC) + resample onto `samples` points.
        const double C = (double)cyc.size();
        for (int k = 0; k < A.samples; ++k) {
            double tk = (k + 0.5) * C / A.samples, s = 0;
            long c_hi = (long)std::floor(tk);
            for (long c = c_hi; c >= 0; --c) {
                double dt = tk - (double)c;
                if (A.tau <= 0) { s = cyc[c]; break; }
                if (dt > 8 * A.tau + 1) break;
                s += cyc[c] * std::exp(-dt / A.tau);
            }
            if (A.noise > 0) s += noise(g);
            row[k] = (float)s;
        }
        fwrite(row.data(), sizeof(float), row.size(), ft);
        uint8_t lb = (uint8_t)grp; fwrite(&lb, 1, 1, fl);
    }
    fclose(ft); fclose(fl); fclose(fk); fclose(fc);
#if VM_TRACE
    if (tfp) tfp->close();
#endif
    FILE *fm = fopen((A.out + ".meta.json").c_str(), "w");
    fprintf(fm, "{\"dut_kind\": %d, \"mode\": \"%s\", \"n_per_group\": %ld, "
                "\"samples\": %d, \"cycles\": %ld, \"tau\": %g, \"noise_pj\": %g, "
                "\"seed\": %llu, \"nets\": %llu, \"vdd\": %g, \"check\": %d}\n",
            DUT_KIND, A.mode.c_str(), A.n, A.samples, latency, A.tau, A.noise,
            (unsigned long long)A.seed, (unsigned long long)nbits, vdd,
            (int)std::min<long>(A.check, total));
    fclose(fm);
    printf("tvla_harness kind=%d mode=%s traces=%ld (%ld/group) cycles=%ld samples=%d nets=%llu\n",
           DUT_KIND, A.mode.c_str(), total, A.n, latency, A.samples,
           (unsigned long long)nbits);
    delete dut;
    return 0;
}
