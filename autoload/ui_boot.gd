extends Node
## Installs the painted UI theme at startup, built from the kit by UITheme.build() (never baked).
## It is merged into the engine default theme rather than set on root.theme: Window themes only
## propagate through Control parents, and screens live under plain Nodes, so root.theme left
## most buttons on Godot's grey defaults.

func _enter_tree() -> void:
	install()

static func install() -> void:
	ThemeDB.get_default_theme().merge_with(UITheme.build())
