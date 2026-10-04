class_name AlmanacScreen
extends Control
## Almanac: every plant, zombie and Graft recipe with a full stat sheet.
## Nothing is hidden behind placeholders; plants not yet unlocked are only slightly dimmed.

var _back: StringName = &"menu"
var _detail: VBoxContainer

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"menu")

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.new())
	var root := UIKit.vbox(12)
	root.position = Vector2(40, 24)
	root.custom_minimum_size = Vector2(1840, 1030)
	var head := UIKit.hbox(20)
	head.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(_back), 180))
	head.add_child(UIKit.title(tr("UI_ALMANAC"), 52))
	root.add_child(head)
	var body := UIKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(1180, 900)
	tabs.add_theme_font_size_override("font_size", 28)
	tabs.add_child(_plants_tab())
	tabs.add_child(_zombies_tab())
	tabs.add_child(_recipes_tab())
	tabs.set_tab_title(0, tr("ALMANAC_PLANTS"))
	tabs.set_tab_title(1, tr("ALMANAC_ZOMBIES"))
	tabs.set_tab_title(2, tr("ALMANAC_GRAFTS"))
	body.add_child(tabs)
	var dp := UIKit.panel(24)
	dp.custom_minimum_size = Vector2(640, 900)
	var ds := ScrollContainer.new()
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ds.custom_minimum_size = Vector2(600, 860)
	_detail = UIKit.vbox(8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail)
	dp.add_child(ds)
	body.add_child(dp)
	root.add_child(body)
	add_child(root)
	_detail.add_child(UIKit.wrap(tr("ALMANAC_PICK"), 26))

static func plant_known(id: StringName) -> bool:
	return DB.plant(id) != null

## Whether the player has actually met this plant (unlocked or grafted).
static func plant_met(id: StringName) -> bool:
	var d := DB.plant(id)
	if d == null:
		return false
	if SaveManager.is_plant_unlocked(id):
		return true
	if d.is_hybrid:
		for r: FusionRecipe in DB.recipes_with_result(id):
			if SaveManager.is_recipe_discovered(r.recipe_id()):
				return true
	return false

func _scroll_grid() -> Array:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	return [scroll, grid]

func _tile(known: bool, legendary: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 170)
	var st := UITheme.box(Color(0.99, 0.9, 0.6) if legendary else Color(0.93, 0.86, 0.66), UITheme.LEGEND if legendary else Color(0.55, 0.38, 0.22), 12, 6 if legendary else 4, 6)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", UITheme.box(Color(0.98, 0.93, 0.75), Color(0.55, 0.38, 0.22), 12, 4, 6))
	b.add_theme_stylebox_override("pressed", st)
	b.disabled = not known
	b.add_theme_stylebox_override("disabled", UITheme.box(Color(0.6, 0.56, 0.48), Color(0.4, 0.3, 0.2), 12, 4, 6))
	return b

func _plants_tab() -> Control:
	var sg := _scroll_grid()
	var scroll: ScrollContainer = sg[0]
	var grid: GridContainer = sg[1]
	for id: StringName in DB.PLANT_ORDER:
		var d := DB.plant(id)
		if d == null:
			continue
		var known := true
		var b := _tile(known, d.rarity == &"legendary")
		var prev := EntityPreview.new(Vector2(150, 140))
		prev.silhouette = false
		if not plant_met(id):
			b.modulate = Color(0.86, 0.86, 0.86)
		prev.position = Vector2(0, 0)
		prev.size = Vector2(150, 140)
		b.add_child(prev)
		prev.show_plant(d, 0.75)
		var l := UIKit.fit_label(tr(d.name_key), 16, 142.0)
		l.clip_text = true
		l.position = Vector2(0, 138)
		l.size = Vector2(150, 28)
		b.add_child(l)
		b.pressed.connect(_show_plant.bind(id))
		grid.add_child(b)
	return scroll

