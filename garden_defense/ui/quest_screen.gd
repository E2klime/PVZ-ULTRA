class_name QuestScreen
extends Control
## Quest log: concrete goals with coin / recipe-hint rewards.

var _back: StringName = &"menu"
var _list: VBoxContainer
var _msg: Label

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"menu")

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.new())
	var root := UIKit.vbox(14)
	root.position = Vector2(260, 30)
	root.custom_minimum_size = Vector2(1400, 1000)
	var head := UIKit.hbox(20)
	head.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(_back), 180))
	head.add_child(UIKit.title(tr("UI_QUESTS"), 52))
	head.add_child(UIKit.spacer())
	_msg = UIKit.label("", 26, Color.WHITE)
	head.add_child(_msg)
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1400, 880)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(10)
	_list.custom_minimum_size = Vector2(1370, 0)
	scroll.add_child(_list)
	root.add_child(scroll)
	add_child(root)
	_rebuild()

func _rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for q: QuestData in DB.quests:
		var claimed := SaveManager.is_quest_claimed(q.id)
		var prog := SaveManager.quest_progress(q)
		var p := UIKit.panel(14)
		var h := UIKit.hbox(18)
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(tr(q.title_key), 28))
		v.add_child(UIKit.wrap(tr(q.desc_key).format({"n": q.amount}), 22))
		var bar := ProgressBar.new()
		bar.max_value = q.amount
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(600, 22)
		v.add_child(bar)
		v.add_child(UIKit.label("%d / %d" % [prog, q.amount], 20))
		h.add_child(v)
		var reward := tr("QUEST_REWARD").format({"n": q.reward_coins})
		if q.reward_hint:
			reward += " + " + tr("QUEST_REWARD_HINT")
		h.add_child(UIKit.label(reward, 22, UITheme.LEAF_DARK))
		var b := UIKit.button(tr("QUEST_CLAIMED") if claimed else tr("QUEST_CLAIM"), _claim.bind(q), 200, 24)
		b.disabled = claimed or prog < q.amount
		h.add_child(b)
		p.add_child(h)
		if claimed:
			p.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(p)

func _claim(q: QuestData) -> void:
	var hint := SaveManager.claim_quest(q)
	if hint != &"":
		var r := DB.recipe_by_id(hint)
		_msg.text = tr("MSG_HINT_GAINED").format({"a": tr(DB.plant(r.base_id).name_key), "b": tr(DB.plant(r.catalyst_id).name_key)})
	else:
		_msg.text = tr("MSG_COINS_GAINED").format({"n": q.reward_coins})
	_rebuild()
