class_name FusionSystem
extends RefCounted
## Graft rules: base + catalyst -> hybrid, order-independent.
## Plants never upgrade in place (no evolutions, no star-ups): dropping a seed on
## a plant only works when a hybrid recipe exists, including same-plant "twin"
## recipes such as Sunbud + Sunbud = Twin Sunbud or Pod Shooter + Pod Shooter = Twin Pod.

enum Kind { NONE, GRAFT }

class Plan:
	extends RefCounted
	var kind: Kind = Kind.NONE
	var result: PlantData
	var recipe: FusionRecipe
	var base: Plant
	var cost: int = 0
	## Translation key explaining why it is not possible (empty = ok).
	var error_key: String = ""

static func plan(battle: Battle, base: Plant, seed_data: PlantData, from_glove: bool = false) -> Plan:
	var p := Plan.new()
	p.base = base
	if base == null or seed_data == null:
		p.error_key = "MSG_CELL_OCCUPIED"
		return p
	var recipe := DB.find_recipe(base.data.id, seed_data.id)
	if recipe == null:
		p.error_key = "MSG_NO_RECIPE"
		return p
	p.kind = Kind.GRAFT
	p.recipe = recipe
	p.result = DB.plant(recipe.result_id)
	p.cost = recipe.fee + (0 if from_glove else seed_data.cost)
	if p.result == null:
		p.kind = Kind.NONE
		p.error_key = "MSG_NO_RECIPE"
	elif not SaveManager.has_feature(&"graft") or not battle.level.allow_hybrids:
		p.error_key = "MSG_GRAFT_DISABLED"
	elif battle.hybrid_count() - (1 if base.counts_as_hybrid() else 0) >= battle.level.hybrid_cap:
		# Grafting onto a hybrid replaces it, so it does not need a new slot.
		p.error_key = "MSG_HYBRID_CAP"
	elif not base.is_fusion_ready():
		p.error_key = "MSG_NOT_READY"
	else:
		# The hybrid must fit into its own layer of the cell.
		var other := battle.board.get_layer(base.row, base.col, p.result.layer)
		if other and other != base and other.data.id != seed_data.id:
			p.error_key = "MSG_CELL_OCCUPIED"
	return p
