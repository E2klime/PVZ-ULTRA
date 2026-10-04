"""Painted plant rigs. Run: python3 plants.py [ids...]  -> assets/sprites/plants/<id>/"""
import sys, os, math, json
import numpy as np, cv2
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
from parts import *
from parts import _glow_layer

OUT = os.path.join(os.path.dirname(__file__), '../../../assets/sprites/plants')
REG = {}


def plant(fn):
    REG[fn.__name__] = fn
    return fn


def P(name, layer, pivot, parent=None, z=0):
    return Part(name, layer, pivot, parent, z)


# ---------------------------------------------------------------- templates
def base_leaves(col, spread=1.0, n=2, size=1.0):
    back = leaves([(160, 292, -160, 80 * size, 26 * size, 6), (160, 292, -22, 72 * size, 23 * size, 6)], hsv_shift(col, dv=0.82))
    front = leaves([(157, 295, -198 + 10 * (1 - spread), 72 * size, 23 * size, -4), (163, 295, 22 - 10 * (1 - spread), 68 * size, 21 * size, -4)], col)
    return back, front


def shooter(head_col, leaf_col, stem_col, *, snouts=1, head_c=(150, 118), r=(64, 60), snout_len=112,
            snout_r=30, tuft=None, brow_style='calm', extras_back=None, extras_head=None, eye_s=1.0,
            iris=None, snout_col=None, mouth_col='1d3b14', stem_top=(158, 162), spec=0.35, tuft_col=None):
    hx, hy = head_c
    back, front = base_leaves(leaf_col)
    st = stem([(160, 298), (150, 252), (172, 212), stem_top], 18, stem_col)
    sc = snout_col if snout_col is not None else head_col
    offs = [0] if snouts == 1 else ([-24, 24] if snouts == 2 else [-30, 0, 30])
    rr = snout_r if snouts == 1 else snout_r * 0.72

    def head_shape(c):
        ellipse(c, hx, hy, r[0], r[1])
        for o in offs:
            c.new_sub_path()
            y = hy - 4 + o
            c.move_to(hx + 30, y - rr * 0.9)
            c.curve_to(hx + 60, y - rr * 0.95, hx + snout_len - 20, y - rr * 1.05, hx + snout_len, y - rr * 1.15)
            c.curve_to(hx + snout_len + 10, y - rr * 0.4, hx + snout_len + 10, y + rr * 0.4, hx + snout_len, y + rr * 1.15)
            c.curve_to(hx + snout_len - 20, y + rr * 1.05, hx + 60, y + rr * 0.95, hx + 30, y + rr * 0.9)
            c.close_path()
    hm = fill_mask(W, H, head_shape)
    det = 0.94 + 0.06 * noise(W, H, 5, 3, seed=5)
    head = shade(hm, head_col, roundness=0.75, h_extra=sphere_bulge(hx, hy, r[0], r[1], 30), spec=spec, toon=0.5, detail=det, spec_power=22)
    for o in offs:
        y = hy - 4 + o
        rim_m = fill_mask(W, H, lambda c: ellipse(c, hx + snout_len + 2, y, rr * 0.48, rr * 1.18))
        head.over_layer(shade(rim_m, hsv_shift(sc, dv=1.06), roundness=0.9, outline=2.5))
        hole = fill_mask(W, H, lambda c: ellipse(c, hx + snout_len + 4, y, rr * 0.28, rr * 0.82))
        head.over_layer(shade(hole, hexc(mouth_col), roundness=0.6, spec=0.0, rim=0.0, outline=0, toon=0.2))
    layers = []
    if tuft is not None:
        layers.append(leaves(tuft, tuft_col if tuft_col is not None else hsv_shift(head_col, dv=0.88), roundness=0.65))
    if extras_back:
        layers += extras_back
    layers.append(head)
    ex, ey = hx + 18, hy - 14
    es = eye_s
    e = eye(ex, ey, es, look=(5, 1), iris=iris)
    layers.append(e)
    bc = hsv_shift(head_col, ds=1.3, dv=0.45)
    if brow_style == 'angry':
        layers.append(brow((ex - 20 * es, ey - 30 * es), (ex, ey - 22 * es), (ex + 18 * es, ey - 14 * es), bc, 7))
    elif brow_style == 'calm':
        layers.append(brow((ex - 16 * es, ey - 26 * es), (ex, ey - 32 * es), (ex + 16 * es, ey - 26 * es), bc, 6))
    if extras_head:
        layers += extras_head
    head_all = stack(*layers)
    neck = stem_top
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head_all, neck, 'stem', 0), P('lids', lids([(ex, ey, es)], head_col), neck, 'head', 1),
             P('front', front, FEET, None, 2)]
    meta = {"muzzle": [(hx + snout_len + 8 - 160) * 0.5, (hy - 4 - 300) * 0.5],
            "muzzles": [[(hx + snout_len + 8 - 160) * 0.5, (hy - 4 + o - 300) * 0.5] for o in offs]}
    return parts, meta


