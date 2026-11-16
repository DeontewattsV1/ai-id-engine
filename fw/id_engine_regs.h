/* SPDX-License-Identifier: MIT */
/* The register ABI both RTL (rtl/apb_regfile.v, rtl/id_engine_top.v) and
 * firmware agree on. test/check_regmap.py fails CI if the two drift apart.
 *
 * APB aperture 0x000-0xFFF, 32-bit accesses, 4-byte aligned. Reachable over
 * AXI4-Lite (rtl/axil_to_apb.v) or, on the FPGA board, the UART bridge
 * (rtl/uart_apb_bridge.v, tools/aiid_uart.py).
 * Multi-word values move as big-endian 32-bit words through one address:
 * the word index auto-increments on back-to-back accesses to the same
 * address and restarts at word 0 when a different address is accessed. */
#ifndef _ID_ENGINE_REGS_H
#define _ID_ENGINE_REGS_H

#define IE_REG_ID            0x000  /* RO  0x49444531 'IDE1' */
#define IE_ID_MAGIC          0x49444531u
#define IE_REG_STATUS        0x004  /* RO  see IE_ST_* */
#define IE_REG_VERSION       0x008  /* RO  0x00000100 = v0.1.0 */
#define IE_REG_HWINFO        0x00C  /* RO  [31:16] hw_rev (ASCII) [15:8] lifecycle */
#define IE_REG_IRQ_STATUS    0x010  /* RW1C see IE_IRQ_* */
#define IE_REG_IRQ_EN        0x014  /* RW  */

#define IE_REG_PCR_SEL       0x020  /* RW  PCR index 0..15 */
#define IE_REG_PCR_DATA      0x024  /* WO  8 words */
#define IE_REG_PCR_READ      0x028  /* RO  8 words of PCR[PCR_SEL] */
#define IE_REG_PCR_EXTEND    0x02C  /* WO  bit0: PCR = SHA256(PCR || DATA); extend-only, no reset */

#define IE_REG_MEAS_CTRL     0x030  /* WO  bit0 start, [7:4] target PCR, bit8 auto-extend */
#define IE_REG_MEAS_DATA     0x034  /* WO  stream 32-bit big-endian words (waits when busy) */
#define IE_REG_MEAS_FINAL    0x038  /* WO  number of valid bytes (0..4) of the last word */
#define IE_REG_MEAS_TAIL     0x03C  /* WO  tail word for MEAS_FINAL */
#define IE_REG_MEAS_DIGEST   0x040  /* RO  8 words, SHA-256 of the stream */
#define IE_REG_MEAS_LEN      0x044  /* RO  low 32 bits of byte count */

#define IE_REG_CDI_LABEL     0x060  /* WO  4 words, 16-byte layer label */
#define IE_REG_CDI_START     0x06C  /* WO  bit0: DICE CDI from UDS, measurement = PCR[PCR_SEL] */
#define IE_REG_CDI_OUT       0x070  /* RO  zeros unless AI_ID_DEBUG_READBACK (sim) */
#define IE_REG_DEVICE_ID     0x074  /* RO  8 words, public DICE device ID */

#define IE_REG_NONCE         0x080  /* WO  8 words, 32-byte verifier nonce */
#define IE_REG_CONFIG        0x084  /* WO  8 words, config digest */
#define IE_REG_TIME          0x088  /* WO  2 words (hi, lo) unix seconds */

#define IE_REG_QUOTE_START   0x0A0  /* WO  bit0 sign AIQ2 quote, bit1 fetch SE public key */
#define IE_REG_QUOTE_LEN     0x0A4  /* RO  660 when a quote is ready */
#define IE_REG_QUOTE_SIG     0x0A8  /* RO  16 words, ECDSA P-256 r||s from the SE */
#define IE_REG_QUOTE_HDR     0x0AC  /* RO  5 words of quote header */
#define IE_REG_SE_PUB        0x0B0  /* RO  16 words, SE public key X||Y */
#define IE_REG_QUOTE_COUNTER 0x0B4  /* RO  monotonic quote counter */
#define IE_REG_QUOTE_DIGEST  0x0B8  /* RO  8 words, SHA-256 of the quote body */

#define IE_REG_SEAL_POLICY   0x0C0  /* WO  bitmask of PCRs to bind */
#define IE_REG_SEAL_IN       0x0C4  /* WO  8 words */
#define IE_REG_UNSEAL_OUT    0x0C8  /* RO  8 words */
#define IE_REG_SEAL_OP       0x0CC  /* WO  1=seal 2=unseal */

#define IE_REG_RNG           0x0D0  /* RO  32-bit HMAC-DRBG output word (read pops) */
#define IE_REG_KEY_RATCHET   0x0D4  /* WO  bit0: ratchet session key slot */

#define IE_REG_OTP_ADDR      0x0E0  /* WO  fuse word 0..15 */
#define IE_REG_OTP_DATA      0x0E4  /* RO  fuse word (UDS words read as 0) */
#define IE_REG_OTP_PROG      0x0E8  /* WO  OR-program word OTP_ADDR (refused when locked) */

#define IE_REG_TAMPER        0x0F0  /* RO  sticky, bit per sensor */

#define IE_REG_HWCP_ADDR     0x100  /* WO  glyph byte address (code point * 8 + row) */
#define IE_REG_HWCP_DATA     0x104  /* RO  4 glyph bytes, auto-increment */
#define IE_REG_BANNER        0x108  /* RO  8 words, boot ROM banner text */

/* STATUS bits */
#define IE_ST_READY          (1u << 0)
#define IE_ST_PCR_BUSY       (1u << 1)
#define IE_ST_CDI_VALID      (1u << 2)
#define IE_ST_QUOTE_DONE     (1u << 3)
#define IE_ST_UNSEAL_OK      (1u << 4)
#define IE_ST_QUOTE_ERR      (1u << 5)
#define IE_ST_CDI_BUSY       (1u << 6)
#define IE_ST_UDS_VALID      (1u << 7)
#define IE_ST_QUOTE_BUSY     (1u << 8)
#define IE_ST_MEAS_BUSY      (1u << 9)
#define IE_ST_MEAS_VALID     (1u << 10)
#define IE_ST_KEYS_READY     (1u << 11)
#define IE_ST_RNG_READY      (1u << 12)
#define IE_ST_TRNG_FAIL      (1u << 13)
#define IE_ST_SE_PUB_VALID   (1u << 14)
#define IE_ST_ZEROIZED       (1u << 15)
#define IE_ST_OTP_PROG_ERR   (1u << 16)
#define IE_ST_MESH_BREACH    (1u << 17)
#define IE_ST_QERR_SHIFT     20     /* [23:20] quote error code, IE_QERR_* */
#define IE_ST_QERR_MASK      (0xFu << 20)

#define IE_QERR_NO_ID        1
#define IE_QERR_TAMPER       2
#define IE_QERR_LIFECYCLE    3
#define IE_QERR_SE           4
#define IE_QERR_ZEROIZED     5

/* IRQ_STATUS / IRQ_EN bits */
#define IE_IRQ_QUOTE_DONE    (1u << 0)
#define IE_IRQ_MEAS_DONE     (1u << 1)
#define IE_IRQ_ZEROIZE       (1u << 2)
#define IE_IRQ_QUOTE_ERR     (1u << 3)

#endif
