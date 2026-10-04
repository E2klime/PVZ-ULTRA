"""Build the style-bible reference sheet (art_src/style_bible/reference_sheet.png).

Inputs: approved/candidate frames in art_src/style_bible/frames, palettes.json,
and a transparent render of real plants/zombies (render_entities.tscn).
Writes reference_sheet.jpg + lawn_band_options.jpg. Shows: raw vs normalized key frame with characters on it (readability),
silhouette-contrast numbers, light/value rules, the 8 world grade presets on
the shared kit, and the ingredient + UI material frames.

CLI: python3 tools/art/review/make_style_sheet.py --entities /tmp/entities.png
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw
from skimage import color

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import palette, sheet  # noqa: E402
from process.normalize_tone import normalize_for_world  # noqa: E402

log = logging.getLogger("style_sheet")
SB = palette.ROOT / "art_src" / "style_bible"


def lawn_mask(rgb: np.ndarray) -> np.ndarray:
    """Soft mask of grass pixels in a key frame (hue/sat heuristic + morphology)."""
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    m = ((hsv[..., 0] > 28) & (hsv[..., 0] < 55) & (hsv[..., 1] > 120)).astype(np.uint8) * 255
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25))
    m = cv2.morphologyEx(cv2.morphologyEx(m, cv2.MORPH_OPEN, k), cv2.MORPH_CLOSE, k)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    if n > 1:
        big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
        m = np.where(lab == big, 255, 0).astype(np.uint8)
    return cv2.GaussianBlur(m, (0, 0), 6).astype(np.float32) / 255.0


def normalized_frame(rgb: np.ndarray) -> np.ndarray:
    m = lawn_mask(rgb)[..., None]
    norm = normalize_for_world(rgb).astype(np.float32)
    return (norm * m + rgb.astype(np.float32) * (1 - m)).astype(np.uint8)


def place_entities(bg: Image.Image, ent: Image.Image, scale: float, rows_y: list[int], x0: int) -> Image.Image:
    out = bg.convert("RGBA")
    e = ent.resize((round(ent.width * scale), round(ent.height * scale)), Image.LANCZOS)
    for y in rows_y:
        out.alpha_composite(e, (x0, y - e.height))
    return out


def silhouette_contrast(bg: np.ndarray, ent: Image.Image, scale: float, y: int, x0: int) -> float:
    """Mean dE76 between character BODY colours (interior, outline pixels L*<35 excluded)
    and the lawn directly around them. Outlines are ignored on purpose: a dark ink line
    reads on any lawn; what fails is green body vs green grass."""
    e = np.array(ent.resize((round(ent.width * scale), round(ent.height * scale)), Image.LANCZOS))
    a = (e[..., 3] > 200).astype(np.uint8)
    interior = cv2.erode(a, np.ones((7, 7), np.uint8))
    ring = cv2.dilate(a, np.ones((25, 25), np.uint8)) - cv2.dilate(a, np.ones((9, 9), np.uint8))
    h, w = a.shape
    patch = bg[y - h:y, x0:x0 + w, :3]
    lab_bg = color.rgb2lab(patch / 255.0)[ring > 0].mean(0)
    lab_e = color.rgb2lab(e[..., :3] / 255.0)[interior > 0]
    lab_e = lab_e[lab_e[:, 0] > 35.0]
    return float(np.linalg.norm(lab_e - lab_bg, axis=1).mean())


GREEN_SLOTS = (0, 1, 4, 5)  # sunbud, pod_shooter, twin_pod, clod_catapult in render_entities.gd
SLOT = 130


def readability(bg: np.ndarray, ent: Image.Image, scale: float, y: int, x0: int) -> tuple[float, float]:
    """(worst green-plant dE, mean dE over the 8 plant slots) for one lawn row."""
    v = [silhouette_contrast(bg, ent.crop((i * SLOT, 0, (i + 1) * SLOT, ent.height)), scale, y,
                             x0 + round(i * SLOT * scale)) for i in range(8)]
    return min(v[i] for i in GREEN_SLOTS), float(np.mean(v))


def ground_preview(norm: np.ndarray, world: dict, mask: np.ndarray) -> np.ndarray:
    """Palette proof for non-grass worlds: luminance-preserving gradient map of the lawn
    area onto the world's ground ramp (dark, base, light). Not final art."""
    if world["ground"] == "grass":
        return norm
    base, light, dark = (palette.hex_rgb(c) for c in world["lawn"])
    m = mask[..., None]
    lum = color.rgb2lab(norm / 255.0)[..., 0:1] / 100.0
    t = np.clip((lum - lum[m[..., 0] > 0.5].mean()) * 3.0 + 0.5, 0.0, 1.0)
    ramp = np.where(t < 0.5, dark + (base - dark) * (t * 2.0), base + (light - base) * ((t - 0.5) * 2.0))
    out = norm / 255.0 * (1 - m) + ramp * m
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


