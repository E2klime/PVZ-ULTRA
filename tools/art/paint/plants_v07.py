"""v0.7 plant rigs: new layered/flying/legendary plants + painted versions of all
previously circle-only hybrids. python3 plants_v07.py [ids]"""
import sys, os, math, copy, colorsys
sys.path.insert(0, os.path.dirname(__file__))
import plants as PL
from plants import *
from parts import _glow_layer

NEW = {}
def newp(fn):
    NEW[fn.__name__] = fn
    return fn

# ------------------------------------------------------------- recolor helper
def recolor_layer(L, hue=None, dh=0.0, s_mul=1.0, v_mul=1.0, only_green=True):
    rgb = np.clip(L.rgb, 0, 1)
    hsv = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    sel = s > 0.22
    if only_green:
        sel &= (h > 0.14) & (h < 0.48)
    if hue is not None:
        h = np.where(sel, hue, h)
    else:
        h = np.where(sel, (h + dh) % 1.0, h)
    s = np.where(sel, np.clip(s * s_mul, 0, 1), s)
    v = np.where(sel, np.clip(v * v_mul, 0, 1), v)
    out = cv2.cvtColor((np.dstack([h, s, v]) * 255).astype(np.uint8), cv2.COLOR_HSV2RGB_FULL).astype(np.float32) / 255.0
    M = Layer(L.w, L.h); M.rgb = out; M.a = L.a.copy()
    return M

def derive(base, parts_filter=None, **kw):
    """Repaint a base plant: parts_filter(name) -> recolor kwargs or None (keep)."""
    parts, meta = REG[base]()
    out = []
    for p in parts:
        args = parts_filter(p.name) if parts_filter else kw
        if args:
            p = Part(p.name, recolor_layer(p.layer, **args), p.pivot, p.parent, p.z)
        out.append(p)
    return out, dict(meta)

def add_to(parts, name, *layers, under=False):
    for i, p in enumerate(parts):
        if p.name == name:
            p.layer = stack(*layers, p.layer) if under else stack(p.layer, *layers)
            return parts
    return parts

def flames(cx, cy, r, n=7, rot=0.0):
    return stack(petal_ring(cx, cy, n, r * 0.4, r, r * 0.28, hexc('ff7a1e'), rot=rot, pointy=0.05),
                 petal_ring(cx, cy, n, r * 0.3, r * 0.75, r * 0.2, hexc('ffd23c'), rot=rot + 0.2, pointy=0.05))

def ice(pts, size=30):
    return spikes(pts, hexc('dff8ff'), size, size * 0.28)

# ------------------------------------------------------------- hybrids (derived)
@newp
def bee_cannon():
    parts, meta = derive('pod_shooter', lambda n: dict(hue=0.12, s_mul=1.1, v_mul=1.1) if n in ('head', 'lids') else None)
    wings = leaves([(126, 84, -130, 48, 22), (140, 80, -100, 44, 20)], hexc('e8f4ff'), vein=False, roundness=0.4)
    stripes = paint_strokes((H, W), [[(110, 100 + i * 18), (210, 92 + i * 18)] for i in range(4)], 6, 0.55, 1.0)
    for p in parts:
        if p.name == 'head':
            p.layer = stack(wings, p.layer)
            p.layer.rgb *= stripes[..., None] * 0.35 + 0.65
    return parts, meta

