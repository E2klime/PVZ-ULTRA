"""Write assets/art/worlds/<world>/world_art.tres (WorldArtConfig) from palettes.json.

Only references files that exist, so worlds without a fringe (sand, tile...) get an
empty fringe array. Usage:
    python3 tools/art/export/world_art_tres.py --world lawn
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import board, palette  # noqa: E402

log = logging.getLogger("world_art_tres")
WORLDS_DIR = palette.ROOT / "assets" / "art" / "worlds"
KIT = "res://assets/art/garden_kit/contact_shadow.png"


def color(h: str, a: float = 1.0) -> str:
    r, g, b = palette.hex_rgb(h)
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a:.3f})"

PROPS = {"tile": "tiles", "snow": "ice", "gravel": "moonrock"}  # ground type -> obstacle prop


def write(world: str) -> Path:
    pal = palette.load()["worlds"][world]
    d = WORLDS_DIR / world
    res = f"res://assets/art/worlds/{world}/"
    ext: list[tuple[str, str]] = []  # (id, path)

    def ref(path: str) -> str:
        ext.append((f"{len(ext) + 1}_tex", path))
        return f'ExtResource("{len(ext)}_tex")'

    env = ref(res + "environment.jpg")
    ground = ref(res + "ground.png")
    edge = ref(res + "edge.png")
    shadow = ref(KIT)
    fringe = [ref(res + f"fringe_{r}.png") for r in range(board.ROWS) if (d / f"fringe_{r}.png").exists()]
    tuft = ref(res + "tuft.png") if (d / "tuft.png").exists() else "null"
    prop = PROPS.get(pal["ground"], "boulder")
    blocked = ref(f"res://assets/art/props/blocked_{prop}.png")
    tint = pal.get("light_tint", "#ffffff")
    lines = [f'[gd_resource type="Resource" script_class="WorldArtConfig" load_steps={len(ext) + 2} format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://core/art/world_art_config.gd" id="0_cfg"]')
    for i, p in ext:
        lines.append(f'[ext_resource type="Texture2D" path="{p}" id="{i}"]')
    lines += ["", "[resource]", 'script = ExtResource("0_cfg")',
              f"environment = {env}", f"ground = {ground}", f"edge = {edge}", "edge_margin = 40.0",
              f'fringe = Array[Texture2D]([{", ".join(fringe)}])', "fringe_offset_y = -20.0", f"tuft = {tuft}", f"blocked = {blocked}",
              f"contact_shadow = {shadow}", "contact_shadow_color = Color(1, 1, 1, 0.8)",
              "contact_shadow_offset = Vector2(10, 0)", f"light_tint = {color(tint)}",
              f"accent = {color(pal['accent'])}", f'ground_type = &"{pal["ground"]}"', ""]
    out = d / "world_art.tres"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--world", default="lawn", choices=palette.world_names())
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    log.info("wrote %s", write(args.world))


if __name__ == "__main__":
    main()