def flower_head(petal_col, disc_col, cx, cy, r_disc, r_petal, n=16, face='happy', crown=None, layers2=None, petal_col2=None):
    out = []
    out.append(petal_ring(cx, cy, n, r_disc * 0.6, r_petal + 6, 15, petal_col2 if petal_col2 is not None else hsv_shift(petal_col, dh=0.02, dv=0.88), rot=math.pi / n))
    out.append(petal_ring(cx, cy, n, r_disc * 0.6, r_petal, 14, petal_col))
    if layers2:
        out += layers2
    out.append(seed_disc(cx, cy, r_disc, disc_col))
    es = r_disc / 42
    ex1, ex2, ey = cx - 15 * es, cx + 15 * es, cy - 8 * es
    out.append(eye(ex1, ey, 0.75 * es, look=(2, 1)))
    out.append(eye(ex2, ey, 0.75 * es, look=(2, 1)))
    if face == 'happy':
        out.append(mouth([(cx - 13 * es, cy + 12 * es), (cx, cy + 22 * es), (cx + 13 * es, cy + 12 * es)], open_h=9 * es))
    else:
        out.append(mouth([(cx - 12 * es, cy + 14 * es), (cx, cy + 20 * es), (cx + 12 * es, cy + 14 * es)]))
    blush = fill_mask(W, H, lambda c: (ellipse(c, ex1 - 10 * es, ey + 16 * es, 7 * es, 4 * es), ellipse(c, ex2 + 10 * es, ey + 16 * es, 7 * es, 4 * es)))
    out.append(flat_layer(cv2.GaussianBlur(blush, (0, 0), 2), hexc('ff7a5a'), 0.45))
    if crown:
        out += crown
    return stack(*out), [(ex1, ey, 0.75 * es), (ex2, ey, 0.75 * es)]


def stem_plant(head_layer, eyes_list, lid_col, leaf_col, stem_col, neck, extra_parts=(), leaf_size=1.0):
    back, front = base_leaves(leaf_col, size=leaf_size)
    st = stem([(160, 298), (150, 250), (170, 210), neck], 18, stem_col)
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head_layer, neck, 'stem', 0), P('lids', lids(eyes_list, lid_col), neck, 'head', 1),
             P('front', front, FEET, None, 2)]
    parts += list(extra_parts)
    return parts


# ---------------------------------------------------------------- plants
@plant
def pod_shooter():
    return shooter(hexc('7cc843'), hexc('4fae35'), hexc('5aa83a'),
                   tuft=[(96, 104, 200, 50, 16), (100, 92, 235, 44, 13)])


@plant
def twin_pod():
    return shooter(hexc('4fae3c'), hexc('3f9a2c'), hexc('4c9a33'), snouts=2, brow_style='angry', snout_len=108,
                   tuft=[(94, 110, 195, 56, 18), (98, 96, 228, 50, 15), (108, 84, 255, 42, 12)])


@plant
def frost_mint():
    crystals = spikes([(110, 70, -120), (130, 60, -95), (152, 58, -75), (92, 92, -150)], hexc('d9f6ff'), 34, 9)
    return shooter(hexc('8fd6f0'), hexc('59b9d6'), hexc('5fb0c4'), extras_back=[crystals], brow_style='calm',
                   iris=hexc('2a6fb0'), mouth_col='173a52', tuft=[(96, 108, 205, 44, 14)], tuft_col=hexc('bfefff'))


@plant
def glacier_shooter():
    crystals = spikes([(100, 76, -125), (118, 58, -105), (140, 50, -85), (162, 52, -65), (86, 98, -155)], hexc('e6fbff'), 46, 11)
    armor = spikes([(130, 168, 100), (170, 170, 80)], hexc('c6efff'), 22, 8)
    return shooter(hexc('6cc4e8'), hexc('4aa9c8'), hexc('4f9fb8'), snouts=2, extras_back=[crystals], extras_head=[armor],
                   brow_style='angry', iris=hexc('1f5c9a'), mouth_col='0f2f48', r=(68, 64))


@plant
def pepper_stinger():
    stalk = leaves([(118, 72, -120, 40, 13), (128, 66, -80, 34, 11)], hexc('3f9a2c'))
    return shooter(hexc('e8402c'), hexc('4fae35'), hexc('5aa83a'), extras_back=[stalk], brow_style='angry', r=(60, 56),
                   snout_len=120, snout_r=24, mouth_col='4a0c08', spec=0.5)


@plant
def needle_volley():
    quills = spikes([(100 + i * 14, 70 - (i % 2) * 8, -150 + i * 16) for i in range(7)], hexc('f2e6b0'), 30, 6)
    return shooter(hexc('6aa84a'), hexc('4f9a35'), hexc('568f3a'), snouts=3, extras_back=[quills], brow_style='angry',
                   snout_len=100, r=(66, 62), mouth_col='1d3014')


@plant
def phoenix_lily():
    flames = petal_ring(150, 116, 9, 40, 92, 20, hexc('ff8a1e'), rot=-0.3, pointy=0.05)
    flames2 = petal_ring(150, 116, 9, 30, 74, 16, hexc('ffd23c'), rot=0.05, pointy=0.05)
    return shooter(hexc('ff5a2a'), hexc('d9692a'), hexc('8a5a2a'), extras_back=[flames, flames2], brow_style='angry',
                   iris=hexc('ffb000'), mouth_col='4a1204', r=(56, 54), snout_len=108)


@plant
def sunbud():
    head, eyes_ = flower_head(hexc('ffcf2e'), hexc('9a5a24'), 160, 120, 44, 86)
    return stem_plant(head, eyes_, hexc('9a5a24'), hexc('4fae35'), hexc('5aa83a'), (160, 168)), {}


@plant
def twin_sunbud():
    h1, e1 = flower_head(hexc('ffc22a'), hexc('94551f'), 116, 110, 34, 66)
    h2, e2 = flower_head(hexc('ffd84a'), hexc('9a5a24'), 204, 126, 34, 66)
    head = stack(h1, h2)
    return stem_plant(head, e1 + e2, hexc('94551f'), hexc('4fae35'), hexc('5aa83a'), (160, 176)), {}


@plant
def dawn_bloom():
    head, eyes_ = flower_head(hexc('ff8fa8'), hexc('b8562e'), 160, 120, 42, 84, n=12, petal_col2=hexc('ffb45c'))
    return stem_plant(head, eyes_, hexc('b8562e'), hexc('4fae35'), hexc('5aa83a'), (160, 168)), {}


