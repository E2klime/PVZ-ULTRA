"""Assemble the playfield ground layer for one world: exactly board_rect() (1170x700).

A painted ground swatch (art_src/finals/ground/<ground>.webp) is made seamless,
tiled, and gradient-mapped onto the world's ramp from palettes.json. The 9x5 grid
is carried by one broad mow band per lane (5 bands, the zombies' path) and a faint
column tone, both with irregular painted boundaries; per-cell tonal jitter and a warm
top-left / cool bottom-right light bake finish it. No checkerboard, no borders.
Usage:
    python3 tools/art/assemble/lawn_surface.py --world lawn --out assets/art/worlds/lawn/ground.webp
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import board, noise, palette  # noqa: E402

log = logging.getLogger("lawn_surface")
GROUND_DIR = palette.ROOT / "art_src" / "finals" / "ground"
# swatch scale (source px -> screen px) and grid strength per ground type
GROUND_STYLE: dict[str, dict[str, float]] = {
    "grass": {"scale": 0.5, "stripe": 0.021, "row": 0.085, "seam": 0.11, "cell": 0.015, "detail": 0.7},
    "sand": {"scale": 0.5, "seam": 0.09, "stripe": 0.015, "row": 0.065, "cell": 0.015, "detail": 0.8},
    "tile": {"scale": 0.6, "seam": 0.10, "stripe": 0.017, "row": 0.07, "cell": 0.015, "detail": 0.75},
    "turf": {"scale": 0.45, "stripe": 0.024, "row": 0.09, "seam": 0.10, "cell": 0.012, "detail": 0.6},
    "clover": {"scale": 0.55, "stripe": 0.018, "row": 0.075, "seam": 0.10, "cell": 0.018, "detail": 0.8},
    "snow": {"scale": 0.7, "seam": 0.08, "stripe": 0.012, "row": 0.05, "cell": 0.01, "detail": 0.5},
    "soil": {"scale": 1.0, "seam": 0.10, "stripe": 0.017, "row": 0.07, "cell": 0.015, "detail": 0.9},
    "concrete": {"scale": 0.6, "seam": 0.09, "stripe": 0.012, "row": 0.06, "cell": 0.014, "detail": 0.85},
    "gravel": {"scale": 1.0, "seam": 0.10, "stripe": 0.015, "row": 0.07, "cell": 0.015, "detail": 0.9},
}


def ramp_map(t: np.ndarray, ramp: list[np.ndarray]) -> np.ndarray:
    """Map 0..1 values through an evenly spaced colour ramp."""
    n = len(ramp) - 1
    x = np.clip(t, 0, 1) * n
    i = np.clip(x.astype(int), 0, n - 1)
    f = (x - i)[..., None]
    stack = np.stack(ramp)
    return stack[i] * (1 - f) + stack[i + 1] * f


def band_index(coord: np.ndarray, size: float, jitter: np.ndarray) -> np.ndarray:
    return np.floor((coord + jitter) / size).astype(int)


def build(world: str, seed: int) -> np.ndarray:
    pal = palette.load()["worlds"][world]
    ground = pal["ground"]
    st = GROUND_STYLE[ground]
    rng = np.random.default_rng(seed)
    w, h = board.SIZE
    src = cv2.imread(str(GROUND_DIR / f"{ground}.webp"), cv2.IMREAD_COLOR)
    if src is None:
        raise FileNotFoundError(GROUND_DIR / f"{ground}.webp")
    src = cv2.cvtColor(src, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    src = cv2.resize(src, None, fx=st["scale"], fy=st["scale"], interpolation=cv2.INTER_AREA)
    tile = noise.make_seamless(src)
    tex = noise.tile_to(tile, (h, w), (int(rng.integers(0, 999)), int(rng.integers(0, 999))))
    lum = tex @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lo, hi = np.percentile(lum, [2, 98])
    t = np.clip((lum - lo) / (hi - lo), 0, 1)
    t = 0.5 + (t - 0.5) * st["detail"]
    base, light, dark = (palette.hex_rgb(c) for c in pal["lawn"])
    ramp = [dark * 0.72, dark, base, light, light * 1.12 + 0.03]
    rgb = ramp_map(t, ramp)

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cw, ch = board.CELL
    # irregular, blade-like band boundaries: low-freq wobble + fine comb
    jx = 4.0 * noise.value_noise((h, w), 60, rng) + 2.5 * noise.value_noise((h, w), 6, rng, 1)
    jy = 4.0 * noise.value_noise((h, w), 60, rng) + 2.5 * noise.value_noise((h, w), 6, rng, 1)
    col = np.clip(band_index(xx, cw, jx), 0, board.COLS - 1)
    row = np.clip(band_index(yy, ch, jy), 0, board.ROWS - 1)
    stripe = np.where(col % 2 == 0, 1.0, -1.0)
    lane = np.where(row % 2 == 0, 1.0, -1.0)
    cell_j = rng.uniform(-1, 1, (board.ROWS, board.COLS))[row, col]
    shade = 1.0 + st["stripe"] * stripe + st["row"] * lane + st["cell"] * cell_j
    # soft mower-overlap seam between lanes (never at the outer border)
    dy = np.abs(((yy + jy) + ch * 0.5) % ch - ch * 0.5)
    inner = (yy > ch * 0.5) & (yy < h - ch * 0.5)
    shade -= st["seam"] * np.exp(-(dy ** 2) / (2 * 4.5 ** 2)) * inner
    shade = cv2.GaussianBlur(shade.astype(np.float32), (0, 0), 1.2)
    # mow sheen: light stripes warmer, dark stripes cooler
    warm = palette.hex_rgb(palette.load()["global"]["key_light"])
    cool = palette.hex_rgb(palette.load()["global"]["shadow"])
    tint = np.where(lane[..., None] > 0, warm, cool)
    rgb = rgb * shade[..., None]
    rgb = rgb * (1 - 0.05) + rgb * tint * 0.05 * 2.0
    # large soft tonal patches so repetition never reads
    patches = noise.value_noise((h, w), 220, rng)
    rgb *= (1.0 + 0.035 * patches)[..., None]
    # light bake: warm top-left, cool bottom-right
    diag = ((xx / w) * 0.55 + (yy / h) * 0.45)[..., None]
    rgb = rgb * (1.05 - 0.1 * diag) + (cool - 0.5) * 0.04 * diag
    rgb = palette.apply_grade(rgb, palette.world_grade(world))
    return (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--world", default="lawn", choices=palette.world_names())
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=1234)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    img = build(args.world, args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(args.out), cv2.cvtColor(img, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_WEBP_QUALITY, 92])
    log.info("wrote %s %s L/sat=%s", args.out, img.shape, palette.lab_stats(img))


if __name__ == "__main__":
    main()
