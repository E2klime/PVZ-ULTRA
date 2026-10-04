"""Turn a generated environment source into the runtime 1920x1080 surround plate.

Steps: detect the empty soil bed (largest region matching the bed colour at the
image centre), warp it onto the board bed target (fit_plate), then grade the
surround slightly down (saturation/value) so the playfield and characters lead.
Usage:
    python3 tools/art/process/plate.py src.png assets/art/worlds/lawn/environment.jpg --world lawn
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import palette  # noqa: E402
from process.fit_plate import fit  # noqa: E402

log = logging.getLogger("plate")
BED_TARGET: tuple[float, float, float, float] = (304, 194, 1486, 906)
SURROUND_SAT: float = 0.72
SURROUND_GAIN: float = 0.88


def detect_bed(img: np.ndarray, tol: int = 45) -> tuple[int, int, int, int]:
    h, w = img.shape[:2]
    ref = np.median(img[h // 2 - 20:h // 2 + 20, w // 2 - 20:w // 2 + 20].reshape(-1, 3), axis=0)
    m = (np.abs(img.astype(int) - ref).sum(2) < tol).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(m)
    i = 1 + int(np.argmax(stats[1:, 4]))
    x, y, bw, bh = (int(v) for v in stats[i, :4])
    return x, y, x + bw, y + bh


def build(src: Path, world: str) -> np.ndarray:
    img = cv2.imread(str(src), cv2.IMREAD_COLOR)
    bed = detect_bed(img)
    log.info("bed detected at %s in %s", bed, img.shape[1::-1])
    out = fit(img, bed, BED_TARGET, (1920, 1080)).astype(np.float32) / 255.0
    rgb = out[..., ::-1]
    lum = (rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    rgb = (lum + (rgb - lum) * SURROUND_SAT) * SURROUND_GAIN
    rgb = palette.apply_grade(rgb, palette.world_grade(world))
    return (np.clip(rgb[..., ::-1], 0, 1) * 255 + 0.5).astype(np.uint8)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--world", default="lawn", choices=palette.world_names())
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    args.dst.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(args.dst), build(args.src, args.world), [cv2.IMWRITE_JPEG_QUALITY, 92])
    log.info("wrote %s", args.dst)


if __name__ == "__main__":
    main()
