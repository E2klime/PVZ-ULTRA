class_name BlockedProp
extends Node2D
## Painted obstacle on a blocked cell (rock / tile shards / ice / moon rock per world).
## Lives in the y-sorted entity layer at the cell's feet line with its own contact shadow,
## so it sits on the lawn instead of floating over it.

const SHADOW_SIZE := Vector2(128, 40)
var config: WorldArtConfig

func _init(p_config: WorldArtConfig, row: int, col: int) -> void:
	config = p_config
	position = Board.cell_center(row, col) + Vector2(0, 44.8)

func _draw() -> void:
	if config.contact_shadow:
		var s := Rect2(Vector2(-SHADOW_SIZE.x * 0.5 + config.contact_shadow_offset.x, -SHADOW_SIZE.y * 0.5), SHADOW_SIZE)
		draw_texture_rect(config.contact_shadow, s, false, config.contact_shadow_color)
	var tex := config.blocked
	if tex:
		var sz := tex.get_size()
		# base of the prop sits ~10% above its bottom edge (the painted ground contact)
		draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y * 0.9))
