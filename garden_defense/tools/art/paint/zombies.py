"""Painted zombie cut-out parts. Each part has its own canvas and pivot; the
game positions parts with its two-segment limb kinematics (zombie.gd).
Limbs are painted hanging straight down from their pivot (+Y)."""
import sys, os, math, json
import numpy as np, cv2
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
from parts import eye, brow, spikes, _glow_layer, stack as _stack

OUT = os.path.join(os.path.dirname(__file__), '../../../assets/sprites/zombies')


def stack(w, h, *ls):
    return _stack(*ls, w=w, h=h)


STYLES = {
    'shambler':      dict(skin='9fb48a', coat='6a5440', shirt='d8d0b8', tie='a8322a', pants='4a4038', shoe='3a2e26'),
    'flagbearer':    dict(skin='9fb48a', coat='54486a', shirt='d8d0b8', tie='2a6a3a', pants='3e3848', shoe='2e2a30', flag=True),
    'cone_head':     dict(skin='a2b28c', coat='6a5440', shirt='d8d0b8', tie='2a4aa8', pants='4a4038', shoe='3a2e26', hat='cone'),
    'bucket_head':   dict(skin='98ae86', coat='5a5a48', shirt='d8d0b8', tie='8a2a5a', pants='45443a', shoe='3a2e26', hat='bucket'),
    'sprinter':      dict(skin='a8b88e', coat='c83a2e', shirt='f0f0e8', tie=None, pants='2a3a6a', shoe='f0f0f0', band=True, track=True),
    'hurdler':       dict(skin='a4b48c', coat='e8b82a', shirt='f0f0e8', tie=None, pants='2a2a30', shoe='e84a2a', track=True, number=True),
    'shield_carrier':dict(skin='9cb088', coat='e8742a', shirt='d8d0b8', tie=None, pants='3a4a5a', shoe='3a2e26', vest=True, shield=True),
    'burrower':      dict(skin='a0ae88', coat='6a4a2a', shirt='c8b890', tie=None, pants='5a4a3a', shoe='3a2e26', helmet=True, overalls=True),
    'brute':         dict(skin='8fa67e', coat='7a6a5a', shirt='c8c0a8', tie=None, pants='4a3e34', shoe='2e2620', brute=True),
}


def part_canvas(w, h):
    return w, h


def limb(w, h, piv, length, w0, w1, col, end=None, seed=1, cuff=None):
    """Tapered limb hanging down from pivot."""
    px, py = piv
    def draw(c):
        c.move_to(px - w0 / 2, py)
        c.curve_to(px - w0 / 2 - 2, py + length * 0.5, px - w1 / 2, py + length * 0.8, px - w1 / 2, py + length)
        c.line_to(px + w1 / 2, py + length)
        c.curve_to(px + w1 / 2, py + length * 0.8, px + w0 / 2 + 2, py + length * 0.5, px + w0 / 2, py)
        c.close_path()
        ellipse(c, px, py, w0 / 2, w0 / 2.4)
        ellipse(c, px, py + length, w1 / 2, w1 / 2.4)
    m = fill_mask(w, h, draw)
    det = 0.9 + 0.1 * noise(w, h, 4, 3, seed)
    return shade(m, hexc(col), roundness=1.0, detail=det, spec=0.1, toon=0.5, outline=3)


def hand(w, h, cx, cy, skin, s=1.0):
    def draw(c):
        ellipse(c, cx, cy, 13 * s, 11 * s)
        for i, a in enumerate([-140, -110, -80]):
            ar = math.radians(a + 180)
        c.new_sub_path()
    m = fill_mask(w, h, lambda c: ellipse(c, cx, cy, 13 * s, 11 * s))
    fingers = stroke_mask(w, h, lambda c: [(c.move_to(cx - 6 * s, cy + 4 * s), c.line_to(cx - 18 * s + i * 7 * s, cy + 18 * s)) for i in range(3)], 6.5 * s)
    m = np.maximum(m, fingers)
    return shade(m, hexc(skin), roundness=1.0, spec=0.1, outline=2.5)


