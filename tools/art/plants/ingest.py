#!/usr/bin/env python3
"""Ingest raw 1024 px concept PNGs (from the image model) and cut them into rigs.

    python3 tools/art/plants/ingest.py /tmp/concepts/*.png     # stores art_src/plants/concepts/<id>.webp
    python3 tools/art/plants/ingest.py --grid sheet.png a b c d   # 2x2 sheet, one plant per quadrant
    python3 tools/art/plants/ingest.py --rebuild               # re-cut every stored concept

Per-plant fit tweaks live in art_src/plants/fit.json ({"id": scale_hint}).
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CON = ROOT / "art_src/plants/concepts"


def cut(pid):
    fit = json.loads((ROOT / "art_src/plants/fit.json").read_text()) if (ROOT / "art_src/plants/fit.json").exists() else {}
    subprocess.run([sys.executable, str(ROOT / "tools/art/plants/cut_plant.py"), pid,
                    str(CON / f"{pid}.webp"), str(fit.get(pid, 1.0))], check=True)


def main(args):
    CON.mkdir(parents=True, exist_ok=True)
    if args and args[0] == "--grid":
        # --grid sheet.png id_tl id_tr id_bl id_br : 2x2 sheet, one plant per quadrant
        im = Image.open(args[1]).convert("RGB")
        w, h = im.size
        ids = [a for a in args[2:6] if a != "-"]
        for i, pid in enumerate(args[2:6]):
            if pid == "-":
                continue
            q = im.crop(((i % 2) * w // 2, (i // 2) * h // 2, (i % 2 + 1) * w // 2, (i // 2 + 1) * h // 2))
            k = 768 / max(q.size)
            q.resize((round(q.size[0] * k), round(q.size[1] * k)), Image.LANCZOS).save(CON / f"{pid}.webp", quality=90)
    elif args == ["--rebuild"]:
        ids = sorted(p.stem for p in CON.glob("*.webp"))
    else:
        ids = []
        for a in args:
            p = Path(a)
            im = Image.open(p).convert("RGB")
            k = 768 / max(im.size)
            im.resize((round(im.size[0] * k), round(im.size[1] * k)), Image.LANCZOS).save(CON / f"{p.stem}.webp", quality=90)
            ids.append(p.stem)
    for pid in ids:
        cut(pid)
    subprocess.run(["oxipng", "-o", "3", "-q", "--strip", "safe"] +
                   [str(f) for pid in ids for f in (ROOT / f"assets/sprites/plants/{pid}").glob("*.png")])


if __name__ == "__main__":
    main(sys.argv[1:])
