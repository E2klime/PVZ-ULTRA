"""Procedural painted grass blades (supersampled PIL polygons).

Each blade is a tapered, slightly curved stroke: dark at the root, lighter at the
tip, with a warm rim on the left (top-left key light). Colours are sampled from the
ground texture under the root so overlays always match the stripe below them.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw

SS = 3  # supersampling factor


@dataclass(frozen=True)
class Blade:
    x: float          # root position (overlay px)
    y: float
    height: float
    width: float
    lean: float       # tip x offset in px (+ = right)
    rgb: tuple[float, float, float]  # root colour 0..1


def _poly(b: Blade, steps: int = 7) -> list[tuple[float, float]]:
    left: list[tuple[float, float]] = []
    right: list[tuple[float, float]] = []
    for i in range(steps + 1):
        t = i / steps
        cx = b.x + b.lean * t * t
        cy = b.y - b.height * t
        hw = b.width * 0.5 * (1 - t) ** 0.8
        left.append((cx - hw, cy))
        right.append((cx + hw, cy))
    return [(x * SS, y * SS) for x, y in left + right[::-1]]


def paint(size: tuple[int, int], blades: list[Blade], tip_lift: float = 0.32, rim: float = 0.12) -> Image.Image:
    """Render blades (painter's order = list order) to an RGBA image of `size`."""
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for b in blades:
        root = np.array(b.rgb)
        tip = np.clip(root * (1 + tip_lift) + 0.03, 0, 1)
        # two-tone stroke: full blade in a mid colour, then a lighter left half (key light)
        mid = (root * 0.6 + tip * 0.4)
        d.polygon(_poly(b), fill=tuple(int(c * 255) for c in mid) + (255,))
        lit = Blade(b.x - b.width * 0.18, b.y - b.height * 0.25, b.height * 0.72, b.width * 0.5,
                    b.lean * 0.8, tuple(np.clip(tip * (1 + rim), 0, 1)))
        d.polygon(_poly(lit, 5), fill=tuple(int(c * 255) for c in lit.rgb) + (235,))
        base = Blade(b.x, b.y, b.height * 0.3, b.width * 1.05, b.lean * 0.1, tuple(root * 0.8))
        d.polygon(_poly(base, 3), fill=tuple(int(c * 255) for c in base.rgb) + (255,))
    return img.resize((w, h), Image.LANCZOS)


def sample(ground: np.ndarray, x: float, y: float) -> tuple[float, float, float]:
    """Ground colour (0..1) at a pixel, clamped to the image."""
    h, w = ground.shape[:2]
    px = ground[int(np.clip(y, 0, h - 1)), int(np.clip(x, 0, w - 1))]
    return tuple(float(c) / 255.0 for c in px[:3])
