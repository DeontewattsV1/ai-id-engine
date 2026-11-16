// SPDX-License-Identifier: MIT
// ECDSA P-256 / SHA-256 known-answer test (RFC 6979 A.2.5, message "sample"
// and "test") through OpenSSL, the library the secure-element model
// (tb/se_model.h) signs with. It checks:
//   * public key derived from the RFC private key == RFC (Ux, Uy)
//   * deterministic signing (OpenSSL 3.2+ nonce-type=1) == RFC (r, s);
//     older OpenSSL skips only this step
//   * ECDSA_do_verify (the API family se_model.h uses) accepts it and
//     rejects a 1-bit-flipped digest
#include <openssl/bn.h>
#include <openssl/core_names.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/obj_mac.h>
#include <openssl/param_build.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <string.h>

#define FAIL(...) do { fprintf(stderr, "ECDSA KAT FAIL: " __VA_ARGS__); fputc('\n', stderr); return 1; } while (0)

static const char *X = "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721";
static const char *UX = "60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6";
static const char *UY = "7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299";
static const struct { const char *msg, *r, *s; } V[] = {
    {"sample", "EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716",
               "F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8"},
    {"test",   "F1ABB023518351CD71D881567B1EA663ED3EFCF6C5132B354F28D3B0B7D38367",
               "019F4113742A2B14BD25926B49C649155F267E60D3814B4C0CC84250E46F0083"},
};

int main(void) {
    BIGNUM *x = NULL, *ux = NULL, *uy = NULL;
    BN_hex2bn(&x, X); BN_hex2bn(&ux, UX); BN_hex2bn(&uy, UY);
    EC_GROUP *g = EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    EC_POINT *q = EC_POINT_new(g);
    if (!EC_POINT_mul(g, q, x, NULL, NULL, NULL)) FAIL("point mul");
    BIGNUM *qx = BN_new(), *qy = BN_new();
    EC_POINT_get_affine_coordinates(g, q, qx, qy, NULL);
    if (BN_cmp(qx, ux) || BN_cmp(qy, uy)) FAIL("public key mismatch");
    unsigned char pub[65];
    size_t publen = EC_POINT_point2oct(g, q, POINT_CONVERSION_UNCOMPRESSED, pub, sizeof pub, NULL);

    OSSL_PARAM_BLD *b = OSSL_PARAM_BLD_new();
    OSSL_PARAM_BLD_push_utf8_string(b, OSSL_PKEY_PARAM_GROUP_NAME, "prime256v1", 0);
    OSSL_PARAM_BLD_push_BN(b, OSSL_PKEY_PARAM_PRIV_KEY, x);
    OSSL_PARAM_BLD_push_octet_string(b, OSSL_PKEY_PARAM_PUB_KEY, pub, publen);
    OSSL_PARAM *params = OSSL_PARAM_BLD_to_param(b);
    EVP_PKEY_CTX *fc = EVP_PKEY_CTX_new_from_name(NULL, "EC", NULL);
    EVP_PKEY *pk = NULL;
    if (EVP_PKEY_fromdata_init(fc) <= 0 || EVP_PKEY_fromdata(fc, &pk, EVP_PKEY_KEYPAIR, params) <= 0)
        FAIL("fromdata");

    EC_KEY *ek = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
    EC_KEY_set_public_key(ek, q);
    int n = 0, n_det = 0;
    for (size_t i = 0; i < sizeof V / sizeof V[0]; ++i) {
        unsigned char dg[32];
        SHA256((const unsigned char *)V[i].msg, strlen(V[i].msg), dg);
        BIGNUM *wr = NULL, *ws = NULL; BN_hex2bn(&wr, V[i].r); BN_hex2bn(&ws, V[i].s);
        int det_checked = 0;
#if OPENSSL_VERSION_NUMBER >= 0x30200000L
        {
            EVP_PKEY_CTX *sc = EVP_PKEY_CTX_new(pk, NULL);
            unsigned int det = 1;
            OSSL_PARAM sp[] = { OSSL_PARAM_construct_uint(OSSL_SIGNATURE_PARAM_NONCE_TYPE, &det),
                                OSSL_PARAM_construct_utf8_string(OSSL_SIGNATURE_PARAM_DIGEST, "SHA256", 0),
                                OSSL_PARAM_construct_end() };
            unsigned char der[80]; size_t dl = sizeof der;
            if (EVP_PKEY_sign_init_ex(sc, sp) <= 0 || EVP_PKEY_sign(sc, der, &dl, dg, 32) <= 0)
                FAIL("deterministic sign");
            const unsigned char *p = der;
            ECDSA_SIG *ds = d2i_ECDSA_SIG(NULL, &p, (long)dl);
            const BIGNUM *r, *s; ECDSA_SIG_get0(ds, &r, &s);
            if (BN_cmp(r, wr) || BN_cmp(s, ws)) FAIL("%s: (r,s) != RFC 6979", V[i].msg);
            ECDSA_SIG_free(ds); EVP_PKEY_CTX_free(sc);
            det_checked = 1; n_det++;
        }
#endif
        (void)det_checked;
        ECDSA_SIG *sig = ECDSA_SIG_new();
        ECDSA_SIG_set0(sig, wr, ws);              /* takes ownership */
        if (ECDSA_do_verify(dg, 32, sig, ek) != 1) FAIL("%s: RFC signature rejected", V[i].msg);
        dg[31] ^= 1;
        if (ECDSA_do_verify(dg, 32, sig, ek) == 1) FAIL("%s: flipped digest accepted", V[i].msg);
        ECDSA_SIG_free(sig);
        n++;
    }
    printf("ECDSA P-256 KAT PASS %d RFC 6979 A.2.5 vectors (OpenSSL %s): pubkey, verify, tamper-reject; "
           "deterministic (r,s) reproduced for %d (needs OpenSSL >= 3.2)\n",
           n, OpenSSL_version(OPENSSL_VERSION_STRING), n_det);
    return 0;
}
