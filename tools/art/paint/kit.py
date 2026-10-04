"""Painter kit: turns vector shapes (pycairo paths) into shaded, outlined,
textured raster parts. Each shape is rasterised to a mask, given a height
field from its distance transform (a rounded "inflated" profile), lit from the
upper left with a toon ramp + soft gradient, rim light and specular, and then
outlined with a darker tint of its own colour.

Everything renders at 2x of in-game size; Godot draws parts at 0.5 scale.
"""
from __future__ import annotations
import math, json, os, colorsys
import numpy as np
import cairo, cv2

LIGHT = np.array([-0.55, -0.72, 0.62])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
RNG = np.random.default_rng(7)


def hexc(h: str):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def hsv_shift(c, dh=0.0, ds=1.0, dv=1.0):
    h, s, v = colorsys.rgb_to_hsv(*np.clip(c, 0, 1))
    return np.array(colorsys.hsv_to_rgb((h + dh) % 1.0, min(1, s * ds), min(1, v * dv)))


class Layer:
    """Premultiplied-free RGBA float image, same size for every layer of a part."""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)

    def over(self, rgb, a):
        a = np.clip(a, 0, 1)[..., None]
        out_a = a[..., 0] + self.a * (1 - a[..., 0])
        safe = np.maximum(out_a, 1e-6)[..., None]
        self.rgb = (rgb * a + self.rgb * self.a[..., None] * (1 - a)) / safe
        self.a = out_a

    def over_layer(self, other: 'Layer'):
        self.over(other.rgb, other.a)

    def to_png(self, path, crop=True, pad=6):
        img = np.dstack([np.clip(self.rgb, 0, 1), np.clip(self.a, 0, 1)])
        img = (img * 255 + 0.5).astype(np.uint8)
        ox = oy = 0
        if crop:
            ys, xs = np.nonzero(img[..., 3] > 2)
            if len(xs) == 0:
                xs = ys = np.array([0])
            x0, x1 = max(0, xs.min() - pad), min(self.w, xs.max() + pad + 1)
            y0, y1 = max(0, ys.min() - pad), min(self.h, ys.max() + pad + 1)
            img = img[y0:y1, x0:x1]
            ox, oy = x0, y0
        os.makedirs(os.path.dirname(path), exist_ok=True)
        cv2.imwrite(path, cv2.cvtColor(img, cv2.COLOR_RGBA2BGRA))
        return ox, oy, img.shape[1], img.shape[0]


def mask(w, h, draw, aa=True):
    """Rasterise a cairo drawing callback (ctx) -> float mask 0..1."""
    surf = cairo.ImageSurface(cairo.FORMAT_A8, w, h)
    ctx = cairo.Context(surf)
    ctx.set_antialias(cairo.ANTIALIAS_BEST if aa else cairo.ANTIALIAS_NONE)
    draw(ctx)
    buf = np.ndarray((h, surf.get_stride()), np.uint8, surf.get_data())[:, :w]
    return buf.astype(np.float32) / 255.0


def stroke_mask(w, h, draw, width, cap=cairo.LINE_CAP_ROUND):
    def d(ctx):
        ctx.set_line_width(width)
        ctx.set_line_cap(cap)
        ctx.set_line_join(cairo.LINE_JOIN_ROUND)
        draw(ctx)
        ctx.stroke()
    return mask(w, h, d)


def fill_mask(w, h, draw):
    def d(ctx):
        draw(ctx)
        ctx.fill()
    return mask(w, h, d)


def ellipse(ctx, cx, cy, rx, ry, rot=0.0):
    ctx.save()
    ctx.translate(cx, cy)
    ctx.rotate(rot)
    ctx.scale(max(rx, 0.01), max(ry, 0.01))
    ctx.new_sub_path()
    ctx.arc(0, 0, 1, 0, 2 * math.pi)
    ctx.close_path()
    ctx.restore()


