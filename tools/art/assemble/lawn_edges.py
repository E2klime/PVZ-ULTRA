"""Edge overlay, per-lane front fringe, walker tuft and contact-shadow blob for one world.

Outputs (in --out-dir):
  edge.png      board_rect grown by MARGIN: cool drop shadow on the surround, a lip of the
                world's own soil on the front edge, and ground cover (fringe_styles) overhanging
                all four borders so the field never reads as a pasted rectangle.
  fringe_<r>.png  one strip per lane, rooted just in front of the feet line; drawn y-sorted in
                front of that lane's plants/zombies so they stand IN the ground cover.
  tuft.png      small clump drawn at walking zombies' feet.
  garden_kit/contact_shadow.png  soft neutral blob; each world tints it (world_art.tres).
Every world gets all of these; the recipe per world lives in fringe_styles.py.
Usage:
    python3 tools/art/assemble/lawn_edges.py --world lawn --ground assets/art/worlds/lawn/ground.webp \
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
from assemble import fringe_styles as fs  # noqa: E402
from common import blades, board, debris, palette  # noqa: E402

log = logging.getLogger("lawn_edges")
MARGIN: int = 40
FRINGE_H: int = 40      # strip height
FRINGE_ROOT: int = 30   # root line inside the strip (strip top = feet_y + 10 - FRINGE_ROOT)


def _slab(world: str, rng: np.random.Generator) -> Image.Image:
    gw, gh = board.SIZE
    W, H = gw + 2 * MARGIN, gh + 2 * MARGIN
    shadow_rgb = palette.hex_rgb(palette.load()["global"]["shadow"])
    # 1. drop shadow of the ground slab on the surround (light from top-left)
    mask = np.zeros((H, W), np.float32)
    mask[MARGIN + 6:MARGIN + gh + 10, MARGIN + 4:MARGIN + gw + 8] = 1.0
    mask = cv2.GaussianBlur(mask, (0, 0), 7)
    inside = np.zeros((H, W), np.float32)
    inside[MARGIN:MARGIN + gh, MARGIN:MARGIN + gw] = 1.0
    rgba = np.zeros((H, W, 4), np.float32)
    rgba[..., :3] = shadow_rgb * 0.45
    rgba[..., 3] = mask * (1 - inside) * 0.55
    # 2. inner ambient occlusion along the border
    ao = 1 - cv2.GaussianBlur(inside, (0, 0), 5)
    ao_a = np.clip(ao * inside * 1.6, 0, 1) * 0.35
    rgba[..., :3] = rgba[..., :3] * (1 - ao_a[..., None]) + (shadow_rgb * 0.3) * ao_a[..., None]
    rgba[..., 3] = np.maximum(rgba[..., 3], ao_a)
    # 3. lip on the front edge in this world's soil colour (was lawn soil for every world)
    soil = palette.hex_rgb(palette.load()["worlds"][world]["soil"]) * 0.75
    y0 = MARGIN + gh
    for x in range(MARGIN, MARGIN + gw):
        depth = 7 + int(2 * np.sin(x * 0.07) + rng.integers(0, 2))
        rgba[y0:y0 + depth, x, :3] = soil * (0.85 + 0.15 * rng.random())
        rgba[y0:y0 + depth, x, 3] = 1.0
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def edge_overlay(world: str, ground: np.ndarray, rng: np.random.Generator) -> Image.Image:
    st = fs.style(world)
    gw, gh = board.SIZE
    out = _slab(world, rng)
    bl: list[blades.Blade] = []
    pc: list[debris.Piece] = []
    g0 = (-MARGIN, -MARGIN)

    def add(cx: float, cy: float, scale: float, spread: float = 6.0) -> None:
        b, p = fs.clump(st, ground, cx, cy, g0, rng, spread, scale)
        bl.extend(b)
        pc.extend(p)

    for x in np.arange(MARGIN, MARGIN + gw, 18.0):   # top border
        add(x + rng.uniform(-6, 6), MARGIN + 6, rng.uniform(0.05, 0.14))
    for x in np.arange(MARGIN, MARGIN + gw, 18.0):   # front border, over the lip
        add(x + rng.uniform(-6, 6), MARGIN + gh + 4, rng.uniform(0.04, 0.1))
    for y in np.arange(MARGIN + 10, MARGIN + gh, 20.0):  # sides
        add(MARGIN + 3, y, rng.uniform(0.04, 0.1), 4.0)
        add(MARGIN + gw - 3, y, rng.uniform(0.04, 0.1), 4.0)
    for cx, cy in [(MARGIN, MARGIN), (MARGIN + gw, MARGIN), (MARGIN, MARGIN + gh), (MARGIN + gw, MARGIN + gh)]:
        add(cx, cy, 0.45, 10.0)
    out.alpha_composite(fs.render(st, out.size, bl, pc, tip_lift=0.32, rim=0.12))
    return out


def fringe_strip(world: str, ground: np.ndarray, row: int, rng: np.random.Generator) -> Image.Image:
    """Cover rooted ~10px in front of the lane's feet line, clumped at each cell centre only
    (drawn per cell where a plant stands, so empty ground never shows a line)."""
    st = fs.style(world)
    feet_local = (row + 0.5) * board.CELL[1] + board.FEET_OFFSET
    g0 = (0.0, feet_local + 10 - FRINGE_ROOT)
    bl: list[blades.Blade] = []
    pc: list[debris.Piece] = []
    for c in range(board.COLS):
        b, p = fs.clump(st, ground, (c + 0.5) * board.CELL[0], FRINGE_ROOT, g0, rng, 26.0)
        bl += b
        pc += p
    return fs.render(st, (board.SIZE[0], FRINGE_H), bl, pc)


def tuft(world: str, ground: np.ndarray, rng: np.random.Generator) -> Image.Image:
    """Walker tuft (128x40) drawn at zombie feet; mid-ground colours so it suits any stripe."""
    st = fs.style(world)
    mid = np.median(ground.reshape(-1, 3), axis=0)
    flat = np.broadcast_to(mid.astype(np.uint8), (FRINGE_H, 128, 3)).copy()
    flat = np.clip(flat.astype(np.int16) + rng.normal(0, 6, flat.shape).astype(np.int16), 0, 255).astype(np.uint8)
    b, p = fs.clump(st, flat, 64, FRINGE_ROOT, (0.0, 0.0), rng, 22.0, 0.9)
    return fs.render(st, (128, FRINGE_H), b, p)


def shadow_blob() -> Image.Image:
    """128x48 soft neutral-dark ellipse, denser core (contact) + wide falloff. Tinted per world."""
    w, h = 128, 48
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = np.clip(1 - r, 0, 1) ** 1.3 * 0.8 + np.clip(1 - r * 1.7, 0, 1) ** 1.5 * 0.35
    rgba = np.dstack([np.full((h, w, 3), 0.1, np.float32), np.clip(a, 0, 1)[..., None]])
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--world", default="lawn", choices=palette.world_names())
    ap.add_argument("--ground", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--kit-dir", type=Path, default=palette.ROOT / "assets/art/garden_kit")
    ap.add_argument("--seed", type=int, default=99)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    rng = np.random.default_rng(args.seed)
    ground = np.asarray(Image.open(args.ground).convert("RGB"))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    edge_overlay(args.world, ground, rng).save(args.out_dir / "edge.png", optimize=True)
    for r in range(board.ROWS):
        fringe_strip(args.world, ground, r, rng).save(args.out_dir / f"fringe_{r}.png", optimize=True)
    tuft(args.world, ground, rng).save(args.out_dir / "tuft.png", optimize=True)
    args.kit_dir.mkdir(parents=True, exist_ok=True)
    shadow_blob().save(args.kit_dir / "contact_shadow.png")
    log.info("wrote edge/fringe/tuft/shadow for %s to %s", args.world, args.out_dir)


if __name__ == "__main__":
    main()
