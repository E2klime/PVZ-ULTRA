class_name PlantHive
extends Plant
## Hive Pod: releases bees that home in on the nearest zombie anywhere on the lawn.

var _cd: float = 2.0
var bees: Array[Bee] = []

func tick(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var alive: Array[Bee] = []
	for b: Bee in bees:
		if is_instance_valid(b) and not b.done:
			alive.append(b)
	bees = alive
	if bees.size() >= data.summon_max or battle.nearest_target(position) == null:
		_cd = 0.3
		return
	_cd = data.attack_interval / tempo()
	trigger_action(&"action")
	bees.append(battle.spawn_bee(position + Vector2(0, -80), dmg(data.damage)))

func rig_local(n: StringName) -> Transform2D:
	if n == &"head":
		var s := 1.0 + anim_t * 0.12 + sin(_phase * 2.0) * 0.015
		return Transform2D(sin(_phase - 0.7) * 0.05, Vector2(s, 2.0 - s), 0.0, Vector2.ZERO)
	return super.rig_local(n)