def build(entities: Path, out: Path) -> None:
    frames = SB / "frames"
    key = np.array(Image.open(frames / "sb_keyframe_lawn_v1.png").convert("RGB"))
    norm = normalized_frame(key)
    ent = Image.open(entities).convert("RGBA")
    k = key.shape[1] / 1920.0
    rows = [int(key.shape[0] * 0.47), int(key.shape[0] * 0.80)]
    x0 = int(key.shape[1] * 0.05)
    g_raw, m_raw = readability(key, ent, k, rows[0], x0)
    g_norm, m_norm = readability(norm, ent, k, rows[0], x0)
    log.info("green-plant worst dE raw=%.1f norm=%.1f | plant mean raw=%.1f norm=%.1f", g_raw, g_norm, m_raw, m_norm)
    pal = palette.load()
    W, H = 2400, 3350
    cv = Image.new("RGBA", (W, H), pal["global"]["paper"])
    d = ImageDraw.Draw(cv)
    y = sheet.text(d, (60, 40), "Garden Defense - Style Bible v1  (reference sheet, for approval)", 54, bold=True) + 10
    y = sheet.text(d, (60, y), "One garden kit, eight light presets. Painterly gouache, warm key light from top-left, cool shadows. "
                   "Characters below are the real in-game rigs (read-only).", 26) + 30
    tw = 1120
    a = sheet.fit(place_entities(Image.fromarray(key), ent, k, rows, x0), tw)
    b = sheet.fit(place_entities(Image.fromarray(norm), ent, k, rows, x0), tw)
    sheet.shadowed_paste(cv, a, (60, y + 40))
    sheet.shadowed_paste(cv, b, (60 + tw + 60, y + 40))
    sheet.text(d, (60, y), f"A. Raw generation - bright yellow lawn: worst green plant dE {g_raw:.1f}", 26, bold=True)
    sheet.text(d, (1240, y), f"B. Normalized to lawn band: worst green plant dE {g_norm:.1f}", 26, bold=True)
    y += 40 + a.height + 50
    t = pal["global"]["lawn_target"]
    rules = (
        "LIGHT  key light from top-left (135 deg), warm #ffe2a8; shadows cool #3a4a78, soft, offset down-right.\n"
        f"VALUE  playfield lawn L* {t['L_min']}-{t['L_max']}, HSV sat <= {t['sat_max']}, hue {t['hue_min']}-{t['hue_max']} deg "
        "(darker + more muted than plant bodies: chosen by measured body-vs-lawn dE, see STYLE_BIBLE.md).\n"
        f"GRID  mow stripes per column dL* ~{t['stripe_dL']}, per-cell variation dL* ~{t['cell_dL']}; no checkerboard, no cell borders.\n"
        "EDGE  grass -> soil/curb through painted masks + tuft overlays; never a rectangle. Contact shadows are their own layer.\n"
        "OUTLINE  coloured, never black (#2c2418 at ~3 px on 1080p for props; none on ground textures).\n"
        "BRUSH  visible gouache strokes at 1:1; upscaled pieces get matching grain. No airbrush gradients, no vector flats.\n"
        "UI  one material set for the whole game: honey wood frame + parchment + leaf-green faces + brass details. "
        "World only tints the accent.\n"
        "NEVER  text/numbers/logos/people/PvZ shapes in generations; no SVG for scenery/UI; no full-screen dim to fake depth."
    )
    y = sheet.text(d, (60, y), rules, 25) + 40
    y = sheet.text(d, (60, y), "C. World presets = same kit, light grade + ground ramp (palette proof via gradient map, not final art)", 30, bold=True) + 20
    small = Image.fromarray(norm)
    mask = lawn_mask(key)
    tw2 = 540
    for i, w in enumerate(palette.world_names()):
        col, row = i % 4, i // 4
        src = ground_preview(np.asarray(small), pal["worlds"][w], mask).astype(np.float32) / 255.0
        g = palette.apply_grade(src, palette.world_grade(w))
        th = sheet.fit(Image.fromarray((g * 255).astype(np.uint8)), tw2)
        px, py = 60 + col * (tw2 + 40), y + row * (th.height + 140)
        sheet.shadowed_paste(cv, th, (px, py))
        wd = pal["worlds"][w]
        sheet.text(d, (px, py + th.height + 8), f"{w}  -  ground: {wd['ground']}", 22, bold=True)
        sheet.swatch_row(d, (px, py + th.height + 40), wd["lawn"] + [wd["soil"], wd["accent"]], 34, labels=False)
    y += 2 * (th.height + 140) + 20
    y = sheet.text(d, (60, y), "D. Ingredient frame (tufts, patches, edge strip, tileable swatch) and UI material frame", 30, bold=True) + 20
    ing = sheet.fit(Image.open(frames / "sb_lawn_ingredients_v1.png"), 900, 900)
    ui = sheet.fit(Image.open(frames / "sb_ui_materials_v1.png"), 1300, 900)
    sheet.shadowed_paste(cv, ing, (60, y))
    sheet.shadowed_paste(cv, ui, (60 + ing.width + 60, y))
    ux = 60 + ing.width + 60
    sheet.swatch_row(d, (ux, y + ui.height + 30), [pal["ui"][k2] for k2 in ("wood_light", "wood_mid", "wood_dark", "paper", "leaf", "leaf_hover", "leaf_pressed", "disabled", "focus")], 44)
    sheet.swatch_row(d, (ux, y + ui.height + 110), list(pal["ui"]["rarity"].values()), 44)
    out.parent.mkdir(parents=True, exist_ok=True)
    cv.convert("RGB").save(out, quality=90, optimize=True)
    log.info("wrote %s (%dx%d)", out, W, H)


