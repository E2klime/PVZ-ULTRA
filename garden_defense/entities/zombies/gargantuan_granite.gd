class_name GargantuanGranite
extends ZombieGargantuan
## At half health throws two small imps over the front line (never into the house).
func special() -> void:
	battle.hud.banner(tr("BANNER_GARGANTUAN_GRANITE"), 2.0)
	for rr: int in [row, Board.neighbor_row(row)]:
		var imp := battle.spawn_zombie(&"intern_imp", rr)
		if imp: imp.position.x = maxf(Board.ORIGIN.x + 350.0, position.x - 200.0)
