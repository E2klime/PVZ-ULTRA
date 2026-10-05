class_name ScreenArt
extends Resource
## Data-driven background for one UI screen (assets/art/screens/<id>.tres, written by
## tools/art/ui/build_screens.py). Every menu/hub/map/loading/almanac/shop background goes
## through ScreenArt.for_screen(); there is no other code path that picks screen art.

const DIR := "res://assets/art/screens/"

@export var texture: Texture2D
## 0..1 darkening drawn over the art so UI stays readable.
@export var dim: float = 0.0
@export var tint: Color = Color.WHITE

## Screen ids: menu, loading, help, stats, settings, hub, workshop, almanac, quests, shop,
## map_<world> for each of the 8 worlds. Missing art logs a loud error and returns null.
static func for_screen(id: StringName) -> ScreenArt:
	var path := DIR + String(id) + ".tres"
	var art: ScreenArt = load(path) as ScreenArt if ResourceLoader.exists(path) else null
	if art == null or art.texture == null:
		push_error("ScreenArt: MISSING background for screen '%s' (%s) - run tools/art/build_all.py --only ui" % [id, path])
		return null
	return art
