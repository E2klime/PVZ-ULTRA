extends SceneTree
## Smoke test for localization: every locale resolves UI keys and authored content.
## Run: godot --headless --path . -s res://tools/tests/loc_test.gd
func _init() -> void:
	await process_frame
	var db: Node = root.get_node("DB")
	var fails := 0
	for loc: String in ["ru", "zh_CN", "ja", "de"]:
		TranslationServer.set_locale(loc)
		var untranslated := 0
		var total := 0
		for id: StringName in db.levels:
			var lv: LevelData = db.levels[id]
			for s: String in [lv.name_key, lv.desc_key, lv.hint_key]:
				total += 1
				var t := Loc.text(s) if s != lv.name_key else Loc.title(s)
				if t == s:
					untranslated += 1
		var ui_same := 0
		for k: String in ["UI_PLAY", "HUB_HEADER", "OBJ_DEFAULT", "HELP_TWINS_B", "PLANT_TWIN_POD_NAME"]:
			if TranslationServer.translate(k) == k: ui_same += 1
		print("LOC %s: content untranslated %d/%d, ui missing %d, sample: %s | %s" % [loc, untranslated, total, ui_same, Loc.title(db.levels[&"desert_14"].name_key), Loc.text(db.levels[&"desert_14"].desc_key).left(90)])
		if untranslated > 0 or ui_same > 0: fails += 1
	print("LOC RESULT: %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(1 if fails else 0)