@plant
def sun_sovereign():
    crown_m = fill_mask(W, H, lambda c: (c.move_to(118, 52), c.line_to(126, 18), c.line_to(142, 40), c.line_to(160, 8),
                                         c.line_to(178, 40), c.line_to(194, 18), c.line_to(202, 52), c.close_path()))
    crown = shade(crown_m, hexc('ffd447'), roundness=0.5, spec=0.8, spec_power=10, toon=0.6)
    gem = fill_mask(W, H, lambda c: ellipse(c, 160, 38, 8, 9))
    crown.over_layer(shade(gem, hexc('e8304a'), roundness=0.9, spec=0.9, outline=2))
    head, eyes_ = flower_head(hexc('ffb800'), hexc('8a4a1a'), 160, 122, 46, 96, n=20, crown=[crown], petal_col2=hexc('ff8a00'))
    return stem_plant(head, eyes_, hexc('8a4a1a'), hexc('3f9f35'), hexc('4f9a35'), (160, 172), leaf_size=1.15), {}


@plant
def lantern_bloom():
    back, front = base_leaves(hexc('4fae35'))
    st = stem([(160, 298), (148, 220), (150, 120), (176, 92)], 15, hexc('5aa83a'))
    cap = leaves([(176, 92, 160, 40, 14), (176, 92, 20, 40, 14), (176, 92, -90, 22, 10)], hexc('3f9a2c'))
    bulb_m = fill_mask(W, H, lambda c: blob(c, [(176, 96), (206, 118), (212, 160), (196, 192), (176, 198), (156, 192), (140, 160), (146, 118)]))
    ribs = paint_strokes(bulb_m.shape, [[(176, 100), (166, 150), (176, 196)], [(176, 100), (190, 150), (178, 196)], [(176, 100), (148, 150), (166, 194)], [(176, 100), (206, 150), (188, 194)]], 2.5, 0.25)
    bulb = shade(bulb_m, hexc('ffb43c'), roundness=0.8, detail=ribs, spec=0.5, light=hexc('fff2b0'), shadow=hexc('d0601c'))
    inner = glow(176, 150, 46, hexc('fff4b8'), 0.8)
    e1, e2 = (166, 146, 0.55), (188, 146, 0.55)
    face = stack(eye(*e1[:2], 0.55, look=(1, 1)), eye(*e2[:2], 0.55, look=(1, 1)),
                 mouth([(168, 166), (177, 172), (186, 166)]))
    head = stack(glow(176, 150, 90, hexc('ffd36a'), 0.35), bulb, inner, face, cap)
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head, (176, 92), 'stem', 0), P('lids', lids([e1, e2], hexc('ffb43c')), (176, 92), 'head', 1),
             P('front', front, FEET, None, 2)]
    return parts, {"hang": True}


@plant
def dandelion_puff():
    back, front = base_leaves(hexc('5aae3a'), size=0.9)
    st = stem([(160, 298), (154, 250), (166, 200), (160, 150)], 12, hexc('6aa84a'))
    # puff: many fine fluff strands
    def fluff(c):
        rng = np.random.default_rng(4)
        for i in range(200):
            a = rng.random() * 2 * math.pi
            r0, r1 = 22, 68 + rng.random() * 12
            c.move_to(160 + math.cos(a) * r0, 104 + math.sin(a) * r0)
            c.line_to(160 + math.cos(a) * r1, 104 + math.sin(a) * r1)
    fm = stroke_mask(W, H, fluff, 2.0)
    tips = fill_mask(W, H, lambda c: [ellipse(c, 160 + math.cos(i * 0.53) * (70 + (i % 5) * 2), 104 + math.sin(i * 0.53) * (70 + (i % 5) * 2), 4.5, 4.5) for i in range(48)])
    puff_m = np.clip(fm + tips + fill_mask(W, H, lambda c: ellipse(c, 160, 104, 54, 54)) * 0.0, 0, 1)
    puff = shade(cv2.GaussianBlur(np.maximum(puff_m, fill_mask(W, H, lambda c: ellipse(c, 160, 104, 60, 60)) * 0.55), (0, 0), 0.7),
                 hexc('fbfbf6'), roundness=1.0, outline=1.5, outline_color=hexc('b9c3c8'), spec=0.1, rim=0.2)
    core = fill_mask(W, H, lambda c: ellipse(c, 160, 108, 34, 30))
    core_l = shade(core, hexc('f3eccd'), roundness=0.9, outline=2.2, outline_color=hexc('9a8f6a'))
    e1, e2 = (148, 104, 0.6), (172, 104, 0.6)
    head = stack(puff, core_l, eye(148, 104, 0.6, look=(1, 1)), eye(172, 104, 0.6, look=(1, 1)), mouth([(152, 120), (160, 126), (168, 120)]))
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head, (160, 150), 'stem', 0), P('lids', lids([e1, e2], hexc('f3eccd')), (160, 150), 'head', 1),
             P('front', front, FEET, None, 2)]
    return parts, {}


