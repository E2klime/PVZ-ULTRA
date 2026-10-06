#!/usr/bin/env python3
"""Cut one painted plant concept (flat #FF00FF background) into the plant's existing rig.

    python3 tools/art/plants/cut_plant.py <plant_id> art_src/plants/concepts/<plant_id>.webp

The OLD rig.json is the contract: part names, parents, pivots (pos), z order and meta
(muzzles, platform) never change, so gameplay anchors and animation clips stay valid.
How it works:
  1. Render the old rig at rest into a *label map* (which part owns each pixel).
  2. Key + despill the concept, fit it into the old figure's box, feet on the root.
  3. Every new pixel takes the label of the matching old pixel (bbox-normalised, nearest
     label outside the old silhouette), so any template (stem/head, rotor, arm, wing,
     canopy, jaw) splits automatically. Each part bleeds a few px under the parts drawn
     above it so joints never open a seam while animating.
  4. Walls get painted damage stages, mines a buried mound, lids become empty (no blink
     overlay on painted faces).
Writes assets/sprites/plants/<id>/<part>.png + rig.json (old pivots, new rects).
"""
import json
import zlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
SPECIAL = {"lids", "buried", "body_1", "body_2", "light", "flame"}
BLEED = 8          # px (2x space) a part extends under higher parts
MAX_W = 250        # 2x px: a cell is 130 px on screen


def load_rig(pid):
    return json.loads((ROOT / f"assets/sprites/plants/{pid}/rig.json").read_text())


def world_pivots(parts):
    by = {p["name"]: p for p in parts}
    out = {}

    def piv(n):
        if n in out:
            return out[n]
        p = by[n]
        base = np.zeros(2) if not p.get("parent") or p["parent"] not in by else piv(p["parent"])
        out[n] = base + np.array(p.get("pos", [0, 0]), float)
        return out[n]

    for n in by:
        piv(n)
    return out


def label_map(pid, parts, piv):
    """Old rig at rest -> (labels HxW int, origin xy of canvas in rig space, names)."""
    names = [p["name"] for p in parts if p["name"] not in SPECIAL]
    rects = []
    for p in parts:
        if p["name"] in SPECIAL:
            continue
        o = piv[p["name"]] + np.array(p["offset"], float)
        rects.append((p, o))
    x0 = min(o[0] for _, o in rects); y0 = min(o[1] for _, o in rects)
    x1 = max(o[0] + p["size"][0] for p, o in rects); y1 = max(o[1] + p["size"][1] for p, o in rects)
    W, H = int(np.ceil(x1 - x0)) + 2, int(np.ceil(y1 - y0)) + 2
    lab = np.full((H, W), -1, int)
    zbuf = np.full((H, W), -1e9)
    d = ROOT / f"assets/sprites/plants/{pid}"
    for p, o in rects:
        im = Image.open(d / f"{p['name']}.png").convert("RGBA")
        im = im.resize((max(1, int(p["size"][0])), max(1, int(p["size"][1]))))
        a = np.array(im)[:, :, 3] > 40
        ox, oy = int(round(o[0] - x0)), int(round(o[1] - y0))
        h, w = a.shape
        sl = (slice(oy, oy + h), slice(ox, ox + w))
        a = a[: lab[sl].shape[0], : lab[sl].shape[1]]
        z = p.get("z", 0) + names.index(p["name"]) * 1e-3
        m = a & (z > zbuf[sl])
        lab[sl][m] = names.index(p["name"])
        zbuf[sl][m] = z
    return lab, np.array([x0, y0]), names


def key_magenta(path):
    rgba = np.array(Image.open(path).convert("RGBA")).astype(float)
    rgb = rgba[..., :3].copy()
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # distance from pure magenta, measured on the "magenta-ness" axis
    mag = np.minimum(r, b) - g
    dist = np.sqrt((255 - r) ** 2 + g ** 2 + (255 - b) ** 2)
    alpha = np.clip((dist - 70) / 90.0, 0, 1)
    alpha[mag < 60] = np.maximum(alpha[mag < 60], 1.0)
    # keep the largest blobs only (drop stray specks)
    solid = alpha > 0.5
    lbl, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, lbl, range(1, n + 1))
        keep = np.isin(lbl, 1 + np.where(sizes > sizes.max() * 0.02)[0])
        alpha *= ndimage.binary_dilation(keep, iterations=3)
    # despill near the edge only
    edge = ndimage.binary_dilation(alpha < 0.99, iterations=4)
    spill = np.clip(np.minimum(r, b) - g, 0, None) * edge
    rgb[..., 0] -= spill * 0.85
    rgb[..., 2] -= spill * 0.85
    alpha = np.minimum(alpha, rgba[..., 3] / 255.0)  # model sometimes returns real transparency
    alpha = ndimage.gaussian_filter(alpha, 0.6)
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    return im.crop(im.getbbox())


