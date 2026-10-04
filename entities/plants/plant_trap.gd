class_name PlantTrap
extends Plant
## Snapper Trap / Vortex Trap: swallow a zombie in front, then chew for a long time.

enum TrapState { READY, BITING, CHEWING }

var state: TrapState = TrapState.READY
var _t: float = 0.0
var _target: Zombie

func tick(delta: float) -> void:
	match state:
		TrapState.READY:
			var z := battle.first_target_in_lane(row, position.x - 30.0, position.x + Board.CELL.x * 1.25, &"bite")
			if z:
				_target = z
				state = TrapState.BITING
				_t = 0.35
		TrapState.BITING:
			_t -= delta
			if _t <= 0.0:
				_bite()
		TrapState.CHEWING:
			_t -= delta * buff
			if _t <= 0.0:
				state = TrapState.READY
				pop()
				anim.play(idle_clip(), 0.2)

func _bite() -> void:
	trigger_action(&"action_heavy")
	if data.pull_range > 0.0:
		battle.pull_adjacent(row, position.x, data.pull_range)
	if _target and is_instance_valid(_target) and _target.is_alive() and absf(_target.position.x - position.x) < Board.CELL.x * 1.4 and _target.row == row:
		if _target.can_be_devoured():
			_target.devour()
			battle.fx_leaves(position + Vector2(40, -70), data.color_accent)
			state = TrapState.CHEWING
			anim.clear_queue()
			anim.play(&"chew", 0.2)
			_t = data.chew_time
		else:
			_target.take_damage(dmg(data.damage), &"bite")
			state = TrapState.CHEWING
			_t = data.chew_time * 0.25
	else:
		state = TrapState.READY
	_target = null

func _jaw_open() -> float:
	if preview:
		return 0.35 + 0.1 * sin(_phase * 2.0)
	match state:
		TrapState.READY:
			return 0.32 + 0.08 * sin(_phase * 2.2) if anim_t <= 0.0 else 0.0
		TrapState.BITING:
			return 0.2 + 0.6 * clampf(_t / 0.35, 0.0, 1.0)
		TrapState.CHEWING:
			return maxf(0.0, sin(_phase * 6.0)) * 0.18
	return 0.3

func rig_local(n: StringName) -> Transform2D:
	match n:
		&"jaw":
			return Transform2D(_jaw_open() * 0.9, Vector2.ZERO)
		&"head":
			var base := super.rig_local(n)
			var up := Transform2D(-_jaw_open() * 0.35, Vector2.ZERO)
			if state == TrapState.CHEWING and not preview:
				var b := 1.0 + 0.07 * sin(_phase * 6.0)
				up = up * Transform2D(0.0, Vector2(b, 2.0 - b), 0.0, Vector2.ZERO)
			return base * up
	return super.rig_local(n)