func _zombies_tab() -> Control:
	var sg := _scroll_grid()
	var scroll: ScrollContainer = sg[0]
	var grid: GridContainer = sg[1]
	for id: StringName in DB.ZOMBIE_ORDER:
		var d := DB.zombie(id)
		if d == null:
			continue
		var known := true
		var b := _tile(known)
		var prev := EntityPreview.new(Vector2(150, 140))
		prev.silhouette = false
		prev.size = Vector2(150, 140)
		b.add_child(prev)
		prev.show_zombie(d, 0.55 / d.body_scale)
		var l := UIKit.fit_label(tr(d.name_key), 16, 142.0)
		l.clip_text = true
		l.position = Vector2(0, 138)
		l.size = Vector2(150, 28)
		b.add_child(l)
		b.pressed.connect(_show_zombie.bind(id))
		grid.add_child(b)
	return scroll

func _recipes_tab() -> Control:
	var scroll := ScrollContainer.new()
	var v := UIKit.vbox(10)
	v.custom_minimum_size = Vector2(1100, 0)
	var found := 0
	for r: FusionRecipe in DB.recipes:
		var rid := r.recipe_id()
		var discovered := SaveManager.is_recipe_discovered(rid) or not r.hidden_until_discovered
		var hinted := SaveManager.is_recipe_hinted(rid)
		var a := tr(DB.plant(r.base_id).name_key)
		var b := tr(DB.plant(r.catalyst_id).name_key)
		var c := tr(DB.plant(r.result_id).name_key)
		if discovered:
			found += 1
		var p := UIKit.panel(12)
		var h := UIKit.hbox(14)
		h.add_child(UIKit.label("%s  +  %s   →   %s" % [a, b, c], 26))
		h.add_child(UIKit.spacer())
		var total := DB.plant(r.catalyst_id).cost + r.fee
		h.add_child(UIKit.label(tr("ALMANAC_GRAFT_COST").format({"n": total, "fee": r.fee}), 22, UITheme.LEAF_DARK))
		if not discovered:
			h.add_child(UIKit.label(tr("ALMANAC_NOT_TRIED"), 20, Color(0.6, 0.45, 0.1)))
		p.add_child(h)
		v.add_child(p)
	v.add_child(UIKit.label(tr("ALMANAC_FOUND").format({"n": found, "max": DB.recipes.size()}), 24))
	v.add_child(UIKit.wrap(tr("ALMANAC_GRAFT_HELP"), 22))
	scroll.add_child(v)
	return scroll

func _clear_detail() -> void:
	for c: Node in _detail.get_children():
		c.queue_free()

func _show_plant(id: StringName) -> void:
	_clear_detail()
	var d := DB.plant(id)
	var prev := EntityPreview.new(Vector2(600, 260))
	_detail.add_child(prev)
	prev.show_plant(d, 1.6)
	_detail.add_child(UIKit.label(tr(d.name_key), 38))
	if d.rarity == &"legendary":
		_detail.add_child(UIKit.label("★ " + tr("RARITY_LEGENDARY"), 26, UITheme.LEGEND))
	_detail.add_child(UIKit.wrap(tr(d.desc_key), 24))
	_detail.add_child(_stat_sheet(plant_stats(d)))

