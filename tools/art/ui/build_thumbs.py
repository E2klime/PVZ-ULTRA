"""Compose per-world hub thumbnails from the built battle layers (environment + lawn + edge).

The hub shows each world as its actual battlefield, so thumbnails are derived from
assets/art/worlds/<w>/ and never drawn by hand. Usage:
    python3 tools/art/ui/build_thumbs.py [--size 400x225]
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
WORLDS = ROOT / "assets/art/worlds"
OUT = ROOT / "assets/ui/kit/thumbs"
BOARD_POS = (310, 200)
EDGE_MARGIN = 40
log = logging.getLogger("build_thumbs")


def compose(world: Path) -> Image.Image:
    img = Image.open(world / "environment.jpg").convert("RGBA")
    ground = Image.open(world / "ground.png").convert("RGBA")
    img.alpha_composite(ground, BOARD_POS)
    edge_path = world / "edge.png"
    if edge_path.exists():
        edge = Image.open(edge_path).convert("RGBA")
        img.alpha_composite(edge, (BOARD_POS[0] - EDGE_MARGIN, BOARD_POS[1] - EDGE_MARGIN))
    # frame the lawn: crop to board plus a little scenery, 16:9
    x0, y0, x1, y1 = 180, 120, 1640, 941
    return img.crop((x0, y0, x1, y1)).convert("RGB")


def build_all(size: tuple[int, int] = (400, 225)) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for world in sorted(p for p in WORLDS.iterdir() if (p / "environment.jpg").exists()):
        thumb = compose(world).resize(size, Image.LANCZOS)
        thumb.save(OUT / f"{world.name}.jpg", quality=88)
        log.info("thumb %s", world.name)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", default="400x225")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    w, h = (int(v) for v in args.size.split("x"))
    build_all((w, h))


if __name__ == "__main__":
    main()
