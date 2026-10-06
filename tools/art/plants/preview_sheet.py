#!/usr/bin/env python3
"""Rest-pose preview of plant rigs on the lawn ground + 96 px silhouettes + pairwise IoU.

    python3 tools/art/plants/preview_sheet.py out.jpg [ids...]      (no ids = all plants)
Prints every pair with silhouette IoU >= 0.80 (near-duplicates to redesign).
"""
import json
import sys
from itertools import combinations
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
PLANTS = ROOT / "assets/sprites/plants"
HIDDEN = {"lids", "buried", "body_1", "body_2", "light"}


def render(pid):
    rig = json.loads((PLANTS / pid / "rig.json").read_text())
    by = {p["name"]: p for p in rig["parts"]}
    piv = {}

    def pv(n):
        if n not in piv:
            p = by[n]
            par = p.get("parent")
            base = pv(par) if par and par in by else (0.0, 0.0)
            piv[n] = (base[0] + p["pos"][0], base[1] + p["pos"][1])
        return piv[n]

    canvas = Image.new("RGBA", (300, 340))
    org = (150, 300)
    for p in sorted(rig["parts"], key=lambda q: q.get("z", 0)):
        if p["name"] in HIDDEN:
            continue
        im = Image.open(PLANTS / pid / f"{p['name']}.png").convert("RGBA")
        im = im.resize((max(1, int(p["size"][0])), max(1, int(p["size"][1]))))
        x, y = pv(p["name"])
        canvas.alpha_composite(im, (int(org[0] + x + p["offset"][0]), int(org[1] + y + p["offset"][1])))
    return canvas


def silhouette(img):
    a = img.split()[3]
    bb = a.getbbox()
    a = a.crop(bb)
    s = 96 / max(a.size)
    a = a.resize((max(1, int(a.size[0] * s)), max(1, int(a.size[1] * s))))
    sq = Image.new("L", (96, 96))
    sq.paste(a, ((96 - a.size[0]) // 2, 96 - a.size[1]))
    return np.array(sq) > 100


def main(out, ids):
    ids = ids or sorted(p.name for p in PLANTS.iterdir() if (p / "rig.json").exists())
    ground = Image.open(ROOT / "assets/art/worlds/lawn/ground.webp").convert("RGBA")
    cols = 8
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 170, rows * 260), (30, 30, 30))
    sil = {}
    for i, pid in enumerate(ids):
        img = render(pid)
        sil[pid] = silhouette(img)
        cell = ground.crop((130 * (i % 9), 140 * (i % 5), 130 * (i % 9) + 300, 140 * (i % 5) + 340))
        cell.alpha_composite(img)
        tile = cell.resize((150, 170))
        x, y = (i % cols) * 170, (i // cols) * 260
        sheet.paste(tile.convert("RGB"), (x + 10, y + 4))
        s = Image.fromarray((~sil[pid] * 255).astype(np.uint8)).resize((64, 64))
        sheet.paste(s, (x + 53, y + 176))
        ImageDraw.Draw(sheet).text((x + 10, y + 244), pid[:22], fill=(240, 240, 240))
    sheet.save(out, quality=88)
    bad = []
    for a, b in combinations(ids, 2):
        iou = (sil[a] & sil[b]).sum() / max(1, (sil[a] | sil[b]).sum())
        if iou >= 0.80:
            bad.append((round(float(iou), 3), a, b))
    for t in sorted(bad, reverse=True):
        print("NEAR-DUPLICATE", *t)
    print(f"preview: {len(ids)} plants, {len(bad)} pairs with IoU >= 0.80")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
