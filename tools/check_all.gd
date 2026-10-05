extends Node
## Compiles every script, then runs the art gates: repo_budget.py, validate_assets.py and
## the in-engine art wiring test. Exit code 1 if anything fails.

const PY_CHECKS: Array[String] = ["tools/art/review/repo_budget.py", "tools/art/review/validate_assets.py"]


func _ready() -> void:
	var bad := _compile_all()
	for script in PY_CHECKS:
		bad += _run_python(script)
	bad += _run_scene("res://tools/tests/art_wiring_test.tscn")
	print("check_all: total failures ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _compile_all() -> int:
	var stack: Array[String] = ["res://"]
	var n := 0
	var bad := 0
	while stack.size() > 0:
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s: Resource = load(d.path_join(f))
				n += 1
				if s == null:
					print("FAIL ", d.path_join(f))
					bad += 1
		for sd in da.get_directories():
			if not sd.begins_with("."):
				stack.append(d.path_join(sd))
	print("checked ", n, " failures ", bad)
	return bad


func _run_python(script: String) -> int:
	var out: Array = []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://" + script)], out, true)
	for line: String in out:
		print(line.strip_edges())
	if code != 0:
		print("FAIL ", script, " (exit ", code, ")")
		return 1
	return 0


## Runs a test scene in a child Godot process so its quit() code is reported here.
func _run_scene(scene: String) -> int:
	var out: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), scene])
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	for line: String in out:
		for l in line.split("\n"):
			if l.begins_with("FAIL") or l.contains("failure"):
				print(l)
	if code != 0:
		print("FAIL ", scene, " (exit ", code, ")")
		return 1
	return 0
