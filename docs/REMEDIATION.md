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
