"""Reusable painted building blocks for plants and zombies."""
import math
import numpy as np, cv2, cairo
from kit import *

W = H = 320           # plant canvas (2x)
FEET = (160, 300)


def L(): return Layer(W, H)


def stack(*layers, w=W, h=H):
    out = Layer(w, h)
    for l in layers:
        if l is not None:
            out.over_layer(l)
    return out


def leaf_path(ctx, x, y, ang, length, width, curl=0.0):
    ctx.save(); ctx.translate(x, y); ctx.rotate(ang)
    ctx.move_to(0, 0)
    ctx.curve_to(length * 0.3, -width, length * 0.75, -width * 0.8 + curl, length, curl)
    ctx.curve_to(length * 0.75, width * 0.7 + curl, length * 0.3, width * 0.9, 0, 0)
    ctx.restore()


def leaves(specs, col, w=W, h=H, vein=True, roundness=0.7, serrated=False):
    """specs: (x, y, angle_deg, length, width[, curl])"""
    def draw(c):
        for s in specs:
            x, y, a, ln, wd = s[:5]
            leaf_path(c, x, y, math.radians(a), ln, wd, s[5] if len(s) > 5 else 0.0)
    m = fill_mask(w, h, draw)
    if serrated:
        n = noise(w, h, 3.0, 1, seed=3)
        m = m * (cv2.GaussianBlur(m, (0, 0), 2.0) * 0.6 + n * 0.8 > 0.55)
    det = None
    if vein:
        strokes = []
        for s in specs:
            x, y, a, ln, wd = s[:5]
            curl = s[5] if len(s) > 5 else 0.0
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            def P(u, v):
                return (x + ca * u - sa * v, y + sa * u + ca * v)
            strokes.append([P(ln * 0.05, 0), P(ln * 0.5, curl * 0.4), P(ln * 0.88, curl * 0.85)])
            for k in range(1, 4):
                u = ln * (0.2 + 0.2 * k)
                strokes.append([P(u, curl * u / ln * 0.6), P(u + ln * 0.12, -wd * 0.45)])
                strokes.append([P(u, curl * u / ln * 0.6), P(u + ln * 0.12, wd * 0.45)])
        det = paint_strokes(m.shape, strokes, 2.0, 0.2, 0.9)
    return shade(m, col, roundness=roundness, detail=det, spec=0.12, toon=0.5, spec_power=18)


def stem(points, width, col, w=W, h=H):
    def draw(c):
        c.move_to(*points[0])
        if len(points) == 4:
            c.curve_to(*points[1], *points[2], *points[3])
        else:
            for p in points[1:]:
                c.line_to(*p)
    m = stroke_mask(w, h, draw, width)
    # subtle fibres along the stem
    n = noise(w, h, 2.0, 2, seed=11)
    det = 0.92 + 0.08 * n
    return shade(m, col, roundness=1.0, toon=0.4, spec=0.12, detail=det)


def sphere_bulge(cx, cy, rx, ry, amp, w=W, h=H):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    s = np.clip(1 - ((xx - cx) / rx) ** 2 - ((yy - cy) / ry) ** 2, 0, 1)
    return np.sqrt(s) * amp


