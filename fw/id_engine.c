driver core 
// SPDX-License-Identifier: MIT
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>
#include <linux/of.h>
#include "id_engine.h"
#include "id_engine_regs.h"

struct ie_dev {
    void __iomem *base;
    struct device *dev;
    struct mutex  lock;
};

static inline u32 rd(struct ie_dev *d, u32 off) { return readl(d->base + off); }
static inline void wr(struct ie_dev *d, u32 off, u32 v) { writel(v, d->base + off); }

static void ie_write256(struct ie_dev *d, u32 off, const u8 *buf)
{
    int i;
    for (i = 0; i < 8; i++)
        wr(d, off, ((u32)buf[4*i] << 24) | ((u32)buf[4*i+1] << 16) |
                   ((u32)buf[4*i+2] << 8) | buf[4*i+3]);
}

static void ie_read256(struct ie_dev *d, u32 off, u8 *buf)
{
    int i; u32 v;
    for (i = 0; i < 8; i++) {
        v = rd(d, off);
        buf[4*i] = v >> 24; buf[4*i+1] = v >> 16;
        buf[4*i+2] = v >> 8; buf[4*i+3] = v;
    }
}

int ie_extend(struct ie_dev *d, u8 pcr, const u8 digest[32])
{
    int ret = 0;
    mutex_lock(&d->lock);
    if (rd(d, IE_REG_STATUS) & 0x2) { ret = -EBUSY; goto out; }
    wr(d, IE_REG_PCR_SEL, pcr);
    ie_write256(d, IE_REG_PCR_DATA, digest);
    wr(d, IE_REG_PCR_EXTEND, 1);
    while (rd(d, IE_REG_STATUS) & 0x2) cpu_relax();
out:
    mutex_unlock(&d->lock);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_extend);

/* Streaming measurement: hash a kernel/user buffer in 64-byte blocks */
int ie_measure(struct ie_dev *d, u8 pcr, u8 region, const void *buf, size_t len)
{
    u8 blk[64], dg[32];
    size_t i;
    int ret = 0;

    wr(d, IE_REG_MEAS_SEL, region);
    wr(d, IE_REG_MEAS_LEN, len);
    wr(d, IE_REG_MEAS_START, 1);

    for (i = 0; i < len; i += 64) {
        memset(blk, 0, sizeof(blk));
        memcpy(blk, buf + i, min_t(size_t, 64, len - i));
        ie_write256(d, IE_REG_PCR_DATA, blk);
        ie_write256(d, IE_REG_PCR_DATA, blk + 32);
        /* hardware absorbs blocks while MEAS_START asserted */
        if (rd(d, IE_REG_STATUS) & 0x4) { ret = -EIO; break; }
    }

    ie_read256(d, IE_REG_MEAS_DIGEST, dg);
    if (!ret) ret = ie_extend(d, pcr, dg);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_measure);

/* DMA path for multi-GB weight files: no copy, no CPU cache pollution */
int ie_measure_dma(struct ie_dev *d, u8 pcr, dma_addr_t addr, size_t len)
{
    u8 dg[32];
    wr(d, IE_REG_MEAS_SEL, 4);
    wr(d, IE_REG_MEAS_LEN, len);
    wr(d, IE_REG_MEAS_START, 1);
    wr(d, IE_REG_DMA_ADDR_LO, lower_32_bits(addr));
    wr(d, IE_REG_DMA_ADDR_HI, upper_32_bits(addr));
    wr(d, IE_REG_DMA_GO, 1);
    while (rd(d, IE_REG_STATUS) & 0x2) cpu_relax();
    ie_read256(d, IE_REG_MEAS_DIGEST, dg);
    return ie_extend(d, pcr, dg);
}
EXPORT_SYMBOL_GPL(ie_measure_dma);

int ie_derive(struct ie_dev *d, const char *label, const u8 parent[32],
              u8 out_cdi[32], u8 out_alias[32])
{
    u8 lbl[16] = {0};
    int i;

    mutex_lock(&d->lock);
    for (i = 0; i < 16 && label[i]; i++) lbl[i] = label[i];
    ie_write256(d, IE_REG_CDI_LABEL, lbl);
    ie_write256(d, IE_REG_CDI_PARENT, parent);
    wr(d, IE_REG_CDI_START, 1);
    while (!(rd(d, IE_REG_STATUS) & 0x2)) cpu_relax();
    ie_read256(d, IE_REG_CDI_OUT, out_cdi);
    ie_read256(d, IE_REG_CDI_ALIAS, out_alias);
    mutex_unlock(&d->lock);
    return 0;
}
EXPORT_SYMBOL_GPL(ie_derive);

int ie_quote(struct ie_dev *d, const u8 nonce[32], u8 *out, size_t *len)
{
    u32 i, n;
    mutex_lock(&d->lock);
    ie_write256(d, IE_REG_NONCE, nonce);
    wr(d, IE_REG_QUOTE_START, 1);
    while (!(rd(d, IE_REG_STATUS) & 0x8)) cpu_relax();
    n = rd(d, IE_REG_QUOTE_LEN);
    if (n > *len) { mutex_unlock(&d->lock); return -ENOSPC; }
    for (i = 0; i < n; i++) out[i] = (u8)rd(d, IE_REG_QUOTE_FIFO);
    *len = n;
    mutex_unlock(&d->lock);
    return 0;
}
EXPORT_SYMBOL_GPL(ie_quote);

static const struct of_device_id ie_of_match[] = {
    { .compatible = "venice,id-engine-v1" },
    { }
};
MODULE_DEVICE_TABLE(of, ie_of_match);

static int ie_probe(struct platform_device *pdev)
{
    struct ie_dev *d;

    d = devm_kzalloc(&pdev->dev, sizeof(*d), GFP_KERNEL);
    if (!d) return -ENOMEM;
    d->base = devm_platform_ioremap_resource(pdev, 0);
    if (IS_ERR(d->base)) return PTR_ERR(d->base);
    d->dev = &pdev->dev;
    mutex_init(&d->lock);
    platform_set_drvdata(pdev, d);
    dev_info(d->dev, "id-engine ready, tamper=0x%02x\n", ie_tamper(d));
    return 0;
}

static struct platform_driver ie_driver = {
    .probe = ie_probe,
    .driver = { .name = "id-engine", .of_match_table = ie_of_match },
};
module_platform_driver(ie_driver);
MODULE_LICENSE("GPL");
