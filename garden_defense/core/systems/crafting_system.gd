class_name CraftingSystem
extends RefCounted
## Persistent workshop transactions. No coins/materials deducted on invalid recipes.
static func recipes() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/crafting/workshop.json"))

static func status_text(recipe: Dictionary) -> String:
	match str(recipe["kind"]):
		"tool": return " " + TranslationServer.translate("CRAFT_OWNED").format({"n": SaveManager.tool_count(recipe["result"])})
		"upgrade":
			var lvl := SaveManager.upgrade_level(recipe["result"])
			if lvl >= int(recipe["tier"]): return " " + TranslationServer.translate("CRAFT_INSTALLED")
			if lvl < int(recipe["tier"]) - 1: return " " + TranslationServer.translate("CRAFT_NEEDS_TIER").format({"n": int(recipe["tier"]) - 1})
			return ""
		_: return " " + TranslationServer.translate("CRAFT_UNLOCKED") if SaveManager.is_plant_unlocked(StringName(recipe["result"])) else ""

static func can_craft(recipe: Dictionary) -> bool:
	if not CampaignProgress.world_unlocked(StringName(recipe["world"])): return false
	if recipe["kind"] == "unlock" and SaveManager.is_plant_unlocked(StringName(recipe["result"])): return false
	if recipe["kind"] == "upgrade" and SaveManager.upgrade_level(recipe["result"]) != int(recipe["tier"]) - 1: return false
	for item: String in recipe["cost"]:
		if SaveManager.material(item) < int(recipe["cost"][item]): return false
	if recipe["kind"] == "tool" and SaveManager.tool_count(recipe["result"]) >= 9: return false
	return true

static func craft(recipe_id: String) -> bool:
	for recipe: Dictionary in recipes():
		if recipe["id"] != recipe_id: continue
		if not can_craft(recipe): return false
		for item: String in recipe["cost"]: SaveManager.add_material(item, -int(recipe["cost"][item]))
		if recipe["kind"] == "tool":
			SaveManager.add_tool(recipe["result"], 1)
		elif recipe["kind"] == "upgrade":
			SaveManager.add_upgrade(recipe["result"])
		else:
			SaveManager.unlock_plant(StringName(recipe["result"]))
		SaveManager.add_stat(&"crafted")
		SaveManager.save_game()
		return true
	return false

static func use_tool(battle: Battle, id: String) -> bool:
	if battle.phase != Battle.Phase.PLAYING or SaveManager.tool_count(id) <= 0: return false
	match id:
		"sun_flask": battle.add_sun(200, false)  # bought sun never counts toward collect objectives
		"compost_tea":
			var healed := false
			for p: Plant in battle.board.all_plants():
				if not p.dead and p.hp < p.max_hp_now():
					p.hp = minf(p.max_hp_now(), p.hp + 750.0)
					healed = true
			if not healed: return _no_effect(battle)
		"frost_bottle":
			var frozen := false
			for lane: Array in battle.lanes:
				for z: Zombie in lane:
					if z.is_targetable():
						z.freeze(5.0)
						frozen = true
			if not frozen: return _no_effect(battle)
		"pepper_bomb":
			var z := battle.nearest_target(Board.ORIGIN)
			if z == null: return _no_effect(battle)
			battle.damage_area(z.row, z.position.x, 1.5, 900.0, &"explosion")
		"repair_kit":
			if battle.base_integrity >= battle.max_base_integrity: return _no_effect(battle)
			battle.base_integrity += 1
		"seed_clock":
			var any_cd := false
			for seed: SeedState in battle.seeds:
				any_cd = any_cd or seed.cooldown > 0.0
				seed.cooldown = 0.0
			if not any_cd: return _no_effect(battle)
		"sun_magnet":
			var pulled := 0
			for child: Node in battle.sun_layer.get_children():
				var t := child as SunToken
				if t and not t.collected:
					t.collect()
					pulled += 1
			if pulled == 0: return _no_effect(battle)
		"glue_trap":
			var any := false
			for lane: Array in battle.lanes:
				for z: Zombie in lane:
					if z.is_alive():
						z.apply_slow(0.5, 8.0)
						any = true
			if not any: return _no_effect(battle)
		_:
			return false
	SaveManager.add_tool(id, -1)
	SaveManager.save_game()
	battle.hud.update_sun()
	battle.hud.update_base_integrity()
	battle.hud.toast(TranslationServer.translate("TOAST_TOOL_USED").format({"name": tool_name(id)}))
	return true

## A tool that would do nothing right now is kept (not consumed) and explained.
static func _no_effect(battle: Battle) -> bool:
	battle.hud.toast(TranslationServer.translate("TOAST_TOOL_NO_EFFECT"))
	Sfx.play(&"error")
	return false

## Localized name of a consumable tool id such as "sun_flask".
static func tool_name(id: String) -> String:
	var key := "TOOL_" + id.to_upper()
	var t := TranslationServer.translate(key)
	return t if t != key else id.replace("_", " ").capitalize()
