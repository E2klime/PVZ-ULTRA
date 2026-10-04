class_name PlantWall
extends Plant
## Bark Wall, Ironbark Wall, Bramble Vine, Thornwall. Thorns are handled in Plant.take_damage.

func idle_clip() -> StringName:
	return &"idle_legend" if is_legendary() else &"idle_wall"

func sway_amount() -> float:
	return 0.4

func rig_visible(n: StringName) -> bool:
	var st := damage_stage()
	if rig and rig.has(&"body_1"):
		match n:
			&"body":
				return st == 0
			&"body_1":
				return st == 1
			&"body_2":
				return st == 2
	return super.rig_visible(n)

func rig_local(n: StringName) -> Transform2D:
	if n in [&"body", &"body_1", &"body_2"]:
		var b := sin(_phase * 0.9) * 0.012
		return Transform2D(_wob * 0.08, Vector2(1.0 + b, 1.0 - b), 0.0, Vector2.ZERO)
	return super.rig_local(n)
