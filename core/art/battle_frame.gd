class_name BattleFrame
extends Node2D
## Centres the 1920x1080 battle stage inside whatever the viewport is. With
## aspect.mobile="expand" a phone (20:9) or tablet (4:3) gets extra width/height; the
## stage, the HUD and its layout stay in 1920x1080 design space, the surround art is
## mirrored into the margins (LawnRenderer.bleed) and HUD overlays still dim the full screen.

const STAGE := Vector2(1920, 1080)

var renderer: LawnRenderer
var hud: BattleHUD

func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)
	_relayout()

func set_renderer(r: LawnRenderer) -> void:
	renderer = r
	if is_inside_tree():
		_relayout()

## Call once the HUD exists (it is built after the world).
func bind_hud(p_hud: BattleHUD) -> void:
	hud = p_hud
	if hud.is_node_ready():
		_relayout()
	else:
		hud.ready.connect(_relayout, CONNECT_ONE_SHOT)

func pad() -> Vector2:
	var vis := get_viewport().get_visible_rect().size
	return ((vis - STAGE) * 0.5).max(Vector2.ZERO).floor()

func _relayout() -> void:
	var p := pad()
	position = p
	if renderer:
		renderer.set_bleed(p)
	if hud == null or hud.root == null:
		return
	hud.offset = p
	hud.root.offset_left = 0.0
	hud.root.offset_top = 0.0
	hud.root.offset_right = -2.0 * p.x
	hud.root.offset_bottom = -2.0 * p.y
	var ov := hud._overlay_layer
	if ov:
		ov.offset_left = -p.x
		ov.offset_top = -p.y
		ov.offset_right = p.x
		ov.offset_bottom = p.y
