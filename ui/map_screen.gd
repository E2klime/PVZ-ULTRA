class_name MapScreen
extends Control
## Biome map: a node graph with forks, merges, optional bonus nodes, star gates and shop loops.

var map: MapData
var _buttons: Dictionary = {}     # StringName -> MapNodeButton
var _avatar: MapAvatar
var _current: StringName
var _selected: StringName
var _info: PanelContainer
var _info_box: VBoxContainer
var _graph: Control
var _moving: bool = false
var _stars_label: Label
var _coins_label: Label

func _ready() -> void:
	UIKit.full(self)
	map = DB.map(GameState.map_id)
	if map == null:
		map = DB.maps[0]
	_open_gates()
	add_child(ScreenBg.for_screen(StringName("map_" + String(map.id))))
	_graph = MapGraph.new()
	(_graph as MapGraph).screen = self
	add_child(UIKit.full(_graph))
	for n: MapNodeData in map.nodes:
		var b := MapNodeButton.new()
		b.node_data = n
		b.screen = self
		b.position = n.position - b.custom_minimum_size * 0.5
		b.pressed.connect(_on_node_pressed.bind(n.id))
		add_child(b)
		_buttons[n.id] = b
	_current = SaveManager.current_node(map.id)
	if map.get_node_data(_current) == null:
		_current = map.start_node
	_avatar = MapAvatar.new()
	_avatar.position = map.get_node_data(_current).position + Vector2(0, -58)
	add_child(_avatar)
	_build_top_bar()
	_build_info()
	_select(_current)
	EventBus.coins_changed.connect(_on_coins)

func _build_top_bar() -> void:
	var bar := UIKit.hbox(14)
	bar.position = Vector2(20, 16)
	bar.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(&"hub"), 160, 24))
	var p := UIKit.panel(10)
	var h := UIKit.hbox(24)
	h.add_child(UIKit.label(Loc.text(map.name_key), 30))
	_stars_label = UIKit.label("★ %d" % SaveManager.stars(), 30, Color(0.75, 0.55, 0.05))
	h.add_child(_stars_label)
	_coins_label = UIKit.label("", 30, Color(0.55, 0.42, 0.1))
	h.add_child(_coins_label)
	p.add_child(h)
	bar.add_child(p)
	bar.add_child(UIKit.button(tr("UI_ALMANAC"), func() -> void: GameState.goto(&"almanac", {"back": &"map"}), 180, 24))
	var q := tr("UI_QUESTS")
	var n := SaveManager.claimable_quests()
	if n > 0:
		q += " (%d!)" % n
	bar.add_child(UIKit.button(q, func() -> void: GameState.goto(&"quests", {"back": &"map"}), 180, 24))
	bar.add_child(UIKit.button(tr("UI_SETTINGS"), func() -> void: GameState.goto(&"settings", {"back": &"map"}), 180, 24))
	add_child(bar)
	_on_coins(SaveManager.coins())

func _on_coins(total: int) -> void:
	if _coins_label:
		_coins_label.text = tr("UI_COINS").format({"n": total})

## Star gates open automatically once the player has enough stars.
func _open_gates() -> void:
	var changed := true
	while changed:
		changed = false
		for n: MapNodeData in map.nodes:
			if n.type == MapNodeData.NodeType.GATE and not SaveManager.is_node_completed(n.id) and is_available(n):
				SaveManager.complete_node(n.id)
				changed = true
	SaveManager.save_game()

func is_available(n: MapNodeData) -> bool:
	return CampaignProgress.level_unlocked(n.level_id)

func is_selected(id: StringName) -> bool:
	return id == _selected

func label_for(n: MapNodeData) -> String:
	match n.type:
		MapNodeData.NodeType.SHOP:
			return "$"
		MapNodeData.NodeType.GATE:
			return "★%d" % n.requires_stars
		MapNodeData.NodeType.BONUS:
			return "B" + String(n.level_id).get_slice("_", 2)
	return str(int(String(n.level_id).get_slice("_", 1)))

func _on_node_pressed(id: StringName) -> void:
	if _moving:
		return
	var n := map.get_node_data(id)
	if not is_available(n):
		_select(id)
		return
	var route := _route(_current, id)
	if route.size() <= 1:
		_arrive(id)
		return
	_moving = true
	var tw := create_tween()
	for i: int in range(1, route.size()):
		var p := map.get_node_data(route[i]).position + Vector2(0, -58)
		var dist := _avatar.position.distance_to(p) if i == 1 else map.get_node_data(route[i - 1]).position.distance_to(p + Vector2(0, 58))
		tw.tween_property(_avatar, "position", p, clampf(dist / 700.0, 0.12, 0.5))
	tw.tween_callback(_arrive.bind(id))

func _arrive(id: StringName) -> void:
	_moving = false
	_current = id
	SaveManager.set_current_node(map.id, id)
	SaveManager.save_game()
	var n := map.get_node_data(id)
	if n.type == MapNodeData.NodeType.SHOP:
		SaveManager.complete_node(id)
		SaveManager.save_game()
		GameState.goto(&"shop", {"back": &"map"})
		return
	_select(id)

