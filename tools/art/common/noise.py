"""Deterministic smooth value noise and seamless-tile helpers (numpy + OpenCV)."""
from __future__ import annotations

import cv2
import numpy as np


def value_noise(shape: tuple[int, int], cell: float, rng: np.random.Generator, octaves: int = 3) -> np.ndarray:
    """Smooth noise in -1..1, feature size ~cell px, fractal over a few octaves."""
    h, w = shape
    out = np.zeros(shape, np.float32)
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        gh, gw = max(2, int(h / cell) + 2), max(2, int(w / cell) + 2)
        grid = rng.uniform(-1, 1, (gh, gw)).astype(np.float32)
        out += amp * cv2.resize(grid, (w, h), interpolation=cv2.INTER_CUBIC)
        total += amp
        amp *= 0.5
        cell /= 2.0
    return out / total


def make_seamless(img: np.ndarray, border: float = 0.25) -> np.ndarray:
    """Offset-and-blend: returns a tile whose opposite edges match exactly."""
    h, w = img.shape[:2]
    rolled = np.roll(np.roll(img, h // 2, 0), w // 2, 1)
    yy = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * border)
    xx = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * border)
    wgt = np.clip(np.minimum(yy[:, None], xx[None, :]), 0, 1).astype(np.float32)
    wgt = wgt * wgt * (3 - 2 * wgt)
    if img.ndim == 3:
        wgt = wgt[..., None]
    return img * wgt + rolled * (1 - wgt)


def tile_to(tile: np.ndarray, shape: tuple[int, int], offset: tuple[int, int]) -> np.ndarray:
    """Tile `tile` over `shape` starting at a phase offset."""
    h, w = shape
    th, tw = tile.shape[:2]
    reps = (h // th + 2, w // tw + 2) + ((1,) if tile.ndim == 3 else ())
    big = np.tile(tile, reps)
    oy, ox = offset[0] % th, offset[1] % tw
    return big[oy:oy + h, ox:ox + w]