def build(zid, st):
    out = {}
    brute = st.get('brute', False)
    k = 1.0
    skin, coat, shirt, pants, shoe = st['skin'], st['coat'], st['shirt'], st['pants'], st['shoe']
    # ---- legs (thigh pivot = hip joint, shin pivot = knee)
    W1, H1 = 90, 110
    out['thigh'] = (limb(W1, H1, (45, 14), 54, 30, 24, pants, seed=2), (45, 14))
    shin = limb(W1, H1, (45, 12), 50, 24, 20, pants, seed=3)
    sock = fill_mask(W1, H1, lambda c: c.rectangle(35, 52, 20, 10))
    shin.over_layer(shade(sock, hexc('d8d8d0' if not st.get('track') else 'f8f8f8'), roundness=1, outline=2))
    shoe_m = fill_mask(W1, H1, lambda c: blob(c, [(54, 58), (56, 74), (40, 78), (14, 76), (12, 66), (30, 60)]))
    shin.over_layer(shade(shoe_m, hexc(shoe), roundness=0.8, spec=0.35, outline=3))
    if st.get('track'):
        stripe = stroke_mask(W1, H1, lambda c: (c.move_to(44, 14), c.line_to(42, 50)), 4)
        shin.over_layer(flat_layer(stripe, (1, 1, 1), 0.85))
    out['shin'] = (shin, (45, 12))
    # ---- arms (upper pivot = shoulder, fore pivot = elbow)
    sleeve = coat
    out['arm_upper'] = (limb(W1, H1, (45, 14), 50, 26, 20, sleeve, seed=4), (45, 14))
    fore = limb(W1, H1, (45, 10), 40, 19, 16, skin, seed=5)
    cuff = fill_mask(W1, H1, lambda c: ellipse(c, 45, 12, 12, 8))
    fore.over_layer(shade(cuff, hexc(shirt), roundness=1, outline=2))
    fore.over_layer(hand(W1, H1, 45, 56, skin))
    out['arm_fore'] = (fore, (45, 10))
    stub = limb(W1, H1, (45, 14), 26, 26, 22, sleeve, seed=4)
    torn = fill_mask(W1, H1, lambda c: blob(c, [(33, 36), (40, 46), (46, 38), (52, 48), (58, 36), (56, 30), (34, 30)]))
    stub.over_layer(shade(torn, hexc(skin), roundness=1, outline=2))
    out['arm_stub'] = (stub, (45, 14))
    # ---- torso (pivot = hip centre). Upright box ~92 x 132 (2x), front faces left.
    TW, TH = 180, 220
    hx, hy = 90, 190
    def torso_path(c):
        blob(c, [(hx - 44, hy - 4), (hx - 50, hy - 70), (hx - 46, hy - 128), (hx - 20, hy - 140), (hx + 26, hy - 140), (hx + 50, hy - 124), (hx + 52, hy - 60), (hx + 46, hy - 2)], tension=0.35)
    tm = fill_mask(TW, TH, torso_path)
    det = 0.88 + 0.12 * noise(TW, TH, 5, 3, seed=6)
    torso = shade(tm, hexc(coat), roundness=0.7, detail=det, spec=0.12, toon=0.5)
    if not st.get('track') and not st.get('overalls') and not brute:
        shirt_m = fill_mask(TW, TH, lambda c: (c.move_to(hx - 26, hy - 138), c.line_to(hx + 4, hy - 138), c.line_to(hx - 4, hy - 60), c.line_to(hx - 18, hy - 60), c.close_path()))
        torso.over_layer(clip_layer(shade(shirt_m, hexc(shirt), roundness=0.8, outline=2), tm))
        if st.get('tie'):
            tie_m = fill_mask(TW, TH, lambda c: (c.move_to(hx - 16, hy - 134), c.line_to(hx - 6, hy - 134), c.line_to(hx - 4, hy - 84), c.line_to(hx - 12, hy - 74), c.line_to(hx - 20, hy - 84), c.close_path()))
            torso.over_layer(shade(tie_m, hexc(st['tie']), roundness=0.8, spec=0.3, outline=2))
        lapel = stroke_mask(TW, TH, lambda c: [(c.move_to(hx - 30, hy - 136), c.line_to(hx - 22, hy - 70)), (c.move_to(hx + 8, hy - 136), c.line_to(hx - 2, hy - 70))], 4)
        torso.over_layer(flat_layer(lapel * tm, hsv_shift(hexc(coat), dv=0.55), 0.8))
        btn = fill_mask(TW, TH, lambda c: [ellipse(c, hx + 2, y, 4, 4) for y in (hy - 50, hy - 30)])
        torso.over_layer(shade(btn, hexc('2a2420'), roundness=1, outline=1))
    if st.get('track'):
        zip_ = stroke_mask(TW, TH, lambda c: (c.move_to(hx - 12, hy - 138), c.line_to(hx - 12, hy - 6)), 3)
        torso.over_layer(flat_layer(zip_, (0.95, 0.95, 0.9), 0.9))
        stripe = stroke_mask(TW, TH, lambda c: (c.move_to(hx + 40, hy - 130), c.line_to(hx + 44, hy - 10)), 6)
        torso.over_layer(flat_layer(stripe * tm, (1, 1, 1), 0.9))
    if st.get('number'):
        n_m = fill_mask(TW, TH, lambda c: c.rectangle(hx - 34, hy - 104, 44, 38))
        torso.over_layer(shade(n_m, hexc('f8f8f0'), roundness=0.5, outline=2))
        num = stroke_mask(TW, TH, lambda c: (c.move_to(hx - 20, hy - 96), c.line_to(hx - 10, hy - 100), c.line_to(hx - 10, hy - 72)), 4)
        torso.over_layer(flat_layer(num, (0.1, 0.1, 0.1), 1))
    if st.get('vest'):
        band = fill_mask(TW, TH, lambda c: [c.rectangle(hx - 50, y, 104, 9) for y in (hy - 90, hy - 50)])
        torso.over_layer(clip_layer(shade(band, hexc('f0f0a0'), roundness=1, spec=0.6, outline=0), tm))
    if st.get('overalls'):
        bib = fill_mask(TW, TH, lambda c: blob(c, [(hx - 34, hy - 110), (hx + 22, hy - 110), (hx + 30, hy - 4), (hx - 40, hy - 4)], tension=0.2))
        torso.over_layer(clip_layer(shade(bib, hexc('3a5a8a'), roundness=0.7, outline=2, detail=0.9 + 0.1 * noise(TW, TH, 3, 2, 9)), tm))
        straps = stroke_mask(TW, TH, lambda c: [(c.move_to(hx - 30, hy - 110), c.line_to(hx - 26, hy - 140)), (c.move_to(hx + 18, hy - 110), c.line_to(hx + 22, hy - 140))], 7)
        torso.over_layer(shade(straps * tm, hexc('3a5a8a'), roundness=1, outline=1.5))
    if brute:
        belly = fill_mask(TW, TH, lambda c: ellipse(c, hx - 6, hy - 50, 40, 36))
        torso.over_layer(clip_layer(shade(belly, hexc(skin), roundness=0.9, outline=2, spec=0.1), tm))
        rip = stroke_mask(TW, TH, lambda c: (c.move_to(hx - 30, hy - 120), c.line_to(hx - 18, hy - 104), c.line_to(hx - 28, hy - 92)), 3)
        torso.over_layer(flat_layer(rip, (0.2, 0.15, 0.1), 0.8))
    # tears and stains
    stain = fill_mask(TW, TH, lambda c: [ellipse(c, hx + 24, hy - 40, 9, 6), ellipse(c, hx - 30, hy - 20, 6, 4)])
    torso.over_layer(flat_layer(cv2.GaussianBlur(stain, (0, 0), 2) * tm, (0.22, 0.2, 0.12), 0.35))
    # belt
    belt = fill_mask(TW, TH, lambda c: c.rectangle(hx - 50, hy - 16, 104, 12))
    torso.over_layer(clip_layer(shade(belt, hexc(pants), roundness=1, outline=1.5), tm))
    out['torso'] = (torso, (hx, hy))
    # ---- head (pivot = neck). Skull centre at neck + (-4, -48).
    HW, HH = 200, 200
    nx, ny = 104, 168
    cx, cy = nx - 6, ny - 52
    def head_path(c):
        blob(c, [(cx - 46, cy + 6), (cx - 44, cy - 30), (cx - 14, cy - 54), (cx + 26, cy - 52), (cx + 50, cy - 24), (cx + 50, cy + 14), (cx + 30, cy + 40), (cx - 10, cy + 44), (cx - 40, cy + 30)])
    hm = fill_mask(HW, HH, head_path)
    neck_m = stroke_mask(HW, HH, lambda c: (c.move_to(nx, ny + 6), c.line_to(nx - 2, cy + 30)), 26)
    ear = fill_mask(HW, HH, lambda c: ellipse(c, cx + 44, cy + 4, 11, 15))
    det = 0.9 + 0.1 * noise(HW, HH, 4, 3, seed=7)
    veins = paint_strokes(hm.shape, [[(cx + 20, cy - 40), (cx + 30, cy - 26), (cx + 26, cy - 14)], [(cx - 30, cy + 20), (cx - 22, cy + 30)]], 2, 0.25)
    head = stack(HW, HH, shade(neck_m, hsv_shift(hexc(skin), dv=0.8), roundness=1),
                 shade(ear, hexc(skin), roundness=0.9, outline=2.5),
                 shade(hm, hexc(skin), roundness=0.8, detail=det * veins, spec=0.15, toon=0.5, h_extra=None))
    # hair tufts
    if not st.get('hat') and not st.get('helmet'):
        hair = stroke_mask(HW, HH, lambda c: [(c.move_to(cx + x, cy - 50), c.curve_to(cx + x + 6, cy - 62, cx + x + 12, cy - 64, cx + x + 18, cy - 60)) for x in (-12, 4)], 4)
        head.over_layer(flat_layer(hair, (0.18, 0.15, 0.12), 1))
    # eye sockets + eyes (left side = facing direction); one big, one small
    sock = fill_mask(HW, HH, lambda c: (ellipse(c, cx - 22, cy - 8, 17, 15), ellipse(c, cx + 8, cy - 6, 13, 12)))
    head.over_layer(flat_layer(cv2.GaussianBlur(sock, (0, 0), 3) * hm, hsv_shift(hexc(skin), dv=0.5), 0.5))
    head.over_layer(eye(cx - 22, cy - 8, 0.85, look=(-5, 2), w=HW, h=HH, ring=hexc('2a2a1a'), pupil=hexc('1a1a14'), iris=hexc('e8e0a0')))
    head.over_layer(eye(cx + 8, cy - 6, 0.62, look=(-4, 3), w=HW, h=HH, ring=hexc('2a2a1a'), iris=hexc('e8e0a0')))
    lid = fill_mask(HW, HH, lambda c: (c.move_to(cx - 40, cy - 26), c.line_to(cx - 4, cy - 22), c.line_to(cx - 4, cy - 14), c.line_to(cx - 40, cy - 16), c.close_path()))
    head.over_layer(shade(lid, hexc(skin), roundness=1, outline=2, spec=0.05))
    nose = stroke_mask(HW, HH, lambda c: (c.move_to(cx - 12, cy + 2), c.line_to(cx - 18, cy + 14), c.line_to(cx - 10, cy + 16)), 3)
    head.over_layer(flat_layer(nose, hsv_shift(hexc(skin), dv=0.45), 0.8))
    # upper teeth row
    mouth_m = fill_mask(HW, HH, lambda c: blob(c, [(cx - 36, cy + 22), (cx - 4, cy + 20), (cx + 10, cy + 24), (cx - 4, cy + 30), (cx - 34, cy + 30)]))
    head.over_layer(shade(mouth_m, hexc('3a1414'), roundness=0.7, outline=2))
    teeth = fill_mask(HW, HH, lambda c: [c.rectangle(cx - 32 + i * 10, cy + 22, 7, 7) for i in (0, 1, 3)])
    head.over_layer(shade(teeth, hexc('f0e8c8'), roundness=1, outline=1))
    out['head'] = (head, (nx, ny))
    # ---- jaw (pivot = hinge near the back of the mouth)
    jx, jy = cx + 14, cy + 26
    jaw_m = fill_mask(HW, HH, lambda c: blob(c, [(cx - 40, cy + 26), (cx + 18, cy + 24), (cx + 22, cy + 34), (cx - 4, cy + 46), (cx - 36, cy + 40)]))
    jaw = shade(jaw_m, hexc(skin), roundness=0.8, outline=2.5, detail=det)
    lt = fill_mask(HW, HH, lambda c: [c.rectangle(cx - 30 + i * 11, cy + 25, 6, 6) for i in (0, 2)])
    jaw.over_layer(shade(lt, hexc('f0e8c8'), roundness=1, outline=1))
    out['jaw'] = (jaw, (jx, jy))
    # ---- accessories (pivot = neck, same frame as head)
    if st.get('hat') == 'cone':
        for s in range(3):
            tilt = [0, 0.12, 0.28][s]
            hgt = [118, 112, 84][s]
            def cone_path(c, tilt=tilt, hgt=hgt):
                c.save(); c.translate(cx, cy - 34); c.rotate(tilt)
                c.move_to(-54, 6); c.line_to(-10, -hgt); c.line_to(6, -hgt); c.line_to(54, 6); c.close_path()
                c.restore()
            m = fill_mask(HW, HH, cone_path)
            stripes = fill_mask(HW, HH, lambda c, tilt=tilt: (c.save(), c.translate(cx, cy - 34), c.rotate(tilt), c.rectangle(-60, -46, 120, 14), c.rectangle(-60, -82, 120, 10), c.restore()))
            L = shade(m, hexc('f07a22'), roundness=0.55, spec=0.35, toon=0.55)
            L.over_layer(clip_layer(shade(stripes, hexc('f8f2e8'), roundness=0.6, outline=0, spec=0.3), m))
            brim = fill_mask(HW, HH, lambda c, tilt=tilt: (c.save(), c.translate(cx, cy - 30), c.rotate(tilt), ellipse(c, 0, 0, 62, 11), c.restore()))
            L = stack(HW, HH, shade(brim, hexc('d85a12'), roundness=0.8, outline=3), L)
            if s >= 1:
                cr = paint_strokes(m.shape, [[(cx + 10, cy - 100), (cx + 20, cy - 80), (cx + 12, cy - 60)]], 3, 0.6, 0.5)
                L.rgb *= cr[..., None]
            if s == 2:
                chunk = fill_mask(HW, HH, lambda c: blob(c, [(cx + 10, cy - 140), (cx + 40, cy - 90), (cx + 20, cy - 80), (cx - 4, cy - 110)]))
                L.a *= 1 - chunk
            out['hat_%d' % s] = (L, (nx, ny))
    if st.get('hat') == 'bucket':
        for s in range(3):
            m = fill_mask(HW, HH, lambda c: (c.move_to(cx - 56, cy - 16), c.line_to(cx - 46, cy - 110), c.line_to(cx + 46, cy - 110), c.line_to(cx + 56, cy - 16), c.close_path()))
            ribs = paint_strokes(m.shape, [[(cx - 54, cy - 40), (cx + 54, cy - 40)], [(cx - 50, cy - 90), (cx + 50, cy - 90)]], 3, 0.25)
            L = shade(m, hexc('9aa2aa'), roundness=0.45, spec=0.8, spec_power=10, toon=0.6, detail=ribs * (0.92 + 0.08 * noise(HW, HH, 3, 2, 4)))
            handle = stroke_mask(HW, HH, lambda c: (c.move_to(cx - 52, cy - 50), c.curve_to(cx - 40, cy + 20, cx + 40, cy + 20, cx + 52, cy - 50)), 4)
            L = stack(HW, HH, L, shade(handle, hexc('6a7078'), roundness=1, outline=1))
            if s >= 1:
                dent = fill_mask(HW, HH, lambda c: ellipse(c, cx - 10, cy - 70, 16, 12))
                L.rgb *= (1 - cv2.GaussianBlur(dent, (0, 0), 4) * 0.35)[..., None]
                cr = paint_strokes(m.shape, [[(cx + 20, cy - 108), (cx + 12, cy - 84), (cx + 24, cy - 66)]], 3, 0.7, 0.4)
                L.rgb *= cr[..., None]
            if s == 2:
                holes = fill_mask(HW, HH, lambda c: [ellipse(c, cx + 26, cy - 50, 8, 7), ellipse(c, cx - 30, cy - 90, 6, 6)])
                L.rgb *= (1 - holes * 0.8)[..., None]
                L.rgb = L.rgb * 0.85 + np.array([0.35, 0.22, 0.12]) * 0.15
            out['hat_%d' % s] = (L, (nx, ny))
    if st.get('band'):
        m = fill_mask(HW, HH, lambda c: (c.save(), c.translate(cx, cy - 34), c.rotate(-0.08), c.rectangle(-50, -9, 102, 18), c.restore()))
        out['hat_0'] = (shade(m * cv2.dilate(hm, np.ones((5, 5))), hexc('e83a2a'), roundness=1, outline=2), (nx, ny))
    if st.get('helmet'):
        m = fill_mask(HW, HH, lambda c: (c.arc(cx + 2, cy - 18, 56, math.pi, 2 * math.pi), c.close_path()))
        brim = fill_mask(HW, HH, lambda c: ellipse(c, cx, cy - 18, 64, 10))
        lamp = fill_mask(HW, HH, lambda c: ellipse(c, cx - 50, cy - 40, 12, 12))
        L = stack(HW, HH, shade(brim, hexc('d8a020'), roundness=0.8, outline=3), shade(m, hexc('f0c030'), roundness=0.6, spec=0.6),
                  _glow_layer(np.clip(1 - np.hypot(*np.mgrid[0:HH, 0:HW][::-1] - np.array([cx - 56, cy - 40])[:, None, None]) / 34, 0, 1) ** 2, hexc('fff4b0')),
                  shade(lamp, hexc('fffbe0'), roundness=1, spec=1, outline=2.5))
        out['hat_0'] = (L, (nx, ny))
    if st.get('shield'):
        SW, SH = 120, 300
        for s in range(2):
            m = fill_mask(SW, SH, lambda c: c.rectangle(20, 20, 64, 260))
            planks = paint_strokes(m.shape, [[(20, 20 + 52 * i), (84, 20 + 52 * i)] for i in range(1, 5)], 3, 0.35)
            grain = tex_grain = 0.9 + 0.1 * noise(SW, SH, 3, 3, 12)
            L = shade(m, hexc('9a7448'), roundness=0.35, detail=planks * grain, spec=0.1, toon=0.6)
            bars = fill_mask(SW, SH, lambda c: [c.rectangle(22, y, 60, 10) for y in (60, 220)])
            L.over_layer(shade(bars, hexc('6a7078'), roundness=0.9, spec=0.6, outline=2))
            knob = fill_mask(SW, SH, lambda c: ellipse(c, 34, 150, 7, 7))
            L.over_layer(shade(knob, hexc('d8b040'), roundness=1, spec=1, outline=2))
            if s == 1:
                cr = paint_strokes(m.shape, [[(40, 30), (60, 90), (36, 150), (64, 210)]], 5, 0.75, 0.5)
                L.rgb *= cr[..., None]
                L.a *= 1 - fill_mask(SW, SH, lambda c: blob(c, [(84, 230), (84, 282), (50, 282), (70, 250)]))
            out['shield_%d' % s] = (L, (52, 150))
    if st.get('flag'):
        FW, FH = 160, 260
        pole = stroke_mask(FW, FH, lambda c: (c.move_to(30, 250), c.line_to(30, 20)), 7)
        cloth = fill_mask(FW, FH, lambda c: blob(c, [(32, 26), (90, 22), (140, 34), (126, 58), (142, 86), (88, 82), (32, 92)], tension=0.4))
        L = stack(FW, FH, shade(pole, hexc('7a5a3a'), roundness=1, outline=2),
                  shade(cloth, hexc('3a6a3a'), roundness=0.5, spec=0.1, toon=0.5, detail=0.88 + 0.12 * noise(FW, FH, 4, 3, 5)))
        skull = fill_mask(FW, FH, lambda c: (ellipse(c, 80, 52, 15, 13), c.rectangle(72, 60, 16, 10)))
        L.over_layer(shade(skull, hexc('e8e0c8'), roundness=0.9, outline=2))
        sk_e = fill_mask(FW, FH, lambda c: (ellipse(c, 74, 52, 4, 4), ellipse(c, 86, 52, 4, 4)))
        L.over_layer(flat_layer(sk_e, (0.1, 0.1, 0.1), 1))
        out['flag'] = (L, (30, 250))
    if brute:
        CW, CH = 120, 260
        handle = stroke_mask(CW, CH, lambda c: (c.move_to(60, 240), c.line_to(60, 110)), 16)
        head_m = fill_mask(CW, CH, lambda c: blob(c, [(36, 120), (30, 60), (44, 20), (76, 14), (92, 50), (88, 116)]))
        grain = 0.88 + 0.12 * noise(CW, CH, 3, 3, 21)
        L = stack(CW, CH, shade(handle, hexc('7a5232'), roundness=1, detail=grain),
                  shade(head_m, hexc('8a6038'), roundness=0.8, detail=grain * paint_strokes(head_m.shape, [[(50, 40), (56, 100)], [(70, 30), (74, 96)]], 3, 0.3), spec=0.1))
        nails = spikes([(34, 50, 190), (32, 90, 175), (90, 40, -10), (88, 84, 5), (60, 16, -90)], hexc('c8ccd2'), 18, 4, w=CW, h=CH, outline=1.5)
        L = stack(CW, CH, nails, L)
        out['club'] = (L, (60, 230))
    if zid == 'hurdler':
        PW, PH = 340, 40
        m = stroke_mask(PW, PH, lambda c: (c.move_to(10, 20), c.line_to(330, 20)), 9)
        tape = fill_mask(PW, PH, lambda c: [c.rectangle(x, 0, 10, PH) for x in (40, 290)])
        L = shade(m, hexc('d8b070'), roundness=1, spec=0.4)
        L.over_layer(clip_layer(shade(tape, hexc('2a2a30'), roundness=1, outline=0), m))
        out['pole'] = (L, (170, 20))
    if zid == 'burrower':
        KW, KH = 160, 230
        handle = stroke_mask(KW, KH, lambda c: (c.move_to(60, 220), c.line_to(70, 40)), 10)
        head_m = fill_mask(KW, KH, lambda c: (c.move_to(10, 50), c.curve_to(50, 20, 100, 20, 150, 46), c.line_to(140, 54), c.curve_to(100, 38, 50, 38, 16, 60), c.close_path()))
        out['pick'] = (stack(KW, KH, shade(handle, hexc('7a5232'), roundness=1), shade(head_m, hexc('9aa0a8'), roundness=0.8, spec=0.8)), (62, 200))
    # tube ring for swimming (drawn at the waist in water cells)
    RW, RH = 220, 90
    ring = fill_mask(RW, RH, lambda c: ellipse(c, 110, 45, 92, 26))
    ring -= fill_mask(RW, RH, lambda c: ellipse(c, 110, 40, 58, 12))
    ring = np.clip(ring, 0, 1)
    stripes = fill_mask(RW, RH, lambda c: [c.rectangle(x, 0, 22, RH) for x in (40, 100, 160)])
    rl = shade(ring, hexc('f0d020'), roundness=0.9, spec=0.6, toon=0.5)
    rl.over_layer(clip_layer(shade(stripes, hexc('e84a3a'), roundness=0.9, outline=0, spec=0.5), ring))
    out['tube'] = (rl, (110, 45))
    return out


