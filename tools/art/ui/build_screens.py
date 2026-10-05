"""Build every screen background from art_src/finals/screens/ (single data-driven table).

Each source is cover-fitted to 1920x1080, written as assets/art/screens/<image>.webp and
every screen id gets assets/art/screens/<id>.tres (a ScreenArt: texture + dim + tint), which
is what ScreenArt.for_screen(id) loads at runtime. Usage:
    python3 tools/art/ui/build_screens.py [--check]
"""
from __future__ import annotations

import argparse
import logging
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "art_src/finals/screens"
OUT = ROOT / "assets/art/screens"
SIZE = (1920, 1080)
QUALITY = 86
log = logging.getLogger("build_screens")

WORLDS = ("lawn", "pool", "night", "desert", "roof", "frost", "factory", "moon")


@dataclass(frozen=True)
class Screen:
    """One screen id -> source image + readability dim + tint (r, g, b)."""
    image: str
    dim: float = 0.0
    tint: tuple[float, float, float] = (1.0, 1.0, 1.0)


SCREENS: dict[str, Screen] = {
    "menu": Screen("bg_menu"),
    "loading": Screen("bg_loading", 0.1),
    "help": Screen("bg_menu", 0.5),
    "stats": Screen("bg_menu", 0.5),
    "settings": Screen("bg_menu", 0.45),
    "hub": Screen("bg_hub", 0.1),
    "workshop": Screen("bg_hub", 0.3, (1.0, 0.95, 0.88)),
    "almanac": Screen("bg_almanac", 0.15),
    "quests": Screen("bg_almanac", 0.35, (0.95, 0.97, 1.0)),
    "shop": Screen("bg_shop", 0.1),
}
SCREENS.update({f"map_{w}": Screen(f"map_{w}", 0.05) for w in WORLDS})


def cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale to cover `size` (centre crop), with a light unsharp after upscaling."""
    sx, sy = size[0] / img.width, size[1] / img.height
    s = max(sx, sy)
    w, h = round(img.width * s), round(img.height * s)
    big = img.resize((w, h), Image.Resampling.LANCZOS)
    if s > 1.0:
        big = big.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    x, y = (w - size[0]) // 2, (h - size[1]) // 2
    return big.crop((x, y, x + size[0], y + size[1]))


def tres(screen: Screen) -> str:
    r, g, b = screen.tint
    return (
        '[gd_resource type="Resource" script_class="ScreenArt" load_steps=3 format=3]\n\n'
        '[ext_resource type="Script" path="res://core/art/screen_art.gd" id="1"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/art/screens/{screen.image}.webp" id="2"]\n\n'
        '[resource]\nscript = ExtResource("1")\ntexture = ExtResource("2")\n'
        f"dim = {screen.dim}\ntint = Color({r}, {g}, {b}, 1)\n"
    )


def build_all(check: bool = False) -> int:
    """Build images + .tres. Returns the number of missing sources (loud, never silent)."""
    OUT.mkdir(parents=True, exist_ok=True)
    missing = 0
    for image in sorted({s.image for s in SCREENS.values()}):
        src = SRC / f"{image}.webp"
        if not src.exists():
            log.error("MISSING screen source %s", src.relative_to(ROOT))
            missing += 1
            continue
        if not check:
            cover(Image.open(src).convert("RGB"), SIZE).save(OUT / f"{image}.webp", quality=QUALITY, method=6)
            log.info("%s.webp", image)
    for sid, screen in SCREENS.items():
        if not check:
            (OUT / f"{sid}.tres").write_text(tres(screen), encoding="utf-8")
    return missing


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="only verify that every source exists")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    sys.exit(1 if build_all(args.check) else 0)


if __name__ == "__main__":
    main()
