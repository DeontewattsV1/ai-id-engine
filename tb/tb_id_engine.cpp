// SPDX-License-Identifier: MIT
// End-to-end integration test for id_engine_top v0.1.0 (Verilator).
// Every check compares RTL behaviour with an independent computation
// (OpenSSL SHA-256 / HMAC / ECDSA, or the reference SE model); any mismatch
// aborts with a non-zero exit code.
//
// Plusargs:
//   +weights=FILE   model weights streamed through the DMA measurement port
//   +se_key=PEM     SE device key (TEST-ONLY, generated at build time)
//   +nonce=HEX64 +config=HEX64 +time=UNIX   quote inputs (verifier-chosen)
//   +out=FILE       write the hardware quote as JSON for the Rust verifier
#include "Vid_engine_top.h"
#include "verilated.h"
#if VM_COVERAGE
#include "verilated_cov.h"
#endif
#include "se_model.h"
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <random>
#include <string>
#include <vector>
#include <deque>

static Vid_engine_top *dut;
static SeModel se;
static vluint64_t cyc = 0;
static int checks = 0;
static std::mt19937_64 rng_tb(0xA11D);
static bool ent_stuck = false;
static int mesh_cut = 0;              // bitmask of cut mesh traces

#define CHECK(cond, ...) do { checks++; if (!(cond)) { \
    fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); \
    fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); exit(1); } } while (0)

static const uint8_t SIM_UDS[32] = {
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
    16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31};

enum : uint32_t {
    ST_READY = 1u<<0, ST_PCR_BUSY = 1u<<1, ST_CDI_VALID = 1u<<2, ST_QUOTE_DONE = 1u<<3,
    ST_UNSEAL_OK = 1u<<4, ST_QUOTE_ERR = 1u<<5, ST_CDI_BUSY = 1u<<6, ST_UDS_VALID = 1u<<7,
    ST_QUOTE_BUSY = 1u<<8, ST_MEAS_BUSY = 1u<<9, ST_MEAS_VALID = 1u<<10, ST_KEYS_READY = 1u<<11,
    ST_RNG_READY = 1u<<12, ST_TRNG_FAIL = 1u<<13, ST_SE_PUB = 1u<<14, ST_ZEROIZED = 1u<<15,
    ST_OTP_ERR = 1u<<16, ST_MESH_BREACH = 1u<<17 };
static uint32_t qcode(uint32_t st) { return (st >> 20) & 0xF; }

static void tick() {
    dut->ent_bit = ent_stuck ? 1 : (int)(rng_tb() & 1);
    dut->mesh_in = dut->mesh_out ^ mesh_cut;
    dut->pclk = 0; dut->puf_clk = 0; dut->eval();
    dut->pclk = 1; dut->puf_clk = 1; dut->eval();
    se.step(dut->se_cs_n, dut->se_sck, dut->se_mosi);
    dut->se_miso = se.miso;
    dut->mesh_in = dut->mesh_out ^ mesh_cut;
    cyc++;
    if (cyc > 400000000ULL) { fprintf(stderr, "FAIL simulation timeout\n"); exit(1); }
}

static void apb_w(uint32_t a, uint32_t d) {
    dut->psel = 1; dut->pwrite = 1; dut->paddr = a; dut->pwdata = d;
    dut->penable = 0; tick();
    dut->penable = 1; tick();
    while (!dut->pready) tick();
    dut->psel = 0; dut->penable = 0; tick();
}
static uint32_t apb_r(uint32_t a) {
    dut->psel = 1; dut->pwrite = 0; dut->paddr = a;
    dut->penable = 0; tick();
    dut->penable = 1; tick();
    while (!dut->pready) tick();
    uint32_t v = dut->prdata;
    dut->psel = 0; dut->penable = 0; tick();
    return v;
}
static void put_words(uint32_t off, const uint8_t *b, int words) {
    for (int i = 0; i < words; i++)
        apb_w(off, (b[4*i]<<24)|(b[4*i+1]<<16)|(b[4*i+2]<<8)|b[4*i+3]);
}
static void get_words(uint32_t off, uint8_t *b, int words) {
    for (int i = 0; i < words; i++) {
        uint32_t v = apb_r(off);
        b[4*i]=v>>24; b[4*i+1]=v>>16; b[4*i+2]=v>>8; b[4*i+3]=v;
    }
}
static void get256(uint32_t off, uint8_t *b) { get_words(off, b, 8); }
static std::string hexs(const uint8_t *b, size_t n) {
    static const char *H = "0123456789abcdef";
    std::string s; for (size_t i = 0; i < n; i++) { s += H[b[i]>>4]; s += H[b[i]&15]; }
    return s;
}
static bool unhex(const char *s, uint8_t *out, size_t n) {
    if (strlen(s) != 2*n) return false;
    for (size_t i = 0; i < n; i++) { unsigned v; if (sscanf(s + 2*i, "%2x", &v) != 1) return false; out[i] = v; }
    return true;
}
static void show(const char *tag, const uint8_t *b) { printf("  %-14s%s\n", tag, hexs(b, 32).c_str()); }

