"""v0.7: painted rigs for every zombie (styles + extra hats/props).
python3 zombies_v07.py [ids]  -> assets/sprites/zombies/<id>/ + /tmp/zombies_sheet.png"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zombies as Z
from zombies import *

def S(skin, coat, shirt, tie, pants, shoe, **kw):
    d = dict(skin=skin, coat=coat, shirt=shirt, tie=tie, pants=pants, shoe=shoe); d.update(kw); return d

MORE = {
 # tier 1-2
 'intern_imp':   S('a8ba90', 'e8e0d0', 'f0f0e8', '3a5aa8', '3a3a48', '2a2a30', hat2='cap', hatc='3a6ad8'),
 'scrapling':    S('9aa890', '8a7a6a', 'c8c0b0', None, '5a5048', '3a3028', hat2='pot', hatc='b07040', overalls=True),
 'newspaper':    S('a0b08a', '7a6a8a', 'e8e0d0', '6a2a2a', '48404a', '2e2a30', hat2='beanie', hatc='a84a3a', prop='paper'),
 'diver':        S('98b0a0', '2a5a7a', 'c8d8e0', None, '2a3a4a', '1a2a3a', hat2='goggles', hatc='f0c020'),
 'snorkeler':    S('9ab4a4', '3a7a8a', 'd0e0e0', None, '2a4a5a', '1a3a4a', hat2='snorkel', hatc='f06a2a'),
 'glider':       S('a4b48e', '8a4a8a', 'e8d8e8', None, '3a2a4a', '2a2030', hat2='aviator', hatc='7a5232', prop='wing'),
 'prankster':    S('a8b890', 'e83a8a', 'f8e848', None, '3a3a8a', 'e83a2a', hat2='jester', hatc='8a3ae8'),
 'parcel_runner':S('a4b48c', 'a87a3a', 'e8d8b0', None, '5a4a2a', '3a2e26', hat2='cap', hatc='8a5a2a', track=True, prop='parcel'),
 'ice_skater':   S('a8bcc0', '4a8ac8', 'f0f8ff', None, '2a4a7a', 'f0f0f0', hat2='beanie', hatc='e84a5a', track=True),
 'mummy':        S('d8ccaa', 'c8b890', 'e8dcc0', None, 'b0a080', '8a7a60', hat2='wrap', hatc='e0d4b0'),
 'camel_rider':  S('b0b088', 'c8a060', 'f0e0c0', None, '7a6040', '4a3a28', hat2='turban', hatc='e8d8b0'),
 'dreamwalker':  S('a8a8c8', '6a6aa8', 'd8d8f0', None, '4a4a7a', '3a3a5a', hat2='nightcap', hatc='5a5ab8'),
 'mirage':       S('c0b890', 'd8a848', 'f0e0b0', None, '8a6a3a', '5a4a2a', hat2='turban', hatc='4a8ab8'),
 'box_zombie':   S('9fb48a', '6a5440', 'd8d0b8', 'a8322a', '4a4038', '3a2e26', box=True, hat2='cap', hatc='8a6a40'),
 # tier 3
 'angler':       S('a0b4a0', '3a6a5a', 'd8e0c8', None, '2a4a3a', '1a2a20', hat2='rainhat', hatc='e8c020', prop='rod'),
 'chimney_sweep':S('8a9080', '2a2a2a', '6a6a6a', None, '1a1a1a', '101010', hat2='tophat', hatc='1a1a1a', prop='brush'),
 'disco_manager':S('a8b490', 'f0f0f0', 'e83a8a', None, 'f0f0f0', 'e8c020', hat2='afro', hatc='2a1a10'),
 'foreman':      S('9cb088', 'e89a2a', 'd8d0b8', None, '3a4a6a', '3a2e26', hat2='hardhat', hatc='f0d020', vest=True),
 'freezer_technician': S('a8c0c8', 'e8f0f8', 'c8e0f0', None, '4a6a8a', '2a3a4a', hat2='hood', hatc='8ac8e8', prop='tank'),
 'garden_doctor':S('a4b490', 'f0f0f0', 'b8d8e8', '3a8a5a', '5a6a7a', '3a3a40', hat2='doctor', hatc='f0f0f0'),
 'lantern_thief':S('9aa088', '3a3448', '6a6070', None, '2a2830', '1a1820', hat2='mask', hatc='1a1a20', prop='sack'),
 'lifeguard':    S('b0bc90', 'e83a2a', 'f0f0e8', None, 'e83a2a', 'f0d020', hat2='cap', hatc='f0f0f0', track=True),
 'magnet_clerk': S('a0b090', '4a5a7a', 'e0e0e8', 'e8c020', '3a3a4a', '2a2a30', hat2='visor', hatc='3a3a4a', prop='magnet'),
 'necromancer':  S('9a9aa8', '3a2a4a', '6a5a7a', None, '2a2030', '1a1420', hat2='hood', hatc='3a2a4a', prop='staff'),
 'pigeon_keeper':S('a8b490', '6a7a5a', 'd8d0b8', None, '4a4a3a', '3a3028', hat2='flatcap', hatc='6a5a4a', prop='cage'),
 'roof_courier': S('a4b48c', '3a8a4a', 'e8f0e0', None, '2a4a2a', '1a2a1a', hat2='helmet2', hatc='3a8a4a', prop='parcel'),
 'snow_medic':   S('a8c0c0', 'f0f0f0', 'f8e0e0', 'e83a3a', '6a7a8a', '3a3a40', hat2='beanie', hatc='e83a3a'),
 'snowballer':   S('a8c0c8', '5a8ac8', 'e0f0f8', None, '3a4a6a', '2a3040', hat2='beanie', hatc='f0f0f0', prop='snowball'),
 'welder':       S('9aa890', '5a5a48', 'a8a090', None, '3a3a30', '2a2a20', hat2='weldmask', hatc='4a4a50', prop='torch'),
 'cactus_suit':  S('a8b88a', '4a9a4a', '8ac86a', None, '3a6a2a', '2a4a1a', hat2='cactus', hatc='4a9a4a'),
 'astronaut':    S('b0b8c0', 'e8e8f0', 'c8c8d8', None, 'd0d0e0', '8a8a9a', hat2='space', hatc='e8e8f0', prop='tank'),
 'gravity_monk': S('b0b090', 'e89a3a', 'f0c880', None, 'c87a2a', '6a4a2a', hat2='none'),
 'phase_auditor':S('a8a8c8', '2a2a3a', 'e0e0f0', '8a3ae8', '2a2a3a', '1a1a20', hat2='tophat', hatc='3a2a5a', prop='clipboard'),
 'balloon_zombie': S('a2b48c', 'd86a3a', 'f0e0c8', None, '5a4a6a', '3a2e26', hat2='aviator', hatc='7a5232', balloon=True),
 'slingshot_zombie': S('a4b48e', '5a7a3a', 'e8e0c8', None, '4a4a30', '2e2a20', hat2='cap', hatc='e85a2a', sling=True),
 # tier 4-5
 'scrapbot':     S('a0a8b0', '8a9098', 'c0c8d0', None, '5a6068', '3a4048', hat2='robot', hatc='9aa0a8', brute=True),
 'lunar_herald': S('b0b8d0', '4a4a8a', 'e0e0f8', None, '3a3a6a', '2a2a4a', hat2='crown', hatc='e8d050', brute=True),
 'gargantuan_furnace': S('8fa67e', '8a3a2a', 'c88a5a', None, '4a2a20', '2e1a14', brute=True, hat2='hardhat', hatc='e85a1a'),
 'gargantuan_granite': S('9aa090', '7a7a78', 'b0b0a8', None, '4a4a48', '2e2e2c', brute=True, hat2='none'),
 'gargantuan_storm':   S('98a8b0', '3a4a6a', '8a9ab8', None, '2a3048', '1a2030', brute=True, hat2='hood', hatc='2a3a5a'),
}

def _hat(kind, col, HW=200, HH=200):
    nx, ny = 104, 168
    cx, cy = nx - 6, ny - 52
    c0 = hexc(col)
    def M(f): return fill_mask(HW, HH, f)
    L = None
    if kind == 'cap':
        dome = M(lambda c: (c.arc(cx + 4, cy - 26, 50, math.pi, 2 * math.pi), c.close_path()))
        brim = M(lambda c: ellipse(c, cx - 50, cy - 26, 34, 9))
        L = stack(HW, HH, shade(brim, hsv_shift(c0, dv=0.8), roundness=0.8, outline=3), shade(dome, c0, roundness=0.7, spec=0.3))
    elif kind == 'beanie':
        dome = M(lambda c: (c.arc(cx + 2, cy - 22, 52, math.pi, 2 * math.pi), c.close_path()))
        band = M(lambda c: c.rectangle(cx - 52, cy - 34, 106, 16))
        pom = M(lambda c: ellipse(c, cx + 4, cy - 80, 14, 13))
        L = stack(HW, HH, shade(dome, c0, roundness=0.7, detail=paint_strokes(dome.shape, [[(cx - 30 + i * 12, cy - 70), (cx - 30 + i * 12, cy - 30)] for i in range(6)], 2, 0.15)),
                  shade(band, hsv_shift(c0, dv=0.8), roundness=0.9, outline=2), shade(pom, hexc('f0f0f0'), roundness=1, outline=2))
    elif kind in ('tophat',):
        crown = M(lambda c: c.rectangle(cx - 34, cy - 130, 70, 100))
        brim = M(lambda c: ellipse(c, cx, cy - 32, 60, 11))
        band = M(lambda c: c.rectangle(cx - 34, cy - 54, 70, 12))
        L = stack(HW, HH, shade(brim, c0, roundness=0.8, outline=3), shade(crown, c0, roundness=0.5, spec=0.4), shade(band, hexc('8a2a2a'), roundness=0.9, outline=1))
    elif kind in ('hardhat', 'helmet2', 'robot', 'space', 'weldmask'):
        dome = M(lambda c: (c.arc(cx + 2, cy - 16, 58, math.pi, 2 * math.pi), c.close_path()))
        brim = M(lambda c: ellipse(c, cx, cy - 16, 66, 11))
        L = stack(HW, HH, shade(brim, hsv_shift(c0, dv=0.82), roundness=0.8, outline=3), shade(dome, c0, roundness=0.55, spec=0.7, spec_power=12))
        if kind == 'space':
            glass = M(lambda c: ellipse(c, cx, cy - 4, 62, 60))
            L = stack(HW, HH, flat_layer(glass, (0.7, 0.85, 1.0), 0.28), shade(glass - np.clip(M(lambda c: ellipse(c, cx, cy - 4, 56, 54)), 0, 1), c0, roundness=1, spec=0.8))
        if kind == 'weldmask':
            plate = M(lambda c: c.rectangle(cx - 56, cy - 30, 30, 70))
            L.over_layer(shade(plate, c0, roundness=0.4, spec=0.5, outline=2))
            L.over_layer(flat_layer(M(lambda c: c.rectangle(cx - 54, cy - 14, 26, 10)), (0.15, 0.4, 0.2), 1))
        if kind == 'robot':
            ant = stroke_mask(HW, HH, lambda c: (c.move_to(cx, cy - 72), c.line_to(cx + 6, cy - 100)), 4)
            L.over_layer(shade(ant, hexc('6a7078'), roundness=1, outline=1))
            L.over_layer(shade(M(lambda c: ellipse(c, cx + 6, cy - 102, 8, 8)), hexc('e83a2a'), roundness=1, spec=1, outline=2))
    elif kind in ('hood', 'wrap', 'turban', 'nightcap', 'jester', 'doctor', 'rainhat', 'flatcap', 'aviator', 'visor', 'crown', 'afro', 'cactus', 'goggles', 'snorkel', 'mask', 'pot'):
        if kind == 'hood':
            m = M(lambda c: blob(c, [(cx - 50, cy + 40), (cx - 58, cy - 30), (cx - 20, cy - 70), (cx + 34, cy - 66), (cx + 64, cy - 20), (cx + 60, cy + 40), (cx + 40, cy + 10), (cx - 30, cy - 34), (cx - 40, cy + 30)]))
            L = shade(m, c0, roundness=0.6, spec=0.1, detail=0.9 + 0.1 * noise(HW, HH, 4, 3, 3))
        elif kind == 'wrap':
            m = M(lambda c: (c.arc(cx + 2, cy - 4, 52, math.pi * 1.0, 2 * math.pi), c.close_path()))
            L = shade(m, c0, roundness=0.7, detail=paint_strokes(m.shape, [[(cx - 52, cy - 40 + i * 10), (cx + 52, cy - 46 + i * 10)] for i in range(5)], 2, 0.3))
        elif kind == 'turban':
            m = M(lambda c: blob(c, [(cx - 52, cy - 14), (cx - 50, cy - 56), (cx - 10, cy - 82), (cx + 36, cy - 76), (cx + 56, cy - 44), (cx + 52, cy - 12)]))
            L = shade(m, c0, roundness=0.8, detail=paint_strokes(m.shape, [[(cx - 50, cy - 20), (cx + 40, cy - 70)], [(cx - 46, cy - 46), (cx + 52, cy - 30)]], 3, 0.25))
            L.over_layer(shade(M(lambda c: ellipse(c, cx - 30, cy - 40, 9, 11)), hexc('e83a5a'), roundness=1, spec=1, outline=2))
        elif kind in ('nightcap', 'jester'):
            m = M(lambda c: (c.move_to(cx - 52, cy - 24), c.curve_to(cx - 30, cy - 90, cx + 40, cy - 110, cx + 80, cy - 60), c.line_to(cx + 54, cy - 24), c.close_path()))
            band = M(lambda c: c.rectangle(cx - 54, cy - 36, 110, 16))
            L = stack(HW, HH, shade(m, c0, roundness=0.7, spec=0.2), shade(band, hexc('f0f0f0') if kind == 'nightcap' else hexc('f8e848'), roundness=0.9, outline=2),
                      shade(M(lambda c: ellipse(c, cx + 82, cy - 58, 12, 12)), hexc('f0f0f0') if kind == 'nightcap' else hexc('f8e848'), roundness=1, outline=2))
        elif kind == 'doctor':
            band = M(lambda c: c.rectangle(cx - 52, cy - 46, 106, 16))
            mirror = M(lambda c: ellipse(c, cx - 30, cy - 44, 16, 16))
            L = stack(HW, HH, shade(band, c0, roundness=0.9, outline=2), shade(mirror, hexc('d8e0e8'), roundness=1, spec=1, outline=2))
        elif kind == 'rainhat':
            dome = M(lambda c: (c.arc(cx + 2, cy - 26, 48, math.pi, 2 * math.pi), c.close_path()))
            brim = M(lambda c: (c.move_to(cx - 74, cy - 14), c.curve_to(cx - 40, cy - 34, cx + 40, cy - 34, cx + 74, cy - 14), c.line_to(cx + 60, cy - 6), c.curve_to(cx + 20, cy - 22, cx - 20, cy - 22, cx - 60, cy - 6), c.close_path()))
            L = stack(HW, HH, shade(dome, c0, roundness=0.7, spec=0.5), shade(brim, c0, roundness=0.8, spec=0.5, outline=3))
        elif kind == 'flatcap':
            m = M(lambda c: blob(c, [(cx - 66, cy - 26), (cx - 30, cy - 66), (cx + 30, cy - 64), (cx + 54, cy - 34), (cx + 30, cy - 22)]))
            L = shade(m, c0, roundness=0.7, detail=0.9 + 0.1 * noise(HW, HH, 3, 3, 4))
        elif kind == 'aviator':
            m = M(lambda c: (c.arc(cx + 2, cy - 14, 54, math.pi, 2 * math.pi), c.close_path()))
            gog = M(lambda c: (ellipse(c, cx - 22, cy - 46, 16, 12), ellipse(c, cx + 14, cy - 46, 16, 12)))
            L = stack(HW, HH, shade(m, c0, roundness=0.6, spec=0.3), shade(gog, hexc('a8d8f0'), roundness=1, spec=1, outline=3))
        elif kind == 'visor':
            band = M(lambda c: c.rectangle(cx - 50, cy - 46, 104, 12))
            brim = M(lambda c: ellipse(c, cx - 50, cy - 40, 30, 8))
            L = stack(HW, HH, shade(band, c0, roundness=0.9, outline=2), shade(brim, hexc('3a8a4a'), roundness=0.8, outline=2, spec=0.4))
        elif kind == 'crown':
            m = M(lambda c: (c.move_to(cx - 40, cy - 34), c.line_to(cx - 44, cy - 80), c.line_to(cx - 20, cy - 58), c.line_to(cx, cy - 92), c.line_to(cx + 20, cy - 58), c.line_to(cx + 44, cy - 80), c.line_to(cx + 40, cy - 34), c.close_path()))
            L = shade(m, c0, roundness=0.6, spec=0.9, spec_power=14)
        elif kind == 'afro':
            m = M(lambda c: [ellipse(c, cx + dx, cy - 50 + dy, 34, 30) for dx, dy in [(-30, 10), (0, -10), (30, 6), (14, 20), (-16, -16), (40, -14)]])
            L = shade(m, c0, roundness=0.8, detail=0.85 + 0.15 * noise(HW, HH, 2, 3, 8))
        elif kind == 'cactus':
            m = M(lambda c: (c.arc(cx + 2, cy - 10, 60, math.pi, 2 * math.pi), c.close_path()))
            L = shade(m, c0, roundness=0.7, detail=paint_strokes(m.shape, [[(cx - 40 + 20 * i, cy - 60), (cx - 40 + 20 * i, cy - 12)] for i in range(5)], 3, 0.25))
            L = stack(HW, HH, spikes([(cx - 50, cy - 40, 200), (cx - 20, cy - 66, 250), (cx + 20, cy - 68, 290), (cx + 54, cy - 40, 340)], hexc('f0f0d0'), 18, 4, w=HW, h=HH, outline=1.5), L)
        elif kind == 'goggles':
            strap = M(lambda c: c.rectangle(cx - 50, cy - 20, 104, 10))
            gog = M(lambda c: (ellipse(c, cx - 24, cy - 12, 18, 15), ellipse(c, cx + 10, cy - 10, 15, 13)))
            L = stack(HW, HH, shade(strap, hexc('2a2a2a'), roundness=1, outline=1), shade(gog, c0, roundness=0.8, outline=3), flat_layer(M(lambda c: (ellipse(c, cx - 24, cy - 12, 12, 10), ellipse(c, cx + 10, cy - 10, 10, 9))), (0.6, 0.85, 1.0), 0.75))
        elif kind == 'snorkel':
            gog = M(lambda c: blob(c, [(cx - 44, cy - 24), (cx + 22, cy - 24), (cx + 22, cy + 4), (cx - 44, cy + 4)], tension=0.3))
            tube = stroke_mask(HW, HH, lambda c: (c.move_to(cx + 40, cy + 20), c.line_to(cx + 44, cy - 80)), 9)
            L = stack(HW, HH, shade(tube, c0, roundness=1, outline=2), shade(gog, hexc('3a3a3a'), roundness=0.8, outline=2), flat_layer(M(lambda c: blob(c, [(cx - 40, cy - 20), (cx + 18, cy - 20), (cx + 18, cy), (cx - 40, cy)], tension=0.3)), (0.6, 0.85, 1.0), 0.7))
        elif kind == 'mask':
            m = M(lambda c: c.rectangle(cx - 50, cy - 22, 104, 22))
            L = shade(m, c0, roundness=0.9, outline=2)
            L.a *= 1 - M(lambda c: (ellipse(c, cx - 22, cy - 10, 10, 7), ellipse(c, cx + 8, cy - 8, 8, 6)))
        elif kind == 'pot':
            m = M(lambda c: (c.move_to(cx - 50, cy - 20), c.line_to(cx - 46, cy - 84), c.line_to(cx + 46, cy - 84), c.line_to(cx + 50, cy - 20), c.close_path()))
            hd = stroke_mask(HW, HH, lambda c: (c.move_to(cx + 46, cy - 60), c.line_to(cx + 86, cy - 64)), 8)
            L = stack(HW, HH, shade(hd, hexc('3a3a3a'), roundness=1, outline=2), shade(m, c0, roundness=0.5, spec=0.8, spec_power=10, toon=0.6))
    return L

def _stages(L):
    """3 damage stages from one hat layer (cracks + darkening + chips)."""
    out = [L]
    HH, HW = L.a.shape
    for s in (1, 2):
        M2 = Layer(HW, HH)
        M2.rgb = L.rgb.copy(); M2.a = L.a.copy()
        cr = paint_strokes(L.a.shape, [[(120, 40), (104, 70), (118, 96)], [(60, 60), (78, 80)]][:s], 3, 0.7, 0.5)
        M2.rgb *= cr[..., None] * (1 - 0.08 * s)
        if s == 2:
            M2.a *= 1 - fill_mask(HW, HH, lambda c: blob(c, [(130, 20), (160, 60), (120, 70), (110, 40)]))
        out.append(M2)
    return out

def _box(damaged):
    W, H = 220, 240
    m = fill_mask(W, H, lambda c: c.rectangle(20, 50, 180, 170))
    flaps = fill_mask(W, H, lambda c: (c.move_to(20, 50), c.line_to(4, 18), c.line_to(96, 30), c.line_to(110, 50), c.close_path(), c.move_to(110, 50), c.line_to(124, 26), c.line_to(214, 14), c.line_to(200, 50), c.close_path()))
    det = 0.9 + 0.1 * noise(W, H, 4, 3, 31)
    L = stack(W, H, shade(flaps, hexc('b88a52'), roundness=0.3, toon=0.6, detail=det),
              shade(m, hexc('c89a5e'), roundness=0.35, toon=0.6, spec=0.05, detail=det * paint_strokes(m.shape, [[(110, 52), (110, 218)]], 3, 0.3)))
    tape = fill_mask(W, H, lambda c: c.rectangle(96, 50, 28, 170))
    L.over_layer(clip_layer(flat_layer(tape, (0.85, 0.75, 0.55), 0.8), m))
    eye_holes = fill_mask(W, H, lambda c: (ellipse(c, 62, 104, 16, 10), ellipse(c, 100, 104, 14, 9)))
    L.over_layer(flat_layer(eye_holes, (0.1, 0.07, 0.05), 1))
    L.over_layer(eye(62, 104, 0.35, look=(-3, 0), w=W, h=H, ring=hexc('1a1a14'), iris=hexc('e8e0a0')))
    # "fragile" glass icon
    glass = stroke_mask(W, H, lambda c: (c.move_to(150, 130), c.line_to(170, 130), c.line_to(166, 156), c.line_to(154, 156), c.close_path(), c.move_to(160, 156), c.line_to(160, 176), c.move_to(150, 178), c.line_to(170, 178)), 4)
    L.over_layer(flat_layer(glass, (0.6, 0.15, 0.1), 0.85))
    if damaged:
        cr = paint_strokes(m.shape, [[(30, 140), (70, 170), (50, 210)], [(180, 70), (160, 110)]], 4, 0.7, 0.5)
        L.rgb *= cr[..., None]
        L.a *= 1 - fill_mask(W, H, lambda c: blob(c, [(200, 150), (200, 222), (150, 222), (176, 186)]))
    return L, (110, 140)

def _balloon():
    W, H = 160, 330
    b = fill_mask(W, H, lambda c: blob(c, [(80, 16), (128, 50), (134, 110), (100, 160), (80, 170), (60, 160), (26, 110), (32, 50)]))
    knot = fill_mask(W, H, lambda c: (c.move_to(72, 172), c.line_to(88, 172), c.line_to(80, 160), c.close_path()))
    string = stroke_mask(W, H, lambda c: (c.move_to(80, 172), c.curve_to(64, 220, 96, 260, 80, 320)), 2.5)
    L = stack(W, H, flat_layer(string, (0.25, 0.22, 0.2), 1), shade(knot, hexc('c82a2a'), roundness=1, outline=2),
              shade(b, hexc('e83a3a'), roundness=1, spec=0.9, spec_power=16, toon=0.5))
    face = stroke_mask(W, H, lambda c: (c.move_to(54, 96), c.line_to(70, 106), c.move_to(106, 96), c.line_to(90, 106), c.move_to(60, 128), c.curve_to(72, 138, 92, 138, 102, 126)), 4)
    L.over_layer(flat_layer(face, (0.35, 0.05, 0.05), 0.75))
    return L, (80, 320)

def _sling():
    W, H = 100, 170
    y = stroke_mask(W, H, lambda c: (c.move_to(50, 160), c.line_to(50, 90), c.line_to(20, 30), c.move_to(50, 90), c.line_to(80, 30)), 12)
    band = stroke_mask(W, H, lambda c: (c.move_to(20, 30), c.curve_to(40, 60, 60, 60, 80, 30)), 4)
    stone = fill_mask(W, H, lambda c: ellipse(c, 50, 54, 10, 9))
    L = stack(W, H, shade(y, hexc('8a5a32'), roundness=1, detail=0.9 + 0.1 * noise(W, H, 3, 2, 2)), flat_layer(band, (0.5, 0.2, 0.15), 1), shade(stone, hexc('9a9a90'), roundness=1, outline=2))
    return L, (50, 150)

def build_all(zid, st):
    st = dict(st)
    hat2 = st.pop('hat2', None)
    parts = Z.build(zid, st)
    if hat2 and hat2 != 'none':
        L = _hat(hat2, st.get('hatc', '888888'))
        if L is not None:
            for i, s in enumerate(_stages(L)):
                parts['hat_%d' % i] = (s, (104, 168))
    if st.get('box'):
        parts['box'] = _box(False); parts['box_1'] = _box(True)
    if st.get('balloon'):
        parts['balloon'] = _balloon()
    if st.get('sling'):
        parts['sling'] = _sling()
    return parts

if __name__ == '__main__':
    ids = sys.argv[1:] or list(MORE)
    for zid in ids:
        st = MORE.get(zid) or Z.STYLES[zid]
        Z.export(zid, build_all(zid, st))
        print('painted', zid)
    Z.preview(ids[:14], '/tmp/zombies_sheet.png')
