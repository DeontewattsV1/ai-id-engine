# AI Identity Engine — implementation status and release gates

**2026-11-15 · RESEARCH HOLD · NOT production certified.**

The corrected BCH code and arithmetic routines have narrow, independently
checkable software math oracles and separate RTL vector benches. They are
not side-channel hardened. Math-oracle PASS never implies gate-level PASS.

## Parameter correction

Primitive narrow-sense binary BCH, n=2047, field GF(2^11),
primitive polynomial x^11+x^2+1:

| root set | designed t | generator degree | message k |
| --- | ---: | ---: | ---: |
| alpha^1 through alpha^256 | 128 | 1232 | 815 |
| alpha^1 through alpha^342 | 171 | 1408 | 639 |

The actual 639-bit message / 1408-bit parity interface requires
**t=171**, not t=128. The generator script checks all specified roots,
and one-word bch_g.mem is consumed by the new systematic encoder. The
software reference decoder is **not** proof of rtl/bch_dec.v correctness.

## Unresolved blockers (must not promote to release)

- **ECDSA**: ecdsa_core uses private key as nonce, does not select scalar
  bits, has incorrect coordinate arithmetic, and inverts in the wrong
  field. It can expose the signing key. NO signing/attestation release.
- **SHA**: sha256_core uses stale nonblocking word schedule terms;
  its final accumulation is also suspect. Require FIPS known-answer
  verification before using hash-derived identities.
- **PUF**: no characterized silicon, entropy estimate, or error-rate
  distribution. The present fuzzy extractor does not form a verified
  secure sketch; helper and decoder need an independently reviewed design.
- **Montgomery**: fixed 256-cycle radix-2 multiplier now checks against
  a*b*R^-1 modulo both P-256 moduli. Its intermediate switching is not
  DPA-masked; n0prime parameter remains an interface compatibility check.
- **ECC arithmetic**: ec_arith Jacobian procedures and infinity
  handling remain unverified; special cases can yield wrong results.
- **Quote/COSE**: quote_signer has incomplete claims and undriven payload
  hash; testbench prints verification success without a signature check.
- **Firmware**: measurement/linker map, DMA, and kernel driver register
  protocol are not reconciled to RTL, and some symbols are placeholders.
- **Formal**: existing formal bind files are malformed / incomplete.
- **TVLA**: gate-level traces, independent acquisition, leakage masking
  and PPA measurements NOT RUN. Area estimates are unsubstantiated.

## Integration architecture (target, not yet shipped)

Secure UDS/DICE root -> authenticated boot measurements -> weights,
tokenizer/config/runtime hashes -> signed nonce-bound EAT/COSE evidence ->
independent verifier validating signer trust chain, freshness, approved
measurements, and revocation. Platform adapters for Linux/TPM, DICE,
Arm CCA, Intel TDX, AMD SEV-SNP or SEs require individually verified
bindings. Hashing model weights alone does not attest the running system.

## Verification commands

Run: make math-oracle
Run: make rtl-unit  (requires Icarus Verilog)
Run full original signoff separately; it currently has independent
blockers. Do not merge an arithmetic unit PASS into a full-chip PASS.

**Falsifiers:** a <=171-flip reference decode mismatch; any Montgomery
result != a*b*R^-1 mod p; a validated quote that binds to stale weights,
or any signature derived from a predictable/reused nonce.

References: TCG DICE; RFC 9711 EAT; RFC 9334 RATS architecture;
RFC 9052/9053 COSE; FIPS 180-4 / 186-5.

© 2026 Deonté O'dell Watts · ORCID 0009-0005-8586-3650 |
GoodShyt Group Inc. | AI-assisted implementation.


## 2026-11-15 verification extension

- SHA-256 one-block compression engine rewritten with round-local word
  expansion and correct final working-variable accumulation. Three KATs
  verify padded messages "", "a", "abc". This is NOT a full multi-block
  SHA-256 implementation and must not be used as a general streaming hash.
- New mod_n_mul unit uses N_R2/N_N0, enters Montgomery for both operands,
  multiplies, and explicitly exits using mont_mul(., 1). Its unit KAT
  is deliberately separate from the unsafe ecdsa_core signature path.
- ap_no_inf_midloop diagnostic SVA added under
  ENABLE_ECDSA_LADDER_SVA; not a proof of exception-free scalar execution.
- Legacy signoff runner uses YosysHQ OSS CAD Suite to provide sby, instead
  of a missing Ubuntu apt package. Further failures are blocking facts.


## 2026-11-15 integration pass (branch fix/operational)

- `sha256_compress` added (chained compression); `sha256_core` is now a
  thin standard-IV wrapper and still passes its KATs.
- `hmac_sha256` rewritten as a correct four-compression HMAC for 32-byte
  keys and messages up to 55 bytes; new `tb_hmac_sha256` checks six RFC 2104
  vectors. The previous version omitted padding and chaining.
- `pcr_bank` extend is now real SHA-256(PCR || digest) (two blocks), checked
  against OpenSSL in the end-to-end testbench.
- `dice_cdi` message widths corrected; parent latched; zeroize clears state.
  CDI matches OpenSSL HMAC bit-exactly. CDI is only readable over APB in
  simulation builds (`AI_ID_DEBUG_READBACK`).
- `apb_regfile`: one decode per transfer (reads used to double-increment),
  per-address word index (the old index reset between every transfer, so
  multi-word values were never assembled), ID register, CDI start, SEAL_IN
  and QUOTE_LEN registers.
- `seal_unit`: release now requires the PCR digest recorded at seal time;
  previously any non-zero XOR result was reported as success.
- `sram_puf` placeholder added (fail closed in hardware builds); `tamper_ctrl`
  no longer pulses zeroize at reset (power-on is still recorded as tamper).
- `quote_signer` remains fail-closed; its error flag is now visible in STATUS.
- Rust verifier made a real crate: decoded-byte transcript, real chain
  verification against trusted roots, bounds-checked PCR policy, 13 tests.
- Driver core aligned with the RTL register ABI; unimplemented paths return
  `-EOPNOTSUPP` instead of spinning forever.
- Legacy `signoff` workflow made manual-only; new `ci.yml` runs the
  operational gates. Unresolved blockers above are unchanged.
