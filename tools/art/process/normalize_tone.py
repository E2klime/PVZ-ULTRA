"""Pull a painted grass image into the style-bible lawn band (L*, saturation, hue).

Works in Lab: L* is affinely remapped to the target band (keeping relative
contrast), chroma is scaled to hit the saturation ceiling and hue is rotated
toward the target window. Used for every generated lawn ingredient so pieces
from different generations match before assembly.

CLI: python3 tools/art/process/normalize_tone.py in.png out.png [--world lawn]
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from skimage import color

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import palette  # noqa: E402

log = logging.getLogger("normalize_tone")


def normalize(rgb_u8: np.ndarray, L_min: float, L_max: float, sat_max: float,
              hue_min: float, hue_max: float, std_scale: float = 0.75) -> np.ndarray:
    """Return a uint8 RGB image whose L*/chroma/hue sit inside the given band."""
    rgb = rgb_u8[..., :3].astype(np.float32) / 255.0
    lab = color.rgb2lab(rgb)
    L = lab[..., 0]
    mid = 0.5 * (L_min + L_max)
    L2 = mid + (L - L.mean()) * std_scale
    lab[..., 0] = np.clip(L2, L_min - 12.0, L_max + 12.0)
    a, b = lab[..., 1], lab[..., 2]
    chroma = np.hypot(a, b)
    hue = np.degrees(np.arctan2(b, a))
    # Lab hue of the target HSV hue (mid of the window) at mid value/saturation.
    probe = color.hsv2rgb(np.array([[[0.5 * (hue_min + hue_max) / 360.0, 0.5, 0.55]]]))
    plab = color.rgb2lab(probe)[0, 0]
    target_lab_hue = float(np.degrees(np.arctan2(plab[2], plab[1])))
    hue2 = hue + (target_lab_hue - float(np.median(hue)))
    lo, hi = 0.0, 1.0
    for _ in range(10):  # binary-search the chroma scale that meets the HSV saturation ceiling
        k = 0.5 * (lo + hi)
        lab[..., 1] = chroma * k * np.cos(np.radians(hue2))
        lab[..., 2] = chroma * k * np.sin(np.radians(hue2))
        sat = color.rgb2hsv(np.clip(color.lab2rgb(lab), 0, 1))[..., 1].mean()
        lo, hi = (k, hi) if sat < sat_max * 0.95 else (lo, k)
    out = np.clip(color.lab2rgb(lab), 0.0, 1.0)
    return (out * 255.0 + 0.5).astype(np.uint8)


def normalize_for_world(rgb_u8: np.ndarray, world: str = "lawn") -> np.ndarray:
    t = palette.load()["global"]["lawn_target"]
    return normalize(rgb_u8, t["L_min"], t["L_max"], t["sat_max"], t["hue_min"], t["hue_max"])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--world", default="lawn")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    im = np.array(Image.open(args.src).convert("RGB"))
    out = normalize_for_world(im, args.world)
    Image.fromarray(out).save(args.dst)
    log.info("%s -> %s %s", args.src, args.dst, palette.lab_stats(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