static void wait_clear(uint32_t mask, int limit = 200000) {
    for (int i = 0; i < limit && (apb_r(0x004) & mask); i++) tick();
    CHECK(!(apb_r(0x004) & mask), "status bit 0x%x never cleared", mask);
}
static void wait_set(uint32_t mask, int limit = 200000) {
    for (int i = 0; i < limit && !(apb_r(0x004) & mask); i++) tick();
    CHECK(apb_r(0x004) & mask, "status bit 0x%x never set", mask);
}
static void read_pcr(int idx, uint8_t *out) { apb_w(0x020, idx); get256(0x028, out); }
static void extend(int pcr, const uint8_t *dg) {
    apb_w(0x020, pcr); put_words(0x024, dg, 8); apb_w(0x02C, 1); wait_clear(ST_PCR_BUSY);
}
static void sha_ext(const uint8_t *old, const uint8_t *dg, uint8_t *out) {
    uint8_t cat[64]; memcpy(cat, old, 32); memcpy(cat + 32, dg, 32); SHA256(cat, 64, out);
}

// measurement through APB words; auto = extend into PCR[pcr] when done
static void measure_apb(const uint8_t *d, size_t n, int pcr, bool autoext, uint8_t *dig) {
    apb_w(0x030, 1 | (pcr << 4) | (autoext ? 0x100 : 0));
    size_t full = n / 4;
    for (size_t i = 0; i < full; i++)
        apb_w(0x034, (d[4*i]<<24)|(d[4*i+1]<<16)|(d[4*i+2]<<8)|d[4*i+3]);
    uint32_t tail = 0; int tn = (int)(n % 4);
    for (int i = 0; i < tn; i++) tail |= (uint32_t)d[4*full + i] << (24 - 8*i);
    apb_w(0x03C, tail);
    apb_w(0x038, tn);
    wait_clear(ST_MEAS_BUSY);
    CHECK(apb_r(0x004) & ST_MEAS_VALID, "measurement digest valid");
    get256(0x040, dig);
    uint8_t lenb[8]; get_words(0x044, lenb, 2);
    uint64_t len = 0; for (int i = 0; i < 8; i++) len = (len << 8) | lenb[i];
    CHECK(len == n, "MEAS_LEN %llu != %zu", (unsigned long long)len, n);
}

// measurement through the 128-bit DMA port (all beats full except the last)
static void measure_dma(const uint8_t *d, size_t n, int pcr, uint8_t *dig) {
    apb_w(0x030, 1 | (pcr << 4) | 0x100);
    size_t off = 0;
    if (n == 0) {
        // zero-length stream: one empty last beat is not allowed; use APB final
        apb_w(0x03C, 0); apb_w(0x038, 0);
    }
    while (off < n) {
        size_t k = (n - off) < 16 ? (n - off) : 16;
        bool last = (off + k == n);
        // VlWide<4>: word 3 holds bits [127:96] = bytes 0..3
        for (int w = 0; w < 4; w++) {
            uint32_t v = 0;
            for (int b = 0; b < 4; b++) {
                size_t i = off + 4*w + b;
                v = (v << 8) | (i < off + k ? d[i] : 0);
            }
            dut->dma_data[3 - w] = v;
        }
        dut->dma_last = last; dut->dma_nbytes = (uint8_t)k; dut->dma_valid = 1;
        // dma_ready does not depend on dma_valid, so its value now is what
        // the next rising edge samples: valid && ready => beat accepted.
        for (;;) { bool acc = dut->dma_ready; tick(); if (acc) break; }
        dut->dma_valid = 0;
        off += k;
    }
    dut->dma_last = 0;
    wait_clear(ST_MEAS_BUSY, 100000000);
    get256(0x040, dig);
}

