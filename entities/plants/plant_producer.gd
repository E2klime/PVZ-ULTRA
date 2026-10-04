class_name PlantProducer
extends Plant
## Sunbud, Twin Sunbud, Dawn Bloom: produce sun tokens on a timer.

var _t: float = 0.0

func on_ready() -> void:
	_t = data.sun_interval * 0.15 + randf() * 2.5

func tick(delta: float) -> void:
	_t -= delta * buff * speed_buff * stat_mult()
	if _t <= 0.0:
		_t = data.sun_interval
		trigger_action(&"produce", _release_sun)

## Called on the produce clip's key frame.
func _release_sun() -> void:
	if dead:
		return
	for i: int in max(1, data.shots):
		battle.spawn_sun(position + Vector2(-10 + i * 24, -80), data.sun_amount, false)
	if is_legendary():
		battle.fx_sparkles(position + Vector2(0, -90), 3)

func rig_local(n: StringName) -> Transform2D:
	if n == &"head":
		var glow := maxf(anim_t, pose_glow)
		var s := 1.0 + glow * 0.08
		return Transform2D(sin(_phase - 0.7) * 0.05 + pose_lean * 0.3, Vector2(s, s * (1.0 + pose_squash * 0.5)), 0.0, Vector2.ZERO)
	return super.rig_local(n)

func draw_rig_extras(world: Dictionary) -> void:
	var glow := maxf(anim_t, pose_glow)
	if glow <= 0.01 or not world.has(&"head"):
		return
	var xf: Transform2D = world[&"head"]
	draw_set_transform_matrix(xf)
	var center := Vector2(0, -24)
	for i: int in 3:
		draw_circle(center, 34.0 + i * 12.0, Color(1.0, 0.92, 0.45, 0.16 * glow))
