class_name ZombieHurdler
extends Zombie
## Vaults over the first plant it meets. Tall plants stop the vault and break the pole.

const JUMP_TIME := 0.75
var has_pole: bool = true
var _jump_from: float = 0.0

func base_speed() -> float:
	return data.speed if has_pole else 0.2

func _on_plant_blocking(p: Plant) -> bool:
	if not has_pole:
		return super._on_plant_blocking(p)
	if p.data.tags.has(&"tall"):
		has_pole = false
		battle.fx_armor_break(position + Vector2(-20, -60), Color(0.75, 0.6, 0.35))
		return super._on_plant_blocking(p)
	_jump_from = position.x
	_set_state(State.ABILITY)
	return true

func _ability(_delta: float) -> void:
	var t := clampf(state_t / JUMP_TIME, 0.0, 1.0)
	position.x = lerpf(_jump_from, _jump_from - Board.CELL.x * 1.15, t)
	hop = sin(t * PI) * 90.0
	if t >= 1.0:
		hop = 0.0
		has_pole = false
		_set_state(State.WALK)

func draw_accessory_back(sh: Vector2) -> void:
	if has_pole:
		var ang := -0.9 * sin(clampf(state_t / JUMP_TIME, 0.0, 1.0) * PI) if state == State.ABILITY else 0.0
		var a := Vector2(-90, -88).rotated(ang) + sh
		var b := Vector2(50, -96).rotated(ang) + sh
		DrawUtil.line(self, a, b, Color(0.75, 0.6, 0.35), 5)
	DrawUtil.rrect(self, Rect2(Vector2(-22, -84) + sh, Vector2(46, 10)), Color(0.95, 0.95, 0.9), 2, 2)

func rig_back_items(upper: Transform2D, sh: Vector2) -> void:
	if has_pole:
		var ang := -0.9 * sin(clampf(state_t / JUMP_TIME, 0.0, 1.0) * PI) if state == State.ABILITY else 0.05
		_rp(&"pole", upper * Transform2D(ang, Vector2(-20, -92) + sh))