## Rows of [label, value] describing a plant in plain numbers.
func plant_stats(d: PlantData) -> Array:
	var rows: Array = []
	var cell := Board.CELL.x
	rows.append([tr("UI_ROLE"), tr("ROLE_" + String(d.role).to_upper())])
	if d.is_seed:
		rows.append([tr("UI_COST"), tr("STAT_SUN").format({"n": d.cost})])
		rows.append([tr("UI_RECHARGE"), tr("UNIT_SEC").format({"n": "%.1f" % d.recharge})])
		if d.start_cooldown > 0.0:
			rows.append([tr("STAT_START_COOLDOWN"), tr("UNIT_SEC").format({"n": "%.0f" % d.start_cooldown})])
	else:
		rows.append([tr("STAT_MADE_BY"), tr("STAT_GRAFT")])
	rows.append([tr("UI_HP"), str(d.max_hp)])
	rows.append([tr("STAT_SURFACE"), tr("STAT_WATER") if d.allowed_surfaces.has(&"water") and not d.allowed_surfaces.has(&"grass") else tr("STAT_LAWN")])
	if d.damage > 0:
		var per_hit := d.damage
		rows.append([tr("STAT_DAMAGE"), str(per_hit) + (" ×%d" % d.shots if d.shots > 1 and d.sun_amount == 0 else "")])
		if d.role in [&"shooter", &"slower", &"pierce", &"control", &"summoner", &"aoe", &"chain"]:
			rows.append([tr("STAT_RATE"), tr("STAT_EVERY").format({"n": "%.2f" % d.attack_interval})])
			var vol := d.shots if d.sun_amount == 0 else 1
			rows.append([tr("STAT_DPS"), "%.1f" % (per_hit * vol / maxf(0.1, d.attack_interval))])
	if d.attack_range > 0.0:
		rows.append([tr("STAT_RANGE"), tr("STAT_CELLS").format({"n": "%.1f" % d.attack_range})])
	elif d.role in [&"shooter", &"slower", &"pierce"]:
		rows.append([tr("STAT_RANGE"), tr("STAT_WHOLE_LANE")])
	if d.pierce > 0:
		rows.append([tr("STAT_PIERCE"), tr("STAT_ALL") if d.pierce >= 99 else str(d.pierce)])
	if d.projectile_speed != 560.0 and d.damage > 0 and d.role in [&"shooter", &"pierce", &"slower"]:
		rows.append([tr("STAT_PROJECTILE"), tr("UNIT_PX_PER_SEC").format({"n": int(d.projectile_speed)})])
	if d.slow_duration > 0.0:
		rows.append([tr("STAT_SLOW"), tr("STAT_SLOW_V").format({"p": int(round((1.0 - d.slow_factor) * 100.0)), "s": "%.0f" % d.slow_duration})])
	if d.aoe_radius > 0.0:
		rows.append([tr("STAT_AREA"), tr("STAT_CELLS").format({"n": "%.1f" % d.aoe_radius})])
	if d.burn_dps > 0.0:
		rows.append([tr("STAT_BURN"), tr("STAT_BURN_V").format({"d": "%.0f" % d.burn_dps, "s": "%.0f" % d.burn_time})])
	if d.freeze_time > 0.0:
		rows.append([tr("STAT_FREEZE"), tr("UNIT_SEC").format({"n": "%.0f" % d.freeze_time})])
	if d.chain_count > 0:
		rows.append([tr("STAT_CHAIN"), tr("STAT_CHAIN_V").format({"n": d.chain_count, "r": "%.1f" % d.chain_range})])
	if d.stun_time > 0.0:
		rows.append([tr("STAT_STUN"), tr("UNIT_SEC").format({"n": "%.1f" % d.stun_time})])
	if d.thorns_damage > 0:
		rows.append([tr("STAT_THORNS"), tr("STAT_PER_BITE").format({"n": d.thorns_damage})])
	if d.push_distance > 0.0:
		rows.append([tr("STAT_PUSH"), tr("STAT_CELLS").format({"n": "%.2f" % (d.push_distance / cell)})])
	if d.pull_range > 0.0:
		rows.append([tr("STAT_PULL"), tr("STAT_CELLS").format({"n": "%.1f" % d.pull_range})])
	if d.regen_per_sec > 0.0:
		rows.append([tr("STAT_REGEN"), tr("UNIT_HP_PER_SEC").format({"n": "%.0f" % d.regen_per_sec})])
	if d.rebirths > 0:
		rows.append([tr("STAT_REBIRTHS"), str(d.rebirths)])
	if d.sun_amount > 0:
		var per := d.sun_amount * maxi(1, d.shots)
		rows.append([tr("STAT_SUN_MADE"), tr("STAT_SUN_V").format({"n": per, "s": "%.0f" % d.sun_interval, "m": "%.0f" % (per * 60.0 / maxf(1.0, d.sun_interval))})])
	if d.arm_time > 0.0:
		rows.append([tr("STAT_ARM"), tr("UNIT_SEC").format({"n": "%.0f" % d.arm_time})])
	if d.chew_time > 0.0:
		rows.append([tr("STAT_CHEW"), tr("UNIT_SEC").format({"n": "%.0f" % d.chew_time})])
	if d.buff_mult > 1.0:
		rows.append([tr("STAT_BUFF"), "+%d%%" % int(round((d.buff_mult - 1.0) * 100.0))])
	if d.summon_max > 0:
		rows.append([tr("STAT_SUMMONS"), str(d.summon_max)])
	# Either side of a recipe needs a grown plant on the board (order does not matter).
	var is_base := false
	for r: FusionRecipe in DB.recipes:
		if r.base_id == d.id or r.catalyst_id == d.id:
			is_base = true
	if d.fusion_ready_time < 90.0 and is_base:
		rows.append([tr("STAT_GROW_TIME"), tr("UNIT_SEC").format({"n": "%.0f" % d.fusion_ready_time})])
	if d.max_on_board > 0:
		rows.append([tr("STAT_LIMIT"), tr("STAT_LIMIT_V").format({"n": d.max_on_board})])
	for r: FusionRecipe in DB.recipes_with_result(d.id):
		rows.append([tr("STAT_RECIPE"), tr("ALMANAC_RECIPE").format({"a": tr(DB.plant(r.base_id).name_key), "b": tr(DB.plant(r.catalyst_id).name_key)})])
	var into: Array[StringName] = []
	for r: FusionRecipe in DB.recipes:
		if (r.base_id == d.id or r.catalyst_id == d.id) and not into.has(r.result_id) and DB.plant(r.result_id):
			into.append(r.result_id)
			rows.append([tr("STAT_GRAFTS_INTO"), tr(DB.plant(r.result_id).name_key)])
	return rows

