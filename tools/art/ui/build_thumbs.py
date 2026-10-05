"""Per-world hub thumbnails, cut from that world's painted overworld (art_src/finals/screens/map_<w>).

The bare battle ground read as flat stripes on the hub (and lacked the pool, which is drawn
at runtime), so cards now show the same painted world the map screen uses. Usage:
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
MAPS = ROOT / "art_src/finals/screens"
log = logging.getLogger("build_thumbs")


def compose(world: Path) -> Image.Image:
    src = MAPS / f"map_{world.name}.webp"
    if not src.exists():
        raise FileNotFoundError(f"build_thumbs: MISSING map art {src}")
    img = Image.open(src).convert("RGB")
    # keep the full painted frame (props live at the borders), 16:9
    w, h = img.size
    ch = round(w * 9 / 16)
    y0 = max(0, (h - ch) // 2)
    return img.crop((0, y0, w, y0 + min(ch, h)))


def build_all(size: tuple[int, int] = (400, 225)) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for world in sorted(p for p in WORLDS.iterdir() if (p / "environment.jpg").exists()):
        thumb = compose(world).resize(size, Image.LANCZOS)
        thumb.save(OUT / f"{world.name}.jpg", quality=86)
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
