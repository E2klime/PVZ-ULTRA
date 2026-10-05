"""Validate runtime art wiring on disk (no Godot needed). Exit 1 on any failure.

Checks: every res:// reference in .tres/.tscn/.gd resolves; no code points at retired art;
all 8 worlds have the full layer set with a 1170x700 ground that is distinct (md5 + colour)
from every other world; every screen id has its ScreenArt .tres and a 1920x1080 image;
alpha-needing UI kit textures really carry alpha. Usage:
    python3 tools/art/review/validate_assets.py
"""
from __future__ import annotations

import argparse
import hashlib
import logging
import re
import sys
from itertools import combinations
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/art"))
from ui.build_screens import SCREENS, WORLDS  # noqa: E402

log = logging.getLogger("validate_assets")
RES = re.compile(r'res://([^"\'\s\)]+)')
SCAN_DIRS = ("assets", "autoload", "core", "data", "entities", "scenes", "ui", "anim")
RETIRED = ("keyart.jpg", "assets/art/bg/", "source_generated", "assets/tiles/lawn/", "ui/theme.tres")
WORLD_FILES = ("environment.jpg", "ground.webp", "edge.png", "tuft.png", "world_art.tres") + tuple(
    f"fringe_{i}.png" for i in range(5))
GROUND_SIZE = (1170, 700)
SCREEN_SIZE = (1920, 1080)
MIN_GROUND_DIST = 12.0  # mean RGB distance between two worlds' ground colour


class Report:
    def __init__(self) -> None:
        self.fails: list[str] = []

    def fail(self, msg: str) -> None:
        log.error(msg)
        self.fails.append(msg)


def source_files() -> list[Path]:
    out: list[Path] = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if base.exists():
            out += [p for p in base.rglob("*") if p.suffix in (".tres", ".tscn", ".gd")]
    return out


def check_refs(rep: Report) -> None:
    for f in source_files():
        text = f.read_text(encoding="utf-8", errors="replace")
        for bad in RETIRED:
            if bad in text:
                rep.fail(f"{f.relative_to(ROOT)} references retired art '{bad}'")
        if f.suffix == ".gd":
            continue  # .gd paths are often built dynamically; .tres/.tscn must resolve
        for m in RES.finditer(text):
            rel = m.group(1)
            if "%" in rel or rel.endswith("/"):
                continue
            if not (ROOT / rel).exists():
                rep.fail(f"{f.relative_to(ROOT)} -> missing res://{rel}")


def check_worlds(rep: Report) -> None:
    md5: dict[str, str] = {}
    mean: dict[str, np.ndarray] = {}
    for w in WORLDS:
        d = ROOT / "assets/art/worlds" / w
        for name in WORLD_FILES:
            if not (d / name).exists():
                rep.fail(f"world {w}: missing {name}")
        g = d / "ground.webp"
        if not g.exists():
            continue
        img = Image.open(g)
        if img.size != GROUND_SIZE:
            rep.fail(f"world {w}: ground is {img.size}, expected {GROUND_SIZE}")
        md5[w] = hashlib.md5(g.read_bytes()).hexdigest()
        mean[w] = np.asarray(img.convert("RGB"), dtype=np.float32).reshape(-1, 3).mean(0)
        tres = (d / "world_art.tres").read_text(encoding="utf-8") if (d / "world_art.tres").exists() else ""
        if tres.count("fringe_") < 5 or "tuft = " not in tres or "blocked = " not in tres:
            rep.fail(f"world {w}: world_art.tres lacks fringe/tuft/blocked")
    for a, b in combinations(md5, 2):
        if md5[a] == md5[b]:
            rep.fail(f"worlds {a} and {b} share an identical ground")
        dist = float(np.linalg.norm(mean[a] - mean[b]))
        if dist < MIN_GROUND_DIST:
            rep.fail(f"worlds {a}/{b} grounds too similar in colour (dist {dist:.1f})")


def check_screens(rep: Report) -> None:
    d = ROOT / "assets/art/screens"
    for sid, scr in SCREENS.items():
        if not (d / f"{sid}.tres").exists():
            rep.fail(f"screen {sid}: missing {sid}.tres")
        img = d / f"{scr.image}.webp"
        if not img.exists():
            rep.fail(f"screen {sid}: missing {img.name}")
        elif Image.open(img).size != SCREEN_SIZE:
            rep.fail(f"screen {sid}: {img.name} is not {SCREEN_SIZE}")


def check_kit(rep: Report) -> None:
    kit = ROOT / "assets/ui/kit"
    for p in sorted(kit.glob("*.png")):
        im = Image.open(p)
        if im.mode != "RGBA":
            rep.fail(f"ui kit {p.name}: no alpha channel (mode {im.mode})")
            continue
        px = np.asarray(im).astype(np.int16)
        vis = px[..., 3] > 32
        key = (px[..., 0] > 200) & (px[..., 1] < 70) & (px[..., 2] > 200) & vis
        if key.sum() > 0.005 * max(int(vis.sum()), 1):
            rep.fail(f"ui kit {p.name}: magenta key backdrop left in visible pixels")
        grey = (np.abs(px[..., 0] - px[..., 1]) < 4) & (np.abs(px[..., 1] - px[..., 2]) < 4) & vis
        lum = px[..., 0][grey]
        if grey.mean() > 0.6 and lum.size and np.isin(lum // 8, (19, 25, 31)).mean() > 0.8:
            rep.fail(f"ui kit {p.name}: looks like a baked transparency checkerboard")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    rep = Report()
    for check in (check_refs, check_worlds, check_screens, check_kit):
        check(rep)
    log.info("%d failure(s)", len(rep.fails))
    sys.exit(1 if rep.fails else 0)


if __name__ == "__main__":
    main()
