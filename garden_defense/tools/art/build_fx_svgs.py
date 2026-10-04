#!/usr/bin/env python3
"""Writes the vector sources for battle FX sprite sheets into art_src/svg/.
Each sheet is a single horizontal strip of equally sized frames (Sprite2D.hframes).
Render with:  sh tools/art/render_fx.sh   (Inkscape 1.4, headless)
Style: flat cel fills + coloured outline (see GDD 7.1). Light from top-left."""
import math, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art_src", "svg")
os.makedirs(OUT, exist_ok=True)

def svg(w, h, body, defs=""):
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>\n')

def star(cx, cy, r_out, r_in, n=4, rot=0.0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n - math.pi / 2
        pts.append(f"{cx + math.cos(a) * r:.2f},{cy + math.sin(a) * r:.2f}")
    return " ".join(pts)

def write(name, text):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", name)

# 1) sparkle_sheet: 8 x 64px, a 4-point glint that grows, spins and fades.
F = 64; frames = 8; body = []
for i in range(frames):
    t = i / (frames - 1)
    s = math.sin(t * math.pi)            # 0 -> 1 -> 0
    cx = i * F + F / 2; cy = F / 2
    ro = 6 + 22 * s; ri = ro * 0.22; rot = t * 0.9
    op = 0.25 + 0.75 * s
    body.append(f'<circle cx="{cx}" cy="{cy}" r="{ro * 0.9:.1f}" fill="url(#glow)" opacity="{op * 0.8:.2f}"/>')
    body.append(f'<polygon points="{star(cx, cy, ro, ri, 4, rot)}" fill="#fff6c8" stroke="#e0a21c" stroke-width="2" stroke-linejoin="round" opacity="{op:.2f}"/>')
    body.append(f'<polygon points="{star(cx, cy, ro * 0.55, ri * 0.6, 4, rot + math.pi / 4)}" fill="#ffffff" opacity="{op:.2f}"/>')
defs = '<radialGradient id="glow"><stop offset="0" stop-color="#fff3a0" stop-opacity="0.9"/><stop offset="1" stop-color="#ffcc33" stop-opacity="0"/></radialGradient>'
write("sparkle_sheet.svg", svg(F * frames, F, "".join(body), defs))

# 2) flame_sheet: 6 x 64x96 looping flame (burn status on zombies).
FW, FH, frames = 64, 96, 6; body = []
for i in range(frames):
    ph = i / frames * 2 * math.pi
    ox = i * FW
    def flame(scale, col, stroke, sway):
        w = 26 * scale; h = 78 * scale
        tipx = ox + FW / 2 + math.sin(ph) * 7 * sway; tipy = FH - 6 - h
        bx = ox + FW / 2; by = FH - 6
        l1 = math.sin(ph + 1.3) * 5 * sway; l2 = math.cos(ph + 0.7) * 5 * sway
        d = (f"M {bx - w:.1f},{by - 12:.1f} C {bx - w - 4:.1f},{by - h * 0.45 + l1:.1f} {tipx - 10:.1f},{tipy + h * 0.25:.1f} {tipx:.1f},{tipy:.1f} "
             f"C {tipx + 12:.1f},{tipy + h * 0.3:.1f} {bx + w + 4:.1f},{by - h * 0.45 + l2:.1f} {bx + w:.1f},{by - 12:.1f} "
             f"C {bx + w * 0.6:.1f},{by + 2:.1f} {bx - w * 0.6:.1f},{by + 2:.1f} {bx - w:.1f},{by - 12:.1f} Z")
        sw = f' stroke="{stroke}" stroke-width="3" stroke-linejoin="round"' if stroke else ""
        return f'<path d="{d}" fill="{col}"{sw}/>'
    body.append(flame(1.0, "#ff7a1a", "#b8360c", 1.0))
    body.append(flame(0.68, "#ffc23a", None, 1.4))
    body.append(flame(0.36, "#fff3b0", None, 1.8))
write("flame_sheet.svg", svg(FW * frames, FH, "".join(body)))

# 3) ice_block: translucent faceted block that encases a frozen zombie.
W, H = 170, 240
facets = [
    ("M 18,40 L 60,10 L 140,16 L 160,58 L 152,214 L 112,234 L 30,228 L 10,190 Z", "#bfeeff", 0.55),
    ("M 18,40 L 60,10 L 140,16 L 160,58 L 92,70 Z", "#e9fbff", 0.7),
    ("M 18,40 L 92,70 L 84,228 L 30,228 L 10,190 Z", "#9fdcf5", 0.35),
    ("M 92,70 L 160,58 L 152,214 L 112,234 L 84,228 Z", "#7cc6ea", 0.35),
]
body = [f'<path d="{d}" fill="{c}" fill-opacity="{a}"/>' for d, c, a in facets]
body.append('<path d="M 18,40 L 60,10 L 140,16 L 160,58 L 152,214 L 112,234 L 30,228 L 10,190 Z" fill="none" stroke="#4f9fcf" stroke-width="5" stroke-linejoin="round"/>')
body.append('<path d="M 34,60 L 46,48 M 32,90 L 38,150 M 132,40 L 142,52" stroke="#ffffff" stroke-width="7" stroke-linecap="round" opacity="0.85"/>')
body.append('<path d="M 100,120 L 118,138 L 108,160 M 60,170 L 72,186" stroke="#e9fbff" stroke-width="3" fill="none" opacity="0.8"/>')
for (x, y) in [(40, 36), (146, 70), (70, 210)]:
    body.append(f'<polygon points="{star(x, y, 10, 2.4, 4)}" fill="#ffffff"/>')
write("ice_block.svg", svg(W, H, "".join(body)))

# 4) frost_burst_sheet: 6 x 128 shards flying outward (freeze impact).
F = 128; frames = 6; body = []
for i in range(frames):
    t = (i + 1) / frames; cx = i * F + F / 2; cy = F / 2
    op = 1.0 - t * 0.85
    body.append(f'<circle cx="{cx}" cy="{cy}" r="{12 + 48 * t:.1f}" fill="none" stroke="#bff0ff" stroke-width="{8 * (1 - t) + 1:.1f}" opacity="{op:.2f}"/>')
    for k in range(8):
        a = k / 8 * 2 * math.pi + 0.2
        d = 10 + 44 * t; L = 16 * (1 - t * 0.5)
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        nx, ny = -math.sin(a), math.cos(a)
        pts = f"{x + math.cos(a) * L:.1f},{y + math.sin(a) * L:.1f} {x + nx * 5:.1f},{y + ny * 5:.1f} {x - math.cos(a) * 4:.1f},{y - math.sin(a) * 4:.1f} {x - nx * 5:.1f},{y - ny * 5:.1f}"
        body.append(f'<polygon points="{pts}" fill="#e6fbff" stroke="#59ace0" stroke-width="2" opacity="{op:.2f}"/>')
write("frost_burst_sheet.svg", svg(F * frames, F, "".join(body)))

# 5) snowflake particle (32px) and leaf particle sheet (4 x 32px).
arms = []
for k in range(6):
    a = k / 6 * 2 * math.pi
    x2, y2 = 16 + math.cos(a) * 13, 16 + math.sin(a) * 13
    arms.append(f'<line x1="16" y1="16" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>')
    bx, by = 16 + math.cos(a) * 8, 16 + math.sin(a) * 8
    for s in (-1, 1):
        b = a + s * 0.7
        arms.append(f'<line x1="{bx:.1f}" y1="{by:.1f}" x2="{bx + math.cos(b) * 5:.1f}" y2="{by + math.sin(b) * 5:.1f}" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>')
write("snowflake.svg", svg(32, 32, '<circle cx="16" cy="16" r="5" fill="#d8f6ff"/>' + "".join(arms)))
body = []
greens = ["#6cc04a", "#4fa83a", "#8fd25e", "#c9b24a"]
for i in range(4):
    cx = i * 32 + 16; rot = i * 35 - 40
    body.append(f'<g transform="rotate({rot} {cx} 16)"><path d="M {cx - 12},16 Q {cx},2 {cx + 12},16 Q {cx},30 {cx - 12},16 Z" fill="{greens[i]}" stroke="#2f6a24" stroke-width="2"/>'
                f'<line x1="{cx - 10}" y1="16" x2="{cx + 10}" y2="16" stroke="#2f6a24" stroke-width="1.5"/></g>')
write("leaf_sheet.svg", svg(128, 32, "".join(body)))

# 6) legend_aura: soft golden sunburst rendered behind legendary plants (rotated in game).
W = 256; c = W / 2; rays = []
for k in range(16):
    a0 = k / 16 * 2 * math.pi; a1 = a0 + 0.12
    r = 124 if k % 2 == 0 else 96
    rays.append(f'<polygon points="{c},{c} {c + math.cos(a0) * r:.1f},{c + math.sin(a0) * r:.1f} {c + math.cos(a1) * r:.1f},{c + math.sin(a1) * r:.1f}" fill="url(#ray)"/>')
defs = ('<radialGradient id="ray" cx="128" cy="128" r="128" gradientUnits="userSpaceOnUse"><stop offset="0.15" stop-color="#fff2a8" stop-opacity="0.9"/>'
        '<stop offset="1" stop-color="#ffb000" stop-opacity="0"/></radialGradient>'
        '<radialGradient id="core"><stop offset="0" stop-color="#fffbe0" stop-opacity="0.85"/><stop offset="1" stop-color="#ffd24a" stop-opacity="0"/></radialGradient>')
write("legend_aura.svg", svg(W, W, "".join(rays) + f'<circle cx="{c}" cy="{c}" r="70" fill="url(#core)"/>', defs))

# 7) lightning_sheet: 4 x 64x256 vertical bolts (Storm Thistle strikes), stretched in game.
FW, FH, frames = 64, 256, 4; body = []
import random
random.seed(7)
for i in range(frames):
    ox = i * FW + FW / 2; pts = [(ox, 0)]
    y = 0
    while y < FH:
        y += random.randint(22, 40); pts.append((ox + random.randint(-18, 18), min(y, FH)))
    d = " ".join(f"{x:.0f},{yy:.0f}" for x, yy in pts)
    body.append(f'<polyline points="{d}" fill="none" stroke="#8fd8ff" stroke-width="14" stroke-linejoin="round" stroke-linecap="round" opacity="0.55"/>')
    body.append(f'<polyline points="{d}" fill="none" stroke="#ffffff" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>')
write("lightning_sheet.svg", svg(FW * frames, FH, "".join(body)))
