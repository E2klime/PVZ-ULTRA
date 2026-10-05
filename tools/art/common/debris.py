"""Procedural painted ground debris: pebbles, snow lumps, moss cushions, crystal shards.

Companion to blades.py for worlds whose ground is not grass. Every piece is lit from the
top-left (warm lit crescent, cool shadowed underside) and supersampled like the blades.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw

SS = 3


@dataclass(frozen=True)
class Piece:
    x: float            # centre of the base (overlay px)
    y: float
    rx: float           # half width
    ry: float           # half height (shards: full height)
    rgb: tuple[float, float, float]
    kind: str = "round"  # round | shard
    tilt: float = 0.0    # shard tip x offset


def _c(rgb: np.ndarray, a: int = 255) -> tuple[int, int, int, int]:
    return tuple(int(v * 255) for v in np.clip(rgb, 0, 1)) + (a,)


def _round(d: ImageDraw.ImageDraw, p: Piece, lift: float) -> None:
    base = np.array(p.rgb)
    x0, y0, x1, y1 = p.x - p.rx, p.y - p.ry * 2, p.x + p.rx, p.y
    d.ellipse([v * SS for v in (x0, y0, x1, y1)], fill=_c(base * 0.72))
    d.ellipse([v * SS for v in (x0 + p.rx * 0.08, y0, x1 - p.rx * 0.12, y1 - p.ry * 0.35)], fill=_c(base))
    lit = np.clip(base * (1 + lift) + 0.05, 0, 1)
    d.ellipse([v * SS for v in (x0 + p.rx * 0.25, y0 + p.ry * 0.25, p.x + p.rx * 0.2, p.y - p.ry * 1.05)],
              fill=_c(lit, 230))


def _shard(d: ImageDraw.ImageDraw, p: Piece, lift: float) -> None:
    base = np.array(p.rgb)
    tip = (p.x + p.tilt, p.y - p.ry)
    left, right, mid = (p.x - p.rx, p.y), (p.x + p.rx, p.y), (p.x + p.rx * 0.15, p.y + 1)
    d.polygon([(v[0] * SS, v[1] * SS) for v in (left, tip, right)], fill=_c(base * 0.75))
    d.polygon([(v[0] * SS, v[1] * SS) for v in (left, tip, mid)], fill=_c(np.clip(base * (1 + lift) + 0.06, 0, 1)))


def paint(size: tuple[int, int], pieces: list[Piece], lift: float = 0.35) -> Image.Image:
    """Render pieces (painter's order) to RGBA of `size`."""
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for p in pieces:
        (_shard if p.kind == "shard" else _round)(d, p, lift)
    return img.resize((w, h), Image.LANCZOS)


def jitter(rgb: tuple[float, float, float] | np.ndarray, rng: np.random.Generator, amount: float = 0.08) -> tuple[float, float, float]:
    c = np.clip(np.asarray(rgb, np.float32) * (1 + rng.normal(0, amount)) + rng.normal(0, amount * 0.3, 3), 0, 1)
    return (float(c[0]), float(c[1]), float(c[2]))
