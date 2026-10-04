"""Board tiles: painted lawn cells, tileable water + caustics, modular pool
coping (edge / outer corner / inner corner) and pre-baked water-cell variants.
Run: python3 tiles.py  -> assets/tiles/{lawn,pool}/"""
import os, sys, math
import numpy as np, cv2, cairo
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ROOT = os.path.join(os.path.dirname(__file__), '../../../assets/tiles')
CW, CH = 260, 280          # one board cell at 2x (130 x 140 in game)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = np.clip(img, 0, 1)
    if img.shape[2] == 3:
        out = cv2.cvtColor((img * 255 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR)
    else:
        out = cv2.cvtColor((img * 255 + 0.5).astype(np.uint8), cv2.COLOR_RGBA2BGRA)
    cv2.imwrite(path, out)


def periodic_noise(w, h, beta=2.0, seed=0):
    """Tileable 1/f^beta noise via FFT, normalised to 0..1."""
    rng = np.random.default_rng(seed)
    fx = np.fft.fftfreq(w)[None, :]
    fy = np.fft.fftfreq(h)[:, None]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1
    spec = (rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))) / f ** (beta / 2)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec)).astype(np.float32)
    n -= n.min(); n /= max(1e-6, n.max())
    return n


# ------------------------------------------------------------------ lawn
def lawn_cell(light: bool, seed: int):
    rng = np.random.default_rng(seed)
    base_top = hexc('7fc451') if light else hexc('5fa63c')
    base_bot = hexc('6cb444') if light else hexc('4f9433')
    yy = np.linspace(0, 1, CH)[:, None, None]
    img = base_top * (1 - yy) + base_bot * yy
    img = np.broadcast_to(img, (CH, CW, 3)).copy()
    n = noise(CW, CH, 40, 3, seed)
    img *= (0.9 + 0.2 * n)[..., None]
    # blades, drawn back-to-front with cairo onto an RGBA surface
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, CW, CH)
    ctx = cairo.Context(surf)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    count = 2600
    ys = np.sort(rng.random(count) * (CH + 30) - 10)
    for y in ys:
        x = rng.random() * (CW + 20) - 10
        ln = 9 + rng.random() * 13
        lean = rng.normal(0.15, 0.35)
        wdt = 1.6 + rng.random() * 1.6
        hue = rng.normal(0, 0.03)
        light_amt = 0.35 + 0.65 * rng.random()
        c_root = hsv_shift(base_bot, dh=hue, dv=0.62)
        c_tip = hsv_shift(base_top, dh=hue - 0.02, ds=0.85, dv=1.0 + 0.32 * light_amt)
        tx, ty = x + lean * ln, y - ln
        g = cairo.LinearGradient(x, y, tx, ty)
        g.add_color_stop_rgba(0, *c_root, 0.95)
        g.add_color_stop_rgba(1, *c_tip, 1.0)
        ctx.set_source(g)
        ctx.move_to(x - wdt, y)
        ctx.curve_to(x - wdt * 0.6, y - ln * 0.5, tx - lean * 2, ty + ln * 0.25, tx, ty)
        ctx.curve_to(tx + 0.4, ty + ln * 0.3, x + wdt * 0.6, y - ln * 0.5, x + wdt, y)
        ctx.close_path()
        ctx.fill()
    # a few clover leaves and tiny daisies
    for _ in range(rng.integers(1, 4)):
        cx, cy = rng.random() * CW, rng.random() * CH
        for k in range(3):
            a = k * 2.1 + rng.random()
            ctx.set_source_rgba(*hsv_shift(base_top, dv=0.85), 1)
            ctx.arc(cx + math.cos(a) * 5, cy + math.sin(a) * 4, 4.5, 0, 2 * math.pi)
            ctx.fill()
    if rng.random() < 0.45:
        cx, cy = rng.random() * CW, rng.random() * CH
        for k in range(6):
            a = k * math.pi / 3
            ctx.set_source_rgba(1, 1, 0.97, 1)
            ctx.save(); ctx.translate(cx + math.cos(a) * 4, cy + math.sin(a) * 4); ctx.rotate(a); ctx.scale(4, 2); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.restore(); ctx.fill()
        ctx.set_source_rgba(1, 0.82, 0.2, 1); ctx.arc(cx, cy, 2.6, 0, 2 * math.pi); ctx.fill()
    buf = np.ndarray((CH, surf.get_stride() // 4, 4), np.uint8, surf.get_data())[:, :CW].astype(np.float32) / 255
    a = buf[..., 3:4]
    rgb = buf[..., [2, 1, 0]] / np.maximum(a, 1e-6)
    img = img * (1 - a) + rgb * a
    # soft cell framing: slightly darker rim, light top edge, so the grid reads
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    d = np.minimum.reduce([xx, yy, CW - 1 - xx, CH - 1 - yy])
    rim = np.clip(1 - d / 10.0, 0, 1) ** 2
    img *= (1 - rim * 0.16)[..., None]
    top = np.clip(1 - yy / 4.0, 0, 1)
    img += top[..., None] * 0.05
    return img


# ------------------------------------------------------------------ water
def water_textures(S=512):
    n1 = periodic_noise(S, S, 3.2, 1)
    n2 = periodic_noise(S, S, 2.0, 2)
    deep, shallow = hexc('1f8fc4'), hexc('4fc8e8')
    t = np.clip(n1 * 0.7 + n2 * 0.3, 0, 1)[..., None]
    water = deep * (1 - t) + shallow * t
    # tileable caustics: wrapped voronoi F2-F1 ridges
    rng = np.random.default_rng(5)
    pts = rng.random((60, 2)) * S
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    f1 = np.full((S, S), 1e9, np.float32)
    f2 = np.full((S, S), 1e9, np.float32)
    for (px, py) in pts:
        dx = np.abs(xx - px); dx = np.minimum(dx, S - dx)
        dy = np.abs(yy - py); dy = np.minimum(dy, S - dy)
        d = np.sqrt(dx * dx + dy * dy)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    ridge = np.clip(1 - (f2 - f1) / 9.0, 0, 1) ** 2.2
    ridge = cv2.GaussianBlur(ridge, (0, 0), 1.2)
    caust = np.dstack([np.ones((S, S, 3), np.float32), ridge])
    return water, caust


# ------------------------------------------------------------------ pool coping
T = 48       # coping thickness at 2x (24 px in game)
SH = 30      # baked water-side shadow


def stone_strip(length, seed=0, blocks=2):
    """Horizontal coping strip, land side at the top, water side (lip) at the bottom."""
    Hh = T + SH
    m = fill_mask(length, Hh, lambda c: c.rectangle(0, 0, length, T))
    det = 0.9 + 0.1 * noise(length, Hh, 6, 3, seed)
    grout = paint_strokes(m.shape, [[(length * k / blocks, 0), (length * k / blocks, T)] for k in range(1, blocks)], 3, 0.45, 0.8)
    det = det * grout
    # bevel profile: flat top, rounded lip towards the water
    yy = np.linspace(0, 1, Hh)[:, None]
    prof = np.where(yy * Hh < T, np.sqrt(np.clip(1 - ((yy * Hh) / T) ** 6, 0, 1)), 0) * 14
    L = shade(m, hexc('e8dcc4'), roundness=0.35, detail=det, spec=0.2, toon=0.4, outline=0, ao=0.1,
              h_extra=np.broadcast_to(prof, m.shape).astype(np.float32), rim=0.15)
    # lip highlight + dark edge line at the water side
    lip = fill_mask(length, Hh, lambda c: c.rectangle(0, T - 6, length, 6))
    L.over(np.broadcast_to(hexc('9a8a70'), (Hh, length, 3)), lip * 0.55)
    top = fill_mask(length, Hh, lambda c: c.rectangle(0, 0, length, 3))
    L.over(np.broadcast_to(hexc('fff8ea'), (Hh, length, 3)), top * 0.6)
    # baked shadow on the water
    sh = np.zeros((Hh, length), np.float32)
    sh[T:, :] = np.linspace(0.5, 0.0, SH)[:, None] ** 1.4
    L.over(np.broadcast_to(np.array([0.02, 0.12, 0.2]), (Hh, length, 3)), sh)
    return L


def outer_corner(seed=3):
    """Top-left outer corner: stone square with the inner (water-facing) corner rounded."""
    S = T + SH
    def path(c):
        c.move_to(0, 0); c.line_to(T, 0); c.line_to(T, T); c.line_to(0, T); c.close_path()
    m = fill_mask(S, S, path)
    det = 0.9 + 0.1 * noise(S, S, 6, 3, seed)
    L = shade(m, hexc('e6dac2'), roundness=0.5, detail=det, spec=0.25, outline=0, ao=0.1, rim=0.15)
    edge = stroke_mask(S, S, lambda c: (c.move_to(T - 3, 0), c.line_to(T - 3, T - 3), c.line_to(0, T - 3)), 6)
    L.over(np.broadcast_to(hexc('9a8a70'), (S, S, 3)), edge * 0.5)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.maximum(xx - T, yy - T)
    sh = np.where((xx >= T) | (yy >= T), np.clip(1 - np.maximum(xx - T, yy - T) / SH, 0, 1) ** 1.4 * 0.5, 0)
    sh = sh * ((xx < T + SH) & (yy < T + SH))
    L.over(np.broadcast_to(np.array([0.02, 0.12, 0.2]), (S, S, 3)), sh.astype(np.float32))
    return L


def inner_corner(seed=4):
    """Coping wrapped around a convex land corner (top-left of a water cell whose
    top and left neighbours are water but the diagonal is land): a quarter disc
    of stone centred on the cell corner, with its shadow on the water."""
    S = T + SH
    m = fill_mask(S, S, lambda c: (c.move_to(0, 0), c.line_to(T, 0), c.arc(0, 0, T, 0, math.pi / 2), c.close_path()))
    det = 0.9 + 0.1 * noise(S, S, 6, 3, seed)
    L = shade(m, hexc('e6dac2'), roundness=0.6, detail=det, spec=0.25, outline=0, ao=0.1, rim=0.15)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    rr = np.sqrt(xx * xx + yy * yy)
    sh = np.clip(1 - (rr - T) / SH, 0, 1) ** 1.4 * 0.5 * (rr >= T)
    L.over(np.broadcast_to(np.array([0.02, 0.12, 0.2]), (S, S, 3)), sh.astype(np.float32))
    return L


def compose_variant(water_rgb, caust, sides, path):
    """Bake a water cell (CW x CH) with coping on the given sides (t, r, b, l)."""
    img = water_rgb[:CH, :CW].copy()
    img = img + caust[:CH, :CW, 3:4] * 0.35
    L = Layer(CW, CH)
    L.rgb = img.astype(np.float32); L.a = np.ones((CH, CW), np.float32)
    strip_h = stone_strip(CW, 1, blocks=2)
    strip_v = stone_strip(CH, 2, blocks=2)
    def put(layer, rot):
        rgba = np.dstack([layer.rgb, layer.a])
        k = {'t': 0, 'r': 3, 'b': 2, 'l': 1}[rot]
        rgba = np.rot90(rgba, k)
        h, w = rgba.shape[:2]
        x0 = CW - w if rot == 'r' else 0
        y0 = CH - h if rot == 'b' else 0
        sub = Layer(CW, CH)
        sub.rgb[y0:y0 + h, x0:x0 + w] = rgba[..., :3]
        sub.a[y0:y0 + h, x0:x0 + w] = rgba[..., 3]
        L.over_layer(sub)
    for s in sides:
        put(strip_v if s in 'lr' else strip_h, s)
    save(np.dstack([L.rgb, L.a])[..., :3], path)


def main():
    lawn = os.path.join(ROOT, 'lawn')
    for i in range(4):
        save(lawn_cell(True, 10 + i), os.path.join(lawn, 'cell_light_%d.png' % i))
        save(lawn_cell(False, 20 + i), os.path.join(lawn, 'cell_dark_%d.png' % i))
    pool = os.path.join(ROOT, 'pool')
    water, caust = water_textures()
    save(water, os.path.join(pool, 'water.png'))
    save(caust, os.path.join(pool, 'caustics.png'))
    s = stone_strip(CW, 1)
    save(np.dstack([s.rgb, s.a]), os.path.join(pool, 'coping_edge.png'))
    s = stone_strip(CH, 2)
    save(np.dstack([s.rgb, s.a]), os.path.join(pool, 'coping_edge_v.png'))
    s = outer_corner()
    save(np.dstack([s.rgb, s.a]), os.path.join(pool, 'coping_corner_outer.png'))
    s = inner_corner()
    save(np.dstack([s.rgb, s.a]), os.path.join(pool, 'coping_corner_inner.png'))
    # stand-alone stone tile texture (tileable) for decks / UI
    S = 256
    tile = np.broadcast_to(hexc('e8dcc4'), (S, S, 3)) * (0.9 + 0.1 * periodic_noise(S, S, 2.5, 9))[..., None]
    g = np.ones((S, S), np.float32)
    for k in (0, S // 2):
        g[k:k + 3, :] = 0.62; g[:, k:k + 3] = 0.62
    save(tile * cv2.GaussianBlur(g, (0, 0), 0.8)[..., None], os.path.join(pool, 'stone_tile.png'))
    var = os.path.join(pool, 'variants')
    compose_variant(water, caust, '', os.path.join(var, 'water_full.png'))
    compose_variant(water, caust, 'trbl', os.path.join(var, 'water_enclosed.png'))
    compose_variant(water, caust, 'lr', os.path.join(var, 'water_left_right.png'))
    compose_variant(water, caust, 'r', os.path.join(var, 'water_right.png'))
    compose_variant(water, caust, 'l', os.path.join(var, 'water_left.png'))
    compose_variant(water, caust, 'tb', os.path.join(var, 'water_top_bottom.png'))
    print('tiles done')


if __name__ == '__main__':
    main()