def export(zid, parts):
    d = os.path.join(OUT, zid)
    os.makedirs(d, exist_ok=True)
    info = {"scale": 0.5, "parts": {}}
    for name, (layer, piv) in parts.items():
        ox, oy, w, h = layer.to_png(os.path.join(d, name + '.png'))
        info["parts"][name] = {"offset": [float(ox - piv[0]), float(oy - piv[1])], "size": [int(w), int(h)]}
    json.dump(info, open(os.path.join(d, 'rig.json'), 'w'), indent=1)


def preview(ids, path):
    """Rough static assembly for eyeballing."""
    tiles = []
    for zid in ids:
        d = os.path.join(OUT, zid)
        info = json.load(open(os.path.join(d, 'rig.json')))
        C = Layer(300, 420)
        C.over(np.broadcast_to(hexc('6fa64a'), (420, 300, 3)), np.ones((420, 300), np.float32))
        def put(name, px, py):
            if name not in info['parts']:
                return
            img = cv2.cvtColor(cv2.imread(os.path.join(d, name + '.png'), cv2.IMREAD_UNCHANGED), cv2.COLOR_BGRA2RGBA).astype(np.float32) / 255
            o = info['parts'][name]['offset']
            x0, y0 = int(px + o[0]), int(py + o[1])
            h, w = img.shape[:2]
            sub = Layer(300, 420)
            xa, ya, xb, yb = max(0, x0), max(0, y0), min(300, x0 + w), min(420, y0 + h)
            sub.rgb[ya:yb, xa:xb] = img[ya - y0:yb - y0, xa - x0:xb - x0, :3]
            sub.a[ya:yb, xa:xb] = img[ya - y0:yb - y0, xa - x0:xb - x0, 3]
            C.over_layer(sub)
        fx, fy = 150, 400
        hip = (fx + 8, fy - 104)
        put('flag', hip[0] + 36, hip[1] + 10)
        put('arm_upper', hip[0] + 12, hip[1] - 104)
        put('thigh', hip[0] + 6, hip[1]); put('shin', hip[0] + 6, hip[1] + 52)
        put('thigh', hip[0] - 8, hip[1]); put('shin', hip[0] - 8, hip[1] + 52)
        put('torso', hip[0], hip[1])
        neck = (hip[0] - 16, hip[1] - 124)
        put('head', *neck)
        put('jaw', neck[0] + 4, neck[1] - 26 + 0)
        put('hat_0', *neck)
        put('arm_upper', hip[0] - 36, hip[1] - 100); put('arm_fore', hip[0] - 36, hip[1] - 52)
        put('shield_0', hip[0] - 80, hip[1] - 60)
        img = (np.dstack([C.rgb, C.a]) * 255).astype(np.uint8)
        cv2.putText(img, zid, (6, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255, 255), 1)
        tiles.append(img)
    sheet = np.concatenate(tiles, axis=1)
    cv2.imwrite(path, cv2.cvtColor(sheet, cv2.COLOR_RGBA2BGRA))


if __name__ == '__main__':
    ids = sys.argv[1:] or list(STYLES)
    for zid in ids:
        export(zid, build(zid, STYLES[zid]))
        print('painted', zid)
    preview(ids, '/tmp/zombies_sheet.png')
