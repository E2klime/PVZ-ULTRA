"""Edge overlay, per-lane front fringe and contact-shadow blob for one world.

Outputs (in --out-dir):
  edge.png      board_rect grown by MARGIN: cool drop shadow on the surround, a turf
                lip on the front edge, and blades overhanging all four borders so the
                field never reads as a pasted rectangle.
  fringe_<r>.png  one strip per lane, rooted just in front of the feet line; drawn
                y-sorted in front of that lane's plants/zombies so they stand IN the grass.
  garden_kit/contact_shadow.png  soft cool contact-shadow blob drawn under every grounded entity.
Blade colours are sampled from ground.png so overlays match the stripe under them.
Usage:
    python3 tools/art/assemble/lawn_edges.py --world lawn --ground assets/art/worlds/lawn/ground.png \
        --out-dir assets/art/worlds/lawn
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import blades, board, palette  # noqa: E402

log = logging.getLogger("lawn_edges")
MARGIN: int = 40
FRINGE_H: int = 40      # strip height
FRINGE_ROOT: int = 30   # root line inside the strip (strip top = feet_y + 10 - FRINGE_ROOT)


def edge_overlay(ground: np.ndarray, grassy: bool, rng: np.random.Generator) -> Image.Image:
    gw, gh = board.SIZE
    W, H = gw + 2 * MARGIN, gh + 2 * MARGIN
    shadow_rgb = palette.hex_rgb(palette.load()["global"]["shadow"])
    # 1. drop shadow of the turf slab on the surround (light from top-left)
    mask = np.zeros((H, W), np.float32)
    mask[MARGIN + 6:MARGIN + gh + 10, MARGIN + 4:MARGIN + gw + 8] = 1.0
    mask = cv2.GaussianBlur(mask, (0, 0), 7)
    inside = np.zeros((H, W), np.float32)
    inside[MARGIN:MARGIN + gh, MARGIN:MARGIN + gw] = 1.0
    alpha = mask * (1 - inside) * 0.55
    rgba = np.zeros((H, W, 4), np.float32)
    rgba[..., :3] = shadow_rgb * 0.45
    rgba[..., 3] = alpha
    # 2. inner ambient occlusion along the border (slab edge)
    ao = 1 - cv2.GaussianBlur(inside, (0, 0), 5)
    ao_a = np.clip(ao * inside * 1.6, 0, 1) * 0.35
    rgba[..., :3] = rgba[..., :3] * (1 - ao_a[..., None]) + (shadow_rgb * 0.3) * ao_a[..., None]
    rgba[..., 3] = np.maximum(rgba[..., 3], ao_a)
    # 3. turf lip on the front (bottom) edge: visible soil side of the slab
    soil = palette.hex_rgb(palette.load()["worlds"]["lawn"]["soil"]) * 0.7
    y0 = MARGIN + gh
    for x in range(MARGIN, MARGIN + gw):
        depth = 7 + int(2 * np.sin(x * 0.07) + rng.integers(0, 2))
        rgba[y0:y0 + depth, x, :3] = soil * (0.85 + 0.15 * rng.random())
        rgba[y0:y0 + depth, x, 3] = 1.0
    out = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    if not grassy:
        return out
    # 4. blades overhanging every border (outward lean), clumped
    bl: list[blades.Blade] = []

    def clump(cx: float, cy: float, n: int, hgt: float, dir_x: float, dir_y: float) -> None:
        for _ in range(n):
            x = cx + rng.normal(0, 6)
            y = cy + rng.normal(0, 2)
            gx = np.clip(x - MARGIN, 0, gw - 1)
            gy = np.clip(y - MARGIN, 0, gh - 1)
            h = hgt * rng.uniform(0.6, 1.15)
            lean = dir_x * h * rng.uniform(0.2, 0.7) + rng.normal(0, 3)
            col = blades.sample(ground, gx, gy)
            if dir_y > 0:  # front edge: blades fold down over the lip, root above
                bl.append(blades.Blade(x, y + h * 0.9, h, rng.uniform(4, 7), lean, col))
            else:
                bl.append(blades.Blade(x, y, h, rng.uniform(4, 7), lean, col))

    for x in np.arange(MARGIN, MARGIN + gw, 9.0):  # top: blades poke up over the stones
        clump(x + rng.uniform(-4, 4), MARGIN + 6, int(rng.integers(1, 4)), rng.uniform(10, 22), rng.normal(0, 0.5), -1)
    for x in np.arange(MARGIN, MARGIN + gw, 9.0):  # bottom: blades over the lip
        clump(x + rng.uniform(-4, 4), MARGIN + gh - 4, int(rng.integers(1, 3)), rng.uniform(8, 16), rng.normal(0, 0.5), 1)
    for y in np.arange(MARGIN + 10, MARGIN + gh, 10.0):  # sides
        clump(MARGIN + 3, y, int(rng.integers(1, 3)), rng.uniform(9, 18), -1.0, -1)
        clump(MARGIN + gw - 3, y, int(rng.integers(1, 3)), rng.uniform(9, 18), 1.0, -1)
    for cx, cy in [(MARGIN, MARGIN), (MARGIN + gw, MARGIN), (MARGIN, MARGIN + gh), (MARGIN + gw, MARGIN + gh)]:
        clump(cx, cy, 14, 24, -1 if cx == MARGIN else 1, -1)
    bl.sort(key=lambda b: b.y)
    out.alpha_composite(blades.paint((W, H), bl))
    return out


def fringe_strip(ground: np.ndarray, row: int, rng: np.random.Generator) -> Image.Image:
    """Blades rooted ~10px in front of the lane's feet line, clumped at each cell centre only
    (drawn per cell where a plant stands, so empty grass never shows a line)."""
    gw = board.SIZE[0]
    feet_local = (row + 0.5) * board.CELL[1] + board.FEET_OFFSET  # in ground px
    root_y = feet_local + 10
    bl: list[blades.Blade] = []
    for c in range(board.COLS):
        cx = (c + 0.5) * board.CELL[0]
        bl += _clump(ground, cx, root_y, rng, 30, 26.0)
    bl.sort(key=lambda b: b.y)
    return blades.paint((gw, FRINGE_H), bl, tip_lift=0.18, rim=0.08)


def _clump(ground: np.ndarray, cx: float, root_y: float, rng: np.random.Generator, n: int,
           spread: float) -> list[blades.Blade]:
    out: list[blades.Blade] = []
    for _ in range(n):
        x = cx + float(np.clip(rng.normal(0, spread), -spread * 1.9, spread * 1.9))
        fall = 1.0 - min(1.0, abs(x - cx) / (spread * 2.0))
        h = rng.uniform(7, 17) * (0.55 + 0.45 * fall)
        y = FRINGE_ROOT + rng.normal(0, 2.2)
        col = blades.sample(ground, x, root_y + (y - FRINGE_ROOT))
        out.append(blades.Blade(x, y, h, rng.uniform(3.5, 6), rng.normal(0, 4), col))
    return out


def tuft(ground: np.ndarray, rng: np.random.Generator) -> Image.Image:
    """Walker tuft (128x40) drawn at zombie feet; mid-lawn colours so it suits both stripes."""
    mid = np.median(ground.reshape(-1, 3), axis=0)
    flat = np.broadcast_to(mid.astype(np.uint8), (FRINGE_H, 128, 3)).copy()
    jitter = (rng.normal(0, 6, flat.shape)).astype(np.int16)
    flat = np.clip(flat.astype(np.int16) + jitter, 0, 255).astype(np.uint8)
    bl = _clump(flat, 64, FRINGE_ROOT, rng, 26, 22.0)
    bl.sort(key=lambda b: b.y)
    return blades.paint((128, FRINGE_H), bl, tip_lift=0.18, rim=0.08)


def shadow_blob() -> Image.Image:
    """128x48 soft ellipse in the cool shadow colour, denser core (contact) + wide falloff."""
    w, h = 128, 48
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = np.clip(1 - r, 0, 1) ** 1.3 * 0.8 + np.clip(1 - r * 1.7, 0, 1) ** 1.5 * 0.35
    rgb = palette.hex_rgb(palette.load()["global"]["shadow"]) * 0.35
    rgba = np.dstack([np.broadcast_to(rgb, (h, w, 3)), np.clip(a, 0, 1)[..., None]])
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--world", default="lawn", choices=palette.world_names())
    ap.add_argument("--ground", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--kit-dir", type=Path, default=palette.ROOT / "assets/art/garden_kit")
    ap.add_argument("--seed", type=int, default=99)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    rng = np.random.default_rng(args.seed)
    ground = np.asarray(Image.open(args.ground).convert("RGB"))
    grassy = palette.load()["worlds"][args.world]["ground"] == "grass"
    args.out_dir.mkdir(parents=True, exist_ok=True)
    edge_overlay(ground, grassy, rng).save(args.out_dir / "edge.png", optimize=True)
    if grassy:
        for r in range(board.ROWS):
            fringe_strip(ground, r, rng).save(args.out_dir / f"fringe_{r}.png", optimize=True)
        tuft(ground, rng).save(args.out_dir / "tuft.png", optimize=True)
    args.kit_dir.mkdir(parents=True, exist_ok=True)
    shadow_blob().save(args.kit_dir / "contact_shadow.png")
    log.info("wrote edge/fringe/shadow to %s (grass=%s)", args.out_dir, grassy)


if __name__ == "__main__":
    main()
