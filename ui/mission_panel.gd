class_name MissionPanel
extends Control
## Live mission counters and consumable buttons, isolated from the existing HUD.
var battle: Battle
var _status: Label
var _briefing: Label
var _tool_buttons: Dictionary = {}
const TOOLS := ["sun_flask", "sun_magnet", "compost_tea", "glue_trap", "frost_bottle", "pepper_bomb", "repair_kit", "seed_clock"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UIKit.label("", 22, Color.WHITE)
	_status.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.08))
	_status.add_theme_constant_override("outline_size", 6)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(460, 128)
	_status.size = Vector2(1000, 32)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	_briefing = UIKit.wrap(Loc.text(battle.level.hint_key), 22, Color.WHITE)
	_briefing.position = Vector2(1560, 200)
	_briefing.size = Vector2(340, 300)
	_briefing.add_theme_color_override("font_outline_color", Color(0.12, 0.15, 0.12))
	_briefing.add_theme_constant_override("outline_size", 5)
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_briefing)
	var tools := UIKit.hbox(6)
	tools.position = Vector2(330, 1010)
	for id: String in TOOLS:
		var b := UIKit.button(CraftingSystem.tool_name(id), _use.bind(id), 150, 17)
		b.custom_minimum_size.y = 52
		tools.add_child(b)
		_tool_buttons[id] = b
	add_child(tools)

func _process(_delta: float) -> void:
	if battle.phase == Battle.Phase.SEED_SELECT: visible = false; return
	visible = true
	_briefing.visible = battle.objectives.elapsed < 12.0
	_status.text = battle.objectives.summary()
	if battle.level.mode == &"artillery":
		_status.text += " · " + tr("MISSION_CANNON").format({"s": "%.1f" % battle.mission_actions.cooldown})
	elif battle.level.mode == &"holdout":
		_status.text += " · " + tr("MISSION_REPAIR").format({"s": "%.1f" % battle.mission_actions.cooldown})
	for id: String in TOOLS:
		var b: Button = _tool_buttons[id]
		b.text = "%s ×%d" % [CraftingSystem.tool_name(id), SaveManager.tool_count(id)]
		b.visible = SaveManager.tool_count(id) > 0  # only owned tools; keeps the panel on-screen
		b.disabled = battle.phase != Battle.Phase.PLAYING

func _use(id: String) -> void:
	CraftingSystem.use_tool(battle, id)
