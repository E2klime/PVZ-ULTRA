"""Fit a generated environment plate to the real board geometry.

The image model never places the empty playfield bed exactly. This piecewise-linear
warp maps the measured bed rectangle of the source onto a target rectangle around
board_rect() in a 1920x1080 frame (margins stretch independently, so the bed lands
pixel-exact). Usage:
    python3 tools/art/process/fit_plate.py src.png dst.png --bed 258 210 1375 752 \
        [--target 300 190 1490 910] [--size 1920 1080]
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

import cv2
import numpy as np

log = logging.getLogger("fit_plate")


def axis_map(n_out: int, src_lo: float, src_hi: float, src_n: int, dst_lo: float, dst_hi: float) -> np.ndarray:
    """For every output coordinate return the source coordinate (piecewise linear)."""
    xs = np.arange(n_out, dtype=np.float32)
    return np.interp(xs, [0, dst_lo, dst_hi, n_out - 1], [0, src_lo, src_hi, src_n - 1]).astype(np.float32)


def fit(img: np.ndarray, bed: tuple[float, float, float, float], target: tuple[float, float, float, float],
        size: tuple[int, int]) -> np.ndarray:
    h, w = img.shape[:2]
    mx = axis_map(size[0], bed[0], bed[2], w, target[0], target[2])
    my = axis_map(size[1], bed[1], bed[3], h, target[1], target[3])
    map_x, map_y = np.meshgrid(mx, my)
    return cv2.remap(img, map_x, map_y, interpolation=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REFLECT)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--bed", type=float, nargs=4, required=True, metavar=("X0", "Y0", "X1", "Y1"))
    ap.add_argument("--target", type=float, nargs=4, default=(300, 190, 1490, 910))
    ap.add_argument("--size", type=int, nargs=2, default=(1920, 1080))
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    img = cv2.imread(str(args.src), cv2.IMREAD_UNCHANGED)
    out = fit(img, tuple(args.bed), tuple(args.target), tuple(args.size))
    args.dst.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(args.dst), out)
    log.info("wrote %s (%dx%d)", args.dst, *args.size)


if __name__ == "__main__":
    main()
