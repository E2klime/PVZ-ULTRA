class_name LawnEdgeOverlay
extends Node2D
## Border of the playfield: drop shadow on the surround, front turf lip and blades
## overhanging the edge, so the field never reads as a pasted rectangle.

var config: WorldArtConfig

func _init(p_config: WorldArtConfig) -> void:
	config = p_config
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	if config == null or config.edge == null:
		return
	var m := config.edge_margin
	draw_texture_rect(config.edge, Board.board_rect().grow(m), false)
