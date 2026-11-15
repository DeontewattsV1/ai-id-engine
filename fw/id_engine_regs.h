the ABI both RTL and firmware agree on.
/* SPDX-License-Identifier: MIT */
#ifndef _ID_ENGINE_REGS_H
#define _ID_ENGINE_REGS_H

/* APB aperture 0x0000-0x0FFF. 4-byte aligned, 32-bit access only. */
#define IE_REG_ID            0x000  /* RO  magic 'IDE1', version, rev */
#define IE_REG_STATUS        0x004  /* RO  bit0 ready bit1 busy bit2 err */
#define IE_REG_CTRL          0x008  /* RW  bit0 puf_start bit1 zeroize
                                           bit2 clk_gate_off */
#define IE_REG_IRQ_EN        0x00C
#define IE_REG_IRQ_STAT      0x010  /* W1C */

#define IE_REG_PCR_SEL       0x020  /* RW  PCR index 0..15 */
#define IE_REG_PCR_DATA      0x024  /* WO  8 words, auto-increment */
#define IE_REG_PCR_READ      0x028  /* RO  8 words, auto-increment */
#define IE_REG_PCR_EXTEND    0x02C  /* WO  bit0 commit */

#define IE_REG_MEAS_SEL      0x040  /* RW  0=rom 1=boot 2=kernel 3=drv
                                           4=model 5=config */
#define IE_REG_MEAS_START    0x044  /* WO  bit0 start, bits[15:8] region */
#define IE_REG_MEAS_LEN      0x048  /* RW  bytes */
#define IE_REG_MEAS_DIGEST   0x04C  /* RO  8 words */

#define IE_REG_CDI_LABEL     0x060  /* WO  16 bytes, layer label */
#define IE_REG_CDI_OUT       0x070  /* RO  8 words */

#define IE_REG_NONCE         0x080  /* WO  8 words, 32-byte verifier nonce */
#define IE_REG_QUOTE_START   0x0A0  /* WO  bit0 sign */
#define IE_REG_QUOTE_LEN     0x0A4  /* RO */
#define IE_REG_QUOTE_FIFO    0x0A8  /* RO  drain */

#define IE_REG_SEAL_POLICY   0x0C0  /* RW  bitmask of PCRs to bind */
#define IE_REG_SEAL_IN       0x0C4  /* WO  8 words */
#define IE_REG_UNSEAL_OUT    0x0C8  /* RO  8 words */
#define IE_REG_SEAL_OP       0x0CC  /* WO  1=seal 2=unseal */

#define IE_REG_OTP_WR        0x0E0  /* WO  fuse programming, 1 bit/cycle */
#define IE_REG_OTP_RD        0x0E4  /* RO */
#define IE_REG_TAMPER       0x0F0   /* RO  sticky, bit per sensor */

#endif
