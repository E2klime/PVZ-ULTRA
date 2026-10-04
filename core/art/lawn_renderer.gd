class_name LawnRenderer
extends Node2D
## Draws the world surround and the playfield ground (exactly Board.board_rect()).

var config: WorldArtConfig

func _init(p_config: WorldArtConfig) -> void:
	config = p_config
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	if config == null:
		return
	if config.environment:
		draw_texture_rect(config.environment, Rect2(Vector2.ZERO, Vector2(1920, 1080)), false)
	if config.ground:
		draw_texture_rect(config.ground, Board.board_rect(), false)
