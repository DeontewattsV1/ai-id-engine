#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Gate on a Yosys `equiv_status` report (tools/equiv_netlist.sh).

usage: equiv_check.py STATUS.txt TOP [--known config/equiv_known.txt]

Prints proven/unproven counts per signal. Fails (exit 1) if any signal
outside the known-unproven list for TOP has an unproven bit, or if the
report has no $equiv cells at all. A known-unproven signal that becomes
fully proven is reported so the list can be shrunk; it does not fail.
The known list records open proof gaps, not accepted bugs (docs/EQUIVALENCE.md).
"""
import argparse, collections, re, sys

ap = argparse.ArgumentParser()
ap.add_argument("status")
ap.add_argument("top")
ap.add_argument("--known", default="config/equiv_known.txt")
a = ap.parse_args()

txt = open(a.status).read()
m = re.search(r"Found (\d+) \$equiv cells", txt)
if not m or int(m.group(1)) == 0:
    sys.exit(f"{a.status}: no $equiv cells (nothing was paired)")
total = int(m.group(1))
unproven = collections.Counter(
    s for s in re.findall(r"Unproven \$equiv \S+: \\(\S+?)_gold", txt))
known = set()
for line in open(a.known):
    f = line.split("#")[0].split()
    if f and f[0] == a.top:
        known.update(f[1:])
nu = sum(unproven.values())
print(f"equiv {a.top}: {total - nu}/{total} paired bits proven")
bad = sorted(s for s in unproven if s not in known)
for s, n in sorted(unproven.items()):
    print(f"  unproven {s}: {n} bits{'' if s in known else '  <-- NOT in the known-gap list'}")
for s in sorted(known - set(unproven)):
    print(f"  {s}: now fully proven; remove it from {a.known}")
if bad:
    sys.exit(f"equiv {a.top}: FAIL, unexpected unproven signals {bad}")
print(f"equiv {a.top}: PASS (no unproven signal outside the known-gap list)")