def fit(fig, box_w, box_h, scale_hint=1.0):
    w, h = fig.size
    s = min(box_h * scale_hint / h, max(box_w, MAX_W * 0.8) * scale_hint / w, MAX_W / w)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    im = fig.resize((nw, nh), Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def damage(arr, stage, seed):
    rng = np.random.default_rng(seed)
    a = arr.copy().astype(float)
    h, w = a.shape[:2]
    a[..., :3] *= 1.0 - 0.09 * stage
    alpha = a[..., 3] > 30
    cracks = np.zeros((h, w), bool)
    for _ in range(3 * stage + 1):
        ys, xs = np.nonzero(alpha)
        i = rng.integers(len(ys)); y, x = float(ys[i]), float(xs[i])
        ang = rng.uniform(0, np.pi * 2)
        for _ in range(int(h * 0.35)):
            ang += rng.normal(0, 0.35); y += np.sin(ang) * 1.5; x += np.cos(ang) * 1.5
            yi, xi = int(y), int(x)
            if not (0 <= yi < h and 0 <= xi < w):
                break
            cracks[yi, xi] = True
    cracks = ndimage.binary_dilation(cracks, iterations=1) & alpha
    a[cracks, :3] *= 0.35
    a[ndimage.binary_dilation(cracks, iterations=2) & ~cracks & alpha, :3] *= 1.12
    # bites out of the silhouette edge
    edge = alpha & ~ndimage.binary_erosion(alpha, iterations=3)
    ys, xs = np.nonzero(edge)
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(4 * stage):
        i = rng.integers(len(ys)); rr = rng.uniform(5, 9 + 4 * stage)
        a[(yy - ys[i]) ** 2 + (xx - xs[i]) ** 2 < rr * rr, 3] = 0
    return np.clip(a, 0, 255).astype(np.uint8)


def buried(arr):
    h, w = arr.shape[:2]
    top = Image.fromarray(arr).crop((0, 0, w, int(h * 0.55)))
    top = top.resize((w, max(1, int(h * 0.3))), Image.LANCZOS)
    t = np.array(top).astype(float)
    t[..., :3] = t[..., :3] * 0.55 + np.array([70, 52, 36]) * 0.45
    out = np.zeros_like(arr)
    out[h - t.shape[0]:] = np.clip(t, 0, 255)
    return out


def save_part(d, name, arr, pivot, canvas_origin):
    a = Image.fromarray(arr, "RGBA")
    bb = a.getbbox() or (0, 0, 2, 2)
    a = a.crop(bb)
    a.save(d / f"{name}.png", optimize=True)
    off = canvas_origin + np.array(bb[:2], float) - pivot
    return [round(float(off[0]), 1), round(float(off[1]), 1)], [a.size[0], a.size[1]]


def main(pid, concept, scale_hint=1.0):
    rig = load_rig(pid)
    parts = rig["parts"]
    piv = world_pivots(parts)
    # The label map is frozen on first cut (from the v1 rig) so re-cuts are reproducible.
    lp = ROOT / f"art_src/plants/labels/{pid}.png"
    if lp.exists():
        info = json.loads(lp.with_suffix(".json").read_text())
        lab = np.array(Image.open(lp)).astype(int) - 1
        lab_o, names = np.array(info["origin"], float), info["names"]
    else:
        lab, lab_o, names = label_map(pid, parts, piv)
        lp.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray((lab + 1).astype(np.uint8)).save(lp, optimize=True)
        lp.with_suffix(".json").write_text(json.dumps({"origin": lab_o.tolist(), "names": names}))
    ys, xs = np.nonzero(lab >= 0)
    ob = np.array([xs.min(), ys.min(), xs.max() + 1, ys.max() + 1], float)  # old figure bbox (label px)
    old_w, old_h = ob[2] - ob[0], ob[3] - ob[1]
    fig = fit(key_magenta(concept), old_w, old_h, scale_hint)
    fa = np.array(fig)
    fh, fw = fa.shape[:2]
    # new figure placement in rig space: centred on the old figure, feet at the old bottom (<= +4)
    cx = lab_o[0] + (ob[0] + ob[2]) / 2
    bottom = min(lab_o[1] + ob[3], 4.0)
    origin = np.array([cx - fw / 2, bottom - fh])
    # label transfer
    _, (iy, ix) = ndimage.distance_transform_edt(lab < 0, return_indices=True)
    near = lab[iy, ix]
    u = (np.arange(fw) + 0.5) / fw; v = (np.arange(fh) + 0.5) / fh
    lx = np.clip((ob[0] + u * old_w).astype(int), 0, lab.shape[1] - 1)
    ly = np.clip((ob[1] + v * old_h).astype(int), 0, lab.shape[0] - 1)
    nl = near[ly[:, None], lx[None, :]]
    zs = {p["name"]: p.get("z", 0) for p in parts}
    d = ROOT / f"assets/sprites/plants/{pid}"
    for f in d.glob("*.png"):
        if f.stem not in ("light", "flame"):
            f.unlink()
    out = {}
    for i, n in enumerate(names):
        m = nl == i
        higher = np.isin(nl, [j for j, k in enumerate(names) if zs[k] > zs[n]])
        m = m | (ndimage.binary_dilation(m, iterations=BLEED) & higher)
        arr = fa.copy()
        arr[..., 3] = (arr[..., 3] * m).astype(np.uint8)
        out[n] = arr
    rects = {}
    for n, arr in out.items():
        rects[n] = save_part(d, n, arr, piv[n], origin)
    full = fa
    for p in parts:
        n = p["name"]
        if n in ("body_1", "body_2"):
            rects[n] = save_part(d, n, damage(out.get("body", full), int(n[-1]), zlib.crc32(pid.encode()) % 999), piv[n], origin)
        elif n == "buried":
            rects[n] = save_part(d, n, buried(out.get("body", full)), piv[n], origin)
        elif n == "lids":
            Image.new("RGBA", (2, 2)).save(d / "lids.png")
            rects[n] = ([0.0, 0.0], [2, 2])
    for p in parts:
        if p["name"] in rects:
            p["offset"], p["size"] = rects[p["name"]]
    rig.setdefault("meta", {})["art"] = "v2"
    (d / "rig.json").write_text(json.dumps(rig, indent=1))
    kb = sum(f.stat().st_size for f in d.glob("*.png")) / 1024
    print(f"{pid}: {fw}x{fh} parts={list(rects)} {kb:.0f} KB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 1.0)
