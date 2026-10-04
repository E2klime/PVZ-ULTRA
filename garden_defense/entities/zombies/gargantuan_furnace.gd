class_name GargantuanFurnace
extends ZombieGargantuan
## Cleavable armor and a short-range furnace; frost stops its pulse timer.
func special() -> void:
	battle.hud.banner(tr("BANNER_GARGANTUAN_FURNACE"), 2.0)
	pulse()

func pulse() -> void:
	for p: Plant in battle.board.all_plants().duplicate():
		if p.row == row and not p.is_air() and absf(position.x - p.position.x) < 230:
			p.take_damage(90.0, self)
	battle.fx_explosion(position + Vector2(0, -40), 75, Color.ORANGE_RED)
