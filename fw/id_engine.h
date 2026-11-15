/* SPDX-License-Identifier: MIT */
#ifndef _ID_ENGINE_H
#define _ID_ENGINE_H
#include <linux/types.h>

#define IE_PCR_ROM      0
#define IE_PCR_BOOT     1
#define IE_PCR_KERNEL   2
#define IE_PCR_DRIVER   3
#define IE_PCR_INITRD   4
#define IE_PCR_MODEL    8
#define IE_PCR_CONFIG   9
#define IE_PCR_POLICY   10
#define IE_PCR_RUNTIME  11

#define IE_LABEL_BL     "bootloader-0001"
#define IE_LABEL_KERN   "kernel-0002"
#define IE_LABEL_DRV    "id-engine-drv-0003"
#define IE_LABEL_MODEL  "model-0004"
#define IE_LABEL_RT     "runtime-0005"

struct ie_dev;

int  ie_measure(struct ie_dev *d, u8 pcr, u8 region, const void *buf, size_t len);
int  ie_measure_dma(struct ie_dev *d, u8 pcr, dma_addr_t addr, size_t len);
int  ie_extend(struct ie_dev *d, u8 pcr, const u8 digest[32]);
int  ie_derive(struct ie_dev *d, const char *label, const u8 parent[32],
               u8 out_cdi[32], u8 out_alias[32]);
int  ie_quote(struct ie_dev *d, const u8 nonce[32], u8 *out, size_t *len);
int  ie_seal(struct ie_dev *d, u16 policy, const u8 secret[32], u8 wrapped[32]);
int  ie_unseal(struct ie_dev *d, u16 policy, const u8 wrapped[32], u8 out[32]);
u8   ie_tamper(struct ie_dev *d);
void ie_zeroize_clear(struct ie_dev *d);
#endif