@plant
def storm_thistle():
    back, front = base_leaves(hexc('3f8f5a'))
    st = stem([(160, 298), (152, 250), (168, 210), (160, 170)], 16, hexc('4a8a5a'))
    sp = spikes([(160 + math.cos(a) * 40, 104 + math.sin(a) * 40, math.degrees(a)) for a in np.linspace(-math.pi, 0, 11)], hexc('8fd8ff'), 46, 7, outline=2.0)
    bud = fill_mask(W, H, lambda c: blob(c, [(116, 104), (130, 74), (160, 62), (190, 74), (204, 104), (196, 140), (160, 156), (124, 140)]))
    scales = paint_strokes(bud.shape, [[(124 + i * 12, 150), (128 + i * 12, 128)] for i in range(7)], 3, 0.2)
    bud_l = shade(bud, hexc('8a4ad0'), roundness=0.8, detail=scales, spec=0.4)
    cup_m = fill_mask(W, H, lambda c: blob(c, [(124, 132), (196, 132), (186, 172), (160, 182), (134, 172)]))
    cup = shade(cup_m, hexc('3f8f5a'), roundness=0.8, detail=paint_strokes(cup_m.shape, [[(134 + i * 9, 136), (148 + i * 3, 176)] for i in range(7)], 3, 0.3))
    e1, e2 = (148, 104, 0.62), (174, 104, 0.62)
    face = stack(eye(148, 104, 0.62, look=(2, 1), iris=hexc('46b8ff')), eye(174, 104, 0.62, look=(2, 1), iris=hexc('46b8ff')),
                 brow((136, 88), (148, 92), (158, 96), hexc('3a1a5a'), 5), brow((164, 96), (176, 92), (188, 88), hexc('3a1a5a'), 5),
                 mouth([(150, 124), (161, 120), (172, 124)]))
    head = stack(glow(160, 104, 100, hexc('8fd8ff'), 0.3), sp, bud_l, face, cup)
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head, (160, 170), 'stem', 0), P('lids', lids([e1, e2], hexc('8a4ad0')), (160, 170), 'head', 1),
             P('front', front, FEET, None, 2)]
    return parts, {"muzzle": [0, -98]}


@plant
def hive_pod():
    back, front = base_leaves(hexc('4fae35'))
    st = stem([(160, 298), (152, 250), (168, 210), (160, 176)], 16, hexc('5aa83a'))
    body_m = fill_mask(W, H, lambda c: blob(c, [(160, 60), (204, 80), (214, 128), (198, 170), (160, 184), (122, 170), (106, 128), (116, 80)]))
    bands = paint_strokes(body_m.shape, [[(110, 92 + i * 20), (160, 98 + i * 20), (210, 92 + i * 20)] for i in range(5)], 4, 0.3)
    body = shade(body_m, hexc('ffb22a'), roundness=0.85, detail=bands, spec=0.45)
    hole = fill_mask(W, H, lambda c: ellipse(c, 184, 140, 14, 12))
    body.over_layer(shade(hole, hexc('3a1a08'), roundness=0.7, spec=0, rim=0, outline=2.5))
    drip = fill_mask(W, H, lambda c: blob(c, [(130, 166), (140, 168), (138, 190), (134, 194), (130, 188)]))
    body.over_layer(shade(drip, hexc('ffd04a'), roundness=0.9, spec=0.9, outline=1.5))
    e1, e2 = (146, 112, 0.6), (172, 112, 0.6)
    face = stack(eye(146, 112, 0.6, look=(3, 1)), eye(172, 112, 0.6, look=(3, 1)), mouth([(150, 132), (159, 138), (168, 132)]))
    head = stack(body, face)
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', head, (160, 176), 'stem', 0), P('lids', lids([e1, e2], hexc('ffb22a')), (160, 176), 'head', 1),
             P('front', front, FEET, None, 2)]
    return parts, {"muzzle": [12, -80]}


def trap(head_col, jaw_col, tooth_col, spots_col, leaf_col, swirl=False):
    back, front = base_leaves(leaf_col, size=1.05)
    st = stem([(160, 298), (140, 250), (176, 214), (150, 176)], 20, hsv_shift(leaf_col, dv=0.95))
    # upper head (dome with lip), pivot at hinge (118, 150)
    up_m = fill_mask(W, H, lambda c: blob(c, [(112, 150), (104, 108), (130, 66), (180, 56), (232, 78), (262, 116), (254, 140), (190, 140), (130, 156)]))
    det = None
    if swirl:
        det = paint_strokes(up_m.shape, [[(150 + math.cos(t) * t * 6, 104 + math.sin(t) * t * 5) for t in np.linspace(0.5, 9, 40)]], 5, 0.25, 1.0)
    upper = shade(up_m, head_col, roundness=0.75, spec=0.4, detail=det)
    spots = fill_mask(W, H, lambda c: [ellipse(c, x, y, r, r * 0.8) for (x, y, r) in [(160, 82, 9), (196, 76, 7), (226, 98, 6), (140, 108, 6)]])
    upper.over_layer(clip_layer(shade(spots, spots_col, roundness=0.8, outline=0, spec=0.2), up_m))
    teeth_u = spikes([(150 + i * 18, 142 - i * 0.8, 92) for i in range(6)], tooth_col, 20, 6, outline=2)
    lip_u = stroke_mask(W, H, lambda c: (c.move_to(130, 154), c.curve_to(170, 142, 220, 140, 258, 134)), 9)
    upper.over_layer(shade(lip_u, hsv_shift(head_col, dv=1.2), roundness=1, outline=2))
    eye_l = eye(196, 96, 0.8, look=(5, 2))
    br = brow((176, 70), (194, 74), (214, 82), hsv_shift(head_col, dv=0.4), 7)
    up_layer = stack(teeth_u, upper, eye_l, br)
    # lower jaw
    lo_m = fill_mask(W, H, lambda c: blob(c, [(116, 152), (190, 150), (252, 146), (240, 172), (190, 190), (140, 186)]))
    lower = shade(lo_m, jaw_col, roundness=0.8, spec=0.3)
    teeth_l = spikes([(156 + i * 18, 152, -88) for i in range(5)], tooth_col, 16, 5, outline=2)
    tongue = fill_mask(W, H, lambda c: ellipse(c, 190, 156, 40, 7))
    lo_layer = stack(teeth_l, lower, shade(tongue, hexc('d84a6a'), roundness=0.9, outline=2))
    parts = [P('back', back, FEET, None, -2), P('stem', st, (160, 298), None, -1),
             P('head', up_layer, (150, 176), 'stem', 0),
             P('jaw', lo_layer, (122, 152), 'head', -1),
             P('lids', lids([(196, 96, 0.8)], head_col), (150, 176), 'head', 1),
             P('front', front, FEET, None, 2)]
    return parts, {"hinge": True}


