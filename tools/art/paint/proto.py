import sys, math, numpy as np, cv2
sys.path.insert(0, '.')
from kit import *
W = H = 320
G = hexc('7cc843'); GD = hexc('3f8f2c'); LEAF = hexc('4fae35')

def leaf(ctx, x, y, ang, L, Wd):
    ctx.save(); ctx.translate(x, y); ctx.rotate(ang)
    ctx.move_to(0, 0)
    ctx.curve_to(L*0.3, -Wd, L*0.75, -Wd*0.8, L, 0)
    ctx.curve_to(L*0.75, Wd*0.7, L*0.3, Wd*0.9, 0, 0)
    ctx.restore()

def leaf_layer(specs, col):
    m = fill_mask(W, H, lambda c: [leaf(c, *s) for s in specs])
    veins = []
    for (x, y, a, L, Wd) in specs:
        ca, sa = math.cos(a), math.sin(a)
        veins.append([(x, y), (x + ca*L*0.85, y + sa*L*0.85)])
    det = paint_strokes(m.shape, veins, 2.2, 0.22)
    return shade(m, col, roundness=0.7, detail=det, spec=0.2, toon=0.5)

back = leaf_layer([(160, 292, math.radians(-160), 78, 26), (160, 292, math.radians(-25), 70, 22)], hsv_shift(LEAF, dv=0.85))
front = leaf_layer([(158, 294, math.radians(-200), 70, 22), (162, 294, math.radians(25), 66, 20)], LEAF)

stem_m = stroke_mask(W, H, lambda c: (c.move_to(160, 296), c.curve_to(150, 250, 172, 210, 158, 160)), 18)
stem = shade(stem_m, hexc('5aa83a'), roundness=1.0, toon=0.4, spec=0.15)

def head_shape(c):
    ellipse(c, 150, 118, 64, 60)
    c.new_sub_path()
    c.move_to(180, 92); c.curve_to(215, 86, 240, 84, 262, 80)
    c.curve_to(272, 98, 272, 132, 262, 148)
    c.curve_to(240, 146, 215, 146, 182, 146); c.close_path()
hm = fill_mask(W, H, head_shape)
# head height field gets an extra bulge for the sphere so the snout reads as a tube
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
sph = np.clip(1 - ((xx-150)/64)**2 - ((yy-118)/60)**2, 0, 1)
head = shade(hm, G, roundness=0.75, h_extra=np.sqrt(sph)*30, spec=0.45, toon=0.5)
# mouth rim + hole
rim_m = fill_mask(W, H, lambda c: ellipse(c, 262, 114, 15, 35))
head.over_layer(shade(rim_m, hsv_shift(G, dv=1.05), roundness=0.9, outline=2.5))
hole = fill_mask(W, H, lambda c: ellipse(c, 264, 114, 9, 25))
head.over_layer(shade(hole, hexc('1d3b14'), roundness=0.6, spec=0.0, rim=0.0, outline=0, toon=0.2))
# tuft leaf on back of head
tuft = leaf_layer([(96, 104, math.radians(200), 50, 16), (100, 92, math.radians(235), 44, 13)], hsv_shift(G, dv=0.9))
# eyes
def eye(cx, cy, s=1.0):
    sc = fill_mask(W, H, lambda c: ellipse(c, cx, cy, 15*s, 19*s))
    L = shade(sc, hexc('fbfbf3'), roundness=0.9, spec=0.0, rim=0.0, outline=2.5, outline_color=hexc('1f3315'), ao=0.5, toon=0.3)
    pu = fill_mask(W, H, lambda c: ellipse(c, cx+5*s, cy+2*s, 8.5*s, 11*s))
    L.over_layer(shade(pu, hexc('1a1a22'), roundness=0.8, spec=0.0, rim=0.15, outline=0, toon=0.2))
    gl = fill_mask(W, H, lambda c: ellipse(c, cx+2*s, cy-4*s, 3.4*s, 3.4*s))
    L.over_layer(flat_layer(gl, (1, 1, 1), 0.95))
    return L
eyes = eye(168, 104)
brow = stroke_mask(W, H, lambda c: (c.move_to(152, 80), c.curve_to(160, 76, 172, 76, 184, 82)), 6)
eyes.over_layer(flat_layer(brow, hexc('2c5a1c')))

comp = Layer(W, H)
for L in [back, stem, tuft, head, eyes, front]:
    comp.over_layer(L)
bg = Layer(W, H); bg.over(np.broadcast_to(hexc('6fa64a'), (H, W, 3)), np.ones((H, W), np.float32))
sh = fill_mask(W, H, lambda c: ellipse(c, 160, 298, 70, 14))
bg.over(np.zeros((H, W, 3), np.float32), cv2.GaussianBlur(sh, (0,0), 5)*0.35)
bg.over_layer(comp)
bg.to_png('/tmp/proto_pod.png', crop=False)
