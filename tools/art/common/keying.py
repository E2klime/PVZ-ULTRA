"""Chroma-key helpers for model outputs painted on a flat magenta (#FF00FF) backdrop.

key_magenta() turns the backdrop into alpha with a soft edge and removes the pink
spill from anti-aliased rims; trim() crops to the opaque bounding box.
"""
from __future__ import annotations

import cv2
import numpy as np


def key_magenta(rgb: np.ndarray, lo: float = 0.18, hi: float = 0.42) -> np.ndarray:
    """rgb float 0..1 (H,W,3) -> rgba float. Distance to magenta in a chroma space."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = np.minimum(r, b) - g          # 1 on pure magenta, <=0 on neutrals/greens
    dist = 1.0 - np.clip(magenta, 0, 1)
    a = np.clip((dist - (1 - hi)) / (hi - lo), 0, 1)
    a = cv2.GaussianBlur(a.astype(np.float32), (0, 0), 0.8)
    a = np.where(a < 0.04, 0.0, a)
    # despill: where magenta excess remains, pull r and b toward g
    spill = np.clip(np.minimum(r, b) - g, 0, 1)[..., None] * (1 - a[..., None] * 0.5)
    out = rgb.copy()
    out[..., 0] -= spill[..., 0] * 0.9
    out[..., 2] -= spill[..., 0] * 0.9
    # largest component only (drops stray specks)
    n, lab, stats, _ = cv2.connectedComponentsWithStats((a > 0.5).astype(np.uint8), 8)
    if n > 2:
        keep = np.zeros(n, bool)
        big = stats[1:, cv2.CC_STAT_AREA]
        keep[1:] = big >= big.max() * 0.02
        mask = keep[lab].astype(np.uint8)
        mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
        a = a * mask
    return np.dstack([np.clip(out, 0, 1), a]).astype(np.float32)


def trim(rgba: np.ndarray, pad: int = 2) -> np.ndarray:
    ys, xs = np.nonzero(rgba[..., 3] > 0.02)
    if len(xs) == 0:
        return rgba
    y0, y1 = max(0, ys.min() - pad), min(rgba.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(rgba.shape[1], xs.max() + pad + 1)
    return rgba[y0:y1, x0:x1]


def components(rgba: np.ndarray, min_area: int = 400) -> list[tuple[int, int, int, int]]:
    """Bounding boxes (x0,y0,x1,y1) of separate opaque islands, reading order."""
    m = (rgba[..., 3] > 0.3).astype(np.uint8)
    m = cv2.dilate(m, np.ones((9, 9), np.uint8))
    n, _, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    boxes = [(int(s[0]), int(s[1]), int(s[0] + s[2]), int(s[1] + s[3])) for s in stats[1:] if s[4] >= min_area]
    rows = sorted(boxes, key=lambda b: b[1])
    out: list[tuple[int, int, int, int]] = []
    while rows:
        top = rows[0][1]
        h = rows[0][3] - rows[0][1]
        line = [b for b in rows if b[1] < top + h * 0.5]
        out += sorted(line, key=lambda b: b[0])
        rows = [b for b in rows if b not in line]
    return out


def resize(rgba: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    """Premultiplied-alpha area resize (no dark fringes)."""
    pm = rgba.copy()
    pm[..., :3] *= pm[..., 3:4]
    interp = cv2.INTER_AREA if size[0] < rgba.shape[1] else cv2.INTER_LANCZOS4
    pm = cv2.resize(pm, size, interpolation=interp)
    a = np.clip(pm[..., 3:4], 0, 1)
    rgb = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 0)
    return np.dstack([np.clip(rgb, 0, 1), a]).astype(np.float32)