@plant
def snapper_trap():
    return trap(hexc('9a4ac8'), hexc('7a38a8'), hexc('fbf6e6'), hexc('d9a8ff'), hexc('4fae35'))


@plant
def vortex_trap():
    return trap(hexc('2fb8a8'), hexc('208f86'), hexc('eafff8'), hexc('a8fff0'), hexc('3f9a5a'), swirl=True)


def wall_body(col, eyes_y=150, bands=False, thorns=False, stage=0, tall=False, seed=2):
    top = 50 if tall else 70
    m = fill_mask(W, H, lambda c: blob(c, [(160, top), (214, top + 14), (236, 150), (230, 250), (200, 296), (120, 296), (90, 250), (84, 150), (106, top + 14)]))
    det = tex_wood(W, H, seed=seed, scale=1.3)
    body = shade(m, col, roundness=0.7, detail=det, spec=0.15, toon=0.5)
    top_m = fill_mask(W, H, lambda c: ellipse(c, 160, top + 22, 50, 16))
    rings = paint_strokes(top_m.shape, [[(160 + math.cos(t) * r, top + 22 + math.sin(t) * r * 0.32) for t in np.linspace(0, 6.3, 30)] for r in (14, 26, 38)], 2, 0.25)
    body.over_layer(clip_layer(shade(top_m, hsv_shift(col, ds=0.7, dv=1.35), roundness=0.4, outline=2, detail=rings, spec=0.05), m))
    layers = [body]
    if bands:
        for y in (110, 240):
            b = fill_mask(W, H, lambda c: c.rectangle(80, y - 9, 160, 18))
            b = b * m
            layers.append(shade(b, hexc('8a9098'), roundness=0.9, spec=0.8, spec_power=12, outline=2))
            rv = fill_mask(W, H, lambda c: [ellipse(c, x, y, 3.5, 3.5) for x in (104, 136, 184, 216)])
            layers.append(shade(rv * m, hexc('c8ccd2'), roundness=1, spec=0.9, outline=1))
    if thorns:
        layers.insert(0, spikes([(96, 120, 200), (88, 180, 185), (94, 240, 165), (224, 120, -20), (232, 180, -5), (226, 240, 15), (130, 82, -110), (190, 82, -70)], hexc('c84a6a'), 30, 9))
    if stage >= 1:
        cr = paint_strokes(m.shape, [[(196, 90), (184, 120), (198, 140), (186, 170)], [(120, 210), (134, 230), (124, 250)]], 4, 0.55, 0.6)
        layers.append(flat_layer(m * (1 - cr), (0, 0, 0), 0.0))
        body.rgb *= cr[..., None]
    if stage >= 2:
        chip = fill_mask(W, H, lambda c: blob(c, [(214, 84), (238, 118), (222, 132), (204, 110)]))
        body.a = body.a * (1 - chip)
        cr2 = paint_strokes(m.shape, [[(110, 110), (130, 140), (118, 170), (140, 200)], [(200, 200), (186, 236), (204, 262)]], 5, 0.6, 0.6)
        body.rgb *= cr2[..., None]
    es = 1.15
    e1, e2 = (136, eyes_y, es), (186, eyes_y, es)
    look = (4, 1) if stage < 2 else (2, 4)
    face = [eye(136, eyes_y, es, look=look), eye(186, eyes_y, es, look=look)]
    if stage == 0:
        face.append(mouth([(146, eyes_y + 44), (161, eyes_y + 50), (176, eyes_y + 44)], width=5))
    else:
        face.append(mouth([(146, eyes_y + 50), (161, eyes_y + 44), (176, eyes_y + 50)], width=5))
        face.append(brow((120, eyes_y - 24), (136, eyes_y - 30), (150, eyes_y - 24), hsv_shift(col, dv=0.4), 6))
        face.append(brow((172, eyes_y - 24), (186, eyes_y - 30), (200, eyes_y - 24), hsv_shift(col, dv=0.4), 6))
    return stack(*layers, *face), [e1, e2]


def wall(col, **kw):
    parts = []
    eyes_ = None
    for s in range(3):
        b, eyes_ = wall_body(col, stage=s, **kw)
        parts.append(P('body' if s == 0 else 'body_%d' % s, b, FEET, None, 0))
    parts.append(P('lids', lids(eyes_, hsv_shift(col, dv=0.95)), FEET, 'body', 1))
    return parts, {"stages": 3}


@plant
def bark_wall():
    return wall(hexc('b07a44'))


@plant
def ironbark_wall():
    return wall(hexc('8a6a4a'), bands=True, seed=5)


@plant
def thornwall():
    return wall(hexc('a8743e'), thorns=True, seed=7)


