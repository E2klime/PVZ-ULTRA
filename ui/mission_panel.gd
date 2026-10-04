class_name MissionPanel
extends Control
## Live mission counters and consumable buttons, isolated from the existing HUD.
var battle: Battle
var _status: Label
var _briefing: Label
var _note: PanelContainer
var _status_pill: PanelContainer
const NOTE_HOLD := 10.0
const NOTE_FADE := 1.5
var _tool_buttons: Dictionary = {}
const TOOLS := ["sun_flask", "sun_magnet", "compost_tea", "glue_trap", "frost_bottle", "pepper_bomb", "repair_kit", "seed_clock"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pill = BattleHUD.pill()
	_status_pill.position = Vector2(660, 142)
	_status_pill.custom_minimum_size = Vector2(600, 0)
	_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = BattleHUD.outlined("", 22, Color(1.0, 0.96, 0.84))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pill.add_child(_status)
	add_child(_status_pill)
	# Level briefing: a pinned note card beside the lawn that fades after a few seconds.
	_note = PanelContainer.new()
	_note.add_theme_stylebox_override("panel", UITheme.kit("note"))
	_note.position = Vector2(1520, 210)
	_note.custom_minimum_size = Vector2(380, 0)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing = UIKit.wrap(Loc.text(battle.level.hint_key), 21, UITheme.INK)
	_briefing.custom_minimum_size = Vector2(320, 0)
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(_briefing)
	_note.rotation = deg_to_rad(1.2)
	add_child(_note)
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
	var t := battle.objectives.elapsed
	if _note.visible and _briefing.get_line_count() > 0:
		var need := _briefing.get_line_count() * _briefing.get_line_height() + 6.0
		if absf(_briefing.custom_minimum_size.y - need) > 1.0:
			_briefing.custom_minimum_size.y = need
			_note.reset_size()
	_note.visible = t < NOTE_HOLD + NOTE_FADE
	_note.modulate.a = clampf((NOTE_HOLD + NOTE_FADE - t) / NOTE_FADE, 0.0, 1.0)
	_status.text = battle.objectives.summary()
	if battle.level.mode == &"artillery":
		_status.text += " · " + tr("MISSION_CANNON").format({"s": "%.1f" % battle.mission_actions.cooldown})
	elif battle.level.mode == &"holdout":
		_status.text += " · " + tr("MISSION_REPAIR").format({"s": "%.1f" % battle.mission_actions.cooldown})
	_status_pill.visible = _status.text != ""
	for id: String in TOOLS:
		var b: Button = _tool_buttons[id]
		b.text = "%s ×%d" % [CraftingSystem.tool_name(id), SaveManager.tool_count(id)]
		b.visible = SaveManager.tool_count(id) > 0  # only owned tools; keeps the panel on-screen
		b.disabled = battle.phase != Battle.Phase.PLAYING

func _use(id: String) -> void:
	CraftingSystem.use_tool(battle, id)
