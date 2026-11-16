// SPDX-License-Identifier: MIT
#include <openssl/bn.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/obj_mac.h>
#include <svdpi.h>

#include <cstdint>
#include <cstring>

namespace {
void unpack(const svBitVecVal *src, std::uint8_t *dst, int bytes) {
    for (int i = 0; i < bytes; ++i) {
        const int word = bytes / 4 - 1 - i / 4;
        const int shift = (3 - i % 4) * 8;
        dst[i] = static_cast<std::uint8_t>((src[word] >> shift) & 0xff);
    }
}
}

extern "C" void c_ecdsa_sign(const svBitVecVal *priv,
                             const svBitVecVal *hash,
                             svBitVecVal *sig) {
    std::uint8_t private_bytes[32];
    std::uint8_t hash_bytes[32];
    std::uint8_t signature[64] = {};
    std::memset(sig, 0, 16 * sizeof(*sig));
    unpack(priv, private_bytes, sizeof(private_bytes));
    unpack(hash, hash_bytes, sizeof(hash_bytes));

    EC_KEY *key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
    BIGNUM *private_key = BN_bin2bn(private_bytes, sizeof(private_bytes), nullptr);
    EC_POINT *public_key = key ? EC_POINT_new(EC_KEY_get0_group(key)) : nullptr;
    ECDSA_SIG *result = nullptr;

    if (key && private_key && public_key && !BN_is_zero(private_key) &&
        EC_KEY_set_private_key(key, private_key) == 1 &&
        EC_POINT_mul(EC_KEY_get0_group(key), public_key, private_key, nullptr,
                     nullptr, nullptr) == 1 &&
        EC_KEY_set_public_key(key, public_key) == 1)
        result = ECDSA_do_sign(hash_bytes, sizeof(hash_bytes), key);

    if (result) {
        const BIGNUM *r;
        const BIGNUM *s;
        ECDSA_SIG_get0(result, &r, &s);
        if (BN_bn2binpad(r, signature, 32) == 32 &&
            BN_bn2binpad(s, signature + 32, 32) == 32) {
            for (int word = 0; word < 16; ++word) {
                const int offset = 60 - word * 4;
                sig[word] = (static_cast<svBitVecVal>(signature[offset]) << 24) |
                            (static_cast<svBitVecVal>(signature[offset + 1]) << 16) |
                            (static_cast<svBitVecVal>(signature[offset + 2]) << 8) |
                            static_cast<svBitVecVal>(signature[offset + 3]);
            }
        }
    }

    ECDSA_SIG_free(result);
    EC_POINT_free(public_key);
    BN_clear_free(private_key);
    EC_KEY_free(key);
    OPENSSL_cleanse(private_bytes, sizeof(private_bytes));
}
