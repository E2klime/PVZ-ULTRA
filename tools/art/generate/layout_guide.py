"""Paint a flat colour-block layout guide (1920x1080) for environment-plate generation.

The guide fixes where the house, fence, path and the empty playfield bed go, so the
image model paints around the real board_rect(). Usage:
    python3 tools/art/generate/layout_guide.py --world lawn --out art_build/guides/lawn.png
"""
from __future__ import annotations

import argparse
import logging
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import board  # noqa: E402

log = logging.getLogger("layout_guide")

# zone colours per ground family: (house/left, back/top, path/right, front/bottom, bed)
ZONES: dict[str, tuple[str, str, str, str, str]] = {
    "garden": ("#e8d6b0", "#4f7a3a", "#b9ab92", "#8a6a48", "#5a3d26"),
    "pool": ("#e8d6b0", "#4f7a3a", "#c9c2b0", "#8a6a48", "#5a3d26"),
    "desert": ("#e2c08c", "#c89a5a", "#d8b67a", "#a7774a", "#9a6a3e"),
    "roof": ("#a85a3e", "#7d8fa8", "#8c4a34", "#6e3a2a", "#7a3e2c"),
    "frost": ("#e9eef2", "#8fa6b8", "#d6e2ea", "#b7c6d2", "#6c7d8c"),
    "factory": ("#8a8478", "#5c5850", "#7a746a", "#4c4a44", "#3e3c38"),
    "moon": ("#6c6a80", "#2a2a44", "#8a889a", "#4a4860", "#3a3850"),
}


def build(world_family: str, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    left, top, right, bottom, bed = ZONES[world_family]
    img = Image.new("RGB", (1920, 1080), top)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = board.RECT
    d.rectangle((0, y1 + 10, 1920, 1080), fill=bottom)
    d.rectangle((x1 + 20, 0, 1920, 1080), fill=right)
    d.rectangle((0, 0, x0 - 70, 1080), fill=left)
    # porch deck where the mowers sit
    d.rectangle((x0 - 70, y0 - 10, x0 - 8, y1 + 10), fill="#9a6a3e")
    # fence / back line
    for x in range(x0 - 60, x1 + 20, 34):
        d.rectangle((x, y0 - 70, x + 24, y0 - 18), fill="#c9a87a")
    # empty soil bed where the lawn layer goes (slightly larger than the board)
    d.rounded_rectangle((x0 - 14, y0 - 12, x1 + 14, y1 + 14), radius=26, fill=bed)
    for _ in range(40):  # a few stones on the margins only
        cx = rnd.choice([rnd.randint(20, x0 - 90), rnd.randint(x1 + 40, 1900)])
        cy = rnd.randint(40, 1060)
        r = rnd.randint(8, 22)
        d.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), fill="#9c9488")
    return img


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--family", default="garden", choices=sorted(ZONES))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    build(args.family, args.seed).save(args.out)
    log.info("wrote %s", args.out)


if __name__ == "__main__":
    main()
