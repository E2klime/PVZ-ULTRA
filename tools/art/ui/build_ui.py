"""Build the raster UI kit from model-painted sources in art_src/finals/ui/.

Every element is keyed off its magenta backdrop, scaled so the frame lands at a
fixed pixel thickness, colour-graded into the style-bible palette and exported as
PNG + a StyleBoxTexture .tres (9-slice margins measured from the source). Button
states (hover/pressed/disabled/focus) are derived here, never painted separately,
so they always match. Usage:
    python3 tools/art/ui/build_ui.py [--out assets/ui/kit]
"""
from __future__ import annotations

import argparse
import logging
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ui import kit_ops as k  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
log = logging.getLogger("build_ui")
Op = Callable[[np.ndarray], np.ndarray]

LEAF_HUE = 98.0
GOLD_HUE = 42.0
SUN = (1.0, 0.86, 0.32)


@dataclass(frozen=True)
class Box:
    """One 9-slice texture. margins/content are (l, t, r, b) in output pixels."""
    name: str
    src: str
    width: int = 0
    height: int = 0
    margins: tuple[int, int, int, int] = (0, 0, 0, 0)
    content: tuple[int, int, int, int] = (-1, -1, -1, -1)
    ops: tuple[Op, ...] = ()
    tile: bool = False
    rotate: bool = False
    extra: dict[str, str] = field(default_factory=dict)
    crop: tuple[float, float, float, float] = (0.0, 0.0, 1.0, 1.0)


def leaf(a: np.ndarray) -> np.ndarray:
    return k.grade(a, hue_to=LEAF_HUE, hue_mix=0.6, sat=0.72, val=0.9)


def hover(a: np.ndarray) -> np.ndarray:
    return k.grade(a, sat=1.06, val=1.1, lift=0.02)


def press(a: np.ndarray) -> np.ndarray:
    return k.grade(a, sat=1.05, val=0.82)


def dis(a: np.ndarray) -> np.ndarray:
    return k.desaturate(a, 0.85, 0.04)


def gold(a: np.ndarray) -> np.ndarray:
    return k.grade(a, hue_to=GOLD_HUE, hue_mix=0.85, sat=1.15, val=1.06, min_sat=0.05)


def danger(a: np.ndarray) -> np.ndarray:
    return k.grade(a, hue_to=6.0, hue_mix=1.0, sat=0.85, val=0.92)


def dark(a: np.ndarray) -> np.ndarray:
    return k.grade(a, sat=0.9, val=0.78)


def bright(a: np.ndarray) -> np.ndarray:
    return k.grade(a, val=1.12)


BTN = dict(height=72, margins=(36, 22, 36, 26), content=(28, 10, 28, 14))
BAR = dict(height=30, margins=(15, 10, 15, 10), content=(0, 0, 0, 0))
KIT: list[Box] = [
    Box("panel", "ui_panel_paper_v1", width=360, margins=(30, 30, 30, 30), content=(30, 28, 30, 28)),
    Box("panel_small", "ui_panel_paper_v1", width=180, margins=(15, 15, 15, 15), content=(14, 12, 14, 12)),
    Box("board", "ui_panel_wood_v1", width=420, margins=(26, 26, 26, 26), content=(22, 20, 22, 20)),
    Box("board_small", "ui_panel_wood_v1", width=200, margins=(13, 13, 13, 13), content=(10, 8, 10, 8)),
    Box("pill", "ui_pill_wood_v1", height=64, margins=(32, 18, 32, 18), content=(22, 6, 22, 6)),
    Box("button", "ui_button_green_v1", ops=(leaf,), **BTN),
    Box("button_hover", "ui_button_green_v1", ops=(leaf, hover), **BTN),
    Box("button_pressed", "ui_button_green_v1", ops=(leaf, press), **{**BTN, "content": (28, 13, 28, 11)}),
    Box("button_disabled", "ui_button_green_v1", ops=(leaf, dis), **BTN),
    Box("button_wood", "ui_pill_wood_v1", **BTN),
    Box("button_wood_hover", "ui_pill_wood_v1", ops=(hover,), **BTN),
    Box("button_wood_pressed", "ui_pill_wood_v1", ops=(press,), **{**BTN, "content": (28, 13, 28, 11)}),
    Box("tab_selected", "ui_panel_paper_v1", width=150, margins=(13, 13, 13, 4), content=(16, 8, 16, 6)),
    Box("tab", "ui_panel_wood_v1", width=150, margins=(10, 10, 10, 4), content=(16, 8, 16, 6)),
    Box("tab_hover", "ui_panel_wood_v1", width=150, margins=(10, 10, 10, 4), content=(16, 8, 16, 6), ops=(bright,)),
    Box("bar_bg", "ui_pill_wood_v1", ops=(dark,), **BAR),
    Box("bar_fill", "ui_button_green_v1", ops=(leaf,), **BAR),
    Box("bar_fill_gold", "ui_button_green_v1", ops=(gold,), **BAR),
    Box("scroll_track", "ui_pill_wood_v1", height=18, margins=(9, 9, 9, 9), content=(4, 4, 4, 4), ops=(dark,), rotate=True),
    Box("scroll_grab", "ui_button_green_v1", height=18, margins=(9, 9, 9, 9), content=(4, 4, 4, 4), ops=(leaf,), rotate=True),
    Box("scroll_grab_hover", "ui_button_green_v1", height=18, margins=(9, 9, 9, 9), content=(4, 4, 4, 4), ops=(leaf, hover), rotate=True),
    Box("card", "ui_card_v1", width=108, margins=(17, 26, 17, 53), content=(0, 0, 0, 0)),
    Box("card_legend", "ui_card_v1", width=108, margins=(17, 26, 17, 53), content=(0, 0, 0, 0), ops=(gold,)),
    Box("packet", "ui_panel_paper_v1", width=150, margins=(12, 12, 12, 12), content=(8, 6, 8, 6)),
    Box("packet_legend", "ui_panel_paper_v1", width=150, margins=(12, 12, 12, 12), content=(8, 6, 8, 6), ops=(gold,)),
    Box("packet_hover", "ui_panel_paper_v1", width=150, margins=(12, 12, 12, 12), content=(8, 6, 8, 6), ops=(bright,)),
    Box("packet_legend_hover", "ui_panel_paper_v1", width=150, margins=(12, 12, 12, 12), content=(8, 6, 8, 6), ops=(gold, bright)),
    Box("button_danger", "ui_button_green_v1", ops=(danger,), **BTN),
    Box("button_danger_hover", "ui_button_green_v1", ops=(danger, hover), **BTN),
    Box("tag", "ui_pill_wood_v1", height=32, margins=(16, 10, 16, 10), content=(0, 0, 0, 0)),
    Box("tag_poor", "ui_pill_wood_v1", height=32, margins=(16, 10, 16, 10), content=(0, 0, 0, 0), ops=(dis,)),
    Box("window", "ui_card_v1", width=96, margins=(14, 14, 14, 14), content=(0, 0, 0, 0), crop=(0.06, 0.08, 0.94, 0.755)),
    Box("window_legend", "ui_card_v1", width=96, margins=(14, 14, 14, 14), content=(0, 0, 0, 0), crop=(0.06, 0.08, 0.94, 0.755), ops=(gold,)),
    Box("note", "ui_card_v1", width=180, margins=(28, 40, 28, 40), content=(26, 36, 26, 46), ops=(lambda a: k.grade(a, hue_to=48, hue_mix=1.0, sat=0.35, val=1.04),), tile=False),
]


