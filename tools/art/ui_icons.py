"""Procedural UI icons + logo (pycairo). python3 tools/art/ui_icons.py"""
import cairo, math, os
OUT = os.path.join(os.path.dirname(__file__), '../../assets/ui')
os.makedirs(OUT, exist_ok=True)

def surf(w, h): s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h); return s, cairo.Context(s)
def rgb(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def fill_stroke(c, fill, stroke='3a2410', lw=6):
    c.set_source_rgb(*rgb(fill)); c.fill_preserve(); c.set_source_rgb(*rgb(stroke)); c.set_line_width(lw); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke()
def grad_fill(c, x0, y0, x1, y1, a, b, stroke='3a2410', lw=6):
    g = cairo.LinearGradient(x0, y0, x1, y1); g.add_color_stop_rgb(0, *rgb(a)); g.add_color_stop_rgb(1, *rgb(b))
    c.set_source(g); c.fill_preserve(); c.set_source_rgb(*rgb(stroke)); c.set_line_width(lw); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke()
def shine(c, x, y, rx, ry, a=0.45):
    c.save(); c.translate(x, y); c.scale(rx, ry); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore(); c.set_source_rgba(1, 1, 1, a); c.fill()
def save(s, name): s.write_to_png(os.path.join(OUT, name + '.png'))

# shovel
s, c = surf(128, 128)
c.save(); c.translate(64, 64); c.rotate(-0.75)
c.rectangle(-7, -56, 14, 60); grad_fill(c, -7, 0, 7, 0, 'c08a4a', '8a5a2a', lw=5)
c.rectangle(-20, -62, 40, 12); grad_fill(c, 0, -62, 0, -50, 'c08a4a', '8a5a2a', lw=5)
c.move_to(-26, 4); c.line_to(26, 4); c.line_to(22, 40); c.curve_to(14, 58, -14, 58, -22, 40); c.close_path(); grad_fill(c, -26, 0, 26, 0, 'e8eef4', '8a96a4', lw=5)
c.restore(); save(s, 'shovel')
# glove
s, c = surf(128, 128)
c.move_to(36, 112); c.line_to(32, 64)
for i, (x, top) in enumerate([(34, 30), (50, 18), (66, 16), (82, 24)]):
    c.line_to(x, top + 8); c.curve_to(x, top - 4, x + 14, top - 4, x + 14, top + 8)
c.line_to(96, 66); c.curve_to(106, 54, 118, 56, 114, 70); c.line_to(96, 96); c.line_to(92, 112); c.close_path()
grad_fill(c, 30, 20, 110, 110, 'fff4e0', 'd8c8b0', lw=6)
c.rectangle(34, 100, 60, 18); grad_fill(c, 0, 100, 0, 118, 'e85a3a', 'b83a2a', lw=5)
for x in (48, 64, 80):
    c.move_to(x, 66); c.line_to(x, 40); c.set_source_rgba(0.4, 0.3, 0.2, 0.5); c.set_line_width(3); c.stroke()
save(s, 'glove')
# pause
s, c = surf(96, 96)
for x in (26, 54):
    c.rectangle(x, 22, 16, 52); fill_stroke(c, 'ffffff', '2a4a1a', 5)
save(s, 'pause')
# fast forward
s, c = surf(96, 96)
for x in (16, 46):
    c.move_to(x, 22); c.line_to(x + 34, 48); c.line_to(x, 74); c.close_path(); fill_stroke(c, 'ffffff', '2a4a1a', 5)
save(s, 'speed')
# sun
s, c = surf(128, 128)
for i in range(12):
    a = i * math.pi / 6
    c.move_to(64 + math.cos(a - 0.16) * 34, 64 + math.sin(a - 0.16) * 34); c.line_to(64 + math.cos(a) * 60, 64 + math.sin(a) * 60); c.line_to(64 + math.cos(a + 0.16) * 34, 64 + math.sin(a + 0.16) * 34); c.close_path()
c.set_source_rgb(*rgb('ffb020')); c.fill()
g = cairo.RadialGradient(56, 54, 4, 64, 64, 40); g.add_color_stop_rgb(0, *rgb('fff8b0')); g.add_color_stop_rgb(1, *rgb('ffb818'))
c.arc(64, 64, 38, 0, 2 * math.pi); c.set_source(g); c.fill_preserve(); c.set_source_rgb(*rgb('d07a10')); c.set_line_width(4); c.stroke()
c.arc(50, 60, 5, 0, 2 * math.pi); c.arc(78, 60, 5, 0, 2 * math.pi); c.set_source_rgb(*rgb('6a3a10')); c.fill()
c.arc(64, 68, 14, 0.3, math.pi - 0.3); c.set_line_width(4); c.stroke()
save(s, 'sun')
# coin
s, c = surf(96, 96)
c.arc(48, 48, 40, 0, 2 * math.pi); grad_fill(c, 0, 8, 0, 88, 'ffe070', 'd89a20', '8a5a10', 5)
c.arc(48, 48, 28, 0, 2 * math.pi); c.set_source_rgb(*rgb('c88a18')); c.set_line_width(4); c.stroke()
c.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); c.set_font_size(36)
c.move_to(36, 61); c.text_path('$'); c.set_source_rgb(*rgb('8a5a10')); c.fill()
shine(c, 36, 30, 12, 7, 0.5); save(s, 'coin')
# gear (settings)
s, c = surf(96, 96)
for i in range(8):
    a = i * math.pi / 4
    c.save(); c.translate(48, 48); c.rotate(a); c.rectangle(-8, -42, 16, 16); c.restore()