def eye(cx, cy, s=1.0, look=(5, 2), w=W, h=H, ring=None, angry=0.0, pupil=None, iris=None):
    sc = fill_mask(w, h, lambda c: ellipse(c, cx, cy, 15 * s, 19 * s))
    oc = ring if ring is not None else hexc('1f2a18')
    Lr = shade(sc, hexc('fbfbf3'), roundness=0.9, spec=0.0, rim=0.0, outline=2.6 * s, outline_color=oc, ao=0.55, toon=0.3)
    if iris is not None:
        ir = fill_mask(w, h, lambda c: ellipse(c, cx + look[0] * s, cy + look[1] * s, 10 * s, 12.5 * s))
        Lr.over_layer(clip_layer(shade(ir, iris, roundness=0.8, spec=0.0, rim=0.0, outline=0, toon=0.3), sc))
    pu = fill_mask(w, h, lambda c: ellipse(c, cx + look[0] * s, cy + look[1] * s, 7.5 * s, 10 * s))
    Lr.over_layer(clip_layer(shade(pu, pupil if pupil is not None else hexc('17171f'), roundness=0.8, spec=0.0, rim=0.1, outline=0, toon=0.2), sc))
    gl = fill_mask(w, h, lambda c: ellipse(c, cx + look[0] * s - 3 * s, cy + look[1] * s - 4 * s, 3.4 * s, 3.4 * s))
    Lr.over_layer(flat_layer(gl, (1, 1, 1), 0.95))
    gl2 = fill_mask(w, h, lambda c: ellipse(c, cx + look[0] * s + 3 * s, cy + look[1] * s + 4 * s, 1.6 * s, 1.6 * s))
    Lr.over_layer(flat_layer(gl2, (1, 1, 1), 0.8))
    if angry:
        # upper lid cut: a slanted band of skin colour drawn by caller (brow); darken top
        pass
    return Lr


def brow(p0, p1, p2, col, width=6, w=W, h=H):
    m = stroke_mask(w, h, lambda c: (c.move_to(*p0), c.curve_to(*p1, *p1, *p2)), width)
    return shade(m, col, roundness=1.0, outline=0, spec=0, rim=0, toon=0.2)


def lids(eyes, skin, w=W, h=H):
    """Closed-eye overlay: skin-coloured lids with a lash line. eyes: (cx, cy, s)."""
    def draw(c):
        for (cx, cy, s) in eyes:
            ellipse(c, cx, cy, 16.5 * s, 20.5 * s)
    m = fill_mask(w, h, draw)
    Lr = shade(m, skin, roundness=0.9, outline=2.0, spec=0.05, rim=0.1)
    lash = stroke_mask(w, h, lambda c: [ (c.move_to(cx - 14 * s, cy + 3 * s), c.curve_to(cx - 5 * s, cy + 11 * s, cx + 5 * s, cy + 11 * s, cx + 14 * s, cy + 3 * s)) for (cx, cy, s) in eyes], 3.0)
    Lr.over_layer(flat_layer(lash, hexc('1f2a18')))
    return Lr


def mouth(points, w=W, h=H, open_h=0.0, col=None, width=4.0):
    """Smile line (3 points) or open mouth if open_h > 0."""
    p0, p1, p2 = points
    if open_h <= 0:
        m = stroke_mask(w, h, lambda c: (c.move_to(*p0), c.curve_to(p1[0], p1[1], p1[0], p1[1], *p2)), width)
        return flat_layer(m, col if col is not None else hexc('2a1a12'))
    def draw(c):
        c.move_to(*p0)
        c.curve_to(p1[0] - 6, p1[1] - 2, p1[0] + 6, p1[1] - 2, *p2)
        c.curve_to(p2[0] - 2, p2[1] + open_h, p0[0] + 2, p0[1] + open_h, *p0)
        c.close_path()
    m = fill_mask(w, h, draw)
    Lr = shade(m, hexc('5a1c1c'), roundness=0.6, spec=0, rim=0, outline=2.5, outline_color=hexc('2a0f0f'))
    tongue = fill_mask(w, h, lambda c: ellipse(c, (p0[0] + p2[0]) / 2, p1[1] + open_h * 0.55, abs(p2[0] - p0[0]) * 0.28, open_h * 0.3))
    Lr.over_layer(clip_layer(shade(tongue, hexc('e0607a'), roundness=0.8, outline=0, spec=0.2), m))
    return Lr