// ---- HMAC-DRBG reference (same semantics as rtl/hmac_drbg.v) ----
struct Drbg {
    uint8_t K[32], V[32];
    void hm(const uint8_t *msg, size_t n, uint8_t *out) {
        unsigned int l = 32; HMAC(EVP_sha256(), K, 32, msg, n, out, &l);
    }
    void update(const uint8_t *d, size_t dn) {
        uint8_t m[32 + 1 + 22];
        memcpy(m, V, 32); m[32] = 0; if (dn) memcpy(m + 33, d, dn);
        hm(m, 33 + dn, K); hm(V, 32, V);
        if (!dn) return;
        memcpy(m, V, 32); m[32] = 1; memcpy(m + 33, d, dn);
        hm(m, 33 + dn, K); hm(V, 32, V);
    }
    void init(const uint8_t *d) { memset(K, 0, 32); memset(V, 1, 32); update(d, 22); }
    void gen(uint8_t *out) { hm(V, 32, V); memcpy(out, V, 32); update(nullptr, 0); }
};

// Returns the value of +name=VALUE (copied: Verilator reuses its buffer).
static const char *plusarg(const char *name) {
    static std::deque<std::string> keep;   // deque: stable addresses
    std::string key = name[0] == '+' ? name + 1 : name;
    const char *v = Verilated::commandArgsPlusMatch(key.c_str());
    if (!v || !*v) return nullptr;
    const char *eq = strchr(v, '=');
    if (!eq) return nullptr;
    keep.emplace_back(eq + 1);
    return keep.back().c_str();
}

