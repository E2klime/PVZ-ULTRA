"""Pixel operations for the UI kit: load a keyed source, scale, colour states, rings.

All arrays are float32 RGBA 0..1. Pure functions; build_ui.py decides what to make.
"""
from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from common import keying

SRC = Path(__file__).resolve().parents[3] / "art_src/finals/ui"


def load(name: str) -> np.ndarray:
    rgb = np.asarray(Image.open(SRC / f"{name}.webp").convert("RGB"), np.float32) / 255.0
    return keying.trim(keying.key_magenta(rgb))


def save(rgba: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


def scale_w(rgba: np.ndarray, width: int) -> np.ndarray:
    h = max(1, round(rgba.shape[0] * width / rgba.shape[1]))
    return keying.resize(rgba, (width, h))


def scale_h(rgba: np.ndarray, height: int) -> np.ndarray:
    w = max(1, round(rgba.shape[1] * height / rgba.shape[0]))
    return keying.resize(rgba, (w, height))


def _hsv(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(np.clip(rgb, 0, 1).astype(np.float32), cv2.COLOR_RGB2HSV)


def _rgb(hsv: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(hsv.astype(np.float32), cv2.COLOR_HSV2RGB)


def grade(rgba: np.ndarray, hue_to: float | None = None, hue_mix: float = 1.0, sat: float = 1.0,
          val: float = 1.0, lift: float = 0.0, min_sat: float = 0.12) -> np.ndarray:
    """HSV grade. hue_to (degrees) rotates saturated pixels toward a target hue."""
    hsv = _hsv(rgba[..., :3])
    if hue_to is not None:
        w = np.clip((hsv[..., 1] - min_sat) / 0.2, 0, 1) * hue_mix
        d = ((hue_to - hsv[..., 0] + 180) % 360) - 180
        hsv[..., 0] = (hsv[..., 0] + d * w) % 360
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 1)
    hsv[..., 2] = np.clip(hsv[..., 2] * val + lift, 0, 1)
    out = rgba.copy()
    out[..., :3] = _rgb(hsv)
    return out


def desaturate(rgba: np.ndarray, amount: float = 0.85, lighten: float = 0.06) -> np.ndarray:
    lum = rgba[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    out = rgba.copy()
    out[..., :3] = rgba[..., :3] * (1 - amount) + lum[..., None] * amount + lighten
    return np.clip(out, 0, 1)


def glow_ring(rgba: np.ndarray, color: tuple[float, float, float], width: int = 5, pad: int = 8) -> np.ndarray:
    """Soft outline that hugs the silhouette (focus / selection state)."""
    a = np.pad(rgba[..., 3], pad)
    m = (a > 0.5).astype(np.uint8)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * width + 1, 2 * width + 1))
    ring = cv2.dilate(m, k).astype(np.float32) * (1.0 - m)
    ring = cv2.GaussianBlur(ring, (0, 0), 1.4)
    out = np.zeros(a.shape + (4,), np.float32)
    out[..., :3] = color
    out[..., 3] = np.clip(ring * 1.2, 0, 1)
    return out


def split_disc(rgba: np.ndarray, inner_frac: float) -> tuple[np.ndarray, np.ndarray]:
    """Round button -> (ring with transparent hole, neutral inner disc)."""
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    inner = np.clip((inner_frac - r) * 120, 0, 1)
    ring = rgba.copy()
    ring[..., 3] *= 1 - inner
    disc = rgba.copy()
    disc[..., 3] = np.clip((inner_frac + 0.01 - r) * 120, 0, 1)
    lum = disc[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    lum = lum / max(1e-3, float(np.percentile(lum[disc[..., 3] > 0.5], 70)))
    disc[..., :3] = np.clip(lum, 0, 1.15)[..., None] * 0.92
    return ring, disc


def rotate90(rgba: np.ndarray) -> np.ndarray:
    return np.ascontiguousarray(np.rot90(rgba, -1))


def pad(rgba: np.ndarray, px: int) -> np.ndarray:
    return np.pad(rgba, ((px, px), (px, px), (0, 0)))