def sized(src: np.ndarray, b: Box) -> np.ndarray:
    h, w = src.shape[:2]
    x0, y0, x1, y1 = b.crop
    a = np.ascontiguousarray(src[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)])
    if b.rotate:
        a = k.rotate90(a)
        return k.scale_w(a, b.height)
    if b.width:
        return k.scale_w(a, b.width)
    return k.scale_h(a, b.height)


def tres(b: Box, png: str, size: tuple[int, int]) -> str:
    l, t, r, bt = b.margins
    if b.rotate:
        l, t, r, bt = t, l, bt, r
    c = b.content if b.content[0] >= 0 else b.margins
    if b.rotate:
        c = (c[1], c[0], c[3], c[2])
    stretch = 2 if b.tile else 0
    lines = [
        '[gd_resource type="StyleBoxTexture" load_steps=2 format=3]', "",
        f'[ext_resource type="Texture2D" path="{png}" id="1_tex"]', "", "[resource]",
        f"content_margin_left = {float(c[0])}", f"content_margin_top = {float(c[1])}",
        f"content_margin_right = {float(c[2])}", f"content_margin_bottom = {float(c[3])}",
        'texture = ExtResource("1_tex")',
        f"texture_margin_left = {float(l)}", f"texture_margin_top = {float(t)}",
        f"texture_margin_right = {float(r)}", f"texture_margin_bottom = {float(bt)}",
        f"axis_stretch_horizontal = {stretch}", f"axis_stretch_vertical = {stretch}",
    ]
    lines += [f"{key} = {val}" for key, val in b.extra.items()]
    return "\n".join(lines) + "\n"


def build_boxes(out: Path) -> None:
    cache: dict[str, np.ndarray] = {}
    for b in KIT:
        if b.src not in cache:
            cache[b.src] = k.load(b.src)
        a = sized(cache[b.src], b)
        for op in b.ops:
            a = op(a)
        k.save(a, out / f"{b.name}.png")
        (out / "styles").mkdir(parents=True, exist_ok=True)
        rel = "res://" + str((out / f"{b.name}.png").relative_to(ROOT))
        (out / "styles" / f"{b.name}.tres").write_text(tres(b, rel, (a.shape[1], a.shape[0])))
        log.info("%-20s %dx%d", b.name, a.shape[1], a.shape[0])
    btn = sized(cache["ui_button_green_v1"], Box("f", "", **BTN))
    focus = k.glow_ring(btn, SUN, 4, 6)
    k.save(focus, out / "button_focus.png")
    fb = Box("button_focus", "", height=0, margins=(42, 28, 42, 32), content=(28, 10, 28, 14))
    rel = "res://" + str((out / "button_focus.png").relative_to(ROOT))
    (out / "styles/button_focus.tres").write_text(tres(fb, rel, (focus.shape[1], focus.shape[0])))
    ring, disc = k.split_disc(k.load("ui_round_v1"), 0.735)
    k.save(k.scale_w(ring, 128), out / "round_ring.png")
    k.save(k.scale_w(disc, 128), out / "round_disc.png")
    k.save(k.glow_ring(k.scale_w(ring, 128), SUN, 5, 8), out / "round_glow.png")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "assets/ui/kit")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    build_boxes(args.out.resolve())
    from ui import build_screens, build_thumbs, build_widgets  # noqa: E402
    build_widgets.build(args.out.resolve())
    build_thumbs.build_all()
    if build_screens.build_all():
        raise SystemExit("build_ui: screen sources missing (see errors above)")

if __name__ == "__main__":
    main()
