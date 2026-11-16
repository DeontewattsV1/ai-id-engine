// SPDX-License-Identifier: MIT
// id-engine platform driver core. Implements the register ABI in
// id_engine_regs.h; paths whose hardware is not implemented fail with
// -EOPNOTSUPP instead of polling forever.
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>
#include <linux/of.h>
#include <linux/mutex.h>
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

#define IE_POLL_LIMIT 1000000

static int ie_wait(struct ie_dev *d, u32 mask, bool set)
{
    u32 n;
    for (n = 0; n < IE_POLL_LIMIT; n++) {
        bool on = rd(d, IE_REG_STATUS) & mask;
        if (on == set)
            return 0;
        cpu_relax();
    }
    return -ETIMEDOUT;
}

int ie_extend(struct ie_dev *d, u8 pcr, const u8 digest[32])
{
    int ret = 0;
    if (pcr > 15)
        return -EINVAL;
    mutex_lock(&d->lock);
    if (rd(d, IE_REG_STATUS) & IE_ST_PCR_BUSY) { ret = -EBUSY; goto out; }
    wr(d, IE_REG_PCR_SEL, pcr);
    ie_write256(d, IE_REG_PCR_DATA, digest);
    wr(d, IE_REG_PCR_EXTEND, 1);
    ret = ie_wait(d, IE_ST_PCR_BUSY, false);
out:
    mutex_unlock(&d->lock);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_extend);

int ie_read_pcr(struct ie_dev *d, u8 pcr, u8 out[32])
{
    if (pcr > 15)
        return -EINVAL;
    mutex_lock(&d->lock);
    wr(d, IE_REG_PCR_SEL, pcr);
    ie_read256(d, IE_REG_PCR_READ, out);
    mutex_unlock(&d->lock);
    return 0;
}
EXPORT_SYMBOL_GPL(ie_read_pcr);

/* The streaming measurement engine and weight DMA are not implemented in
 * RTL. Callers hash in software and use ie_extend(). */
int ie_measure(struct ie_dev *d, u8 pcr, u8 region, const void *buf, size_t len)
{
    return -EOPNOTSUPP;
}
EXPORT_SYMBOL_GPL(ie_measure);

int ie_measure_dma(struct ie_dev *d, u8 pcr, dma_addr_t addr, size_t len)
{
    return -EOPNOTSUPP;
}
EXPORT_SYMBOL_GPL(ie_measure_dma);

/* Derive the root-layer CDI and alias key inside the engine from the UDS,
 * the 16-byte label and PCR[measure_pcr]. The secrets never leave the
 * engine; success means they are ready for sealing and quoting. */
int ie_derive(struct ie_dev *d, const char *label, u8 measure_pcr)
{
    u8 lbl[16] = {0};
    int i, ret;

    if (measure_pcr > 15)
        return -EINVAL;
    mutex_lock(&d->lock);
    if (!(rd(d, IE_REG_STATUS) & IE_ST_UDS_VALID)) { ret = -ENODEV; goto out; }
    for (i = 0; i < 16 && label[i]; i++) lbl[i] = label[i];
    for (i = 0; i < 4; i++)
        wr(d, IE_REG_CDI_LABEL, ((u32)lbl[4*i] << 24) | ((u32)lbl[4*i+1] << 16) |
                                ((u32)lbl[4*i+2] << 8) | lbl[4*i+3]);
    wr(d, IE_REG_PCR_SEL, measure_pcr);
    wr(d, IE_REG_CDI_START, 1);
    ret = ie_wait(d, IE_ST_CDI_VALID, true);
out:
    mutex_unlock(&d->lock);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_derive);

/* Hardware quoting is fail-closed until the ECDSA signer is verified. */
int ie_quote(struct ie_dev *d, const u8 nonce[32], u8 *out, size_t *len)
{
    int ret;
    mutex_lock(&d->lock);
    ie_write256(d, IE_REG_NONCE, nonce);
    wr(d, IE_REG_QUOTE_START, 1);
    ret = ie_wait(d, IE_ST_QUOTE_DONE | IE_ST_QUOTE_ERR, true);
    if (!ret && (rd(d, IE_REG_STATUS) & IE_ST_QUOTE_ERR))
        ret = -EOPNOTSUPP;
    else if (!ret)
        ret = -EOPNOTSUPP;      /* no FIFO drain register exists yet */
    *len = 0;
    mutex_unlock(&d->lock);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_quote);

int ie_seal(struct ie_dev *d, u16 policy, const u8 secret[32])
{
    mutex_lock(&d->lock);
    wr(d, IE_REG_SEAL_POLICY, policy);
    ie_write256(d, IE_REG_SEAL_IN, secret);
    wr(d, IE_REG_SEAL_OP, 1);
    mutex_unlock(&d->lock);
    return 0;
}
EXPORT_SYMBOL_GPL(ie_seal);

int ie_unseal(struct ie_dev *d, u8 out[32])
{
    int ret = 0;
    mutex_lock(&d->lock);
    wr(d, IE_REG_SEAL_OP, 2);
    if (rd(d, IE_REG_STATUS) & IE_ST_UNSEAL_OK)
        ie_read256(d, IE_REG_UNSEAL_OUT, out);
    else
        ret = -EACCES;
    mutex_unlock(&d->lock);
    return ret;
}
EXPORT_SYMBOL_GPL(ie_unseal);

u8 ie_tamper(struct ie_dev *d)
{
    return (u8)rd(d, IE_REG_TAMPER);
}
EXPORT_SYMBOL_GPL(ie_tamper);

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
    if (rd(d, IE_REG_ID) != IE_ID_MAGIC)
        return -ENODEV;
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