## BFS over edges (both directions) restricted to available nodes.
func _route(from: StringName, to: StringName) -> Array[StringName]:
	var prev := {from: &""}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		if cur == to:
			break
		var neighbours: Array[StringName] = []
		var cn := map.get_node_data(cur)
		if cn:
			neighbours.append_array(cn.next_ids)
		for p: MapNodeData in map.predecessors(cur):
			neighbours.append(p.id)
		for nb: StringName in neighbours:
			var nd := map.get_node_data(nb)
			if nd and not prev.has(nb) and (is_available(nd) or nb == to):
				prev[nb] = cur
				queue.append(nb)
	var out: Array[StringName] = []
	if not prev.has(to):
		return [from, to]
	var c: StringName = to
	while c != &"":
		out.push_front(c)
		c = prev[c]
	return out

func _select(id: StringName) -> void:
	_selected = id
	for b: MapNodeButton in _buttons.values():
		b.queue_redraw()
	_fill_info(map.get_node_data(id))

func _build_info() -> void:
	_info = UIKit.panel(22)
	_info.position = Vector2(1430, 180)
	_info.custom_minimum_size = Vector2(470, 820)
	_info_box = UIKit.vbox(10)
	_info.add_child(_info_box)
	add_child(_info)

func _fill_info(n: MapNodeData) -> void:
	for c: Node in _info_box.get_children():
		c.queue_free()
	if n == null:
		return
	var available := is_available(n)
	match n.type:
		MapNodeData.NodeType.SHOP:
			_info_box.add_child(UIKit.label(tr("UI_SHOP"), 34))
			_info_box.add_child(UIKit.wrap(tr("MAP_SHOP_DESC")))
			if available:
				_info_box.add_child(UIKit.button(tr("UI_OPEN_SHOP"), func() -> void: GameState.goto(&"shop", {"back": &"map"}), 300))
		MapNodeData.NodeType.GATE:
			_info_box.add_child(UIKit.label(tr("MAP_GATE"), 34))
			_info_box.add_child(UIKit.wrap(tr("MAP_GATE_DESC").format({"n": n.requires_stars, "have": SaveManager.stars()})))
		_:
			var lvl := DB.level(n.level_id)
			if lvl == null:
				return
			var t := Loc.title(lvl.name_key)
			if n.type == MapNodeData.NodeType.BONUS:
				t = tr("MAP_BONUS") + ": " + t
			_info_box.add_child(UIKit.wrap(t, 30))
			_info_box.add_child(UIKit.wrap(Loc.text(lvl.desc_key), 22))
			_info_box.add_child(UIKit.wrap(tr("MAP_OBJECTIVES").format({"list": ObjectiveTracker.describe(lvl.objectives)}), 20))
			if not available:
				_info_box.add_child(UIKit.label(tr("MAP_LOCKED"), 24, UITheme.BAD))
				if n.requires_stars > 0:
					_info_box.add_child(UIKit.label(tr("MAP_NEEDS_STARS").format({"n": n.requires_stars}), 22, UITheme.BAD))
				return
			var reward := ""
			if lvl.reward_plant != &"" and not SaveManager.is_plant_unlocked(lvl.reward_plant):
				reward = tr("MAP_REWARD_PLANT").format({"name": tr(DB.plant(lvl.reward_plant).name_key)})
			elif not SaveManager.is_node_completed(n.id):
				reward = tr("MAP_REWARD_COINS").format({"n": lvl.reward_coins})
			else:
				reward = tr("MAP_CLEARED")
				var best := SaveManager.best_difficulty(lvl.id)
				if best >= 0 and best < DB.difficulties.size():
					reward += "  ·  " + tr("MAP_BEST").format({"name": tr(DB.difficulties[best].name_key)})
			_info_box.add_child(UIKit.wrap(reward, 22, UITheme.LEAF_DARK))
			# Difficulty is chosen in Settings only; the panel just shows it.
			var dd := DB.difficulty(GameState.difficulty_id)
			var dname := tr(dd.name_key) if dd else String(GameState.difficulty_id)
			_info_box.add_child(UIKit.wrap(tr("MAP_DIFFICULTY_READONLY").format({"name": dname}), 22, UITheme.LEAF_DARK))
			var play := UIKit.button(tr("UI_PLAY"), func() -> void: GameState.start_level(n.id, lvl.id), 300, 32)
			_info_box.add_child(play)

class MapGraph:
	extends Control
	var screen: MapScreen
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for n: MapNodeData in screen.map.nodes:
			for nid: StringName in n.next_ids:
				var m := screen.map.get_node_data(nid)
				if m == null:
					continue
				var open := screen.is_available(n) and screen.is_available(m)
				var col := Color(0.93, 0.85, 0.6) if open else Color(0.45, 0.42, 0.36, 0.7)
				var w := 16.0 if open else 9.0
				if m.optional:
					_dashed(n.position, m.position, col, w)
				else:
					draw_line(n.position, m.position, col.darkened(0.3), w + 6.0, true)
					draw_line(n.position, m.position, col, w, true)
	func _dashed(a: Vector2, b: Vector2, c: Color, w: float) -> void:
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(1.0, length)
		var t := 0.0
		while t < length:
			var e: float = min(t + 22.0, length)
			draw_line(a + dir * t, a + dir * e, c, w, true)
			t += 38.0

