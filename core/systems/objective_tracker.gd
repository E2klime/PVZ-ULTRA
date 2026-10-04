class_name ObjectiveTracker
extends RefCounted
## Battle-local counters; never consult lifetime save stats for mission objectives.
var battle: Battle
var collected: int = 0
var planted: int = 0
var losses: int = 0
var grafts: int = 0
var kills: int = 0
var elapsed: float = 0.0
var breaches: int = 0
var failure: String = ""
## Soft-lock guard: after the last wave, an economy goal that can no longer progress fails cleanly.
const STALL_SECONDS := 60.0
var _stall_sig: String = ""
var _stall_t: float = 0.0
var cleared_hint_shown: bool = false

func setup(owner_battle: Battle) -> void:
	battle = owner_battle

func planting_error(cell: Vector2i) -> String:
	if battle.level.mode == &"artillery" or battle.level.mode == &"holdout":
		return "OBJ_NO_PLANTING"
	if battle.level.is_blocked(cell.y, cell.x):
		return "OBJ_TILE_BLOCKED"
	for rule: Dictionary in battle.level.objectives:
		if rule["type"] == "plant_limit" and planted >= int(rule["target"]):
			return TranslationServer.translate("OBJ_PLANT_LIMIT_REACHED").format({"n": planted, "max": int(rule["target"])})
	return ""

func tick(delta: float) -> void:
	elapsed += delta
	_check_stall(delta)
	for rule: Dictionary in battle.level.objectives:
		var kind: String = rule["type"]
		var target := int(rule["target"])
		if kind == "loss_limit" and losses > target:
			failure = TranslationServer.translate("FAIL_LOSSES").format({"n": losses, "max": target})
		elif kind == "no_breach" and breaches > target:
			failure = TranslationServer.translate("FAIL_BREACH")
		elif kind == "time_limit" and elapsed > target:
			failure = TranslationServer.translate("FAIL_TIME")

func _check_stall(delta: float) -> void:
	if battle.director == null or not battle.director.finished or battle.alive_zombie_count() > 0 or _goals_met():
		_stall_t = 0.0
		return
	if not cleared_hint_shown:
		cleared_hint_shown = true
		battle.hud.toast(TranslationServer.translate("OBJ_WAVES_CLEARED").format({"s": summary()}))
	var tokens := 0
	for child: Node in battle.sun_layer.get_children():
		if child is SunToken and not (child as SunToken).collected: tokens += 1
	var sig := "%d|%d|%d|%d" % [collected, battle.sun, grafts, tokens]
	if sig != _stall_sig or (_needs_graft() and battle.sun >= 100):
		_stall_sig = sig
		_stall_t = 0.0
		return
	_stall_t += delta
	if _stall_t > STALL_SECONDS:
		failure = TranslationServer.translate("FAIL_STALL")

func _needs_graft() -> bool:
	for rule: Dictionary in battle.level.objectives:
		if rule["type"] == "graft_count" and grafts < int(rule["target"]): return true
	return false

func fulfilled() -> bool:
	if failure != "":
		return false
	return _goals_met()

func _goals_met() -> bool:
	for rule: Dictionary in battle.level.objectives:
		var target := int(rule["target"])
		match str(rule["type"]):
			"collect_sun":
				if collected < target: return false
			"bank_sun":
				if battle.sun < target: return false
			"graft_count":
				if grafts < target: return false
	return true

func summary() -> String:
	var parts: PackedStringArray = []
	for rule: Dictionary in battle.level.objectives:
		var n := int(rule["target"])
		match str(rule["type"]):
			"collect_sun": parts.append(_fmt("OBJ_COLLECT_SUN", collected, n))
			"bank_sun": parts.append(_fmt("OBJ_BANK_SUN", battle.sun, n))
			"loss_limit": parts.append(_fmt("OBJ_LOSSES", losses, n))
			"plant_limit": parts.append(_fmt("OBJ_PLANT_ACTIONS", planted, n))
			"graft_count": parts.append(_fmt("OBJ_GRAFTS", grafts, n))
			"no_breach": parts.append(_fmt("OBJ_BREACHES", breaches, n))
			"time_limit": parts.append(_fmt("OBJ_TIME", int(elapsed), n))
	if parts.is_empty():
		return TranslationServer.translate("OBJ_DEFAULT")
	return " · ".join(parts)

static func _fmt(key: String, n: int, target: int) -> String:
	return TranslationServer.translate(key).format({"n": n, "max": target})

## Short, translated list of a level's objectives for the map screen (before play).
static func describe(objectives: Array) -> String:
	var text: PackedStringArray = []
	for objective: Dictionary in objectives:
		var kind := str(objective["type"])
		var key := "OBJTYPE_" + kind.to_upper()
		var line := TranslationServer.translate(key)
		if line == key:
			line = kind.replace("_", " ") + ": {n}"
		text.append(line.format({"n": int(objective["target"])}))
	if text.is_empty():
		return TranslationServer.translate("OBJ_CLEAR_ALL_WAVES")
	return ", ".join(text)