def blob(ctx, pts, closed=True, tension=0.5):
    """Smooth closed Catmull-Rom curve through points."""
    n = len(pts)
    p = [np.array(q, float) for q in pts]
    ctx.move_to(*p[0])
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0, p1, p2, p3 = p[(i - 1) % n], p[i], p[(i + 1) % n], p[(i + 2) % n]
        if not closed:
            p0 = p[max(i - 1, 0)]
            p3 = p[min(i + 2, n - 1)]
        c1 = p1 + (p2 - p0) * tension / 3.0
        c2 = p2 - (p3 - p1) * tension / 3.0
        ctx.curve_to(*c1, *c2, *p2)
    if closed:
        ctx.close_path()


def height_field(m, roundness=1.0, flat=0.0):
    """Dome profile from distance to edge. roundness scales the radius at
    which the dome flattens (1 = the shape's inscribed radius)."""
    b = (m > 0.5).astype(np.uint8)
    if b.sum() == 0:
        return np.zeros_like(m)
    d = cv2.distanceTransform(b, cv2.DIST_L2, 5).astype(np.float32)
    r = max(2.0, d.max() * roundness)
    t = np.clip(d / r, 0, 1)
    h = np.sqrt(1 - (1 - t) ** 2) * r * (1 - flat)
    h = cv2.GaussianBlur(h, (0, 0), max(1.0, r * 0.06))
    return h


def normals(h, strength=1.0):
    gx = cv2.Sobel(h, cv2.CV_32F, 1, 0, ksize=3) / 8.0 * strength
    gy = cv2.Sobel(h, cv2.CV_32F, 0, 1, ksize=3) / 8.0 * strength
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def shade(m, base, *, roundness=0.9, shadow=None, light=None, toon=0.55, spec=0.35,
          spec_power=28.0, rim=0.35, rim_color=None, outline=3.0, outline_color=None,
          detail=None, gloss_spot=True, flat=0.0, ao=0.25, h_extra=None):
    """Return a Layer: shaded and outlined part from mask m."""
    hgt, wid = m.shape
    base = np.asarray(base, float)
    if shadow is None:
        shadow = hsv_shift(base, dh=0.035, ds=1.15, dv=0.55)
        shadow = shadow * 0.85 + np.array([0.12, 0.08, 0.30]) * 0.15
    if light is None:
        light = hsv_shift(base, dh=-0.02, ds=0.8, dv=1.18) + 0.04
    if rim_color is None:
        rim_color = np.array([1.0, 0.97, 0.85])
    if outline_color is None:
        outline_color = hsv_shift(base, dh=0.02, ds=1.25, dv=0.32)
    h = height_field(m, roundness, flat)
    if h_extra is not None:
        h = h + h_extra
    n = normals(h)
    diff = np.clip((n @ LIGHT), -1, 1)
    lam = np.clip(diff * 0.5 + 0.5, 0, 1)           # half-lambert
    ramp = toon * smoothstep(0.48, 0.56, lam) + (1 - toon) * lam
    col = shadow[None, None] * (1 - ramp[..., None]) + base[None, None] * ramp[..., None]
    # light-side lift
    lift = smoothstep(0.72, 0.95, lam)[..., None]
    col = col * (1 - lift * 0.55) + light[None, None] * lift * 0.55
    if detail is not None:
        col = col * detail[..., None] if detail.ndim == 2 else col * detail
    # ambient occlusion near the outer edge (soft inner darkening)
    if ao > 0:
        b = (m > 0.5).astype(np.uint8)
        d = cv2.distanceTransform(b, cv2.DIST_L2, 3).astype(np.float32)
        occ = np.clip(1 - d / 7.0, 0, 1) * ao
        bottom = smoothstep(-0.1, 0.6, n[..., 1])  # faces pointing down are darker
        col = col * (1 - (occ * 0.5 + bottom[..., None][..., 0] * ao * 0.35))[..., None]
    # rim light on the side facing away from the key light
    if rim > 0:
        facing = np.clip(-(n[..., 0] * LIGHT[0] + n[..., 1] * LIGHT[1]) / 0.8, 0, 1)
        edge = 1 - n[..., 2]
        r = smoothstep(0.15, 0.5, edge) * facing * rim
        col = col * (1 - r[..., None]) + rim_color[None, None] * r[..., None]
    # specular
    if spec > 0:
        hv = LIGHT + np.array([0, 0, 1.0])
        hv /= np.linalg.norm(hv)
        s = np.clip(n @ hv, 0, 1) ** spec_power
        s = smoothstep(0.35, 0.65, s) * spec
        col = col + s[..., None] * 0.9
    L = Layer(wid, hgt)
    if outline > 0:
        k = int(math.ceil(outline))
        ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * k + 1, 2 * k + 1))
        dil = cv2.dilate(m, ker)
        dil = cv2.GaussianBlur(dil, (0, 0), 0.6)
        L.over(np.broadcast_to(outline_color, (hgt, wid, 3)), dil)
    L.over(np.clip(col, 0, 1).astype(np.float32), m)
    return L