class MapDecor:
	extends Control
	var map_id: StringName
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if map_id == &"pool":
			var water := PackedVector2Array([
				Vector2(0, 780), Vector2(230, 690), Vector2(500, 710),
				Vector2(760, 590), Vector2(1040, 620), Vector2(1280, 500),
				Vector2(1540, 520), Vector2(1920, 350), Vector2(1920, 740),
				Vector2(1590, 700), Vector2(1280, 820), Vector2(930, 790),
				Vector2(620, 920), Vector2(280, 900), Vector2(0, 980),
			])
			draw_colored_polygon(water, Color(0.18, 0.55, 0.72, 0.62))
			for i: int in 11:
				var x := 80.0 + i * 175.0
				var y := 800.0 - sin(i * 1.3) * 105.0
				draw_arc(Vector2(x, y), 42.0, 0.15, PI - 0.15, 24, Color(0.75, 0.94, 0.9, 0.5), 4.0)
		else:
			for i: int in 28:
				var x := 45.0 + float((i * 191) % 1840)
				var y := 360.0 + float((i * 83) % 620)
				var color := Color(1.0, 0.78, 0.32, 0.52) if i % 2 == 0 else Color(0.88, 0.48, 0.66, 0.48)
				draw_circle(Vector2(x, y), 5.0 + float(i % 3), color)

class MapNodeButton:
	extends Button
	var node_data: MapNodeData
	var screen: MapScreen
	func _init() -> void:
		custom_minimum_size = Vector2(96, 96)
		size = custom_minimum_size
		flat = true
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, empty)
	func _draw() -> void:
		var c := size * 0.5
		var avail := screen.is_available(node_data)
		var done := SaveManager.is_node_completed(node_data.id)
		var base := Color(0.55, 0.55, 0.52)
		if avail:
			match node_data.type:
				MapNodeData.NodeType.SHOP:
					base = Color(0.95, 0.7, 0.2)
				MapNodeData.NodeType.GATE:
					base = Color(0.6, 0.45, 0.75)
				MapNodeData.NodeType.BONUS:
					base = Color(0.3, 0.6, 0.85)
				_:
					base = Color(0.4, 0.72, 0.3)
		var r := 40.0 if node_data.type != MapNodeData.NodeType.GATE else 34.0
		if screen.is_selected(node_data.id):
			draw_circle(c, r + 12, Color(1, 1, 1, 0.6))
		if is_hovered():
			r += 3.0
		DrawUtil.circle(self, c, r, base, 6)
		var font := get_theme_default_font()
		var txt := screen.label_for(node_data)
		if not avail and node_data.type != MapNodeData.NodeType.GATE:
			_lock(c)
		else:
			draw_string(font, c + Vector2(-r, 11), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 30, Color.WHITE)
		if node_data.type == MapNodeData.NodeType.LEVEL or node_data.type == MapNodeData.NodeType.BONUS:
			var lvl := DB.level(node_data.level_id)
			if lvl and SaveManager.has_star(lvl.id):
				_star(c + Vector2(r * 0.8, -r * 0.8), 14)
		elif done and node_data.type == MapNodeData.NodeType.GATE:
			draw_arc(c, r - 8, 0, TAU, 24, Color.WHITE, 3)
	func _lock(c: Vector2) -> void:
		draw_arc(c + Vector2(0, -6), 11, PI, TAU, 12, Color.WHITE, 5)
		draw_rect(Rect2(c + Vector2(-15, -6), Vector2(30, 24)), Color.WHITE)
		draw_circle(c + Vector2(0, 5), 4, Color(0.4, 0.4, 0.38))
	func _star(p: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for i: int in 10:
			var a := -PI / 2.0 + TAU * float(i) / 10.0
			pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		DrawUtil.poly(self, pts, UITheme.SUN, 3)

class MapAvatar:
	extends Node2D
	var _t: float = 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var bob := sin(_t * 3.0) * 4.0
		DrawUtil.stem(self, Vector2(0, 10), Vector2(0, -10 + bob), Color(0.3, 0.6, 0.25), 6)
		DrawUtil.circle(self, Vector2(0, -24 + bob), 20, Color(0.45, 0.8, 0.35))
		DrawUtil.eye(self, Vector2(-7, -28 + bob), 5, Vector2(0.4, 0.3))
		DrawUtil.eye(self, Vector2(7, -28 + bob), 5, Vector2(0.4, 0.3))
		DrawUtil.leaf(self, Vector2(0, -42 + bob), 18, -PI / 2.0 - 0.6, Color(0.35, 0.7, 0.3))

