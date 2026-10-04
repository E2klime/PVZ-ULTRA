class_name ZombieBrute
extends Zombie
## Huge and slow. Smashes plants with a log instead of biting. Cannot be swallowed or pushed.

var _smash: float = 0.0

func _bite(p: Plant) -> void:
	_smash = 1.0
	p.take_damage(data.damage * data.eat_interval * diff.zombie_dps_mult, self)
	battle.shake(6.0)

func _process(delta: float) -> void:
	_smash = max(0.0, _smash - delta * 3.0)
	super._process(delta)

func draw_accessory_front(sh: Vector2) -> void:
	var up := 1.0 - _smash
	var hand := Vector2(-20, -104) + sh
	var tip := hand + Vector2(-30, -60).rotated(-1.6 * (1.0 - up) * 0.6)
	if state == State.EAT:
		tip = hand + Vector2(-60, -10).rotated(-1.2 * up)
	DrawUtil.line(self, hand, tip, Color(0.45, 0.3, 0.18), 16)
	DrawUtil.circle(self, tip, 13, Color(0.5, 0.34, 0.2), 3)

func draw_accessory_head(head: Vector2) -> void:
	DrawUtil.rrect(self, Rect2(head + Vector2(-26, -30), Vector2(52, 10)), Color(0.35, 0.3, 0.4), 3, 2)

func rig_front_items(upper: Transform2D, sh: Vector2) -> void:
	var up := 1.0 - _smash
	var hand := Vector2(-30, -96) + sh
	var ang := -0.5 - 1.0 * (1.0 - up) * 0.6
	if state == State.EAT:
		ang = -1.6 + 1.1 * up
	_rp(&"club", upper * Transform2D(ang, hand))
