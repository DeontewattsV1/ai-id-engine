# UNSAFE — do not synthesize or simulate as a signer

These files are the original in-RTL ECDSA P-256 attempt. They are kept only
as a record and are **excluded from every build** (`rtl/*.v` no longer
contains them).

Why they were removed from the design (v0.1.0):

1. **Private-key leak.** `ecdsa_core.v` used the private key itself as the
   ECDSA nonce (`inv_in <= k_base` with `k_base = priv`). With `k = d`,
   `s = d⁻¹(z + r·d)`, so anyone holding one signature recovers
   `d = z / (s − r) mod n`. One quote is enough to forge every later quote.
2. **Not a scalar multiplier.** The "ladder" adds `G` on every iteration
   regardless of the scalar bit, so `r` is not `x([k]G)`.
3. **Non-synthesizable shortcuts.** 256×256 combinational products
   (`rx * inv_r`) for the affine conversion.

v0.1.0 instead signs attestation quotes in an attached **secure element**
over SPI (`rtl/se_spi_master.v`, `rtl/quote_engine.v`, SE model in
`tb/se_model.h`). See `ARCHITECTURE.md` and `LIMITATIONS.md`.
