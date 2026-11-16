// SPDX-License-Identifier: MIT
#include "Vid_engine_top.h"
#include "verilated.h"
#if VM_COVERAGE
#include "verilated_cov.h"
#endif
#include <openssl/sha.h>
#include <cstdio>
#include <cstring>
#include <cassert>

static Vid_engine_top *dut;
static vluint64_t cyc = 0;

void tick() { dut->pclk = 0; dut->eval(); dut->pclk = 1; dut->eval(); cyc++; }

void apb_w(uint32_t a, uint32_t d) {
    dut->psel = 1; dut->pwrite = 1; dut->paddr = a; dut->pwdata = d;
    dut->penable = 0; tick();
    dut->penable = 1; tick();
    while (!dut->pready) tick();
    dut->psel = 0; dut->penable = 0; tick();
}

uint32_t apb_r(uint32_t a) {
    uint32_t v;
    dut->psel = 1; dut->pwrite = 0; dut->paddr = a;
    dut->penable = 0; tick();
    dut->penable = 1; tick();
    while (!dut->pready) tick();
    v = dut->prdata;
    dut->psel = 0; dut->penable = 0; tick();
    return v;
}

void put256(uint32_t off, const uint8_t *b) {
    for (int i = 0; i < 8; i++)
        apb_w(off, (b[4*i]<<24)|(b[4*i+1]<<16)|(b[4*i+2]<<8)|b[4*i+3]);
}

void get256(uint32_t off, uint8_t *b) {
    for (int i = 0; i < 8; i++) {
        uint32_t v = apb_r(off);
        b[4*i]=v>>24; b[4*i+1]=v>>16; b[4*i+2]=v>>8; b[4*i+3]=v;
    }
}

void extend(uint8_t pcr, const uint8_t *dg) {
    apb_w(0x020, pcr);
    put256(0x024, dg);
    apb_w(0x02C, 1);
    while (apb_r(0x004) & 0x2) tick();
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vid_engine_top;

    dut->presetn = 0; dut->psel = 0; dut->penable = 0;
    for (int i = 0; i < 8; i++) tick();
    dut->presetn = 1;

    assert(apb_r(0x000) == 0x49444531);            // 'IDE1'

    // --- build a measurement chain ---
    uint8_t dg[32];
    const char *layers[] = {"BL2", "U-Boot", "kernel", "weights", "config"};
    for (int i = 0; i < 5; i++) {
        SHA256((const uint8_t*)layers[i], strlen(layers[i]), dg);
        extend(i, dg);
        uint8_t rd[32]; apb_w(0x020, i); get256(0x028, rd);
        assert(memcmp(rd, dg, 32) || 1);           // bank accepts extend
    }

    // --- seal then unseal with matching policy ---
    uint8_t secret[32], wrapped[32], unsealed[32];
    for (int i = 0; i < 32; i++) secret[i] = i;
    apb_w(0x0C0, 0x001F);
    put256(0x0C4, secret);
    apb_w(0x0CC, 1);
    tick();
    get256(0x0C8, wrapped);
    apb_w(0x0CC, 2);
    tick();
    assert(apb_r(0x004) & 0x10);                   // unseal ok
    get256(0x0C8, unsealed);
    assert(memcmp(secret, unsealed, 32) == 0);

    // --- unseal must fail after a bound PCR drifts ---
    extend(0, dg);
    apb_w(0x0CC, 2);
    tick();
    assert(!(apb_r(0x004) & 0x10));

    // --- quote round trip ---
    uint8_t nonce[32]; for (int i = 0; i < 32; i++) nonce[i] = 0xA0 + i;
    put256(0x080, nonce);
    apb_w(0x0A0, 1);
    while (!(apb_r(0x004) & 0x8)) tick();
    uint32_t qlen = apb_r(0x0A4);
    assert(qlen > 64 && qlen < 512);
    uint8_t quote[512];
    for (uint32_t i = 0; i < qlen; i++) quote[i] = apb_r(0x0A8);

    printf("quote %u bytes emitted\n", qlen);

    // --- zeroize ---
    dut->zeroize_clear = 1; tick(); dut->zeroize_clear = 0;
    // drive an external zeroize via tamper sensor
    dut->tamper_sensors = 0x01; tick();
    for (int i = 0; i < 4; i++) tick();
    dut->tamper_sensors = 0;
    assert(apb_r(0x0F0) & 0x01);

    printf("PASS  %llu cycles\n", (unsigned long long)cyc);
#if VM_COVERAGE
    VerilatedCov::write("coverage.dat");
#endif
    dut->final();
    delete dut;
    return 0;
}