func zombie_stats(d: ZombieData) -> Array:
	var rows: Array = []
	var px := d.speed * Board.CELL.x
	rows.append([tr("UI_HP"), str(d.hp)])
	if d.armor_hp > 0:
		rows.append([tr("STAT_ARMOR"), "%d (%s)" % [d.armor_hp, tr("ARMOR_" + String(d.armor_kind).to_upper())]])
	rows.append([tr("UI_TOUGHNESS"), str(d.hp + d.armor_hp)])
	rows.append([tr("UI_SPEED"), tr("STAT_SPEED_V").format({"c": "%.2f" % d.speed, "p": "%.0f" % px})])
	rows.append([tr("STAT_CROSS"), tr("UNIT_SEC").format({"n": "%.0f" % (Board.COLS / maxf(0.01, d.speed))})])
	rows.append([tr("STAT_BITE"), tr("STAT_BITE_V").format({"d": "%.0f" % d.damage, "s": "%.2f" % d.eat_interval})])
	rows.append([tr("STAT_EAT_DPS"), "%.0f" % (d.damage / maxf(0.05, d.eat_interval))])
	rows.append([tr("STAT_THREAT"), "%.0f" % d.threat_cost])
	rows.append([tr("STAT_POD_HITS"), str(ceili(float(d.hp + d.armor_hp) / 20.0))])
	if not d.immune_to.is_empty():
		var names: Array[String] = []
		for t: StringName in d.immune_to:
			names.append(tr("IMMUNE_" + String(t).to_upper()))
		rows.append([tr("STAT_IMMUNE"), ", ".join(names)])
	if d.body_scale > 1.0:
		rows.append([tr("STAT_SIZE"), "×%.2f" % d.body_scale])
	return rows

func _stat_sheet(rows: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	for row: Array in rows:
		var k := UIKit.label(str(row[0]), 22, UITheme.INK)
		k.custom_minimum_size = Vector2(220, 0)
		g.add_child(k)
		var v := UIKit.wrap(str(row[1]), 22)
		v.custom_minimum_size = Vector2(340, 0)
		v.add_theme_color_override("font_color", UITheme.LEAF_DARK)
		g.add_child(v)
	return g

func _show_zombie(id: StringName) -> void:
	_clear_detail()
	var d := DB.zombie(id)
	var prev := EntityPreview.new(Vector2(600, 300))
	_detail.add_child(prev)
	prev.show_zombie(d, 1.3 / d.body_scale)
	_detail.add_child(UIKit.label(tr(d.name_key), 38))
	_detail.add_child(UIKit.wrap(tr(d.desc_key), 24))
	_detail.add_child(_stat_sheet(zombie_stats(d)))

func _speed_word(s: float) -> String:
	if s < 0.18:
		return tr("SPEED_SLOW")
	if s < 0.3:
		return tr("SPEED_NORMAL")
	return tr("SPEED_FAST")