c.set_source_rgb(*rgb('e8e8e0')); c.fill()
c.arc(48, 48, 30, 0, 2 * math.pi); fill_stroke(c, 'e8e8e0', '3a3a30', 5)
c.arc(48, 48, 11, 0, 2 * math.pi); fill_stroke(c, '6a8a4a', '3a3a30', 4)
save(s, 'gear')
# zombie head (wave progress marker) + flag
s, c = surf(64, 64)
c.arc(32, 34, 22, 0, 2 * math.pi); fill_stroke(c, '9fb48a', '2a3a1a', 4)
c.arc(24, 30, 6, 0, 2 * math.pi); fill_stroke(c, 'f0f0e0', '2a3a1a', 2); c.arc(40, 31, 4, 0, 2 * math.pi); fill_stroke(c, 'f0f0e0', '2a3a1a', 2)
c.move_to(20, 46); c.line_to(44, 44); c.set_line_width(3); c.stroke(); save(s, 'zombie_head')
s, c = surf(48, 64)
c.move_to(10, 60); c.line_to(10, 6); c.set_source_rgb(*rgb('6a4a2a')); c.set_line_width(5); c.stroke()
c.move_to(12, 8); c.line_to(42, 14); c.line_to(34, 22); c.line_to(42, 30); c.line_to(12, 32); c.close_path(); fill_stroke(c, 'd83a2a', '5a1a10', 3)
save(s, 'flag')

