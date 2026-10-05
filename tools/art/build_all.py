"""One-command rebuild of every generated runtime art asset.

Re-runs the deterministic post-processing over the committed model finals in
art_src/finals/ (it never calls the image model). Stages:
    worlds   environment plate, ground layer, edge/fringe overlays, world_art.tres
    ui       UI kit: 9-slice frames, buttons, cards, icons, screen backgrounds, logo
    validate tools/art/review/validate_assets.py
    import   godot --headless --import
Usage:
    python3 tools/art/build_all.py                 # everything
    python3 tools/art/build_all.py --only worlds --world desert
"""
from __future__ import annotations

import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "tools/art"
ENV = ROOT / "art_src/finals/env"
log = logging.getLogger("build_all")

# world -> environment plate (shared plates are graded per world by palettes.json)
WORLD_PLATES: dict[str, str] = {
    "lawn": "env_garden_v3.webp",
    "night": "env_garden_v3.webp",
    "pool": "env_garden_v3.webp",
    "desert": "env_desert_v1.webp",
    "roof": "env_roof_v1.webp",
    "frost": "env_frost_v1.webp",
    "factory": "env_factory_v1.webp",
    "moon": "env_moon_v1.webp",
}
STAGES = ("worlds", "ui", "validate", "import")


def run(*args: str | Path) -> None:
    cmd = [str(a) for a in args]
    log.debug("$ %s", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True)


def py(script: str, *args: str | Path) -> None:
    run(sys.executable, ART / script, *args)


def build_world(world: str) -> None:
    out = ROOT / "assets/art/worlds" / world
    out.mkdir(parents=True, exist_ok=True)
    py("process/plate.py", ENV / WORLD_PLATES[world], out / "environment.jpg", "--world", world)
    py("assemble/lawn_surface.py", "--world", world, "--out", out / "ground.png")
    py("assemble/lawn_edges.py", "--world", world, "--ground", out / "ground.png", "--out-dir", out)
    py("export/world_art_tres.py", "--world", world)
    log.info("world %s done", world)


def build_ui() -> None:
    py("ui/build_ui.py")


def godot_import() -> None:
    godot = shutil.which("godot") or str(Path.home() / "bin/godot")
    env = dict(os.environ, HOME=os.environ.get("GODOT_HOME", "/tmp/gdhome"))
    subprocess.run([godot, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT, env=env,
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", choices=STAGES, action="append", help="run only these stages")
    ap.add_argument("--world", choices=sorted(WORLD_PLATES), action="append", help="limit the worlds stage")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, format="%(name)s: %(message)s")
    stages = args.only or list(STAGES)
    if "worlds" in stages:
        for w in args.world or WORLD_PLATES:
            build_world(w)
    if "ui" in stages:
        build_ui()
    if "import" in stages:
        godot_import()
    if "validate" in stages:
        py("review/validate_assets.py")


if __name__ == "__main__":
    main()