def band_options(entities: Path, out: Path, sats: tuple[float, ...] = (0.32, 0.36, 0.40)) -> None:
    """Side-by-side crops: raw vs each candidate lawn saturation ceiling, with real rigs."""
    from process.normalize_tone import normalize
    key = np.array(Image.open(SB / "frames" / "sb_keyframe_lawn_v1.png").convert("RGB"))
    t = palette.load()["global"]["lawn_target"]
    ent = Image.open(entities).convert("RGBA")
    m = lawn_mask(key)[..., None]
    k = key.shape[1] / 1920.0
    y, x0 = int(key.shape[0] * 0.47), int(key.shape[1] * 0.05)
    tiles: list[tuple[str, np.ndarray]] = [("raw generation", key)]
    for sat in sats:
        n = normalize(key, t["L_min"], t["L_max"], sat, t["hue_min"], t["hue_max"])
        tiles.append((f"sat <= {sat:.2f}", (n * m + key * (1 - m)).astype(np.uint8)))
    cw, ch = 760, 360
    cv = Image.new("RGBA", (cw * len(tiles) + 40 * (len(tiles) + 1), ch + 120), "#f4e6c4")
    d = ImageDraw.Draw(cv)
    for i, (label, img) in enumerate(tiles):
        g, mean = readability(img, ent, k, y, x0)
        im = place_entities(Image.fromarray(img), ent, k, [y], x0).crop((60, y - 330, 60 + cw, y + 30))
        cv.alpha_composite(im, (40 + i * (cw + 40), 70))
        sheet.text(d, (40 + i * (cw + 40), 20), f"{label}:  worst green dE {g:.1f}, mean {mean:.1f}", 26, bold=True)
    cv.convert("RGB").save(out, quality=90)
    log.info("wrote %s", out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--entities", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=SB / "reference_sheet.jpg")
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    build(args.entities, args.out)
    band_options(args.entities, args.out.with_name("lawn_band_options.jpg"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