@plant
def elder_oak():
    trunk_m = fill_mask(W, H, lambda c: blob(c, [(124, 110), (196, 110), (208, 220), (238, 296), (82, 296), (112, 220)]))
    det = tex_wood(W, H, seed=9, scale=1.0)
    trunk = shade(trunk_m, hexc('8a5a34'), roundness=0.6, detail=det, spec=0.1)
    roots = stroke_mask(W, H, lambda c: [(c.move_to(120, 280), c.curve_to(100, 290, 80, 292, 64, 298)), (c.move_to(200, 280), c.curve_to(222, 290, 240, 292, 258, 298))], 14)
    trunk = stack(shade(roots, hexc('7a4e2c'), roundness=1, detail=det), trunk)
    e1, e2 = (140, 196, 0.85), (182, 196, 0.85)
    face = stack(eye(140, 196, 0.85, look=(3, 1), iris=hexc('7ab84a')), eye(182, 196, 0.85, look=(3, 1), iris=hexc('7ab84a')),
                 brow((124, 176), (140, 170), (154, 178), hexc('4a2e18'), 7), brow((168, 178), (182, 170), (198, 176), hexc('4a2e18'), 7),
                 mouth([(146, 236), (161, 242), (176, 236)], width=5))
    beard = leaves([(150, 250, 100, 30, 10), (170, 250, 80, 30, 10)], hexc('6aa84a'), vein=False)
    body = stack(trunk, face, beard)

    canopy_layers = []
    blobs = [(160, 74, 96, 54, '4f9a35'), (92, 92, 52, 40, '458c30'), (228, 92, 52, 40, '458c30'), (124, 44, 54, 40, '5aaa3f'), (196, 44, 54, 40, '5aaa3f'), (160, 30, 52, 34, '66b84a')]
    for (x, y, rx, ry, c) in blobs:
        m = fill_mask(W, H, lambda c_: blob(c_, [(x + math.cos(t) * rx * (1 + 0.09 * math.sin(t * 5)), y + math.sin(t) * ry * (1 + 0.09 * math.cos(t * 4))) for t in np.linspace(0, 6.2, 14)[:-1]]))
        leafy = 0.9 + 0.1 * noise(W, H, 3, 3, seed=x)
        canopy_layers.append(shade(m, hexc(c), roundness=0.8, detail=leafy, spec=0.12))
    fruit = fill_mask(W, H, lambda c: [ellipse(c, x, y, 6, 6) for (x, y) in [(118, 58), (204, 70), (160, 40), (236, 96), (86, 96)]])
    canopy_layers.append(shade(fruit, hexc('e84a3a'), roundness=1, spec=0.8, outline=2))
    canopy = stack(*canopy_layers)
    # canopy canvas is shifted: it sits above the trunk (pivot at trunk top)
    canopy_shift = Layer(W, H)
    M = np.float32([[1, 0, 0], [0, 1, 18]])
    canopy_shift.rgb = cv2.warpAffine(canopy.rgb, M, (W, H))
    canopy_shift.a = cv2.warpAffine(canopy.a, M, (W, H))
    parts = [P('body', body, FEET, None, 0), P('canopy', canopy_shift, (160, 130), 'body', -1),
             P('lids', lids([e1, e2], hexc('8a5a34')), FEET, 'body', 1)]
    return parts, {"tall": True}


def mine(body_col, armed_extra=None, seed=3, light_col='ff3a2a'):
    mound_m = fill_mask(W, H, lambda c: ellipse(c, 160, 292, 70, 20))
    dirt = shade(mound_m, hexc('7a5232'), roundness=0.6, detail=0.85 + 0.15 * noise(W, H, 3, 2, seed=1), spec=0)
    pebbles = fill_mask(W, H, lambda c: [ellipse(c, x, y, 6, 4) for (x, y) in [(110, 288), (204, 286), (150, 296), (186, 298)]])
    dirt.over_layer(shade(pebbles, hexc('9a8a7a'), roundness=1, outline=1.5))
    sprout = leaves([(160, 282, -110, 26, 8), (160, 282, -70, 24, 8)], hexc('5aae3a'))
    buried = stack(dirt, sprout)
    body_m = fill_mask(W, H, lambda c: blob(c, [(108, 290), (104, 250), (124, 214), (160, 204), (196, 214), (216, 250), (212, 290)]))
    body = shade(body_m, body_col, roundness=0.8, detail=0.9 + 0.1 * noise(W, H, 4, 3, seed=seed), spec=0.3)
    layers = [body]
    if armed_extra:
        layers = armed_extra + layers
    antenna = stroke_mask(W, H, lambda c: (c.move_to(160, 208), c.curve_to(160, 190, 166, 180, 162, 168)), 5)
    bulb = fill_mask(W, H, lambda c: ellipse(c, 162, 164, 9, 9))
    e1, e2 = (140, 248, 0.6), (180, 248, 0.6)
    face = [eye(140, 248, 0.6, look=(2, 1)), eye(180, 248, 0.6, look=(2, 1)), mouth([(150, 270), (160, 266), (170, 270)])]
    armed = stack(dirt, *layers, shade(antenna, hexc('5a5a5a'), roundness=1, outline=1.5), *face)
    light = stack(glow(162, 164, 26, hexc(light_col), 0.7), shade(bulb, hexc(light_col), roundness=1, spec=0.9, outline=2))
    parts = [P('buried', buried, FEET, None, 0), P('body', armed, FEET, None, 0),
             P('light', light, FEET, 'body', 1), P('lids', lids([e1, e2], body_col), FEET, 'body', 1)]
    return parts, {}


@plant
def thorn_mine():
    th = spikes([(116, 250, 200), (124, 222, 230), (160, 208, -90), (196, 222, -50), (204, 250, -20)], hexc('e6d8b0'), 22, 7)
    return mine(hexc('8a6a3a'), [th])


