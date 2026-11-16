// SPDX-License-Identifier: MIT
// End-to-end integration test for id_engine_top (Verilator, simulation build).
// Every check compares RTL output with an independent OpenSSL computation;
// any mismatch aborts with a non-zero exit code.
#include "Vid_engine_top.h"
#include "verilated.h"
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static Vid_engine_top *dut;
static vluint64_t cyc = 0;
static int checks = 0;

#define CHECK(cond, ...) do { checks++; if (!(cond)) { \
    fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); \
    fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); exit(1); } } while (0)

// Must match SIM_UDS in rtl/sram_puf.v (public test value, sim only).
static const uint8_t SIM_UDS[32] = {
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
    16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31};

enum { ST_READY = 1, ST_PCR_BUSY = 2, ST_CDI_VALID = 4, ST_QUOTE_DONE = 8,
       ST_UNSEAL_OK = 16, ST_QUOTE_ERR = 32, ST_CDI_BUSY = 64, ST_UDS_VALID = 128 };

static void tick() {
    dut->pclk = 0; dut->puf_clk = 0; dut->eval();
    dut->pclk = 1; dut->puf_clk = 1; dut->eval();
    cyc++;
    if (cyc > 2000000) { fprintf(stderr, "FAIL simulation timeout\n"); exit(1); }
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

static void get256(uint32_t off, uint8_t *b) {
    for (int i = 0; i < 8; i++) {
        uint32_t v = apb_r(off);
        b[4*i]=v>>24; b[4*i+1]=v>>16; b[4*i+2]=v>>8; b[4*i+3]=v;
    }
}

static void hex(const char *tag, const uint8_t *b) {
    printf("  %-14s", tag);
    for (int i = 0; i < 32; i++) printf("%02x", b[i]);
    printf("\n");
}

static void wait_clear(uint32_t mask) {
    for (int i = 0; i < 100000 && (apb_r(0x004) & mask); i++) tick();
    CHECK(!(apb_r(0x004) & mask), "status bit 0x%x never cleared", mask);
}

static void read_pcr(int idx, uint8_t *out) { apb_w(0x020, idx); get256(0x028, out); }

static void extend(int pcr, const uint8_t *dg) {
    apb_w(0x020, pcr);
    put_words(0x024, dg, 8);
    apb_w(0x02C, 1);
    wait_clear(ST_PCR_BUSY);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vid_engine_top;
    dut->presetn = 0; dut->psel = 0; dut->penable = 0;
    dut->tamper_sensors = 0; dut->zeroize_clear = 0;
    dut->dma_valid = 0; dut->dma_last = 0; dut->se_miso = 0;
    for (int i = 0; i < 8; i++) tick();
    dut->presetn = 1;
    for (int i = 0; i < 4; i++) tick();

    // 1. identification and power-on state
    CHECK(apb_r(0x000) == 0x49444531, "ID register");
    uint32_t st = apb_r(0x004);
    CHECK(st & ST_READY, "ready bit");
    CHECK(st & ST_UDS_VALID, "UDS valid after reset (sim PUF)");
    CHECK(apb_r(0x0F0) == 0xFF, "power-on recorded in tamper sticky flags");
    printf("[1] ID, status and tamper power-on state OK\n");

    // 2. measured-boot chain: PCR[i] = SHA256(0^32 || SHA256(layer_i))
    const char *layers[] = {"BL2", "U-Boot", "kernel", "weights", "config"};
    uint8_t model[32];
    for (int i = 0; i < 5; i++) {
        uint8_t dg[32], cat[64], want[32], got[32];
        SHA256((const uint8_t *)layers[i], strlen(layers[i]), dg);
        read_pcr(i, cat);                 // current value (zero)
        memcpy(cat + 32, dg, 32);
        SHA256(cat, 64, want);
        extend(i, dg);
        read_pcr(i, got);
        CHECK(memcmp(got, want, 32) == 0, "PCR%d extend mismatch", i);
        if (i == 4) { memcpy(model, got, 32); hex("PCR4", got); }
    }
    // a second extend chains from the previous value
    {
        uint8_t dg[32], cat[64], want[32], got[32];
        SHA256((const uint8_t *)"tokenizer", 9, dg);
        read_pcr(3, cat); memcpy(cat + 32, dg, 32); SHA256(cat, 64, want);
        extend(3, dg); read_pcr(3, got);
        CHECK(memcmp(got, want, 32) == 0, "chained PCR3 extend mismatch");
    }
    printf("[2] 6 PCR extends match OpenSSL SHA-256(PCR || digest)\n");

    // 3. DICE root layer: CDI = HMAC(UDS, "DICE" || label || PCR4)
    const uint8_t label[16] = {'a','i','-','i','d','-','e','n','g','i','n','e','-','v','1',0};
    uint8_t cdi[32], want_cdi[32];
    put_words(0x060, label, 4);
    apb_w(0x020, 4);
    apb_w(0x06C, 1);
    wait_clear(ST_CDI_BUSY);
    CHECK(apb_r(0x004) & ST_CDI_VALID, "CDI valid");
    get256(0x070, cdi);
    {
        uint8_t m[52]; unsigned int len = 32;
        memcpy(m, "DICE", 4); memcpy(m + 4, label, 16); memcpy(m + 20, model, 32);
        HMAC(EVP_sha256(), SIM_UDS, 32, m, sizeof m, want_cdi, &len);
    }
    hex("CDI", cdi);
    CHECK(memcmp(cdi, want_cdi, 32) == 0, "CDI != OpenSSL HMAC-SHA256");
    printf("[3] DICE CDI matches OpenSSL HMAC-SHA256(UDS, DICE||label||PCR4)\n");

    // 4. seal / unseal bound to PCR0..4
    uint8_t secret[32], out[32], zero[32] = {0};
    for (int i = 0; i < 32; i++) secret[i] = (uint8_t)(0x40 + i);
    apb_w(0x0C0, 0x001F);
    put_words(0x0C4, secret, 8);
    apb_w(0x0CC, 1);
    apb_w(0x0CC, 2);
    CHECK(apb_r(0x004) & ST_UNSEAL_OK, "unseal with matching PCRs");
    get256(0x0C8, out);
    CHECK(memcmp(out, secret, 32) == 0, "unsealed secret mismatch");
    // changing the policy register after sealing must not widen release
    apb_w(0x0C0, 0x0000);
    apb_w(0x0CC, 2);
    CHECK(apb_r(0x004) & ST_UNSEAL_OK, "unseal uses policy recorded at seal time");
    // drift a bound PCR: release must be refused and output cleared
    { uint8_t dg[32]; SHA256((const uint8_t *)"evil", 4, dg); extend(0, dg); }
    apb_w(0x0CC, 2);
    CHECK(!(apb_r(0x004) & ST_UNSEAL_OK), "unseal must fail after PCR0 drift");
    get256(0x0C8, out);
    CHECK(memcmp(out, zero, 32) == 0, "no secret output after failed unseal");
    printf("[4] seal/unseal releases only under the sealed PCR policy\n");

    // 5. quote path is fail-closed until ECDSA is verified
    uint8_t nonce[32]; for (int i = 0; i < 32; i++) nonce[i] = (uint8_t)(0xA0 + i);
    put_words(0x080, nonce, 8);
    apb_w(0x0A0, 1);
    for (int i = 0; i < 2000; i++) tick();
    st = apb_r(0x004);
    CHECK(!(st & ST_QUOTE_DONE), "no quote may be issued");
    CHECK(st & ST_QUOTE_ERR, "quote error flag set (fail closed)");
    CHECK(apb_r(0x0A4) == 0, "quote length 0");
    printf("[5] quote request fails closed (no unsigned/forged evidence)\n");

    // 6. tamper -> zeroize wipes identity and sealed state
    dut->zeroize_clear = 1; tick(); dut->zeroize_clear = 0; tick();
    CHECK(apb_r(0x0F0) == 0x00, "tamper flags cleared");
    dut->tamper_sensors = 0x01; tick(); tick();
    dut->tamper_sensors = 0;
    for (int i = 0; i < 4; i++) tick();
    CHECK(apb_r(0x0F0) & 0x01, "shield tamper latched");
    st = apb_r(0x004);
    CHECK(!(st & ST_UDS_VALID), "UDS wiped by zeroize");
    CHECK(!(st & ST_CDI_VALID), "CDI invalidated by zeroize");
    get256(0x070, out);
    CHECK(memcmp(out, zero, 32) == 0, "CDI register cleared");
    apb_w(0x06C, 1);
    for (int i = 0; i < 2000; i++) tick();
    CHECK(!(apb_r(0x004) & ST_CDI_VALID), "no CDI derivation after zeroize");
    apb_w(0x0CC, 2);
    CHECK(!(apb_r(0x004) & ST_UNSEAL_OK), "sealed blob destroyed by zeroize");
    printf("[6] tamper zeroize wipes UDS, CDI and sealed blob\n");

    printf("PASS  %d checks, %llu cycles\n", checks, (unsigned long long)cyc);
    dut->final();
    delete dut;
    return 0;
}