def noise(w, h, scale=8.0, octaves=3, seed=0):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    s = scale
    for _ in range(octaves):
        sw, sh = max(2, int(w / s)), max(2, int(h / s))
        n = rng.random((sh, sw)).astype(np.float32)
        out += cv2.resize(n, (w, h), interpolation=cv2.INTER_CUBIC) * amp
        tot += amp
        amp *= 0.5
        s /= 2
    return out / tot


def paint_strokes(m_shape, strokes, width, darkness=0.25, blur=0.8):
    """Multiplicative detail map: 1 = untouched, lower = darker lines."""
    hgt, wid = m_shape
    def d(ctx):
        ctx.set_line_width(width)
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for s in strokes:
            ctx.move_to(*s[0])
            if len(s) == 2:
                ctx.line_to(*s[1])
            else:
                blob(ctx, s, closed=False)
            ctx.stroke()
    lm = mask(wid, hgt, d)
    if blur:
        lm = cv2.GaussianBlur(lm, (0, 0), blur)
    return 1 - lm * darkness


def flat_layer(m, color, alpha=1.0):
    L = Layer(m.shape[1], m.shape[0])
    L.over(np.broadcast_to(np.asarray(color, np.float32), (m.shape[0], m.shape[1], 3)), m * alpha)
    return L


def clip_layer(L: Layer, m):
    L.a = L.a * m
    return L


def drop_shadow(m, dx, dy, blur, alpha):
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    s = cv2.warpAffine(m, M, (m.shape[1], m.shape[0]))
    return cv2.GaussianBlur(s, (0, 0), blur) * alpha


class Part:
    """A rendered sprite part with a pivot (in canvas px) and parent link."""
    def __init__(self, name, layer: Layer, pivot, parent=None, z=0):
        self.name, self.layer, self.pivot, self.parent, self.z = name, layer, pivot, parent, z


def export_rig(out_dir, parts, origin, scale=0.5, extra=None):
    """Write part PNGs + rig.json. origin = the entity's feet in canvas px.
    Each part stores: texture, offset of its top-left relative to its own pivot,
    pivot position relative to the parent pivot (or origin), z order."""
    os.makedirs(out_dir, exist_ok=True)
    info = {"scale": scale, "parts": []}
    piv = {p.name: p.pivot for p in parts}
    for p in parts:
        ox, oy, w, h = p.layer.to_png(os.path.join(out_dir, p.name + ".png"))
        par = p.parent
        ref = piv[par] if par else origin
        info["parts"].append({
            "name": p.name, "parent": par or "", "z": p.z,
            "pos": [float(p.pivot[0] - ref[0]), float(p.pivot[1] - ref[1])],
            "offset": [float(ox - p.pivot[0]), float(oy - p.pivot[1])], "size": [int(w), int(h)]})
    if extra:
        info.update(extra)
    with open(os.path.join(out_dir, "rig.json"), "w") as f:
        json.dump(info, f, indent=1)
    return info
