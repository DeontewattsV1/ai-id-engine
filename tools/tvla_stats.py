#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Streaming Welch TVLA statistics over harness trace files.

A trace set is PREFIX.f32 (float32, rows = traces, `samples` columns),
PREFIX.lbl (uint8 group per row) and PREFIX.meta.json. Every statistic runs
in fixed-size chunks with Chan/Welford moment merging, so profile=signoff
(1e6 traces/group) needs disk space but not RAM.

first_order(prefix)          -> per-sample Welch t, fixed vs random
second_order(prefix, pois)   -> Welch t on centered squares (all samples,
                                univariate 2nd order) and on centered
                                products of POI pairs (bivariate 2nd order);
                                centering uses each group's own mean
select_pois(prefix, P, gap)  -> top-variance samples, at least `gap` apart
"""
import json
import numpy as np

CHUNK = 2048


class Moments:
    """Running count/mean/M2 per column (Chan et al. parallel merge)."""

    def __init__(self, k):
        self.n = 0
        self.mean = np.zeros(k)
        self.m2 = np.zeros(k)

    def add_block(self, x):
        if len(x) == 0:
            return
        x = np.asarray(x, dtype=np.float64)
        nb = len(x)
        mb = x.mean(axis=0)
        m2b = ((x - mb) ** 2).sum(axis=0)
        n = self.n + nb
        d = mb - self.mean
        self.mean = self.mean + d * nb / n
        self.m2 = self.m2 + m2b + d * d * self.n * nb / n
        self.n = n

    def var(self):
        return self.m2 / max(self.n - 1, 1)


def welch(g0, g1):
    """Welch t per column. Constant-and-equal columns give 0; constant but
    different columns give +-inf (a deterministic difference is a leak)."""
    den = np.sqrt(g0.var() / g0.n + g1.var() / g1.n)
    diff = g0.mean - g1.mean
    t = np.zeros_like(den)
    np.divide(diff, den, out=t, where=den > 0)
    t[(den == 0) & (diff != 0)] = np.inf * np.sign(diff[(den == 0) & (diff != 0)])
    return t


def load(prefix):
    meta = json.load(open(prefix + ".meta.json"))
    m = meta["samples"]
    lbl = np.fromfile(prefix + ".lbl", dtype=np.uint8)
    tr = np.memmap(prefix + ".f32", dtype=np.float32, mode="r",
                   shape=(len(lbl), m))
    if not np.isin(lbl, (0, 1)).all():
        raise ValueError("labels must be 0/1")
    return meta, tr, lbl


def _chunks(tr, lbl):
    for s in range(0, len(lbl), CHUNK):
        x = np.asarray(tr[s:s + CHUNK], dtype=np.float64)
        if not np.isfinite(x).all():
            raise ValueError("non-finite sample in traces")
        yield x, lbl[s:s + CHUNK]


def group_moments(prefix):
    meta, tr, lbl = load(prefix)
    g = [Moments(meta["samples"]), Moments(meta["samples"])]
    for x, l in _chunks(tr, lbl):
        g[0].add_block(x[l == 0]); g[1].add_block(x[l == 1])
    return meta, g


def summary(t, **extra):
    a = np.abs(t)
    idx = int(np.argmax(a))
    d = {"peak": float(a[idx]), "idx": idx, "tests": int(len(t))}
    d.update(extra)
    return d


def first_order(prefix):
    meta, g = group_moments(prefix)
    if min(g[0].n, g[1].n) < 2:
        raise ValueError("need >= 2 traces per group")
    if np.all(g[0].var() + g[1].var() == 0) and np.all(g[0].mean == g[1].mean):
        raise ValueError("degenerate traces: no variance and no difference")
    return meta, g, welch(g[0], g[1])


def select_pois(prefix, count, gap):
    meta, g = group_moments(prefix)
    v = (g[0].m2 + g[1].m2) / max(g[0].n + g[1].n - 2, 1)
    order = np.argsort(-v, kind="stable")
    taken = np.zeros(len(v), dtype=bool)
    pois = []
    for i in order:
        if taken[i] or v[i] <= 0:
            continue
        pois.append(int(i))
        taken[max(0, i - gap):i + gap + 1] = True
        if len(pois) == count:
            break
    return np.array(sorted(pois), dtype=np.int64)


def second_order(prefix, pois):
    meta, g = group_moments(prefix)
    _, tr, lbl = load(prefix)
    mu = [g[0].mean, g[1].mean]
    pois = np.asarray(pois, dtype=np.int64)
    iu, ju = np.triu_indices(len(pois), k=1)
    m = meta["samples"]
    uni = [Moments(m), Moments(m)]
    biv = [Moments(len(iu)), Moments(len(iu))]
    for x, l in _chunks(tr, lbl):
        for k in (0, 1):
            y = x[l == k] - mu[k]
            if len(y) == 0:
                continue
            uni[k].add_block(y * y)
            yp = y[:, pois]
            biv[k].add_block(yp[:, iu] * yp[:, ju])
    t_uni = welch(uni[0], uni[1])
    t_biv = welch(biv[0], biv[1]) if len(iu) else np.zeros(0)
    pairs = np.stack([pois[iu], pois[ju]], axis=1) if len(iu) else np.zeros((0, 2))
    return meta, g, t_uni, t_biv, pairs
