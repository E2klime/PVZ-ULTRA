"""Slice the magenta-keyed blocked-cell prop sheet into one alpha PNG per prop.

Islands are found in reading order (boulder, tiles, ice, moonrock) and scaled to a
cell-sized footprint. Usage:
    python3 tools/art/process/slice_props.py [--width 116]
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import keying  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "art_src/finals/props/props_blocked_v1.webp"
OUT = ROOT / "assets/art/props"
NAMES = ("boulder", "tiles", "ice", "moonrock")
log = logging.getLogger("slice_props")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--width", type=int, default=116)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    rgb = np.asarray(Image.open(SRC).convert("RGB"), np.float32) / 255.0
    rgba = keying.key_magenta(rgb)
    boxes = keying.components(rgba, min_area=4000)
    if len(boxes) != len(NAMES):
        raise SystemExit(f"expected {len(NAMES)} props, found {len(boxes)}")
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (x0, y0, x1, y1) in zip(NAMES, boxes):
        crop = keying.trim(rgba[y0:y1, x0:x1], 2)
        h = round(crop.shape[0] * args.width / crop.shape[1])
        small = keying.resize(crop, (args.width, h))
        Image.fromarray((np.clip(small, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(OUT / f"blocked_{name}.png")
        log.info("blocked_%s %dx%d", name, args.width, h)


if __name__ == "__main__":
    main()
