"""Slice the painted widget sheet (art_src/finals/ui/ui_widgets_v1.webp) into theme icons.

The sheet holds 8 items in reading order (alpha background):
    check_off, check_on, radio_off, radio_on, knob, knob_hover, arrow_down, slider_track
Icons are scaled to fixed heights; the slider groove also gets a 9-slice StyleBoxTexture.
Usage:
    python3 tools/art/ui/build_widgets.py [--out assets/ui/kit]
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
from ui import kit_ops as k  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SHEET = ROOT / "art_src/finals/ui/ui_widgets_v1.webp"
log = logging.getLogger("build_widgets")
# name -> output height in px (width follows aspect)
ITEMS: list[tuple[str, int]] = [
    ("check_off", 40), ("check_on", 40), ("radio_off", 40), ("radio_on", 40),
    ("knob", 38), ("knob_hover", 38), ("arrow_down", 22), ("slider_track", 18),
]
TRACK_W = 240


def load_sheet() -> np.ndarray:
    rgba = np.asarray(Image.open(SHEET).convert("RGBA"), np.float32) / 255.0
    rgba[..., :3] *= (rgba[..., 3:4] > 0.01)  # drop the painted glow living in transparent px
    return rgba


def slider_tres(png: str) -> str:
    return "\n".join([
        '[gd_resource type="StyleBoxTexture" load_steps=2 format=3]', "",
        f'[ext_resource type="Texture2D" path="{png}" id="1_tex"]', "", "[resource]",
        "content_margin_left = 4.0", "content_margin_top = 4.0",
        "content_margin_right = 4.0", "content_margin_bottom = 4.0",
        'texture = ExtResource("1_tex")',
        "texture_margin_left = 9.0", "texture_margin_top = 8.0",
        "texture_margin_right = 9.0", "texture_margin_bottom = 8.0", "",
    ])


def build(out: Path) -> None:
    sheet = load_sheet()
    boxes = keying.components(sheet, min_area=2000)
    if len(boxes) != len(ITEMS):
        raise RuntimeError(f"widget sheet: expected {len(ITEMS)} items, found {len(boxes)}: {boxes}")
    for (name, h), (x0, y0, x1, y1) in zip(ITEMS, boxes):
        a = keying.trim(np.ascontiguousarray(sheet[y0:y1, x0:x1]))
        a = k.scale_h(a, h) if name != "slider_track" else keying.resize(a, (TRACK_W, h))
        k.save(a, out / f"{name}.png")
        log.info("%-14s %dx%d", name, a.shape[1], a.shape[0])
    rel = "res://" + str((out / "slider_track.png").relative_to(ROOT))
    (out / "styles").mkdir(parents=True, exist_ok=True)
    (out / "styles/slider_track.tres").write_text(slider_tres(rel))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "assets/ui/kit")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    build(args.out.resolve())


if __name__ == "__main__":
    main()