@plant
def volcano_mine():
    m = mine(hexc('4a3a3a'), None, seed=8, light_col='ffb02a')
    # lava cracks on the armed body
    parts, meta = m
    body = parts[1].layer
    cr = paint_strokes((H, W), [[(124, 240), (140, 256), (134, 276)], [(176, 226), (190, 246), (184, 270)], [(150, 214), (160, 230)]], 5, 1.0, 1.0)
    lava = (1 - cr) * (body.a > 0.5)
    body.over_layer(_glow_layer(cv2.GaussianBlur(lava, (0, 0), 1.5), hexc('ff7a1a')))
    return parts, meta


@plant
def ember_berry():
    stem_l = stroke_mask(W, H, lambda c: [(c.move_to(160, 150), c.curve_to(150, 180, 120, 200, 116, 220)), (c.move_to(160, 150), c.curve_to(172, 180, 200, 200, 206, 220))], 9)
    stems_l = shade(stem_l, hexc('4f8a2a'), roundness=1)
    lf = leaves([(160, 150, -150, 50, 17), (160, 150, -40, 46, 15)], hexc('4fae35'))
    layers = [stems_l, lf]
    eyes_ = []
    for (x, y, r, look) in [(116, 246, 46, (3, 1)), (206, 250, 42, (-3, 1))]:
        m = fill_mask(W, H, lambda c: ellipse(c, x, y, r, r * 0.96))
        layers.append(shade(m, hexc('d8202a'), roundness=0.9, spec=0.75, spec_power=14, h_extra=sphere_bulge(x, y, r, r, 20)))
        es = r / 46
        layers += [eye(x - 13 * es, y - 6, 0.62 * es, look=look), eye(x + 13 * es, y - 6, 0.62 * es, look=look),
                   brow((x - 26 * es, y - 28), (x - 13 * es, y - 22), (x - 2 * es, y - 18), hexc('5a0a0a'), 6),
                   brow((x + 2 * es, y - 18), (x + 13 * es, y - 22), (x + 26 * es, y - 28), hexc('5a0a0a'), 6),
                   mouth([(x - 10 * es, y + 18), (x, y + 12), (x + 10 * es, y + 18)], width=4)]
        eyes_ += [(x - 13 * es, y - 6, 0.62 * es), (x + 13 * es, y - 6, 0.62 * es)]
    body = stack(*layers)
    return [P('body', body, FEET, None, 0)], {}


@plant
def rime_lettuce():
    layers = []
    rng = np.random.default_rng(2)
    for i, (a, ln, wd, col) in enumerate([(-170, 74, 34, 'a8e8f0'), (-10, 74, 34, 'a8e8f0'), (-140, 70, 34, 'c4f2f8'), (-40, 70, 34, 'c4f2f8'), (-115, 64, 34, 'd8f8ff'), (-65, 64, 34, 'd8f8ff')]):
        layers.append(leaves([(160, 290, a, ln, wd, -8)], hexc(col), roundness=0.6, serrated=False))
    head_m = fill_mask(W, H, lambda c: ellipse(c, 160, 252, 46, 40))
    curls = paint_strokes(head_m.shape, [[(140, 230), (150, 220), (162, 226)], [(168, 236), (180, 228), (188, 240)], [(132, 258), (140, 248)]], 3, 0.25)
    layers.append(shade(head_m, hexc('e6fbff'), roundness=0.85, detail=curls, spec=0.4, shadow=hexc('6ab4d8')))
    frost = fill_mask(W, H, lambda c: [ellipse(c, 120 + rng.random() * 80, 220 + rng.random() * 60, 1.8, 1.8) for _ in range(40)])
    layers.append(flat_layer(frost, (1, 1, 1), 0.9))
    e1, e2 = (146, 252, 0.62), (174, 252, 0.62)
    layers += [eye(146, 252, 0.62, look=(1, 2), iris=hexc('4ab0e0')), eye(174, 252, 0.62, look=(1, 2), iris=hexc('4ab0e0')),
               mouth([(152, 272), (160, 278), (168, 272)])]
    body = stack(*layers)
    return [P('body', body, FEET, None, 0), P('lids', lids([e1, e2], hexc('e6fbff')), FEET, 'body', 1)], {}


@plant
def bramble_vine():
    vine = stroke_mask(W, H, lambda c: (c.move_to(70, 286), c.curve_to(110, 260, 140, 300, 170, 278), c.curve_to(200, 258, 230, 300, 256, 280)), 16)
    vine2 = stroke_mask(W, H, lambda c: (c.move_to(80, 296), c.curve_to(120, 276, 160, 304, 200, 290), c.curve_to(220, 284, 240, 296, 250, 294)), 12)
    v = stack(shade(vine2, hexc('3f7a2a'), roundness=1), shade(vine, hexc('4f8f35'), roundness=1))
    th = spikes([(x, 282 + 8 * math.sin(x * 0.07), -90 + 30 * math.sin(x)) for x in range(80, 250, 18)], hexc('d0c09a'), 26, 6)
    lf = leaves([(110, 280, -140, 30, 10), (200, 276, -40, 30, 10), (156, 288, -100, 24, 8)], hexc('5aae3a'))
    e1, e2 = (146, 268, 0.5), (170, 268, 0.5)
    body = stack(th, v, lf, eye(146, 268, 0.5, look=(2, 0)), eye(170, 268, 0.5, look=(2, 0)),
                 brow((136, 254), (146, 258), (154, 262), hexc('2a4a1a'), 4), brow((162, 262), (170, 258), (180, 254), hexc('2a4a1a'), 4))
    return [P('body', body, FEET, None, 0), P('lids', lids([e1, e2], hexc('4f8f35')), FEET, 'body', 1)], {}


