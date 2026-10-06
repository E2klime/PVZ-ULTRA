#!/usr/bin/env python3
"""Split a concept sheet into one image per figure by connected components (robust to the
model not respecting an exact grid). Figures are ordered in reading order (rows, then x).

    python3 tools/art/plants/split_sheet.py sheet.png <rows> id1 id2 ...   ("-" skips a figure)
Writes art_src/plants/concepts/<id>.webp, then cut with ingest.py --rebuild-ids.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]


def main(path, rows, ids):
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    fg = (al > 128) & ~((r > 200) & (b > 200) & (g < 90))
    fg = ndimage.binary_opening(fg, iterations=2)
    lbl, n = ndimage.label(ndimage.binary_dilation(fg, iterations=int(sys.argv[-1][2:]) if sys.argv[-1].startswith("-d") else 14))
    objs = ndimage.find_objects(lbl)
    sizes = ndimage.sum(fg, lbl, range(1, n + 1))
    keep = [i for i in range(n) if sizes[i] > sizes.max() * 0.08]
    boxes = [objs[i] for i in keep]
    h = im.size[1]
    boxes.sort(key=lambda s: (int(((s[0].start + s[0].stop) / 2) / (h / rows)), s[1].start))
    print(f"{len(boxes)} figures for {len(ids)} ids")
    if len(boxes) != len(ids):
        sys.exit("count mismatch: fix ids/rows")
    out = ROOT / "art_src/plants/concepts"
    for s, pid in zip(boxes, ids):
        if pid == "-":
            continue
        m = 12
        crop = im.crop((max(0, s[1].start - m), max(0, s[0].start - m), s[1].stop + m, s[0].stop + m))
        k = min(1.0, 768 / max(crop.size))
        crop = crop.resize((round(crop.size[0] * k), round(crop.size[1] * k)), Image.LANCZOS)
        bg = Image.new("RGBA", crop.size, (255, 0, 255, 255))
        bg.alpha_composite(crop)
        bg.save(out / f"{pid}.webp", quality=92)
        print(pid, crop.size)


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]), [a for a in sys.argv[3:] if not a.startswith("-d")])
