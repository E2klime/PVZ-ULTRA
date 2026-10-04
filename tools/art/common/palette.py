"""Palette + colour-grade helpers shared by every art script.

Loads art_src/style_bible/palettes.json and implements the per-world grade
(lift / gain / saturation / exposure) used to derive world variants from the
shared garden kit, plus Lab-space measurement used by the review checks.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from skimage import color

ROOT = Path(__file__).resolve().parents[3]
PALETTE_PATH = ROOT / "art_src" / "style_bible" / "palettes.json"


def hex_rgb(h: str) -> np.ndarray:
    """'#rrggbb' -> float32 array in 0..1."""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


@dataclass(frozen=True)
class Grade:
    gain: np.ndarray
    lift: np.ndarray
    sat: float
    exposure: float

    @staticmethod
    def from_dict(d: dict) -> "Grade":
        return Grade(hex_rgb(d["gain"]), hex_rgb(d["lift"]), float(d["sat"]), float(d["exposure"]))


def load() -> dict:
    """Return the parsed palettes.json."""
    return json.loads(PALETTE_PATH.read_text(encoding="utf-8"))


def world_names() -> list[str]:
    return list(load()["worlds"].keys())


def world_grade(world: str) -> Grade:
    return Grade.from_dict(load()["worlds"][world]["grade"])


def apply_grade(rgb: np.ndarray, g: Grade) -> np.ndarray:
    """Grade a float RGB image (H,W,3 in 0..1). Lift tints shadows, gain tints lights."""
    x = np.clip(rgb.astype(np.float32), 0.0, 1.0) * (2.0 ** g.exposure)
    lum = (x @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32))[..., None]
    x = lum + (x - lum) * g.sat
    x = g.lift * 0.35 * (1.0 - x) + x * g.gain
    return np.clip(x, 0.0, 1.0)


def lab_stats(rgb_u8: np.ndarray) -> dict[str, float]:
    """Mean/std L*, mean HSV saturation and hue (deg) of an (N,3) or (H,W,3) uint8 array."""
    px = rgb_u8.reshape(-1, 3)[None].astype(np.float32) / 255.0
    lab = color.rgb2lab(px)[0]
    hsv = color.rgb2hsv(px)[0]
    return {
        "L": float(lab[:, 0].mean()), "L_std": float(lab[:, 0].std()),
        "sat": float(hsv[:, 1].mean()), "hue": float(hsv[:, 0].mean() * 360.0),
    }
