# ADR-0002 Vendored cell simulation models

Status: accepted (implemented in v0.2.0)

## Context

The evidence pack has to be reproducible offline and byte-for-byte. The
upstream sky130_fd_sc_hd Verilog models use UDPs that Verilator cannot
simulate.

## Decision

- Download the liberty file `sky130_fd_sc_hd__tt_025C_1v80.lib` at build
  time. It is pinned by URL (OpenROAD-flow-scripts commit 2272e787) and by
  SHA-256 (ec0e1067...). It is not committed (12.8 MB).
- `sim/sky130_fd_sc_hd_cells.v` is **generated** from that same .lib, using
  its `function`/`ff` groups via Yosys `read_liberty`. It is committed, so
  simulation needs no download, and it carries an Apache-2.0 header with
  the source and hash. See `sim/VENDOR.md`.
- `make cells-check` fails if abc picks any cell without a model. `make
  cells` regenerates the file. Upstream bumps are explicit commits.

## Consequences

The models are exactly as correct as the .lib functions. The functional
check in `tools/tvla_collect.py` verifies that the gate-level netlists,
simulated with these models, compute a*b*R^-1 mod n.

The draft vendored file was hand-written and claimed an upstream commit
(`c6d7a1b0f3e8`) and a retrieval date that could not be verified. It was
replaced.