@plant
def gale_fern():
    layers = []
    for (a, ln, col) in [(-150, 110, '3f8f35'), (-30, 110, '3f8f35'), (-120, 120, '4f9f3f'), (-60, 120, '4f9f3f'), (-90, 126, '5aaa45')]:
        ar = math.radians(a)
        specs = [(160 + math.cos(ar) * d, 290 + math.sin(ar) * d, a + s * 70, 26 - d * 0.12, 8) for d in range(12, ln, 14) for s in (-1, 1)]
        layers.append(leaves(specs, hexc(col), vein=False, roundness=0.6))
        rib = stroke_mask(W, H, lambda c: (c.move_to(160, 290), c.line_to(160 + math.cos(ar) * ln, 290 + math.sin(ar) * ln)), 4)
        layers.append(shade(rib, hexc('2f6f25'), roundness=1, outline=1))
    curl = stroke_mask(W, H, lambda c: [c.line_to(160 + math.cos(t) * (4 + t * 3), 160 + math.sin(t) * (4 + t * 3)) for t in np.linspace(0, 10, 50)], 7)
    layers.append(shade(curl, hexc('6aba4f'), roundness=1))
    face_m = fill_mask(W, H, lambda c: ellipse(c, 160, 236, 36, 30))
    layers.append(shade(face_m, hexc('7ac85a'), roundness=0.9, spec=0.3))
    e1, e2 = (148, 232, 0.55), (172, 232, 0.55)
    layers += [eye(148, 232, 0.55, look=(3, 0)), eye(172, 232, 0.55, look=(3, 0))]
    blow_m = fill_mask(W, H, lambda c: ellipse(c, 160, 252, 7, 6))
    layers.append(shade(blow_m, hexc('3a1a12'), roundness=0.8, outline=1.5))
    body = stack(*layers)
    return [P('body', body, FEET, None, 0), P('lids', lids([e1, e2], hexc('7ac85a')), FEET, 'body', 1)], {}


@plant
def lily_raft():
    def pad_path(c):
        c.save(); c.translate(160, 284); c.scale(1.0, 0.36)
        c.move_to(0, 0); c.arc(0, 0, 84, math.radians(-75), math.radians(250)); c.close_path()
        c.restore()
    pad = fill_mask(W, H, pad_path)
    veins = paint_strokes(pad.shape, [[(160, 284), (160 + math.cos(a) * 76, 284 + math.sin(a) * 27)] for a in np.linspace(0.3, 2 * math.pi - 0.3, 9)], 2.2, 0.22)
    rim = shade(cv2.warpAffine(pad, np.float32([[1, 0, 0], [0, 1, 6]]), (W, H)), hexc('2f7a3a'), roundness=0.5, spec=0, flat=0.4)
    pad_l = shade(pad, hexc('5ab84f'), roundness=0.45, detail=veins, spec=0.4, flat=0.35, spec_power=16)
    drops = fill_mask(W, H, lambda c: [ellipse(c, x, y, 4, 3) for (x, y) in [(130, 276), (186, 292), (150, 296)]])
    flower = petal_ring(204, 270, 7, 4, 20, 8, hexc('ffb6d0'))
    flower2 = petal_ring(204, 268, 5, 3, 12, 6, hexc('fff0f5'), rot=0.4)
    body = stack(rim, pad_l, shade(drops, hexc('d8f4ff'), roundness=1, spec=1.0, outline=1), flower, flower2)
    return [P('body', body, FEET, None, 0)], {"platform": True}


def preview_sheet(ids, path):
    tiles = []
    for pid in ids:
        d = os.path.join(OUT, pid)
        info = json.load(open(os.path.join(d, 'rig.json')))
        canvas = Layer(W, H + 40)
        canvas.over(np.broadcast_to(hexc('6fa64a'), (H + 40, W, 3)), np.ones((H + 40, W), np.float32))
        world = {}
        for part in info['parts']:
            par = part['parent']
            base = world[par] if par else (160, 300 + 20)
            world[part['name']] = (base[0] + part['pos'][0], base[1] + part['pos'][1])
        for part in sorted(info['parts'], key=lambda p: p['z']):
            if part['name'] in ('lids', 'buried', 'body_1', 'body_2'):
                continue
            img = cv2.imread(os.path.join(d, part['name'] + '.png'), cv2.IMREAD_UNCHANGED)
            img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGBA).astype(np.float32) / 255
            px, py = world[part['name']]
            x0, y0 = int(px + part['offset'][0]), int(py + part['offset'][1])
            h, w = img.shape[:2]
            sub = Layer(W, H + 40)
            xa, ya = max(0, x0), max(0, y0)
            xb, yb = min(W, x0 + w), min(H + 40, y0 + h)
            if xb <= xa or yb <= ya:
                continue
            sub.rgb[ya:yb, xa:xb] = img[ya - y0:yb - y0, xa - x0:xb - x0, :3]
            sub.a[ya:yb, xa:xb] = img[ya - y0:yb - y0, xa - x0:xb - x0, 3]
            canvas.over_layer(sub)
        img = (np.dstack([canvas.rgb, canvas.a]) * 255).astype(np.uint8)
        cv2.putText(img, pid, (6, H + 32), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255, 255), 1)
        tiles.append(img)
    cols = 7
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * (H + 40), cols * W, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * (H + 40):(r + 1) * (H + 40), c * W:(c + 1) * W] = t
    cv2.imwrite(path, cv2.cvtColor(sheet, cv2.COLOR_RGBA2BGRA))


def main(ids):
    ids = ids or list(REG)
    for pid in ids:
        parts, meta = REG[pid]()
        export_rig(os.path.join(OUT, pid), parts, FEET, 0.5, {"meta": meta})
        print('painted', pid)
    preview_sheet(ids, '/tmp/plants_sheet.png')


if __name__ == '__main__':
    main(sys.argv[1:])
