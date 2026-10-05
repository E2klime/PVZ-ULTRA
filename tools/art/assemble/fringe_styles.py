"""Per-world ground-cover recipes for the fringe strips, walker tuft and edge overhang.

Each world mixes painted blades (common/blades) and debris pieces (common/debris) in its
own proportions and colours, so every world's border and feet read differently:
grass (lawn), short turf (pool), clover (night), dry grass + pebbles (desert), moss on
tiles (roof), snow lumps (frost), grit + weeds (factory), regolith + crystals (moon).
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from common import blades, debris, palette


@dataclass(frozen=True)
class BladeMix:
    count: int
    height: tuple[float, float]
    width: tuple[float, float]
    colours: tuple[str, ...] = ()   # empty -> sample the ground under the root
    lean_sd: float = 4.0


@dataclass(frozen=True)
class PieceMix:
    count: int
    rx: tuple[float, float]
    ry_ratio: float
    colours: tuple[str, ...]
    kind: str = "round"


@dataclass(frozen=True)
class Style:
    blades: BladeMix | None = None
    pieces: tuple[PieceMix, ...] = field(default_factory=tuple)
    lift: float = 0.35


STYLES: dict[str, Style] = {
    "lawn": Style(BladeMix(30, (7, 17), (3.5, 6))),
    "pool": Style(BladeMix(26, (5, 12), (3, 5))),
    "night": Style(BladeMix(12, (5, 11), (3, 5)),
                   (PieceMix(12, (4, 6.5), 0.7, ("#4f7a5c", "#5e8a66", "#3f644e")),)),
    "desert": Style(BladeMix(7, (10, 22), (2, 3.5), ("#c9a85e", "#a8884a", "#94803e"), 6.0),
                    (PieceMix(6, (4, 9), 0.6, ("#b48c5c", "#9a7650", "#c8a878")),)),
    "roof": Style(BladeMix(5, (4, 8), (2.5, 4), ("#6f7f3c", "#5d6c34")),
                  (PieceMix(8, (5, 10), 0.6, ("#6b7a3a", "#7f8c46", "#5a6a32")),)),
    "frost": Style(BladeMix(3, (6, 12), (2, 3), ("#9fb6c4", "#b4c8d4")),
                   (PieceMix(9, (7, 16), 0.6, ("#eef4fa", "#dfe9f3", "#cfdcea")),), lift=0.12),
    "factory": Style(BladeMix(5, (6, 14), (2.5, 4), ("#5f6a34", "#4e5a2c")),
                     (PieceMix(9, (3.5, 7), 0.65, ("#6e665c", "#857b6c", "#5a5248")),
                      PieceMix(2, (2.5, 3.5), 0.6, ("#9a9aa4", "#b0a890")))),
    "moon": Style(None, (PieceMix(8, (4, 8), 0.6, ("#7a7a92", "#8e8ea6", "#5e5e78")),
                         PieceMix(5, (2.5, 5), 3.2, ("#b8a0f0", "#9c86de", "#d4c8ff"), "shard"))),
}


def style(world: str) -> Style:
    return STYLES[world]


def _pick(colours: tuple[str, ...], rng: np.random.Generator) -> np.ndarray:
    return palette.hex_rgb(colours[int(rng.integers(0, len(colours)))])


def clump(st: Style, ground: np.ndarray, cx: float, root_y: float, g0: tuple[float, float], rng: np.random.Generator,
          spread: float, scale: float = 1.0) -> tuple[list[blades.Blade], list[debris.Piece]]:
    """One clump centred at (cx, root_y) in overlay px; g0 is the overlay->ground px offset."""
    bl: list[blades.Blade] = []
    pc: list[debris.Piece] = []
    if st.blades is not None:
        m = st.blades
        for _ in range(max(1, round(m.count * scale))):
            x = cx + float(np.clip(rng.normal(0, spread), -spread * 1.9, spread * 1.9))
            fall = 1.0 - min(1.0, abs(x - cx) / (spread * 2.0))
            h = rng.uniform(*m.height) * (0.55 + 0.45 * fall)
            y = root_y + rng.normal(0, 2.2)
            col = blades.sample(ground, x + g0[0], y + g0[1]) if not m.colours else debris.jitter(_pick(m.colours, rng), rng)
            bl.append(blades.Blade(x, y, h, rng.uniform(*m.width), rng.normal(0, m.lean_sd), col))
    for m in st.pieces:
        for _ in range(max(0, round(m.count * scale))):
            x = cx + float(np.clip(rng.normal(0, spread * 0.8), -spread * 1.6, spread * 1.6))
            rx = rng.uniform(*m.rx)
            pc.append(debris.Piece(x, root_y + rng.normal(1.5, 1.8), rx, rx * m.ry_ratio,
                                   debris.jitter(_pick(m.colours, rng), rng), m.kind, rng.normal(0, rx * 0.6)))
    return bl, pc


def render(st: Style, size: tuple[int, int], bl: list[blades.Blade], pc: list[debris.Piece],
           tip_lift: float = 0.18, rim: float = 0.08) -> Image.Image:
    bl.sort(key=lambda b: b.y)
    pc.sort(key=lambda p: p.y)
    out = blades.paint(size, bl, tip_lift=tip_lift, rim=rim) if bl else Image.new("RGBA", size, (0, 0, 0, 0))
    if pc:
        out.alpha_composite(debris.paint(size, pc, st.lift))
    return out
