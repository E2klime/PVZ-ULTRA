class_name PlantFreeze
extends Plant
## Rime Lettuce: costs 0 sun. Zombies walk onto it; the first one to touch it is
## frozen solid inside an ice block (freeze_time seconds, halved for giants),
## then stays chilled for a few seconds after it thaws. Single use.

func idle_clip() -> StringName:
	return &"idle_ground"

## Zombies step onto it rather than chewing it.
func blocks_zombies() -> bool:
	return false

func sway_amount() -> float:
	return 0.3

func tick(_delta: float) -> void:
	var z := battle.zombie_touching(row, position.x, 50.0, false)
	if z and not z.is_frozen():
		z.freeze(data.freeze_time)
		battle.fx_shatter(position + Vector2(0, -30))
		die(true)

func rig_local(n: StringName) -> Transform2D:
	if n == &"body":
		var b := sin(_phase * 1.4) * 0.025
		return Transform2D(0.0, Vector2(1.0 + b, 1.0 - b), 0.0, Vector2.ZERO)
	return super.rig_local(n)
