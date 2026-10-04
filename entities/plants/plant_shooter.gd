class_name PlantShooter
extends Plant
## Pod Shooter, Twin Pod, Frost Mint, Pepper Stinger, Glacier Shooter, Needle Volley.

var _cd: float = 0.6
var _burst_left: int = 0
var _burst_t: float = 0.0

func tick(delta: float) -> void:
	_cd -= delta
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_fire()
			_burst_left -= 1
			_burst_t = 0.16
		return
	if _cd > 0.0:
		return
	var max_x := Board.SPAWN_X - 45.0
	if data.attack_range > 0.0:
		max_x = min(max_x, position.x + data.attack_range * Board.CELL.x)
	if battle.first_target_in_lane(row, position.x - 20.0, max_x, data.attack_kind) != null:
		_cd = data.attack_interval / tempo()
		trigger_action(&"action_heavy" if data.shots >= 3 or is_legendary() else &"action", _start_volley)
	else:
		_cd = 0.1

## Called on the clip's shoot frame.
func _start_volley() -> void:
	if dead:
		return
	_fire()
	_burst_left = data.shots - 1
	_burst_t = 0.16

func buff_speed() -> float:
	return 1.0 + (buff - 1.0) * 0.5

var _shot_i: int = 0

func _fire() -> void:
	battle.spawn_projectile(row, position + _next_muzzle() + Vector2(0, -hover_height()), dmg(data.damage), data)
	Sfx.play(&"lob" if data.attack_kind == &"lob" else &"shoot", -10.0, 0.12, 70)

## Alternates between the painted barrels (twin/needle heads have 2-3).
func _next_muzzle() -> Vector2:
	_shot_i += 1
	if rig and rig.meta.has("muzzles"):
		var list: Array = rig.meta["muzzles"]
		if list.size() > 0:
			var m: Array = list[_shot_i % list.size()]
			return Vector2(m[0], m[1])
	return muzzle()

func muzzle() -> Vector2:
	return rig_point("muzzle", Vector2(52, -72))
