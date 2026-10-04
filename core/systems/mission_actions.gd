class_name MissionActions
extends Node
## Plant-free artillery; no dependence on purchased items or seed unlocks.
var battle: Battle
var cooldown: float = 0.0

func setup(b: Battle) -> void:
	battle = b

func _physics_process(delta: float) -> void:
	if battle.phase == Battle.Phase.PLAYING:
		cooldown = maxf(0.0, cooldown - delta)

func fire(cell: Vector2i) -> void:
	if battle.level.mode != &"artillery" or cooldown > 0.0:
		return
	cooldown = battle.level.artillery_cooldown
	battle.damage_area(cell.y, Board.cell_center(cell.y, cell.x).x, 1.15, battle.level.artillery_damage, &"blast")
	battle.fx_explosion(Board.cell_center(cell.y, cell.x), 95, Color(1.0, 0.7, 0.2))


func repair(cell: Vector2i) -> void:
	if battle.level.mode != &"holdout" or cooldown > 0.0: return
	var plant := battle.board.get_plant(cell.y, cell.x)
	if plant == null or plant.dead or plant.hp >= plant.max_hp_now(): return
	cooldown = 3.0
	plant.hp = minf(plant.max_hp_now(), plant.hp + 1200.0)
	battle.fx_puff(plant.position + Vector2(0, -50), 40)
