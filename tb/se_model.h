// SPDX-License-Identifier: MIT
// Reference secure-element (SE) model: SPI mode-0 slave + ECDSA P-256.
//
// This is what the RTL's se_spi_master talks to in simulation. It models a
// discrete secure element (e.g. an ATECC608/SE050/OPTIGA-class part) whose
// device key is generated and kept inside the SE. Protocol: see
// rtl/se_spi_master.v. The signature is a standard ECDSA P-256 signature
// over the 32-byte digest the engine sends (OpenSSL ECDSA_do_sign, random k),
// so any ECDSA verifier can check it with the SE public key.
#pragma once
#define OPENSSL_SUPPRESS_DEPRECATED
#include <openssl/bn.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/obj_mac.h>
#include <openssl/pem.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <deque>
#include <vector>

struct SeModel {
    EC_KEY *key = nullptr;
    uint8_t pub[64];
    bool fail_mode = false;          // answer SYNC_ERR (models a locked SE)
    int busy_bytes = 3;              // bytes of 0x00 before SYNC
    int signs = 0;
    // SPI state
    bool prev_cs = true, prev_sck = false;
    int bitn = 0;
    uint8_t rx = 0;
    std::vector<uint8_t> in;
    std::deque<uint8_t> out;
    uint8_t cur = 0;
    int miso = 0;

    bool load_or_generate(const char *pem_path) {
        if (pem_path && *pem_path) {
            FILE *f = fopen(pem_path, "r");
            if (!f) { fprintf(stderr, "SE: cannot open %s\n", pem_path); return false; }
            key = PEM_read_ECPrivateKey(f, nullptr, nullptr, nullptr);
            fclose(f);
            if (!key) { fprintf(stderr, "SE: bad EC key in %s\n", pem_path); return false; }
        } else {
            key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
            if (!key || !EC_KEY_generate_key(key)) return false;
        }
        uint8_t buf[65];
        if (EC_POINT_point2oct(EC_KEY_get0_group(key), EC_KEY_get0_public_key(key),
                               POINT_CONVERSION_UNCOMPRESSED, buf, 65, nullptr) != 65)
            return false;
        memcpy(pub, buf + 1, 64);
        return true;
    }

    void respond() {
        uint8_t cmd = in[0];
        for (int i = 0; i < busy_bytes; i++) out.push_back(0x00);
        if (fail_mode || (cmd != 0x01 && cmd != 0x02)) { out.push_back(0xEE); return; }
        out.push_back(0xA5);
        if (cmd == 0x01) {
            for (int i = 0; i < 64; i++) out.push_back(pub[i]);
        } else {
            ECDSA_SIG *s = ECDSA_do_sign(in.data() + 1, 32, key);
            const BIGNUM *r, *sv;
            ECDSA_SIG_get0(s, &r, &sv);
            uint8_t rs[64];
            BN_bn2binpad(r, rs, 32);
            BN_bn2binpad(sv, rs + 32, 32);
            ECDSA_SIG_free(s);
            for (int i = 0; i < 64; i++) out.push_back(rs[i]);
            signs++;
        }
    }

    size_t expect_len() const {
        if (in.empty()) return 1;
        return in[0] == 0x02 ? 33 : 1;
    }

    // Call after every clock edge with the current pin values.
    void step(int cs_n, int sck, int mosi) {
        if (prev_cs && !cs_n) {               // select: new transaction
            in.clear(); out.clear(); bitn = 0; rx = 0; cur = 0x00; miso = 0;
        }
        if (!cs_n) {
            if (sck && !prev_sck) {            // rising: sample MOSI
                rx = (uint8_t)((rx << 1) | (mosi & 1));
                if (++bitn == 8) {
                    bitn = 0;
                    if (in.size() < expect_len()) {
                        in.push_back(rx);
                        if (in.size() == expect_len()) respond();
                    }
                    rx = 0;
                }
            } else if (!sck && prev_sck) {     // falling: drive next MISO bit
                if (bitn == 0) {
                    if (!out.empty()) { cur = out.front(); out.pop_front(); }
                    else cur = 0x00;
                }
                miso = (cur >> (7 - bitn)) & 1;
            }
        }
        prev_cs = cs_n; prev_sck = sck;
    }
};
