/* SPDX-License-Identifier: MIT */
/* The register ABI both RTL (rtl/apb_regfile.v) and firmware agree on.
 * test/check_regmap.py fails CI if the two drift apart. */
#ifndef _ID_ENGINE_REGS_H
#define _ID_ENGINE_REGS_H

/* APB aperture 0x0000-0x0FFF. 4-byte aligned, 32-bit access only.
 * Multi-word values move as big-endian 32-bit words through one address;
 * the word index auto-increments on back-to-back accesses to the same
 * address and restarts at word 0 when a different address is accessed. */
#define IE_REG_ID            0x000  /* RO  0x49444531 'IDE1' */
#define IE_ID_MAGIC          0x49444531u
#define IE_REG_STATUS        0x004  /* RO  see IE_ST_* */

#define IE_REG_PCR_SEL       0x020  /* RW  PCR index 0..15 */
#define IE_REG_PCR_DATA      0x024  /* WO  8 words */
#define IE_REG_PCR_READ      0x028  /* RO  8 words of PCR[PCR_SEL] */
#define IE_REG_PCR_EXTEND    0x02C  /* WO  bit0: PCR = SHA256(PCR || DATA) */

#define IE_REG_CDI_LABEL     0x060  /* WO  4 words, 16-byte layer label */
#define IE_REG_CDI_START     0x06C  /* WO  bit0: root CDI from UDS, measurement = PCR[PCR_SEL] */
#define IE_REG_CDI_OUT       0x070  /* RO  zeros unless AI_ID_DEBUG_READBACK (sim) */

#define IE_REG_NONCE         0x080  /* WO  8 words, 32-byte verifier nonce */
#define IE_REG_QUOTE_START   0x0A0  /* WO  bit0 sign */
#define IE_REG_QUOTE_LEN     0x0A4  /* RO  0 while the quote path is fail-closed */

#define IE_REG_SEAL_POLICY   0x0C0  /* RW  bitmask of PCRs to bind */
#define IE_REG_SEAL_IN       0x0C4  /* WO  8 words */
#define IE_REG_UNSEAL_OUT    0x0C8  /* RO  8 words */
#define IE_REG_SEAL_OP       0x0CC  /* WO  1=seal 2=unseal */

#define IE_REG_TAMPER        0x0F0  /* RO  sticky, bit per sensor */

/* STATUS bits */
#define IE_ST_READY          (1u << 0)
#define IE_ST_PCR_BUSY       (1u << 1)
#define IE_ST_CDI_VALID      (1u << 2)
#define IE_ST_QUOTE_DONE     (1u << 3)
#define IE_ST_UNSEAL_OK      (1u << 4)
#define IE_ST_QUOTE_ERR      (1u << 5)
#define IE_ST_CDI_BUSY       (1u << 6)
#define IE_ST_UDS_VALID      (1u << 7)

/* Not implemented in RTL (reserved): CTRL/IRQ, streaming measurement
 * engine (MEAS_*), weight DMA, quote FIFO drain, OTP. Drivers must not
 * rely on them; see docs/REMEDIATION.md. */

#endif