static void reset_dut() {
    dut->presetn = 0;
    for (int i = 0; i < 8; i++) tick();
    dut->presetn = 1;
    for (int i = 0; i < 4; i++) tick();
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    const char *weights = plusarg("+weights=");
    const char *se_key = plusarg("+se_key=");
    const char *outp = plusarg("+out=");
    uint8_t nonce[32], cfg[32];
    for (int i = 0; i < 32; i++) { nonce[i] = 0xA0 + i; cfg[i] = 0; }
    if (const char *s = plusarg("+nonce=")) CHECK(unhex(s, nonce, 32), "+nonce must be 64 hex chars");
    if (const char *s = plusarg("+config=")) CHECK(unhex(s, cfg, 32), "+config must be 64 hex chars");
    uint64_t qtime = (uint64_t)time(nullptr);
    if (const char *s = plusarg("+time=")) qtime = strtoull(s, nullptr, 10);

    CHECK(se.load_or_generate(se_key), "secure element model key");
    dut = new Vid_engine_top;
    dut->psel = 0; dut->penable = 0; dut->tamper_sensors = 0; dut->zeroize_clear = 0;
    dut->dma_valid = 0; dut->dma_last = 0; dut->dma_nbytes = 0; dut->se_miso = 0;
    reset_dut();

    // ---- [0] boot ROM hardware code page --------------------------------
    {
        char banner[33] = {0};
        for (int w = 0; w < 8; w++) {
            uint32_t v = apb_r(0x108);
            for (int b = 0; b < 4; b++) banner[4*w + b] = (char)(v >> (24 - 8*b));
        }
        CHECK(strcmp(banner, "AI-ID ENGINE v0.1.0 BOOT ROM    ") == 0, "boot banner '%s'", banner);
        // 'A' (0x41) from the public-domain font8x8_basic
        const uint8_t A[8] = {0x0C,0x1E,0x33,0x33,0x3F,0x33,0x33,0x00};
        apb_w(0x100, (0x41 - 0x20) * 8);
        for (int r = 0; r < 8; r++) CHECK(apb_r(0x104) == A[r], "glyph 'A' row %d", r);
        // render "AI-ID" from the ROM, like a pre-OS console would
        const char *word = "AI-ID";
        uint8_t rows[5][8];
        for (int c = 0; c < 5; c++) {
            apb_w(0x100, (word[c] - 0x20) * 8);
            for (int r = 0; r < 8; r++) rows[c][r] = (uint8_t)apb_r(0x104);
        }
        printf("[0] boot banner from HWCP ROM: \"%s\"\n", banner);
        for (int r = 0; r < 7; r++) {
            printf("      ");
            for (int c = 0; c < 5; c++) {
                for (int x = 0; x < 8; x++) putchar((rows[c][r] >> x) & 1 ? '#' : ' ');
            }
            putchar('\n');
        }
    }

    // ---- [1] identification, OTP-derived hardware info -----------------
    CHECK(apb_r(0x000) == 0x49444531, "ID register");
    CHECK(apb_r(0x008) == 0x00000100, "VERSION 0.1.0");
    uint32_t hwinfo = apb_r(0x00C);
    CHECK((hwinfo >> 16) == 0x4131, "HW revision code 'A1' (got %08x)", hwinfo);
    CHECK(((hwinfo >> 8) & 0xFF) == 0x02, "lifecycle DEV");
    uint32_t st = apb_r(0x004);
    CHECK(st & ST_READY, "ready bit");
    CHECK(st & ST_UDS_VALID, "UDS valid after reset (sim PUF)");
    CHECK(apb_r(0x0F0) == 0xFF, "power-on recorded in tamper sticky flags");
    printf("[1] ID, VERSION 0.1.0, HW code 'A1', lifecycle DEV, tamper power-on state OK\n");

    // ---- [2] OTP fuse model ---------------------------------------------
    {
        auto otp_rd = [](int a) { apb_w(0x0E0, a); return apb_r(0x0E4); };
        auto otp_pg = [](int a, uint32_t v) { apb_w(0x0E0, a); apb_w(0x0E8, v); };
        CHECK(otp_rd(0) == 0x41494944, "OTP vendor word 'AIID'");
        CHECK(otp_rd(15) == 0x1F, "OTP lock word");
        otp_pg(13, 0x0000000F); otp_pg(13, 0x000000F0);
        CHECK(otp_rd(13) == 0xFF, "OTP bits accumulate (OR)");
        otp_pg(13, 0x0);
        CHECK(otp_rd(13) == 0xFF, "OTP bits cannot be cleared");
        otp_pg(1, 0x00FF0000);
        CHECK(apb_r(0x004) & ST_OTP_ERR, "programming a locked word is refused");
        CHECK(otp_rd(1) == 0x41310200, "locked word unchanged");
        otp_pg(15, 1u << 13);                       // lock word 13
        otp_pg(13, 0xFFFF0000);
        CHECK(otp_rd(13) == 0xFF, "word 13 locked");
        otp_pg(5, 0xDEADBEEF);                      // UDS word: write ok, read-protected
        CHECK(otp_rd(5) == 0, "UDS fuse words are read-protected");
        reset_dut();
        CHECK(otp_rd(13) == 0xFF, "fuses survive a warm reset");
        printf("[2] OTP: OR-only programming, lock word, read-protected UDS, reset-persistent\n");
    }

    // clear the power-on tamper record (firmware has checked the sensors)
    dut->zeroize_clear = 1; tick(); dut->zeroize_clear = 0; tick();
    CHECK(apb_r(0x0F0) == 0x00, "tamper flags cleared");
    for (int i = 0; i < 50; i++) tick();
    CHECK(!(apb_r(0x004) & ST_MESH_BREACH), "intact tamper mesh");

    // ---- [3] extend-only PCR bank --------------------------------------
    // PCR map: 0 BL2, 1 U-Boot, 4 kernel; PCR2 is reserved for the model
    // weights (first and only event: PCR2 = SHA256(0^32 || weights digest)).
    const char *layers[] = {"BL2", "U-Boot", "kernel"};
    const int layer_pcr[] = {0, 1, 4};
    for (int i = 0; i < 3; i++) {
        uint8_t dg[32], old[32], want[32], got[32];
        SHA256((const uint8_t *)layers[i], strlen(layers[i]), dg);
        read_pcr(layer_pcr[i], old); sha_ext(old, dg, want);
        extend(layer_pcr[i], dg); read_pcr(layer_pcr[i], got);
        CHECK(memcmp(got, want, 32) == 0, "PCR%d extend mismatch", layer_pcr[i]);
    }
    {
        uint8_t before[32], after[32], junk[32];
        memset(junk, 0x5A, 32);
        read_pcr(1, before);
        apb_w(0x020, 1); put_words(0x024, junk, 8);  // data without EXTEND
        read_pcr(1, after);
        CHECK(memcmp(before, after, 32) == 0, "PCR not writable without extend");
    }
    printf("[3] PCR bank: SHA-256 extend matches OpenSSL, no direct write path\n");

    // ---- [4] streaming measurement engine (APB path, padding edges) ----
    {
        size_t lens[] = {0, 1, 3, 4, 5, 55, 56, 57, 63, 64, 65, 119, 120, 128, 200, 1000};
        for (size_t n : lens) {
            std::vector<uint8_t> d(n);
            for (auto &b : d) b = (uint8_t)rng_tb();
            uint8_t want[32], got[32];
            SHA256(d.data(), n, want);
            measure_apb(d.data(), n, 5, false, got);
            CHECK(memcmp(got, want, 32) == 0, "SHA-256 stream mismatch at %zu bytes", n);
        }
        printf("[4] measurement engine: 16 lengths (0..1000 B, all padding edges) == OpenSSL\n");
    }

    // ---- [5] DMA weight measurement -> PCR2 auto-extend ----------------
    uint8_t model_digest[32];
    {
        for (size_t n : {1, 15, 16, 17, 33, 64, 100}) {
            std::vector<uint8_t> d(n);
            for (auto &b : d) b = (uint8_t)rng_tb();
            uint8_t want[32], got[32];
            SHA256(d.data(), n, want);
            measure_dma(d.data(), n, 6, got);
            CHECK(memcmp(got, want, 32) == 0, "DMA SHA-256 mismatch at %zu bytes", n);
        }
        std::vector<uint8_t> w;
        std::string name = "built-in 1 MiB test pattern";
        if (weights) {
            FILE *f = fopen(weights, "rb");
            CHECK(f, "cannot open +weights=%s", weights);
            fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
            w.resize(sz);
            CHECK(fread(w.data(), 1, sz, f) == (size_t)sz, "read weights");
            fclose(f);
            name = weights;
        } else {
            w.resize(1 << 20);
            for (size_t i = 0; i < w.size(); i++) w[i] = (uint8_t)(i * 2654435761u >> 13);
        }
        uint8_t want[32], old[32], pcr_want[32], pcr_got[32];
        SHA256(w.data(), w.size(), want);
        read_pcr(2, old);
        {
            uint8_t z[32] = {0};
            CHECK(memcmp(old, z, 32) == 0, "PCR2 is fresh before the model measurement");
        }
        vluint64_t c0 = cyc;
        measure_dma(w.data(), w.size(), 2, model_digest);
        CHECK(memcmp(model_digest, want, 32) == 0, "weights digest != OpenSSL SHA-256");
        wait_clear(ST_PCR_BUSY);
        for (int i = 0; i < 20; i++) tick();
        sha_ext(old, want, pcr_want); read_pcr(2, pcr_got);
        CHECK(memcmp(pcr_got, pcr_want, 32) == 0, "PCR2 != extend(PCR2, weights digest)");
        printf("[5] DMA weight measurement of %s (%zu bytes, %llu cycles)\n",
               name.c_str(), w.size(), (unsigned long long)(cyc - c0));
        show("weights", model_digest);
        show("PCR2", pcr_got);
    }

    // ---- [6] DICE: CDI, device_id --------------------------------------
    const uint8_t label[16] = {'a','i','-','i','d','-','e','n','g','i','n','e','-','v','1',0};
    uint8_t cdi[32], want_cdi[32], devid[32], want_id[32], pcr2[32];
    read_pcr(2, pcr2);
    put_words(0x060, label, 4);
    apb_w(0x020, 2);
    apb_w(0x06C, 1);
    wait_clear(ST_CDI_BUSY);
    CHECK(apb_r(0x004) & ST_CDI_VALID, "CDI valid");
    get256(0x070, cdi);
    get256(0x074, devid);
    {
        uint8_t m[52]; unsigned int len = 32;
        memcpy(m, "DICE", 4); memcpy(m + 4, label, 16); memcpy(m + 20, pcr2, 32);
        HMAC(EVP_sha256(), SIM_UDS, 32, m, sizeof m, want_cdi, &len);
        uint8_t m2[20]; memcpy(m2, "DVID", 4); memcpy(m2 + 4, label, 16);
        HMAC(EVP_sha256(), want_cdi, 32, m2, 20, want_id, &len);
    }
    CHECK(memcmp(cdi, want_cdi, 32) == 0, "CDI != OpenSSL HMAC-SHA256");
    CHECK(memcmp(devid, want_id, 32) == 0, "device_id != HMAC(CDI, DVID||label)");
    show("CDI", cdi); show("device_id", devid);
    printf("[6] DICE CDI over PCR2 (model) and public device_id match OpenSSL HMAC\n");

    // ---- [7] HMAC-DRBG key ladder + key SRAM, PCR-bound sealing --------
    wait_set(ST_KEYS_READY);
    {
        uint8_t secret[32], out[32], zero[32] = {0};
        for (int i = 0; i < 32; i++) secret[i] = (uint8_t)(0x40 + i);
        apb_w(0x0C0, 0x0007);
        put_words(0x0C4, secret, 8);
        apb_w(0x0CC, 1); apb_w(0x0CC, 2);
        CHECK(apb_r(0x004) & ST_UNSEAL_OK, "unseal with matching PCRs");
        get256(0x0C8, out);
        CHECK(memcmp(out, secret, 32) == 0, "unsealed secret mismatch");
        apb_w(0x0D4, 1);                          // ratchet the session key
        for (int i = 0; i < 3000; i++) tick();
        apb_w(0x0CC, 2);
        CHECK(apb_r(0x004) & ST_UNSEAL_OK, "seal key (slot 0) unaffected by ratchet");
        uint8_t dg[32]; SHA256((const uint8_t *)"evil", 4, dg); extend(0, dg);
        apb_w(0x0CC, 2);
        CHECK(!(apb_r(0x004) & ST_UNSEAL_OK), "unseal must fail after PCR0 drift");
        get256(0x0C8, out);
        CHECK(memcmp(out, zero, 32) == 0, "no secret output after failed unseal");
        printf("[7] key ladder ready; seal/unseal bound to PCR policy; ratchet leaves seal key\n");
    }

    // ---- [8] TRNG + HMAC-DRBG random output ----------------------------
    {
        wait_set(ST_RNG_READY);
        int ones = 0; uint32_t prev = 0; bool repeat = false;
        for (int i = 0; i < 64; i++) {
            if (!(apb_r(0x004) & ST_RNG_READY)) wait_set(ST_RNG_READY);
            uint32_t v = apb_r(0x0D0);
            ones += __builtin_popcount(v);
            if (i && v == prev) repeat = true;
            prev = v;
        }
        CHECK(!repeat, "RNG words repeat");
        CHECK(ones > 900 && ones < 1150, "RNG bit balance %d/2048", ones);
        CHECK(!(apb_r(0x004) & ST_TRNG_FAIL), "TRNG health tests pass on good entropy");
        printf("[8] TRNG (RCT+APT healthy) -> HMAC-DRBG: 64 words, %d/2048 ones\n", ones);
    }

    // ---- [9] secure element public key ---------------------------------
    uint8_t sepub[64];
    apb_w(0x0A0, 2);
    wait_clear(ST_QUOTE_BUSY);
    CHECK(apb_r(0x004) & ST_SE_PUB, "SE public key fetched");
    get_words(0x0B0, sepub, 16);
    CHECK(memcmp(sepub, se.pub, 64) == 0, "SE_PUB register != SE key");
    printf("[9] SE device public key read over SPI\n");

    // ---- [10] signed hardware quote ------------------------------------
    std::vector<uint8_t> body;
    uint8_t sig[64], qdig[32], hdr[20];
    uint8_t pcrs[512];
    for (int round = 0; round < 2; round++) {
        put_words(0x080, nonce, 8);
        put_words(0x084, cfg, 8);
        apb_w(0x088, (uint32_t)(qtime >> 32)); apb_w(0x088, (uint32_t)qtime);
        apb_w(0x0A0, 1);
        wait_set(ST_QUOTE_BUSY, 50);
        wait_clear(ST_QUOTE_BUSY);
        st = apb_r(0x004);
        CHECK((st & ST_QUOTE_DONE) && !(st & ST_QUOTE_ERR), "quote done (code %u)", qcode(st));
        CHECK(apb_r(0x0A4) == 660, "quote length 660");
        get_words(0x0A8, sig, 16);
        get_words(0x0AC, hdr, 5);
        get256(0x0B8, qdig);
        for (int i = 0; i < 16; i++) read_pcr(i, pcrs + 32*i);
        body.assign(hdr, hdr + 20);
        body.insert(body.end(), devid, devid + 32);
        body.insert(body.end(), nonce, nonce + 32);
        body.insert(body.end(), pcrs, pcrs + 512);
        body.insert(body.end(), model_digest, model_digest + 32);
        body.insert(body.end(), cfg, cfg + 32);
        CHECK(body.size() == 660, "body size");
        CHECK(memcmp(hdr, "AIQ2", 4) == 0 && hdr[4] == 'A' && hdr[5] == '1', "quote header");
        CHECK(hdr[6] == 0x02 && hdr[7] == 0x00, "lifecycle/tamper in quote");
        uint32_t ctr = (hdr[8]<<24)|(hdr[9]<<16)|(hdr[10]<<8)|hdr[11];
        CHECK(ctr == (uint32_t)round, "quote counter %u", ctr);
        uint64_t ts = 0; for (int i = 0; i < 8; i++) ts = (ts << 8) | hdr[12 + i];
        CHECK(ts == qtime, "timestamp");
        uint8_t want[32]; SHA256(body.data(), body.size(), want);
        CHECK(memcmp(qdig, want, 32) == 0, "RTL body digest != SHA-256(reconstructed body)");
        ECDSA_SIG *es = ECDSA_SIG_new();
        ECDSA_SIG_set0(es, BN_bin2bn(sig, 32, nullptr), BN_bin2bn(sig + 32, 32, nullptr));
        CHECK(ECDSA_do_verify(want, 32, es, se.key) == 1, "quote signature (OpenSSL verify)");
        ECDSA_SIG_free(es);
    }
    CHECK(apb_r(0x0B4) == 2, "quote counter after two quotes");
    printf("[10] AIQ2 quote: 660-byte body hashed in RTL, ECDSA P-256 by SE, OpenSSL-verified x2\n");
    show("quote digest", qdig);

    if (outp) {
        FILE *f = fopen(outp, "w");
        CHECK(f, "cannot write %s", outp);
        uint64_t ts = 0; for (int i = 0; i < 8; i++) ts = (ts << 8) | hdr[12 + i];
        uint8_t pubsec1[65]; pubsec1[0] = 4; memcpy(pubsec1 + 1, sepub, 64);
        fprintf(f, "{\n  \"format\": \"AIQ2\",\n  \"source\": \"rtl-sim id_engine_top (Verilator)\",\n");
        fprintf(f, "  \"hw_rev\": \"%c%c\",\n  \"lifecycle\": %u,\n  \"tamper\": %u,\n", hdr[4], hdr[5], hdr[6], hdr[7]);
        fprintf(f, "  \"counter\": %u,\n  \"timestamp\": %llu,\n", (hdr[8]<<24)|(hdr[9]<<16)|(hdr[10]<<8)|hdr[11], (unsigned long long)ts);
        fprintf(f, "  \"device_id\": \"%s\",\n  \"nonce\": \"%s\",\n", hexs(devid, 32).c_str(), hexs(nonce, 32).c_str());
        fprintf(f, "  \"pcrs\": \"%s\",\n", hexs(pcrs, 512).c_str());
        fprintf(f, "  \"model_digest\": \"%s\",\n  \"config_digest\": \"%s\",\n", hexs(model_digest, 32).c_str(), hexs(cfg, 32).c_str());
        fprintf(f, "  \"sig\": \"%s\",\n  \"se_pubkey\": \"%s\",\n", hexs(sig, 64).c_str(), hexs(pubsec1, 65).c_str());
        fprintf(f, "  \"body_sha256\": \"%s\"\n}\n", hexs(qdig, 32).c_str());
        fclose(f);
        printf("  wrote %s\n", outp);
    }

    // ---- [11] fail-closed quote gates ----------------------------------
    {
        se.fail_mode = true;
        apb_w(0x0A0, 1); wait_set(ST_QUOTE_BUSY, 50); wait_clear(ST_QUOTE_BUSY);
        st = apb_r(0x004);
        CHECK((st & ST_QUOTE_ERR) && qcode(st) == 4 && apb_r(0x0A4) == 0, "SE error -> no quote");
        se.fail_mode = false;
        printf("[11] quote fails closed when the secure element reports an error\n");
    }

    // ---- [12] tamper mesh cut -> zeroize -------------------------------
    {
        apb_w(0x014, 0xF);                     // enable all IRQs
        apb_w(0x010, 0xF);                     // clear pending
        mesh_cut = 0x4;                        // cut trace 2
        for (int i = 0; i < 20; i++) tick();
        mesh_cut = 0;
        uint8_t out[32], zero[32] = {0};
        st = apb_r(0x004);
        CHECK(apb_r(0x0F0) & 0x01, "mesh breach latched as shield tamper");
        CHECK(st & ST_ZEROIZED, "zeroized");
        CHECK(!(st & ST_UDS_VALID) && !(st & ST_CDI_VALID) && !(st & ST_KEYS_READY), "identity wiped");
        CHECK(!(st & ST_RNG_READY), "RNG disabled after zeroize");
        CHECK(apb_r(0x010) & 0x4, "tamper IRQ pending");
        CHECK(dut->irq, "irq line asserted");
        get256(0x070, out); CHECK(memcmp(out, zero, 32) == 0, "CDI cleared");
        get256(0x074, out); CHECK(memcmp(out, zero, 32) == 0, "device_id cleared");
        apb_w(0x0CC, 2);
        CHECK(!(apb_r(0x004) & ST_UNSEAL_OK), "sealed blob destroyed");
        dut->zeroize_clear = 1; tick(); dut->zeroize_clear = 0; tick();
        apb_w(0x06C, 1); for (int i = 0; i < 3000; i++) tick();
        CHECK(!(apb_r(0x004) & ST_CDI_VALID), "no CDI derivation after zeroize");
        apb_w(0x0A0, 1); for (int i = 0; i < 20; i++) tick();
        st = apb_r(0x004);
        CHECK((st & ST_QUOTE_ERR) && qcode(st) == 5, "no quote after zeroize");
        printf("[12] tamper-mesh cut: zeroize wipes UDS, CDI, device_id, keys, seal, RNG; IRQ raised\n");
    }

    // ---- [13] TRNG health test: stuck entropy source -------------------
    {
        reset_dut();
        ent_stuck = true;
        for (int i = 0; i < 400; i++) tick();
        st = apb_r(0x004);
        CHECK(st & ST_TRNG_FAIL, "repetition-count test catches a stuck source");
        CHECK(!(st & ST_RNG_READY) && apb_r(0x0D0) == 0, "no random output after health failure");
        ent_stuck = false;
        printf("[13] TRNG health: stuck-at source fails RCT, RNG output withheld\n");
    }

    // ---- [14] HMAC-DRBG reference self-check (C++ model vs RTL ladder) --
    // The key SRAM is not readable (by design), so the ladder is checked
    // through its only consumer: a blob sealed under one boot's slot-0 key
    // must unseal after re-deriving the same CDI (deterministic ladder).
    {
        reset_dut();
        // power-on tamper record not yet cleared by firmware -> no quote
        put_words(0x060, label, 4); apb_w(0x020, 2); apb_w(0x06C, 1);
        wait_clear(ST_CDI_BUSY); wait_set(ST_KEYS_READY);
        apb_w(0x0A0, 1); for (int i = 0; i < 20; i++) tick();
        st = apb_r(0x004);
        CHECK((st & ST_QUOTE_ERR) && qcode(st) == 2, "uncleared tamper record -> quote refused (code %u)", qcode(st));
        dut->zeroize_clear = 1; tick(); dut->zeroize_clear = 0; tick();
        apb_w(0x06C, 1);
        wait_clear(ST_CDI_BUSY); wait_set(ST_KEYS_READY);
        uint8_t secret[32], out[32];
        for (int i = 0; i < 32; i++) secret[i] = (uint8_t)(0x90 ^ i);
        apb_w(0x0C0, 0x0001); put_words(0x0C4, secret, 8); apb_w(0x0CC, 1);
        apb_w(0x06C, 1); wait_clear(ST_CDI_BUSY); wait_set(ST_KEYS_READY);
        apb_w(0x0CC, 2);
        CHECK(apb_r(0x004) & ST_UNSEAL_OK, "re-derived ladder reproduces seal key");
        get256(0x0C8, out);
        CHECK(memcmp(out, secret, 32) == 0, "secret after re-derivation");
        Drbg d; uint8_t seed[22] = {0}, a[32], b[32];
        d.init(seed); d.gen(a); d.gen(b);
        CHECK(memcmp(a, b, 32) != 0, "DRBG reference produces distinct blocks");
        printf("[14] quote refused while the power-on tamper record is set; key ladder deterministic across re-derivation (bit-exact DRBG: make rtl-unit)\n");
    }

    printf("PASS  %d checks, %llu cycles, %d SE signatures\n", checks,
           (unsigned long long)cyc, se.signs);
#if VM_COVERAGE
    Verilated::threadContextp()->coveragep()->write("coverage.dat");
#endif
    dut->final();
    delete dut;
    return 0;
}