# logo
W, H = 1100, 380
s, c = surf(W, H)
def logo_text(txt, y, size, colA, colB, arc=0.0):
    c.select_font_face('Impact', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    c.set_font_size(size)
    ext = c.text_extents(txt)
    total = ext.x_advance
    x = (W - total) / 2
    paths = []
    for ch in txt:
        e = c.text_extents(ch)
        cx = x + e.x_advance / 2
        t = (cx - W / 2) / (W / 2)
        dy = arc * (t * t) * size
        c.save(); c.translate(cx, y + dy); c.rotate(t * arc * 0.5)
        c.move_to(-e.x_advance / 2, 0); c.text_path(ch); c.restore()
        x += e.x_advance
    path = c.copy_path(); c.new_path()
    for lw, col in ((34, '2a1a08'), (20, 'ffffff')):
        c.append_path(path); c.set_line_width(lw); c.set_line_join(cairo.LINE_JOIN_ROUND); c.set_source_rgb(*rgb(col)); c.stroke()
    c.append_path(path)
    g = cairo.LinearGradient(0, y - size * 0.8, 0, y); g.add_color_stop_rgb(0, *rgb(colA)); g.add_color_stop_rgb(1, *rgb(colB))
    c.set_source(g); c.fill()
    c.append_path(path); c.set_line_width(4); c.set_source_rgba(0, 0, 0, 0.35); c.stroke()
# leaves behind
for (x, y, a, l) in [(300, 80, -2.5, 110), (820, 70, -0.6, 110), (310, 330, 2.7, 80), (800, 330, 0.4, 80)]:
    c.save(); c.translate(x, y); c.rotate(a)
    c.move_to(0, 0); c.curve_to(l * 0.3, -l * 0.35, l * 0.8, -l * 0.3, l, 0); c.curve_to(l * 0.8, l * 0.3, l * 0.3, l * 0.35, 0, 0)
    grad_fill(c, 0, -l * 0.3, 0, l * 0.3, '8ad84a', '3a8a2a', '1a3a10', 6); c.restore()
logo_text('GARDEN', 190, 170, 'b8f070', '3a9a2a', arc=0.12)
logo_text('DEFENSE', 345, 150, 'ffe070', 'e8701a', arc=-0.05)
save(s, 'logo')
print('ok')

# ---- dock icons (96px)
def icon(name, fn):
    s, c = surf(96, 96); fn(c); save(s, name)
def book(c):
    c.move_to(12, 24); c.curve_to(30, 16, 42, 18, 48, 26); c.line_to(48, 82); c.curve_to(40, 74, 28, 72, 12, 80); c.close_path(); fill_stroke(c, '6ab84a', '2a3a10', 5)
    c.move_to(84, 24); c.curve_to(66, 16, 54, 18, 48, 26); c.line_to(48, 82); c.curve_to(56, 74, 68, 72, 84, 80); c.close_path(); fill_stroke(c, '8ad86a', '2a3a10', 5)
    c.arc(30, 46, 7, 0, 6.3); fill_stroke(c, 'f0d040', '2a3a10', 3)
def hammer(c):
    c.save(); c.translate(48, 48); c.rotate(-0.7)
    c.rectangle(-6, -10, 12, 52); fill_stroke(c, 'b07a44', '3a2410', 5)
    c.rectangle(-28, -32, 56, 24); fill_stroke(c, 'a8b0b8', '2a2a30', 5); c.restore()
def cart(c):
    c.move_to(8, 20); c.line_to(22, 20); c.line_to(32, 62); c.line_to(78, 62); c.line_to(86, 32); c.line_to(26, 32); c.set_line_width(7); c.set_line_join(cairo.LINE_JOIN_ROUND); c.set_source_rgb(*rgb('f0f0f0')); c.stroke_preserve(); c.set_source_rgb(*rgb('3a2410')); c.set_line_width(3); c.stroke()
    for x in (38, 72): c.arc(x, 76, 8, 0, 6.3); fill_stroke(c, 'e8a030', '3a2410', 4)
def scroll(c):
    c.rectangle(22, 16, 52, 64); fill_stroke(c, 'f4e4b8', '6a4a2a', 5)
    for y in (32, 44, 56): c.move_to(32, y); c.line_to(64, y); c.set_source_rgb(*rgb('8a6a4a')); c.set_line_width(4); c.stroke()
    c.arc(66, 70, 10, 0, 6.3); fill_stroke(c, 'd83a2a', '6a1a10', 3)
def chart(c):
    for i, (x, h) in enumerate([(16, 30), (38, 52), (60, 70)]):
        c.rectangle(x, 84 - h, 18, h); fill_stroke(c, ['6ab84a', 'f0c030', 'e85a3a'][i], '2a2410', 4)
def question(c):
    c.arc(48, 48, 38, 0, 6.3); fill_stroke(c, '4a8ad8', '1a2a4a', 5)
    c.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); c.set_font_size(54); c.move_to(32, 67); c.text_path('?'); c.set_source_rgb(1, 1, 1); c.fill()
def power(c):
    c.arc(48, 52, 28, -1.0, 4.14); c.set_line_width(10); c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_source_rgb(*rgb('e85a3a')); c.stroke()
    c.move_to(48, 14); c.line_to(48, 46); c.stroke()
def trophy(c):
    c.move_to(26, 16); c.line_to(70, 16); c.curve_to(70, 56, 58, 62, 48, 62); c.curve_to(38, 62, 26, 56, 26, 16); c.close_path(); fill_stroke(c, 'f0c030', '6a4a10', 5)
    c.rectangle(40, 62, 16, 12); fill_stroke(c, 'd8a020', '6a4a10', 4); c.rectangle(28, 74, 40, 10); fill_stroke(c, 'a87a3a', '4a2a10', 4)
def calendar(c):
    c.rectangle(14, 20, 68, 62); fill_stroke(c, 'f8f8f0', '2a2a30', 5); c.rectangle(14, 20, 68, 16); fill_stroke(c, 'e85a3a', '2a2a30', 5)
    c.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); c.set_font_size(30); c.move_to(30, 72); c.text_path('24'); c.set_source_rgb(*rgb('2a2a30')); c.fill()
for n, f in [('book', book), ('hammer', hammer), ('cart', cart), ('scroll', scroll), ('chart', chart), ('question', question), ('power', power), ('trophy', trophy), ('calendar', calendar)]:
    icon(n, f)
print('dock ok')
