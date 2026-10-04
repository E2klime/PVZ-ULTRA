class_name DrawUtil
extends RefCounted
## Procedural "flat cel" placeholder drawing: flat fills + coloured (not black) outline.

const OUTLINE := 4.0

static func outline_of(c: Color) -> Color:
	return Color(c.r * 0.45, c.g * 0.45, c.b * 0.5, c.a)

static func ellipse_points(center: Vector2, rx: float, ry: float, segments: int = 24, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

static func circle(ci: CanvasItem, center: Vector2, r: float, fill: Color, w: float = OUTLINE) -> void:
	if w > 0.0:
		ci.draw_circle(center, r + w * 0.5, outline_of(fill))
	ci.draw_circle(center, max(0.5, r - w * 0.5), fill)

static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, fill: Color, w: float = OUTLINE, rot: float = 0.0) -> void:
	var pts := ellipse_points(center, rx, ry, 28, rot)
	ci.draw_colored_polygon(pts, fill)
	if w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline_of(fill), w, true)

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = OUTLINE) -> void:
	ci.draw_colored_polygon(pts, fill)
	if w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline_of(fill), w, true)

static func rrect_points(rect: Rect2, radius: float, seg: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r: float = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var corners: Array[Vector2] = [
		rect.position + Vector2(rect.size.x - r, r),
		rect.position + Vector2(rect.size.x - r, rect.size.y - r),
		rect.position + Vector2(r, rect.size.y - r),
		rect.position + Vector2(r, r),
	]
	var start_angles: Array[float] = [-PI / 2.0, 0.0, PI / 2.0, PI]
	for i: int in 4:
		for s: int in seg + 1:
			var a: float = start_angles[i] + (PI / 2.0) * float(s) / float(seg)
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * r)
	return pts

static func rrect(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 10.0, w: float = OUTLINE) -> void:
	poly(ci, rrect_points(rect, radius), fill, w)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = 6.0) -> void:
	ci.draw_line(a, b, outline_of(c), w + 3.0, true)
	ci.draw_line(a, b, c, w, true)

static func eye(ci: CanvasItem, center: Vector2, r: float, look: Vector2 = Vector2.ZERO, lid: float = 0.0) -> void:
	ci.draw_circle(center, r + 2.0, Color(0.15, 0.12, 0.1))
	ci.draw_circle(center, r, Color(0.98, 0.97, 0.92))
	ci.draw_circle(center + look * r * 0.35, r * 0.5, Color(0.1, 0.08, 0.08))
	if lid > 0.0:
		ci.draw_rect(Rect2(center.x - r - 2.0, center.y - r - 2.0, r * 2.0 + 4.0, (r * 2.0 + 4.0) * lid), Color(0.15, 0.12, 0.1))

static func leaf(ci: CanvasItem, base: Vector2, length: float, angle: float, fill: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var n := dir.orthogonal()
	var pts := PackedVector2Array([
		base,
		base + dir * length * 0.5 + n * length * 0.28,
		base + dir * length,
		base + dir * length * 0.5 - n * length * 0.28,
	])
	poly(ci, pts, fill, 3.0)

static func stem(ci: CanvasItem, from: Vector2, to: Vector2, fill: Color, w: float = 8.0) -> void:
	line(ci, from, to, fill, w)
