class_name LawnLighting
extends Node2D
## Ground contact: a soft cool shadow under every grounded plant and zombie, drawn
## between the ground and the entities so nothing looks like it floats.

var config: WorldArtConfig
var entities: Node2D

const PLANT_SIZE := Vector2(132, 42)
const ZOMBIE_SIZE := Vector2(140, 42)

func _init(p_config: WorldArtConfig, p_entities: Node2D) -> void:
	config = p_config
	entities = p_entities
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if config == null or config.contact_shadow == null or entities == null:
		return
	for n: Node in entities.get_children():
		var size := _shadow_size(n)
		if size == Vector2.ZERO:
			continue
		var p := (n as Node2D).position + config.contact_shadow_offset
		draw_texture_rect(config.contact_shadow, Rect2(p - size * 0.5, size), false, config.contact_shadow_color)

func _shadow_size(n: Node) -> Vector2:
	if n is Plant:
		var p := n as Plant
		if p.dead or p.on_raft or p.is_air() or p.data == null or p.data.layer == &"under":
			return Vector2.ZERO
		return PLANT_SIZE * clampf(p.pose_grow, 0.2, 1.1)
	if n is Zombie:
		var z := n as Zombie
		if z.data == null or z.underground or z.submerge > 0.3:
			return Vector2.ZERO
		return ZOMBIE_SIZE * z.data.body_scale
	return Vector2.ZERO
