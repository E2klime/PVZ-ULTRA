class_name WorkshopScreen
extends Control
var _inventory: Label
var _list: VBoxContainer

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.with_art("res://assets/art/bg/hub_greenhouse.jpg", 0.15))
	var panel := UIKit.panel(22)
	panel.position = Vector2(180, 100)
	panel.size = Vector2(1560, 880)
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label(tr("UI_WORKSHOP"), 42))
	_inventory = UIKit.label("", 26)
	v.add_child(_inventory)
	v.add_child(UIKit.wrap(tr("WORKSHOP_INTRO"), 22))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1450, 620)
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	v.add_child(scroll)
	v.add_child(UIKit.button(tr("WORKSHOP_BACK"), func() -> void: GameState.goto(&"hub")))
	panel.add_child(v)
	add_child(panel)
	_refresh()

func _refresh() -> void:
	var mats: PackedStringArray = []
	for m: String in ["compost", "scrap", "crystal"]:
		mats.append("%s: %d" % [tr("MAT_" + m.to_upper()), SaveManager.material(m)])
	_inventory.text = "   ".join(mats)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for recipe: Dictionary in CraftingSystem.recipes():
		var row := UIKit.hbox(16)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned := CraftingSystem.status_text(recipe)
		info.add_child(UIKit.label(Loc.text(str(recipe["name"])) + owned, 26))
		info.add_child(UIKit.wrap(Loc.text(str(recipe["description"])), 20))
		var costs: PackedStringArray = []
		for item: String in recipe["cost"]:
			costs.append("%d %s" % [int(recipe["cost"][item]), tr("MAT_" + item.to_upper())])
		var world := DB.map(StringName(recipe["world"]))
		var world_name := Loc.text(world.name_key) if world else str(recipe["world"])
		info.add_child(UIKit.label(tr("WORKSHOP_COST").format({"cost": " + ".join(costs), "world": world_name}), 20))
		row.add_child(info)
		var button := UIKit.button(tr("WORKSHOP_CRAFT"), _craft.bind(str(recipe["id"])), 170)
		button.disabled = not CraftingSystem.can_craft(recipe)
		row.add_child(button)
		_list.add_child(row)

func _craft(id: String) -> void:
	CraftingSystem.craft(id)
	_refresh()
