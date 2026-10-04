class_name EntityPreview
extends Control
## Shows a plant or zombie (painted rig) inside UI: seed cards, almanac, rewards.

var _node: Node2D
var _scale: float = 1.0
var silhouette: bool = false

func _init(min_size: Vector2 = Vector2(100, 120)) -> void:
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_plant(d: PlantData, s: float = 0.7) -> void:
	_clear()
	if d == null:
		return
	var p := d.behavior.new() as Plant
	p.setup_preview(d)
	# the Elder Oak canopy is ~1.7x taller than a normal plant: shrink to fit
	if d.id == &"elder_oak":
		s *= 0.62
	# low ground-cover plants read better a little larger
	elif d.id in [&"bramble_vine", &"rime_lettuce", &"lily_raft", &"ember_vine"] or d.layer == &"under":
		s *= 1.35
	elif d.layer == &"shell":
		s *= 0.9
	_attach(p, s)

func show_zombie(d: ZombieData, s: float = 0.5) -> void:
	_clear()
	if d == null:
		return
	var z := d.behavior.new() as Zombie
	z.setup_preview(d)
	_attach(z, s)

func _attach(n: Node2D, s: float) -> void:
	_node = Node2D.new()
	_node.scale = Vector2(s, s)
	_node.add_child(n)
	add_child(_node)
	if silhouette:
		_node.modulate = Color(0.05, 0.05, 0.08, 0.75)
	_layout()

func _clear() -> void:
	if _node:
		_node.queue_free()
		_node = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

func _layout() -> void:
	if _node:
		_node.position = Vector2(size.x * 0.5, size.y - 8.0)