def petal_ring(cx, cy, n, r_in, r_out, width, col, rot=0.0, w=W, h=H, pointy=0.3, squash=1.0):
    def draw(c):
        for i in range(n):
            a = rot + i * 2 * math.pi / n
            ca, sa = math.cos(a), math.sin(a) * squash
            bx, by = cx + ca * r_in, cy + sa * r_in
            tx, ty = cx + ca * r_out, cy + sa * r_out
            nx, ny = -sa, ca
            c.move_to(bx, by)
            mx, my = (bx + tx) / 2, (by + ty) / 2
            c.curve_to(mx + nx * width, my + ny * width, tx + nx * width * pointy, ty + ny * width * pointy, tx, ty)
            c.curve_to(tx - nx * width * pointy, ty - ny * width * pointy, mx - nx * width, my - ny * width, bx, by)
            c.close_path()
    m = fill_mask(w, h, draw)
    strokes = []
    for i in range(n):
        a = rot + i * 2 * math.pi / n
        ca, sa = math.cos(a), math.sin(a) * squash
        strokes.append([(cx + ca * (r_in + 4), cy + sa * (r_in + 4)), (cx + ca * (r_out - 8), cy + sa * (r_out - 8))])
    det = paint_strokes(m.shape, strokes, 2.0, 0.12, 1.2)
    return shade(m, col, roundness=0.55, detail=det, spec=0.15, toon=0.5)


def seed_disc(cx, cy, r, col, w=W, h=H, ry=None):
    ry = ry or r
    m = fill_mask(w, h, lambda c: ellipse(c, cx, cy, r, ry))
    # spiral seed pattern
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    det = np.ones((h, w), np.float32)
    golden = math.pi * (3 - math.sqrt(5))
    pts = fill_mask(w, h, lambda c: [ellipse(c, cx + math.cos(i * golden) * math.sqrt(i / 140) * r * 0.92,
                                             cy + math.sin(i * golden) * math.sqrt(i / 140) * ry * 0.92, 2.2, 2.2) for i in range(140)])
    det = 1 - cv2.GaussianBlur(pts, (0, 0), 0.8) * 0.28
    return shade(m, col, roundness=0.6, detail=det, spec=0.15, toon=0.45)


def spikes(base_pts, col, length, width, w=W, h=H, outline=2.5):
    """base_pts: list of (x, y, angle_deg)"""
    def draw(c):
        for (x, y, a) in base_pts:
            ar = math.radians(a)
            ca, sa = math.cos(ar), math.sin(ar)
            nx, ny = -sa, ca
            c.move_to(x + nx * width, y + ny * width)
            c.curve_to(x + ca * length * 0.5 + nx * width * 0.5, y + sa * length * 0.5 + ny * width * 0.5,
                       x + ca * length * 0.9, y + sa * length * 0.9, x + ca * length, y + sa * length)
            c.curve_to(x + ca * length * 0.9, y + sa * length * 0.9,
                       x + ca * length * 0.5 - nx * width * 0.5, y + sa * length * 0.5 - ny * width * 0.5,
                       x - nx * width, y - ny * width)
            c.close_path()
    m = fill_mask(w, h, draw)
    return shade(m, col, roundness=0.8, spec=0.3, toon=0.5, outline=outline)


def glow(cx, cy, r, col, alpha=0.6, w=W, h=H):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** 2 * alpha
    return flat_layer(np.ones((h, w), np.float32), col, 1.0) if False else _glow_layer(a, col)


def _glow_layer(a, col):
    Lr = Layer(a.shape[1], a.shape[0])
    Lr.over(np.broadcast_to(np.asarray(col, np.float32), (a.shape[0], a.shape[1], 3)), a)
    return Lr


def tex_wood(w, h, seed=1, scale=1.0, horizontal=False):
    """Bark/wood grain multiplicative detail."""
    n = noise(w, h, 6.0 * scale, 3, seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    coord = yy if horizontal else xx
    g = np.sin(coord * 0.18 / scale + n * 9.0)
    lines = smoothstep(0.75, 0.98, g)
    return 1 - lines * 0.28 - (1 - n) * 0.08


def bulge_shade(m, col, bulge, **kw):
    return shade(m, col, h_extra=bulge, **kw)
