class_name ZombieBurrower
extends Zombie
## Digs under the defence, surfaces next to the house and attacks from behind.
## Only mines can hit it while underground.

func on_setup() -> void:
	underground = true
	_set_state(State.ABILITY)

func _ability(delta: float) -> void:
	position.x += dir * base_speed() * Board.CELL.x * speed_mult() * delta
	walk_phase += delta * 6.0
	if position.x <= Board.ORIGIN.x + Board.CELL.x * 0.35:
		underground = false
		dir = 1.0
		battle.fx_puff(position + Vector2(0, -20), 60.0)
		stun_t = 1.2
		_set_state(State.WALK)

func can_be_devoured() -> bool:
	return super.can_be_devoured()

func draw_accessory_back(sh: Vector2) -> void:
	DrawUtil.line(self, Vector2(16, -60) + sh, Vector2(30, -150) + sh, Color(0.5, 0.36, 0.22), 5)
	DrawUtil.poly(self, PackedVector2Array([Vector2(6, -146) + sh, Vector2(30, -160) + sh, Vector2(56, -150) + sh, Vector2(30, -152) + sh]), Color(0.6, 0.62, 0.65), 2)

func rig_back_items(upper: Transform2D, sh: Vector2) -> void:
	_rp(&"pick", upper * Transform2D(0.25, Vector2(18, -60) + sh), BACK_TINT)
