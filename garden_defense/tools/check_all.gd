extends Node
func _ready() -> void:
	var stack := ["res://"]
	var n := 0
	var bad := 0
	while stack.size() > 0:
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d.path_join(f))
				n += 1
				if s == null:
					print("FAIL ", d.path_join(f))
					bad += 1
		for sd in da.get_directories():
			if not sd.begins_with("."): stack.append(d.path_join(sd))
	print("checked ", n, " failures ", bad)
	get_tree().quit(1 if bad > 0 else 0)
