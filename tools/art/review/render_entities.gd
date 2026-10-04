extends Node
## Renders a line-up of real plant/zombie rigs at battle scale onto a
## transparent PNG. Used by the style bible and lawn readability checks, so
## art is judged against the actual characters (which are read-only).
## xvfb-run godot --path . res://tools/art/review/render_entities.tscn -- <out.png>

const PLANTS: Array[StringName] = [&"sunbud", &"pod_shooter", &"frost_mint", &"bark_wall", &"twin_pod", &"clod_catapult", &"lantern_bloom", &"thorn_carpet"]
const ZOMBIES: Array[StringName] = [&"shambler", &"cone_head", &"bucket_head", &"brute"]
const STEP := 130.0
const SIZE := Vector2i(1820, 300)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/entities.png"
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var x := STEP * 0.5
	for id: StringName in PLANTS:
		var d := DB.plant(id)
		if d == null:
			continue
		var p := d.behavior.new() as Plant
		p.setup_preview(d)
		p.position = Vector2(x, SIZE.y - 40.0)
		vp.add_child(p)
		x += STEP
	x += STEP * 0.3
	for id: StringName in ZOMBIES:
		var zd := DB.zombie(id)
		if zd == null:
			continue
		var z := zd.behavior.new() as Zombie
		z.setup_preview(zd)
		z.position = Vector2(x, SIZE.y - 30.0)
		vp.add_child(z)
		x += STEP * 1.05
	for i: int in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out)
	print("ENTITIES ", out)
	get_tree().quit()
