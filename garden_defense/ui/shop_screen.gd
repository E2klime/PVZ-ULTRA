class_name ShopScreen
extends Control
## Coin shop (no real money): seed slots, starting sun, mower kits, recipe hints, mower skins.

var _back: StringName = &"map"
var _list: VBoxContainer
var _coins: Label
var _msg: Label

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"map")

func _ready() -> void:
	UIKit.full(self)
	var bg := ScreenBg.new()
	bg.sky_top = Color(0.95, 0.75, 0.45)
	bg.sky_bottom = Color(0.98, 0.9, 0.7)
	add_child(bg)
	var root := UIKit.vbox(14)
	root.position = Vector2(260, 30)
	root.custom_minimum_size = Vector2(1400, 1000)
	var head := UIKit.hbox(20)
	head.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(_back), 180))
	head.add_child(UIKit.title(tr("UI_SHOP"), 52))
	head.add_child(UIKit.spacer())
	_coins = UIKit.label("", 32, Color.WHITE)
	_coins.add_theme_color_override("font_outline_color", Color(0.45, 0.3, 0.05))
	_coins.add_theme_constant_override("outline_size", 8)
	head.add_child(_coins)
	root.add_child(head)
	_msg = UIKit.label("", 24, UITheme.INK)
	root.add_child(_msg)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1400, 840)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(10)
	_list.custom_minimum_size = Vector2(1370, 0)
	scroll.add_child(_list)
	root.add_child(scroll)
	add_child(root)
	_rebuild()

func _maxed(item: ShopItemData) -> bool:
	var owned := SaveManager.purchased(item.id)
	match item.kind:
		&"hint":
			return not SaveManager.hints_available()
		&"slot":
			return SaveManager.seed_slots() >= SaveManager.MAX_SLOTS
		&"plant":
			return SaveManager.is_plant_unlocked(item.plant_id)
	return item.max_count > 0 and owned >= item.max_count

func _rebuild() -> void:
	_coins.text = tr("UI_COINS").format({"n": SaveManager.coins()})
	for c: Node in _list.get_children():
		c.queue_free()
	for item: ShopItemData in DB.shop_items:
		var owned := SaveManager.purchased(item.id)
		var price := item.price_for(owned if item.kind != &"mower_kit" and item.kind != &"hint" else 0)
		var p := UIKit.panel(14)
		var h := UIKit.hbox(18)
		if item.kind == &"plant":
			var pv := EntityPreview.new(Vector2(110, 130))
			pv.show_plant(DB.plant(item.plant_id), 0.6)
			h.add_child(pv)
		if item.kind == &"skin":
			var sw := ColorRect.new()
			sw.color = item.skin_color
			sw.custom_minimum_size = Vector2(60, 60)
			h.add_child(sw)
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(("★ " if item.kind == &"plant" else "") + tr(item.name_key), 28, UITheme.LEGEND if item.kind == &"plant" else UITheme.INK))
		v.add_child(UIKit.wrap(tr(item.desc_key), 22))
		var owned_text := tr("SHOP_OWNED").format({"n": owned})
		if item.max_count > 0:
			owned_text += " / %d" % item.max_count
		v.add_child(UIKit.label(owned_text, 20, UITheme.LEAF_DARK))
		h.add_child(v)
		if item.kind == &"skin" and owned > 0:
			var eq := SaveManager.equipped_skin() == item.id
			var b := UIKit.button(tr("SHOP_EQUIPPED") if eq else tr("SHOP_EQUIP"), _equip.bind(item), 220, 24)
			b.disabled = eq
			h.add_child(b)
		else:
			var maxed := _maxed(item)
			var b := UIKit.button(tr("SHOP_SOLD_OUT") if maxed else tr("SHOP_BUY").format({"n": price}), _buy.bind(item, price), 240, 24)
			b.disabled = maxed or SaveManager.coins() < price
			h.add_child(b)
		p.add_child(h)
		_list.add_child(p)

func _buy(item: ShopItemData, price: int) -> void:
	if _maxed(item) or not SaveManager.spend_coins(price):
		return
	SaveManager.add_purchase(item.id)
	_msg.text = tr("SHOP_THANKS")
	if item.kind == &"hint":
		var rid := SaveManager.grant_recipe_hint()
		var r := DB.recipe_by_id(rid)
		if r:
			_msg.text = tr("MSG_HINT_GAINED").format({"a": tr(DB.plant(r.base_id).name_key), "b": tr(DB.plant(r.catalyst_id).name_key)})
	elif item.kind == &"skin":
		SaveManager.equip_skin(item.id)
	elif item.kind == &"plant":
		SaveManager.unlock_plant(item.plant_id)
		_msg.text = tr("SHOP_LEGEND_THANKS").format({"name": tr(DB.plant(item.plant_id).name_key)})
	SaveManager.add_stat(&"purchases")
	SaveManager.save_game()
	_rebuild()

func _equip(item: ShopItemData) -> void:
	SaveManager.equip_skin(item.id)
	SaveManager.save_game()
	_rebuild()
