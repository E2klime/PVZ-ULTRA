"""Paint the placement cursor: a soft ground glow at the plant's feet plus brushed corner marks.

White-on-alpha so the game tints it (valid = warm sun, invalid = red). One cell
(130x140) at 2x for crisp scaling. Usage:
    python3 tools/art/assemble/cell_cursor.py [--out assets/ui/kit/cell_cursor.png] [--seed 7]
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CELL = (130, 140)
FEET_Y = 70 + 44.8
SCALE = 2
log = logging.getLogger("cell_cursor")


def paint(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    w, h = CELL[0] * SCALE, CELL[1] * SCALE
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / SCALE
    # ground glow: ellipse centred on the feet, soft falloff, brush-noise modulated
    ex = (xx - CELL[0] / 2) / 52.0
    ey = (yy - FEET_Y) / 20.0
    glow = np.clip(1.0 - np.hypot(ex, ey), 0, 1) ** 1.4 * 0.55
    # cell wash: barely-there rounded fill so the whole cell reads
    m = 8.0
    dx = np.maximum(np.maximum(m - xx, xx - (CELL[0] - m)), 0)
    dy = np.maximum(np.maximum(m - yy, yy - (CELL[1] - m)), 0)
    inside = np.clip(1 - np.hypot(dx, dy) / 6.0, 0, 1)
    wash = inside * 0.12
    # corner marks: short rounded L strokes with brush wobble
    marks = np.zeros((h, w), np.float32)
    arm = 26 * SCALE
    th = int(5 * SCALE)
    inset = int(7 * SCALE)
    for cx, cy, sx, sy in ((inset, inset, 1, 1), (w - inset, inset, -1, 1),
                           (inset, h - inset, 1, -1), (w - inset, h - inset, -1, -1)):
        pts_h = np.array([[cx, cy], [cx + sx * arm, cy]], np.int32)
        pts_v = np.array([[cx, cy], [cx, cy + sy * arm]], np.int32)
        cv2.polylines(marks, [pts_h, pts_v], False, 1.0, th, cv2.LINE_AA)
    brush = cv2.GaussianBlur(rng.random((h, w)).astype(np.float32), (0, 0), 3.0)
    brush = (brush - brush.mean()) / (brush.std() + 1e-6)
    marks = cv2.GaussianBlur(marks, (0, 0), 1.3) * np.clip(0.85 + 0.12 * brush, 0, 1)
    alpha = np.clip(np.maximum(glow * np.clip(0.9 + 0.1 * brush, 0, 1), wash) + marks * 0.95, 0, 1)
    out = np.ones((h, w, 4), np.float32)
    out[..., 3] = alpha
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "assets/ui/kit/cell_cursor.png")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    rgba = paint(args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((rgba * 255).round().astype(np.uint8), "RGBA").save(args.out)
    log.info("wrote %s", args.out)


if __name__ == "__main__":
    main()