@newp
def ember_pod():
    parts, meta = derive('pod_shooter', lambda n: dict(hue=0.05, s_mul=1.2) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', flames(132, 96, 70, rot=-0.4), under=True), meta

@newp
def ember_snapper():
    parts, meta = derive('snapper_trap', lambda n: dict(dh=0.2, s_mul=1.2, only_green=False) if n in ('head', 'jaw', 'lids') else None)
    return add_to(parts, 'head', flames(170, 80, 64, 6, -0.6), under=True), meta

@newp
def ember_vine():
    parts, meta = derive('bramble_vine', lambda n: dict(hue=0.03, s_mul=1.1, v_mul=0.9))
    return add_to(parts, 'body', glow(160, 280, 90, hexc('ff7a1a'), 0.35), flames(110, 270, 26, 5), flames(210, 272, 24, 5)), meta

@newp
def frost_barrier():
    parts, meta = derive('bark_wall', lambda n: dict(hue=0.55, s_mul=0.6, v_mul=1.25, only_green=False) if n.startswith('body') or n == 'lids' else None)
    for p in parts:
        if p.name.startswith('body'):
            p.layer = stack(p.layer, ice([(100, 130, -150), (110, 90, -120), (214, 100, -60), (226, 150, -30), (160, 70, -90)], 34))
    return parts, meta

@newp
def gale_pod():
    parts, meta = derive('pod_shooter', lambda n: dict(hue=0.42, s_mul=0.8, v_mul=1.05) if n in ('head', 'lids') else None)
    swirl = stroke_mask(W, H, lambda c: [(c.move_to(90, 60 + k * 20), c.curve_to(120, 40 + k * 20, 150, 80 + k * 20, 190, 50 + k * 20)) for k in range(2)], 4)
    return add_to(parts, 'head', flat_layer(swirl, (0.9, 1, 1), 0.7)), meta

@newp
def glacial_hive():
    parts, meta = derive('hive_pod', lambda n: dict(hue=0.55, s_mul=0.55, v_mul=1.2, only_green=False) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', ice([(120, 76, -130), (160, 58, -90), (200, 76, -50)], 30)), meta

@newp
def hail_volley():
    parts, meta = derive('twin_pod', lambda n: dict(hue=0.55, s_mul=0.7, v_mul=1.15) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', ice([(100, 80, -140), (124, 60, -110), (150, 56, -80)], 32), under=True), meta

@newp
def healing_lantern():
    parts, meta = derive('lantern_bloom', lambda n: dict(dh=0.85, s_mul=0.9, only_green=False) if n in ('head', 'lids') else None)
    cross = fill_mask(W, H, lambda c: (c.rectangle(152, 40, 16, 44), c.rectangle(138, 54, 44, 16)))
    return add_to(parts, 'head', shade(cross, hexc('ff5a6a'), roundness=0.9, outline=2.5, spec=0.5)), meta

@newp
def ice_mine():
    parts, meta = derive('thorn_mine', lambda n: dict(hue=0.55, s_mul=0.6, v_mul=1.25, only_green=False) if n in ('body', 'lids') else None)
    return add_to(parts, 'body', ice([(120, 236, -150), (200, 236, -30), (160, 214, -90)], 26)), meta

@newp
def needle_storm():
    parts, meta = derive('storm_thistle', lambda n: dict(dh=0.25, s_mul=1.2, only_green=False) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', spikes([(110 + i * 20, 70 + (i % 2) * 10, -150 + i * 20) for i in range(6)], hexc('f2e6b0'), 26, 6), under=True), meta

@newp
def pepper_hive():
    parts, meta = derive('hive_pod', lambda n: dict(hue=0.01, s_mul=1.2, only_green=False) if n in ('head', 'lids') else None)
    stalk = leaves([(156, 64, -110, 34, 12), (166, 62, -70, 30, 10)], hexc('3f9a2c'))
    return add_to(parts, 'head', stalk, under=True), meta

@newp
def pepper_wall():
    parts, meta = derive('bark_wall', lambda n: dict(hue=0.01, s_mul=1.4, v_mul=1.05, only_green=False) if n.startswith('body') or n == 'lids' else None)
    stalk = leaves([(156, 76, -120, 40, 14), (166, 74, -60, 36, 12)], hexc('3f9a2c'))
    for p in parts:
        if p.name.startswith('body'):
            p.layer = stack(stalk, p.layer)
    return parts, meta

@newp
def solar_barricade():
    parts, meta = derive('bark_wall', lambda n: dict(hue=0.11, s_mul=1.3, v_mul=1.15, only_green=False) if n.startswith('body') or n == 'lids' else None)
    ring = petal_ring(160, 150, 14, 70, 112, 16, hexc('ffcf2e'))
    for p in parts:
        if p.name.startswith('body'):
            p.layer = stack(ring, p.layer)
    return parts, meta

@newp
def solar_turret():
    parts, meta = derive('pod_shooter', lambda n: dict(hue=0.13, s_mul=1.2, v_mul=1.1) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', petal_ring(150, 118, 14, 50, 96, 16, hexc('ffcf2e')), under=True), meta

@newp
def storm_pod():
    parts, meta = derive('pod_shooter', lambda n: dict(hue=0.68, s_mul=0.8, v_mul=1.0) if n in ('head', 'lids') else None)
    bolt = fill_mask(W, H, lambda c: (c.move_to(150, 30), c.line_to(126, 74), c.line_to(146, 74), c.line_to(130, 112), c.line_to(170, 62), c.line_to(150, 62), c.line_to(166, 30), c.close_path()))
    return add_to(parts, 'head', shade(bolt, hexc('ffe23a'), roundness=0.7, spec=0.8, outline=2.5), under=True), meta

@newp
def sun_mine():
    parts, meta = derive('thorn_mine', lambda n: dict(hue=0.12, s_mul=1.3, v_mul=1.2, only_green=False) if n in ('body', 'lids') else None)
    return add_to(parts, 'body', petal_ring(160, 254, 10, 36, 62, 12, hexc('ffcf2e')), under=True), meta

@newp
def thorn_lantern():
    parts, meta = derive('lantern_bloom', lambda n: dict(hue=0.08, s_mul=0.8, v_mul=0.8, only_green=False) if n in ('head', 'lids') else None)
    return add_to(parts, 'head', spikes([(138, 120, 195), (144, 96, 225), (178, 96, -45), (184, 120, -15)], hexc('e6d8b0'), 18, 6)), meta

# ------------------------------------------------------------- new plants
def pumpkin_body(col, stage=0, thorns=False, gold=False, seed=4):
    """Front half of a hollow pumpkin worn at the feet (open top shows the plant inside)."""
    m = fill_mask(W, H, lambda c: blob(c, [(48, 236), (70, 196), (120, 182), (160, 186), (200, 182), (250, 196), (272, 236), (256, 290), (200, 304), (120, 304), (64, 290)], tension=0.45))
    rib = paint_strokes(m.shape, [[(x, 188), (x + (x - 160) * 0.12, 250), (x, 302)] for x in (92, 126, 160, 194, 228)], 4, 0.28, 1.4)
    det = rib * (0.92 + 0.08 * noise(W, H, 4, 3, seed=seed))
    body = shade(m, col, roundness=0.8, detail=det, spec=0.35, toon=0.5)
    rim = stroke_mask(W, H, lambda c: (c.move_to(70, 198), c.curve_to(120, 176, 200, 176, 250, 198)), 10)
    body.over_layer(shade(rim, hsv_shift(col, dv=0.7), roundness=1, outline=2))
    # carved face
    face = fill_mask(W, H, lambda c: (c.move_to(104, 226), c.line_to(124, 214), c.line_to(130, 236), c.close_path(),
                                      c.move_to(186, 236), c.line_to(194, 214), c.line_to(214, 226), c.close_path(),
                                      c.move_to(112, 260), c.line_to(136, 270), c.line_to(148, 262), c.line_to(160, 272), c.line_to(172, 262), c.line_to(184, 270), c.line_to(208, 260), c.line_to(196, 284), c.line_to(124, 284), c.close_path()))
    glow_c = hexc('7ad8ff') if gold else hexc('ffd84a')
    body.over_layer(shade(face, glow_c, roundness=0.4, spec=0.0, outline=2.5, toon=0.3))
    layers = []
    if gold:
        band = fill_mask(W, H, lambda c: c.rectangle(44, 244, 232, 12))
        body.over_layer(clip_layer(shade(band, hexc('5a7ae8'), roundness=1, spec=0.8, outline=0), m))
        gem = fill_mask(W, H, lambda c: ellipse(c, 160, 196, 12, 10))
        body.over_layer(shade(gem, hexc('4ab0ff'), roundness=1, spec=1, outline=2))
    if thorns:
        layers.append(spikes([(56, 240, 190), (66, 210, 215), (254, 210, -35), (266, 242, -10), (100, 192, 250), (220, 192, -70)], hexc('e6d8b0'), 26, 7))
    vine = leaves([(232, 190, -60, 40, 14), (88, 190, -130, 34, 12)], hexc('4fae35'))
    layers += [body, vine]
    L = stack(*layers)
    if stage >= 1:
        cr = paint_strokes(m.shape, [[(150, 190), (166, 230), (150, 262)], [(232, 220), (246, 256)]][:stage], 5, 0.75, 0.6)
        L.rgb *= cr[..., None]
    if stage == 2:
        L.a *= 1 - fill_mask(W, H, lambda c: blob(c, [(250, 200), (276, 230), (260, 262), (236, 230)]))
    return L

def _pumpkin(col, **kw):
    return [P('body' if s == 0 else 'body_%d' % s, pumpkin_body(col, s, **kw), FEET, None, 0) for s in range(3)], {"stages": 3, "shell": True}

@newp
def pumpkin_shell(): return _pumpkin(hexc('f08a22'))
@newp
def thorn_pumpkin(): return _pumpkin(hexc('c8641a'), thorns=True, seed=7)
@newp
def aegis_pumpkin(): return _pumpkin(hexc('ffc23a'), gold=True, seed=9)

@newp
def thorn_carpet():
    mat = fill_mask(W, H, lambda c: ellipse(c, 160, 292, 112, 20))
    body = shade(mat, hexc('7a5a3a'), roundness=0.5, detail=0.85 + 0.15 * noise(W, H, 3, 3, 2), spec=0.05)
    sp = spikes([(x, 288 + 5 * math.sin(x), -90 + 18 * math.sin(x * 0.3)) for x in range(64, 260, 16)], hexc('e6dcc0'), 34, 8, outline=2)
    lf = leaves([(80, 292, -170, 30, 10), (240, 292, -10, 30, 10)], hexc('5aae3a'))
    e = [eye(146, 290, 0.42, look=(2, 0)), eye(172, 290, 0.42, look=(2, 0))]
    return [P('body', stack(lf, body, sp, *e), FEET, None, 0)], {"flat": True}

@newp
def thunder_root():
    mat = fill_mask(W, H, lambda c: ellipse(c, 160, 292, 110, 20))
    roots = stroke_mask(W, H, lambda c: [(c.move_to(160, 292), c.curve_to(160 + dx * 0.4, 280, 160 + dx * 0.8, 300, 160 + dx, 290)) for dx in (-100, -60, 60, 100)], 9)
    body = stack(shade(roots, hexc('5a3a7a'), roundness=1), shade(mat, hexc('6a4a9a'), roundness=0.5, detail=0.85 + 0.15 * noise(W, H, 3, 3, 5)))
    cracks = paint_strokes((H, W), [[(80, 292), (110, 286), (130, 296), (160, 288), (190, 296), (214, 286), (240, 292)]], 4, 1.0, 0.8)
    body.over_layer(_glow_layer(cv2.GaussianBlur((1 - cracks) * mat, (0, 0), 1.6), hexc('fff04a')))
    crystal = fill_mask(W, H, lambda c: (c.move_to(150, 284), c.line_to(156, 238), c.line_to(166, 232), c.line_to(174, 284), c.close_path()))
    cr = stack(glow(162, 256, 44, hexc('fff04a'), 0.5), shade(crystal, hexc('d8c8ff'), roundness=0.6, spec=1, outline=2.5))
    e = [eye(132, 290, 0.45, look=(2, 0)), eye(192, 290, 0.45, look=(2, 0))]
    return [P('body', stack(body, *e), FEET, None, 0), P('head', cr, FEET, 'body', 1)], {"flat": True}

def bedding(leaf_col, pod_col, extra=None):
    mat = leaves([(160 + dx, 296, a, 44, 15) for dx, a in [(-80, -175), (-50, -150), (-20, -120), (20, -60), (50, -30), (80, -5)]], leaf_col, roundness=0.6)
    pods = []
    for i, (x, y) in enumerate([(110, 272), (160, 266), (210, 274)]):
        pm = fill_mask(W, H, lambda c, x=x, y=y: (ellipse(c, x, y, 20, 17), c.new_sub_path(), ellipse(c, x + 22, y, 10, 11)))
        pods.append(shade(pm, pod_col, roundness=0.8, spec=0.4, outline=2.5))
        pods.append(shade(fill_mask(W, H, lambda c, x=x, y=y: ellipse(c, x + 30, y, 4, 7)), hexc('1d3b14'), roundness=0.6, outline=0))
        pods.append(eye(x - 2, y - 4, 0.36, look=(3, 0)))
    head = stack(*pods, *(extra or []))
    return [P('back', mat, FEET, None, -1), P('head', head, (160, 290), None, 0)], {"muzzle": [(240 - 160) * 0.5, (270 - 300) * 0.5], "muzzles": [[(240 - 160) * 0.5, -15.0], [(190 - 160) * 0.5, -17.0]], "flat": True}

@newp
def pea_bedding(): return bedding(hexc('4fae35'), hexc('7cc843'))
@newp
def frost_bedding(): return bedding(hexc('59b9d6'), hexc('8fd6f0'), [ice([(110, 252, -120), (160, 246, -90), (210, 254, -60)], 18)])

def rotor(cx, cy, col):
    return stack(leaves([(cx, cy, -180, 62, 13), (cx, cy, 0, 62, 13)], col, roundness=0.5),
                 shade(fill_mask(W, H, lambda c: ellipse(c, cx, cy, 9, 7)), hexc('6a5a3a'), roundness=1, outline=2))

def flying(body_layer, rotor_y, rotor_col, eyes_list, lid_col, muzzle, extra_parts=()):
    parts = [P('head', body_layer, (160, 200), None, 0), P('rotor', rotor(160, rotor_y, rotor_col), (160, rotor_y), 'head', 1),
             P('lids', lids(eyes_list, lid_col), (160, 200), 'head', 2)] + list(extra_parts)
    return parts, {"muzzle": muzzle, "flying": True}

def garlic_bulb(col, accent, snout=True):
    m = fill_mask(W, H, lambda c: blob(c, [(160, 108), (182, 140), (214, 170), (220, 214), (196, 250), (160, 258), (124, 250), (100, 214), (106, 170), (138, 140)], tension=0.5))
    seg = paint_strokes(m.shape, [[(160, 120), (140, 190), (150, 254)], [(160, 120), (186, 190), (176, 254)]], 3, 0.22, 1.2)
    b = shade(m, col, roundness=0.85, detail=seg, spec=0.4)
    tip = fill_mask(W, H, lambda c: (c.move_to(150, 120), c.curve_to(156, 96, 164, 96, 170, 120), c.close_path()))
    b = stack(shade(tip, accent, roundness=0.8, outline=2), b)
    roots = stroke_mask(W, H, lambda c: [(c.move_to(160 + dx, 254), c.line_to(160 + dx * 1.4, 270)) for dx in (-12, -4, 4, 12)], 2.5)
    b = stack(flat_layer(roots, (0.75, 0.68, 0.55), 1), b)
    if snout:
        sm = fill_mask(W, H, lambda c: (c.move_to(200, 196), c.line_to(246, 190), c.line_to(250, 212), c.line_to(204, 216), c.close_path()))
        b.over_layer(shade(sm, hsv_shift(col, dv=0.9), roundness=0.8, outline=2.5))
        b.over_layer(shade(fill_mask(W, H, lambda c: ellipse(c, 248, 201, 5, 9)), hexc('3a2a1a'), roundness=0.6, outline=0))
    e1, e2 = (146, 190, 0.6), (178, 190, 0.6)
    face = [eye(146, 190, 0.6, look=(4, 1)), eye(178, 190, 0.6, look=(4, 1)), brow((132, 170), (146, 166), (158, 172), hexc('6a5a4a'), 5),
            mouth([(150, 222), (162, 228), (174, 222)])]
    return stack(b, *face), [e1, e2]

@newp
def garlic_drone():
    body, eyes_ = garlic_bulb(hexc('f4f0e0'), hexc('b8a0d8'))
    return flying(body, 108, hexc('6ab84a'), eyes_, hexc('f4f0e0'), [(250 - 160) * 0.5, (201 - 300) * 0.5])

@newp
def chili_drone():
    m = fill_mask(W, H, lambda c: blob(c, [(120, 140), (170, 128), (214, 150), (236, 190), (226, 226), (196, 250), (150, 260), (110, 236), (100, 190)], tension=0.5))
    b = shade(m, hexc('e8402c'), roundness=0.85, spec=0.6)
    cap = leaves([(150, 136, -120, 30, 12), (168, 134, -60, 30, 12)], hexc('3f9a2c'))
    clove = garlic_bulb(hexc('f4f0e0'), hexc('b8a0d8'), snout=False)[0]
    sm = fill_mask(W, H, lambda c: (c.move_to(214, 190), c.line_to(254, 186), c.line_to(256, 208), c.line_to(216, 212), c.close_path()))
    e1, e2 = (146, 188, 0.6), (178, 186, 0.6)
    body = stack(cap, b, shade(sm, hexc('f4f0e0'), roundness=0.8, outline=2.5), eye(146, 188, 0.6, look=(4, 1)), eye(178, 186, 0.6, look=(4, 1)),
                 brow((130, 166), (146, 172), (160, 176), hexc('5a1a0a'), 6), brow((166, 174), (180, 168), (194, 164), hexc('5a1a0a'), 6),
                 mouth([(150, 222), (164, 216), (178, 222)]))
    return flying(body, 118, hexc('f4f0e0'), [e1, e2], hexc('e8402c'), [(256 - 160) * 0.5, (198 - 300) * 0.5])

@newp
def turbo_bean():
    m = fill_mask(W, H, lambda c: blob(c, [(124, 140), (176, 128), (214, 152), (220, 196), (196, 232), (160, 246), (118, 234), (100, 200), (116, 176), (110, 156)], tension=0.5))
    b = shade(m, hexc('f5b82a'), roundness=0.85, spec=0.55, detail=0.94 + 0.06 * noise(W, H, 4, 3, 3))
    stripe = stroke_mask(W, H, lambda c: (c.move_to(120, 160), c.curve_to(150, 150, 190, 150, 214, 170)), 8)
    b.over_layer(clip_layer(flat_layer(stripe, hexc('e8462a'), 0.9), m))
    goggles = fill_mask(W, H, lambda c: (ellipse(c, 146, 186, 17, 14), ellipse(c, 182, 186, 17, 14)))
    strap = stroke_mask(W, H, lambda c: (c.move_to(104, 186), c.line_to(218, 186)), 6)
    sprout = leaves([(162, 132, -110, 30, 11), (162, 132, -60, 26, 10)], hexc('5aae3a'))
    jet = fill_mask(W, H, lambda c: (c.move_to(140, 236), c.line_to(180, 236), c.line_to(176, 256), c.line_to(144, 256), c.close_path()))
    body = stack(sprout, b, flat_layer(strap, (0.25, 0.2, 0.2), 1), shade(goggles, hexc('9ad8f0'), roundness=1, spec=1, outline=3),
                 eye(146, 188, 0.5, look=(4, 1)), eye(182, 188, 0.5, look=(4, 1)), mouth([(150, 214), (162, 222), (176, 212)], open_h=6),
                 shade(jet, hexc('8a8a96'), roundness=0.7, spec=0.7, outline=2.5))
    flame = stack(glow(160, 274, 30, hexc('ffb02a'), 0.6), shade(fill_mask(W, H, lambda c: (c.move_to(146, 256), c.curve_to(150, 280, 156, 296, 160, 300), c.curve_to(164, 296, 170, 280, 174, 256), c.close_path())), hexc('ffd84a'), roundness=0.6, outline=0))
    parts, meta = flying(body, 130, hexc('5aae3a'), [], hexc('f5b82a'), [0, -60])
    parts = [p for p in parts if p.name != 'lids'] + [P('flame', flame, (160, 256), 'head', -1)]
    return parts, meta

@newp
def cloud_bloom():
    cl = fill_mask(W, H, lambda c: [ellipse(c, x, y, rx, ry) for x, y, rx, ry in [(110, 250, 46, 30), (160, 238, 58, 40), (212, 250, 46, 30), (160, 262, 90, 22)]])
    cloud = shade(cl, hexc('f4f8ff'), roundness=0.9, spec=0.2, toon=0.6)
    head, eyes_ = flower_head(hexc('ffcf2e'), hexc('9a5a24'), 160, 150, 34, 66)
    stemm = stem([(160, 236), (156, 210), (160, 184)], 12, hexc('5aa83a'))
    parts = [P('body', cloud, (160, 250), None, 0), P('stem', stemm, (160, 236), 'body', -1),
             P('head', head, (160, 184), 'stem', 1), P('lids', lids(eyes_, hexc('9a5a24')), (160, 184), 'head', 2)]
    return parts, {"flying": True}

def catapult(body_col, leaf_col, clod_col, arm_col='8a5a32', extra_head=None, clod_extra=None, star=False):
    back, front = base_leaves(leaf_col, size=1.1)
    m = fill_mask(W, H, lambda c: blob(c, [(96, 250), (100, 196), (130, 166), (180, 162), (218, 186), (228, 240), (210, 288), (120, 290)]))
    body = shade(m, body_col, roundness=0.8, spec=0.35, detail=paint_strokes(m.shape, [[(120, 180), (150, 230), (130, 280)], [(200, 180), (180, 230), (200, 280)]], 3, 0.25, 1.4))
    face = [eye(140, 214, 0.65, look=(4, 1)), eye(176, 212, 0.65, look=(4, 1)), mouth([(144, 248), (158, 254), (172, 248)]),
            brow((126, 192), (140, 188), (154, 194), hsv_shift(body_col, dv=0.45), 6)]
    head = stack(body, *face, *(extra_head or []))
    arm = stroke_mask(W, H, lambda c: (c.move_to(150, 190), c.curve_to(130, 140, 110, 110, 92, 90)), 10)
    basket = fill_mask(W, H, lambda c: (c.arc(84, 84, 28, 0, math.pi), c.close_path()))
    clod = fill_mask(W, H, lambda c: blob(c, [(66, 80), (76, 58), (98, 56), (108, 76), (96, 88), (72, 90)]))
    cl = shade(clod, clod_col, roundness=0.9, detail=0.85 + 0.15 * noise(W, H, 2, 2, 8), spec=0.3 if star else 0.1)
    lay = [shade(arm, hexc(arm_col), roundness=1, outline=2), cl]
    if clod_extra: lay += clod_extra
    lay.append(shade(basket, hsv_shift(hexc(arm_col), dv=1.2), roundness=0.8, outline=2.5))
    armL = stack(*lay)
    parts = [P('back', back, FEET, None, -2), P('head', head, FEET, None, 0), P('arm', armL, (150, 190), 'head', -1),
             P('lids', lids([(140, 214, 0.65), (176, 212, 0.65)], body_col), FEET, 'head', 1), P('front', front, FEET, None, 2)]
    return parts, {"muzzle": [(84 - 160) * 0.5, (70 - 300) * 0.5], "lob": True}

@newp
def clod_catapult(): return catapult(hexc('8ac850'), hexc('4fae35'), hexc('7a5232'))
@newp
def lava_catapult():
    return catapult(hexc('c8642a'), hexc('6a8a2a'), hexc('ff6a1a'), extra_head=[flames(160, 166, 36, 6)], clod_extra=[glow(86, 72, 30, hexc('ffb02a'), 0.6)])
@newp
def starfall_melon():
    stars_ = fill_mask(W, H, lambda c: [ellipse(c, x, y, 3, 3) for x, y in [(78, 70), (92, 64), (86, 80), (100, 74)]])
    return catapult(hexc('5a4ac8'), hexc('3f8a5a'), hexc('3a2a8a'), extra_head=[glow(160, 220, 80, hexc('ffd84a'), 0.25)],
                    clod_extra=[flat_layer(stars_, (1, 0.95, 0.5), 1), glow(86, 72, 34, hexc('ffd84a'), 0.5)], star=True)

@newp
def spine_cactus():
    sp = spikes([(100 + i * 18, 80 + (i % 2) * 12, -150 + i * 20) for i in range(6)], hexc('f6f0d0'), 22, 5)
    fl = petal_ring(124, 70, 6, 4, 18, 9, hexc('ff7ab0'))
    side = spikes([(96, 140, 190), (100, 110, 210), (196, 166, 60), (150, 176, 100)], hexc('f6f0d0'), 18, 4)
    return shooter(hexc('4fa84a'), hexc('3f9a3a'), hexc('4c8a33'), extras_back=[sp], extras_head=[side, fl], brow_style='angry', snout_len=104, snout_r=22, mouth_col='1d3014', r=(60, 66))

@newp
def sky_dragon():
    m = fill_mask(W, H, lambda c: blob(c, [(110, 160), (150, 130), (200, 136), (232, 170), (236, 214), (206, 250), (160, 258), (118, 240), (100, 200)], tension=0.5))
    scales = fill_mask(W, H, lambda c: [(c.move_to(x - 10, y), c.line_to(x, y - 22), c.line_to(x + 10, y), c.close_path()) for x, y in [(120, 160), (150, 140), (186, 142), (216, 168), (226, 210), (110, 214), (196, 248), (140, 252)]])
    b = shade(m, hexc('f04a7a'), roundness=0.85, spec=0.5)
    sc = shade(scales, hexc('7ad04a'), roundness=0.6, outline=2)
    dots = fill_mask(W, H, lambda c: [ellipse(c, x, y, 3, 3) for x, y in [(140, 200), (170, 220), (190, 196), (150, 230), (126, 186)]])
    snout = fill_mask(W, H, lambda c: blob(c, [(214, 180), (262, 178), (272, 200), (252, 214), (214, 214)]))
    horns = spikes([(150, 136, -110), (180, 136, -70)], hexc('ffe8a0'), 26, 8)
    body = stack(horns, sc, b, flat_layer(dots, (0.15, 0.1, 0.1), 1), shade(snout, hexc('ff7aa0'), roundness=0.8, outline=2.5),
                 shade(fill_mask(W, H, lambda c: ellipse(c, 258, 190, 4, 3)), hexc('3a1a1a'), roundness=1, outline=0),
                 eye(196, 176, 0.62, look=(4, 1), angry=0.4, iris=hexc('ffb000')), brow((180, 156), (196, 160), (212, 168), hexc('8a1a3a'), 6))
    wing = leaves([(130, 170, -150, 80, 34), (130, 176, -125, 70, 28)], hexc('7ad04a'), roundness=0.4)
    parts = [P('head', body, (160, 200), None, 0), P('wing', wing, (130, 172), 'head', -1),
             P('lids', lids([(196, 176, 0.62)], hexc('f04a7a')), (160, 200), 'head', 1)]
    return parts, {"muzzle": [(272 - 160) * 0.5, (200 - 300) * 0.5], "flying": True}

@newp
def chrono_clover():
    leaves_ = [shade(fill_mask(W, H, lambda c, a=a: ellipse(c, 160 + math.cos(a) * 44, 120 + math.sin(a) * 44, 40, 34, a)), hexc('4fc070'), roundness=0.8, spec=0.3) for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
    clock = fill_mask(W, H, lambda c: ellipse(c, 160, 120, 40, 40))
    face = shade(clock, hexc('fff4d0'), roundness=0.7, spec=0.5, outline=3)
    ticks = stroke_mask(W, H, lambda c: [(c.move_to(160 + math.cos(a) * 30, 120 + math.sin(a) * 30), c.line_to(160 + math.cos(a) * 36, 120 + math.sin(a) * 36)) for a in np.linspace(0, 2 * math.pi, 13)[:-1]], 3)
    rim = fill_mask(W, H, lambda c: ellipse(c, 160, 120, 46, 46)) - fill_mask(W, H, lambda c: ellipse(c, 160, 120, 40, 40))
    e1, e2 = (146, 112, 0.5), (174, 112, 0.5)
    head = stack(*leaves_, shade(np.clip(rim, 0, 1), hexc('e8c040'), roundness=1, spec=0.9), face, flat_layer(ticks, (0.3, 0.25, 0.2), 1),
                 eye(146, 112, 0.5, look=(2, 1)), eye(174, 112, 0.5, look=(2, 1)), mouth([(150, 136), (160, 142), (170, 136)]))
    hands = stack(flat_layer(stroke_mask(W, H, lambda c: (c.move_to(160, 120), c.line_to(160, 92)), 4), (0.25, 0.2, 0.15), 1),
                  flat_layer(stroke_mask(W, H, lambda c: (c.move_to(160, 120), c.line_to(182, 128)), 4), (0.25, 0.2, 0.15), 1))
    parts = stem_plant(stack(head, hands), [e1, e2], hexc('fff4d0'), hexc('4fae35'), hexc('5aa83a'), (160, 166))
    return parts, {}

@newp
def bean_patriarch():
    m = fill_mask(W, H, lambda c: blob(c, [(110, 120), (170, 92), (222, 120), (236, 190), (220, 260), (160, 292), (104, 262), (88, 190)], tension=0.5))
    b = shade(m, hexc('c08a40'), roundness=0.85, spec=0.35, detail=0.92 + 0.08 * noise(W, H, 4, 3, 6))
    beard = fill_mask(W, H, lambda c: blob(c, [(120, 200), (200, 200), (196, 250), (160, 290), (124, 250)]))
    brows = [brow((118, 150), (138, 140), (156, 152), hexc('f0f0f0'), 9), brow((168, 152), (186, 140), (206, 150), hexc('f0f0f0'), 9)]
    mon = fill_mask(W, H, lambda c: ellipse(c, 180, 168, 16, 16))
    cane = stroke_mask(W, H, lambda c: (c.move_to(240, 296), c.line_to(246, 150), c.curve_to(248, 128, 270, 128, 270, 146)), 9)
    sprout = leaves([(166, 96, -110, 40, 14), (166, 96, -50, 34, 12)], hexc('5aae3a'))
    e1, e2 = (138, 168, 0.6), (180, 168, 0.6)
    body = stack(sprout, b, shade(beard, hexc('f4f4ee'), roundness=0.8, detail=paint_strokes(beard.shape, [[(140, 210), (150, 270)], [(180, 210), (170, 270)]], 3, 0.15)),
                 eye(138, 168, 0.6, look=(3, 1)), eye(180, 168, 0.6, look=(3, 1)), shade(np.clip(mon - fill_mask(W, H, lambda c: ellipse(c, 180, 168, 12, 12)), 0, 1), hexc('e8c040'), roundness=1, spec=1),
                 *brows, shade(cane, hexc('6a4a2a'), roundness=1, outline=2))
    crown = fill_mask(W, H, lambda c: (c.move_to(130, 108), c.line_to(136, 80), c.line_to(150, 98), c.line_to(166, 70), c.line_to(182, 98), c.line_to(196, 80), c.line_to(202, 108), c.close_path()))
    body = stack(body, shade(crown, hexc('ffd447'), roundness=0.5, spec=0.8, spec_power=10))
    return [P('head', body, FEET, None, 0), P('lids', lids([e1, e2], hexc('c08a40')), FEET, 'head', 1)], {}

def main(ids):
    ids = ids or list(NEW)
    for pid in ids:
        parts, meta = NEW[pid]()
        export_rig(os.path.join(OUT, pid), parts, FEET, 0.5, {"meta": meta})
        print('painted', pid)
    preview_sheet(ids, '/tmp/plants_sheet.png')

if __name__ == '__main__':
    main(sys.argv[1:])
