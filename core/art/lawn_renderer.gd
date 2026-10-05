class_name LawnRenderer
extends Node2D
## Draws the world surround and the playfield ground (exactly Board.board_rect()).
## bleed > 0 (wider/taller than 16:9, see BattleFrame) mirrors the surround's outer
## strips into the margins so the seam is continuous and nothing shows the clear colour.

const STAGE := Vector2(1920, 1080)

var config: WorldArtConfig
var bleed: Vector2 = Vector2.ZERO

func _init(p_config: WorldArtConfig) -> void:
	config = p_config
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func set_bleed(b: Vector2) -> void:
	if b != bleed:
		bleed = b
		queue_redraw()

func _draw() -> void:
	if config == null:
		return
	if config.environment:
		draw_texture_rect(config.environment, Rect2(Vector2.ZERO, STAGE), false)
		if bleed.x > 0.0 or bleed.y > 0.0:
			_draw_bleed(config.environment)
	if config.ground:
		draw_texture_rect(config.ground, Board.board_rect(), false)

## Eight mirrored margin pieces (sides, top/bottom, corners) around the stage.
func _draw_bleed(tex: Texture2D) -> void:
	var k := Vector2(tex.get_size()) / STAGE  # stage px -> texture px
	var b := bleed.min(STAGE)
	for ix: int in [-1, 0, 1]:
		for iy: int in [-1, 0, 1]:
			if (ix == 0 and iy == 0) or (ix != 0 and b.x <= 0.0) or (iy != 0 and b.y <= 0.0):
				continue
			var w := b.x if ix != 0 else STAGE.x
			var h := b.y if iy != 0 else STAGE.y
			var sx := 0.0 if ix <= 0 else STAGE.x - w
			var sy := 0.0 if iy <= 0 else STAGE.y - h
			var dst_x := -w if ix < 0 else (STAGE.x if ix > 0 else 0.0)
			var dst_y := -h if iy < 0 else (STAGE.y if iy > 0 else 0.0)
			var flip := Vector2(-1.0 if ix != 0 else 1.0, -1.0 if iy != 0 else 1.0)
			# Mirror about the stage edge: draw in a flipped frame anchored at the far side.
			var origin := Vector2(dst_x + (w if flip.x < 0.0 else 0.0), dst_y + (h if flip.y < 0.0 else 0.0))
			draw_set_transform(origin, 0.0, flip)
			draw_texture_rect_region(tex, Rect2(Vector2.ZERO, Vector2(w, h)), Rect2(Vector2(sx, sy) * k, Vector2(w, h) * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
