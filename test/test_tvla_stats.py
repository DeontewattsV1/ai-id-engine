#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Unit tests for the TVLA statistics on SYNTHETIC data (not evidence).

Checks the computed thresholds against ADR-0001, that the streaming Welch
matches a direct numpy computation, that a null set passes, that an
injected first-order leak is caught, and that a two-share leak is invisible
to the first-order test but caught by the second-order centered tests.
"""
import json, os, subprocess, sys, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
import tvla_stats
from threshold import thresh, mde

tvla_stats.CHUNK = 97          # force many chunks with ragged edges


def write(prefix, x, lbl, mode):
    x.astype(np.float32).tofile(prefix + ".f32")
    lbl.astype(np.uint8).tofile(prefix + ".lbl")
    json.dump({"samples": x.shape[1], "cycles": x.shape[1], "mode": mode,
               "dut": "synthetic"}, open(prefix + ".meta.json", "w"))


def main():
    # ADR-0001 numbers
    assert round(thresh(4000, 0.05), 2) == 4.37, thresh(4000, 0.05)
    assert round(thresh(64, 0.05), 2) == 3.36, thresh(64, 0.05)
    assert abs(mde(thresh(4000, 0.05), 4000) - 0.098) < 0.001
    assert abs(mde(thresh(4000, 0.05), 1_000_000) - 0.0062) < 0.0001
    rng = np.random.default_rng(0x7A1A)
    n, m = 1500, 400
    crit = thresh(m)
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, "s")
        lbl = rng.permutation(np.repeat([0, 1], n))
        x = rng.normal(10.0, 1.0, (2 * n, m))
        # 1) streaming Welch == direct Welch
        write(p, x, lbl, "null")
        _, g, t = tvla_stats.first_order(p)
        xf = x.astype(np.float32).astype(np.float64)
        a, b = xf[lbl == 0], xf[lbl == 1]
        td_ = (a.mean(0) - b.mean(0)) / np.sqrt(a.var(0, ddof=1) / n + b.var(0, ddof=1) / n)
        assert np.allclose(t, td_, atol=1e-8), np.abs(t - td_).max()
        # 2) null control passes; null_control.py exit 0
        assert np.abs(t).max() < crit
        r = subprocess.run([sys.executable, os.path.join(HERE, "null_control.py"), p,
                            p + ".null.json"], capture_output=True, text=True)
        assert r.returncode == 0, r.stdout + r.stderr
        # 3) first-order leak of 0.3 sigma at one sample is caught (exit 3)
        y = x.copy(); y[lbl == 0, 123] += 0.3
        write(p, y, lbl, "fixed")
        r = subprocess.run([sys.executable, os.path.join(HERE, "tvla_gate.py"), p,
                            p + ".t1.json"], capture_output=True, text=True)
        assert r.returncode == 3, r.stdout + r.stderr
        assert json.load(open(p + ".t1.json"))["idx"] == 123
        # 4) null_control refuses a non-null trace set; flags a leaky "null"
        write(p, y, lbl, "null")
        r = subprocess.run([sys.executable, os.path.join(HERE, "null_control.py"), p,
                            p + ".null.json"], capture_output=True, text=True)
        assert r.returncode == 5, r.stdout + r.stderr
        # 5) two-share leak: sample 50 = s, sample 300 = s ^ secret-bit model
        #    (HW of shares). First order blind, second order (bivariate) sees it.
        s = rng.integers(0, 2, 2 * n)
        secret = np.where(lbl == 0, 1, rng.integers(0, 2, 2 * n))
        z = rng.normal(0, 1.0, (2 * n, m))
        z[:, 50] += 2.0 * s
        z[:, 300] += 2.0 * (s ^ secret)
        write(p, z, lbl, "fixed")
        _, _, t1 = tvla_stats.first_order(p)
        assert np.abs(t1).max() < crit, np.abs(t1).max()
        pois = np.array([10, 50, 120, 300])
        _, _, tu, tb, pairs = tvla_stats.second_order(p, pois)
        k = int(np.abs(tb).argmax())
        assert np.abs(tb).max() > thresh(m + len(tb)), np.abs(tb).max()
        assert sorted(pairs[k].tolist()) == [50, 300], pairs[k]
        # 6) same-sample two-share leak is caught by the univariate square
        w = rng.normal(0, 1.0, (2 * n, m))
        w[:, 200] += 2.0 * s + 2.0 * (s ^ secret)
        write(p, w, lbl, "fixed")
        _, _, t1 = tvla_stats.first_order(p)
        assert np.abs(t1).max() < crit
        _, _, tu, tb, _ = tvla_stats.second_order(p, np.array([1, 2]))
        assert int(np.abs(tu).argmax()) == 200 and np.abs(tu).max() > thresh(m + 1)
        # 7) deterministic difference with zero variance is +-inf, equal constants 0
        c = np.zeros((2 * n, m)); c[lbl == 1, 7] = 1.0
        write(p, c + 0.0, lbl, "fixed")
        c2 = c.copy(); c2[:, 9] = rng.normal(0, 1, 2 * n)
        write(p, c2, lbl, "fixed")
        _, _, t = tvla_stats.first_order(p)
        assert np.isinf(t[7]) and t[0] == 0.0
        # 8) POI selection respects the gap and picks high-variance samples
        v = rng.normal(0, 1, (2 * n, m)); v[:, [40, 41, 42, 200]] *= 5
        write(p, v, lbl, "null")
        pois = tvla_stats.select_pois(p, 2, gap=5)
        assert 200 in pois and len(pois) == 2 and abs(pois[0] - pois[1]) > 5, pois
    print("TVLA statistics unit tests PASS (8 synthetic cases; not evidence)")


if __name__ == "__main__":
    main()
