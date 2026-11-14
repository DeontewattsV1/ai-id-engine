boot-time measurement chain
// SPDX-License-Identifier: MIT
// Runs in initramfs before any untrusted userspace.
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/firmware.h>
#include "id_engine.h"

extern struct ie_dev *ie_global;   /* from attd.c */

static int __init measure_chain(void)
{
    const struct firmware *fw;
    u8 cdi[32], alias[32], parent[32];
    int ret;

    /* 1. kernel image (already in memory, measured pre-decompress by BL2) */
    ret = ie_measure(ie_global, IE_PCR_KERNEL, 2,
                     (void *)__pa_symbol(_stext),
                     (unsigned long)(_etext - _stext));
    if (ret) return ret;

    /* 2. loaded modules */
    ret = ie_measure(ie_global, IE_PCR_DRIVER, 3,
                     (void *)__pa_symbol(_stext), 0);
    if (ret) return ret;

    /* 3. model weights: streamed from block device via DMA */
    ret = request_firmware(&fw, "model/weights.safetensors", NULL);
    if (!ret) {
        ret = ie_measure(ie_global, IE_PCR_MODEL, 4, fw->data, fw->size);
        release_firmware(fw);
        if (ret) return ret;
    }

    /* 4. runtime config */
    ret = request_firmware(&fw, "model/inference.json", NULL);
    if (!ret) {
        ret = ie_measure(ie_global, IE_PCR_CONFIG, 5, fw->data, fw->size);
        release_firmware(fw);
        if (ret) return ret;
    }

    /* 5. ratchet identity to this exact software+model state */
    memcpy(parent, (u8 *)IE_ROOT_SEED_ADDR, 32);
    ie_derive(ie_global, IE_LABEL_MODEL, parent, cdi, alias);

    /* 6. unseal the model decryption key, PCR-bound */
    ret = ie_unseal(ie_global, 0x071F, (u8 *)IE_SEALED_KEY_ADDR,
                    (u8 *)IE_PLAIN_KEY_ADDR);
    if (ret) pr_crit("id-engine: unseal failed, key release denied\n");

    return 0;
}
late_initcall(measure_chain);
