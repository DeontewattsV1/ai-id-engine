# Coded fault detection (v0.2.0)

**Scope.** This is fault *detection*: it notices when a register bit is
flipped (a single-event upset, a laser or EM pulse, a clock or voltage glitch
that corrupts state) and reacts by correcting it or wiping secrets. It is
**not** a side-channel countermeasure. Coding, duplication and residue checks
do nothing against power, EM or timing leakage; that is what masking is for
(`docs/TVLA.md`). Everything below is pre-silicon evidence from RTL
simulation and SymbiYosys proofs; nothing here has been measured on silicon
or under a real fault-injection rig.

## What is detected

| Block | Code | Corrects | Detects | Escapes |
|---|---|---|---|---|
| `rtl/secded39_{enc,dec}.v` | Extended Hamming SEC-DED (39,32) | any 1-bit error per word | any 2-bit error per word | 3+ bit errors in one word can be miscorrected |
| `rtl/fault_alarm.v` | Two complementary sticky latches (`a`, `b_n`) | – | any fault input; a disagreement between the latches re-sets both | an attacker who flips *both* latches in the same cycle |
| FSM state (in `key_store_fd`, `pcr_bank`) | Hamming(7,4) codewords, minimum distance 3, neither all-0 nor all-1 | – | any 1- or 2-bit state upset | 3-bit upsets that land exactly on another legal code |
| `rtl/mont_mul_rc.v` | Residue check mod 2^16 - 1 on `|r| + s|m| = |a||b| + |Q||m|` | – | any corruption of r, Q or an operand register that is not a multiple of 65535 | about **1 in 65535** random corruptions (errors that are multiples of 65535) |

**Why HD3 codes rather than one-hot.** One-hot state encoding has a minimum
Hamming distance of 2 between legal states. A single flip always lands on an
illegal code, but a 2-bit flip (clear the current bit, set another) lands on
a *legal* state and goes unnoticed. With Hamming(7,4) codewords every pair of
legal states differs in at least 3 bits, so every 1- and 2-bit upset is an
illegal code.

**The alarm is sticky.** `fault_alarm` has no reset input. Only the power-on
(configuration) value clears it, so `rst_n`, software or a debugger cannot.
While it is set, `zeroize` is held high.

## Integration (`AI_ID_FAULT_DETECT`)

The coded logic is opt-in. Build with `+define+AI_ID_FAULT_DETECT` (Verilator)
or `-DAI_ID_FAULT_DETECT` (iverilog/Yosys):

- `pcr_bank` stores each 256-bit PCR as 8 SEC-DED (39,32) words (4,992 flops
  instead of 4,096) and decodes all 128 words in parallel for `digest_out` and
  `flat`. Its controller uses Hamming(7,4) codes for its 5 states.
  - `fault` = any word's DED flag or an illegal state code. It is armed only
    once a reset has been seen and released: before the first reset the
    registers hold power-up values (0 is not a legal state code), and a sticky
    alarm latched then would brick the part.
  - `fd_sec` goes high when a single-bit error was corrected and stays high
    until reset. There is no scrubber: the stored word keeps its flipped bit
    (reads stay correct) until the next extend of that PCR rewrites it, so a
    second upset in the same word before then is a DED and wipes the part.
- `id_engine_top` latches `pcr_fault` in a `fault_alarm`. `zeroize` is
  `tamper_zeroize | fd_zeroize`, so a fault wipes every secret-holding block
  exactly as a tamper event does, and keeps them wiped.
- Status bits (`fw/id_engine_regs.h`): `IE_ST_FAULT_ALARM` (bit 24) and
  `IE_ST_FAULT_CORR` (bit 25). Both read 0 without the define.
- **`mont_mul_rc` is not in `id_engine_top`.** The top has no in-fabric
  multiplier: quotes are signed by the SE/TPM, and the bundle's in-fabric
  signing path was rejected (`docs/BUNDLE-REVIEW.md`). `rc_err` is wired to
  the alarm's `fault_ext` input in the reference composition `key_store_fd`,
  and any future in-fabric multiplier must do the same.
- `key_store_fd` is a reference composition (key store + coded FSM + alarm)
  and is not instantiated in `id_engine_top`. Unlike `pcr_bank`, its fault
  input is not gated on reset having been seen; its proofs and testbench
  apply reset first.

Without the define, `pcr_bank` and `id_engine_top` are functionally unchanged
(`fault` and `fd_sec` are tied to 0) and `formal/pcr_bank.sby` proves the
same extend-only property as before.

## Evidence

`make fault-test` (part of `make test`):

| Check | Result |
|---|---|
| SEC-DED (39,32), 64 words, exhaustive | 1-bit flips corrected 2496/2496; 2-bit flips detected 47424/47424 |
| `fault_alarm` | set by a fault; survives `rst_n`; a single-latch upset re-sets the latch |
| `key_store_fd` FSM, all 1- and 2-bit upsets | detected 35/35 |
| `key_store_fd` key words | 1-bit upsets corrected 312/312; 2-bit upsets zeroize 48/48 |
| `mont_mul_rc`, 40 clean runs | 0 false alarms |
| `mont_mul_rc`, 400 random register upsets | 307 changed r or Q: 307 detected, 0 escaped; 93 had no effect |
| `pcr_bank` (define on), 24 extends vs `hashlib` | match; no false alarm |
| `pcr_bank`, every 1-bit flip of every coded word (128 x 39) | corrected 4992/4992, reads unchanged |
| `pcr_bank`, 2-bit flips inside one word (43 words) | detected 5289/5289 |
| `pcr_bank`, all 1- and 2-bit state upsets, idle and mid-extend | detected and latched 56/56 |
| `pcr_bank`, power-up values before the first reset | no alarm |
| `id_engine_top` full-chip sim with the define | 192 checks pass, alarm never set |

Testbench sensitivity: disabling each detector (residue check, FSM legality,
alarm, DED, SEC correction) makes the corresponding testbench fail.

`make formal-all` (SymbiYosys, fault-free model):

- `formal/fault_alarm.sby`: once set, zeroize never clears; any fault sets both latches.
- `formal/key_store_fd.sby`: the FSM stays legal, the stored words are always
  valid codewords, and `key_out` is 0 while zeroize is high.
- `formal/key_store_nonint.sby` (k-induction): a two-copy miter with
  independent keys proves `status`, `zeroize` and `key_valid` never depend on
  the key. `key_out` is the only keyed port.
- `formal/pcr_bank_fd.sby`: with the define, the extend-only property still
  holds on the decoded PCRs, and once armed the state code is always legal and
  every word is a valid codeword (no false alarm without an upset).

## Limits

- Fault model: register bit flips. Combinational glitches that corrupt a
  value *before* it is encoded (e.g. on the SHA output feeding the encoder)
  are not detected; neither are faults in the decoders themselves beyond what
  the duplicated alarm catches.
- Multi-bit upsets of 3 or more bits in one word or state register can escape.
- The residue check misses about 1 in 65535 random corruptions.
- No scrubbing of PCR words (see above).
- FPGA proxy only. The define is not enabled in the default FPGA build; on
  silicon the alarm latches' power-on value must come from a power-on reset
  cell, not from an `initial` statement.
