extends SceneTree
## Builds the shared AnimationLibrary resources used by every plant and zombie.
## Run:  godot --headless --path . -s res://tools/build_anims.gd
##
## Characters are drawn procedurally, so clips animate *pose properties* on the
## entity root (pose_squash, pose_lean, ...) instead of Sprite2D bones. The node
## names / property names are shared by all plants (and by all humanoid zombies),
## so a single library drives the whole cast (GDD 7.2 "rig templates").
## Method-call tracks fire gameplay events on the right frame (GDD 7.4):
##   plants:  _on_action_frame(), _on_die_finished()
##   zombies: _on_footstep(), _on_bite_frame(), _on_die_finished()
## Keys are authored on a 1/30 s grid (GDD 7.3).

const SNAP := 1.0 / 30.0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://anim")
	_save(_plant_library(), "res://anim/plant_anims.tres")
	_save(_zombie_library(), "res://anim/zombie_anims.tres")
	print("Animation libraries built.")
	quit()

func _save(lib: AnimationLibrary, path: String) -> void:
	var err := ResourceSaver.save(lib, path)
	if err != OK:
		push_error("Failed to save %s: %d" % [path, err])
	else:
		print("saved ", path, " clips=", lib.get_animation_list())

# --- helpers -----------------------------------------------------------------
## tracks: { "pose_x": [[t, v], [t, v, transition]], ... }; events: [[t, "method"], ...]
func _clip(length: float, loop: bool, tracks: Dictionary, events: Array = []) -> Animation:
	var a := Animation.new()
	a.length = length
	a.step = SNAP
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for prop: String in tracks.keys():
		var ti := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(ti, NodePath(".:" + prop))
		# pose_cycle is a 0..1 ramp (leg phase): linear, no wrap-around blending.
		var ramp := prop == "pose_cycle"
		a.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR if ramp else Animation.INTERPOLATION_CUBIC)
		a.value_track_set_update_mode(ti, Animation.UPDATE_CONTINUOUS)
		a.track_set_interpolation_loop_wrap(ti, loop and not ramp)
		for k: Array in tracks[prop]:
			var t: float = snappedf(float(k[0]), SNAP)
			var trans: float = float(k[2]) if k.size() > 2 else 1.0
			a.track_insert_key(ti, t, float(k[1]), trans)
	if not events.is_empty():
		var mi := a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(mi, NodePath("."))
		for e: Array in events:
			a.track_insert_key(mi, snappedf(float(e[0]), SNAP), {"method": StringName(e[1]), "args": []})
	return a

## Sine-like loop sampled into n keys.
func _wave(length: float, amp: float, n: int = 8, phase: float = 0.0, offset: float = 0.0, harmonic: float = 1.0) -> Array:
	var keys: Array = []
	for i: int in n + 1:
		var t := length * float(i) / float(n)
		keys.append([t, offset + amp * sin(TAU * harmonic * float(i) / float(n) + phase)])
	return keys

# --- plants ------------------------------------------------------------------
func _plant_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	# Idles: stem plants sway from the feet, ground plants breathe, walls barely move,
	# floaters bob. Two harmonics keep the loop from looking mechanical.
	lib.add_animation(&"idle_stem", _clip(2.4, true, {
		"pose_lean": _wave(2.4, 0.06, 12),
		"pose_squash": _wave(2.4, 0.03, 12, 0.0, 0.0, 2.0),
		"pose_bob": _wave(2.4, 1.5, 12, PI * 0.5, 1.5, 2.0),
	}))
	lib.add_animation(&"idle_ground", _clip(1.8, true, {
		"pose_squash": _wave(1.8, 0.05, 8),
		"pose_lean": _wave(1.8, 0.015, 8, 1.0),
	}))
	lib.add_animation(&"idle_wall", _clip(3.2, true, {
		"pose_squash": _wave(3.2, 0.018, 8),
		"pose_lean": _wave(3.2, 0.012, 8, 2.0),
	}))
	lib.add_animation(&"idle_float", _clip(2.0, true, {
		"pose_bob": _wave(2.0, 6.0, 8, 0.0, 6.0),
		"pose_lean": _wave(2.0, 0.05, 8, 1.2),
		"pose_squash": _wave(2.0, 0.025, 8, PI, 0.0, 2.0),
	}))
	lib.add_animation(&"idle_legend", _clip(3.0, true, {
		"pose_lean": _wave(3.0, 0.045, 12),
		"pose_squash": _wave(3.0, 0.035, 12, 0.0, 0.0, 2.0),
		"pose_bob": _wave(3.0, 3.0, 12, PI * 0.5, 3.0),
		"pose_glow": _wave(3.0, 0.35, 12, 0.0, 0.55),
	}))
	# Action: anticipation squash -> stretch on the event frame -> settle.
	lib.add_animation(&"action", _clip(0.4, false, {
		"pose_squash": [[0.0, 0.0], [0.1, -0.13], [0.167, 0.15], [0.267, -0.04], [0.4, 0.0]],
		"pose_kick": [[0.0, 0.0], [0.1, -5.0], [0.167, 12.0], [0.4, 0.0]],
		"pose_lean": [[0.0, 0.0], [0.1, -0.06], [0.167, 0.05], [0.4, 0.0]],
	}, [[0.133, "_on_action_frame"]]))
	lib.add_animation(&"action_heavy", _clip(0.7, false, {
		"pose_squash": [[0.0, 0.0], [0.2, -0.2], [0.3, 0.24], [0.467, -0.06], [0.7, 0.0]],
		"pose_kick": [[0.0, 0.0], [0.2, -9.0], [0.3, 16.0], [0.7, 0.0]],
		"pose_lean": [[0.0, 0.0], [0.2, -0.1], [0.3, 0.08], [0.7, 0.0]],
		"pose_glow": [[0.0, 0.0], [0.3, 1.0], [0.7, 0.0]],
	}, [[0.267, "_on_action_frame"]]))
	lib.add_animation(&"produce", _clip(0.6, false, {
		"pose_squash": [[0.0, 0.0], [0.133, -0.1], [0.233, 0.16], [0.4, -0.03], [0.6, 0.0]],
		"pose_glow": [[0.0, 0.0], [0.233, 1.0], [0.6, 0.0]],
		"pose_bob": [[0.0, 0.0], [0.233, 6.0], [0.6, 0.0]],
	}, [[0.233, "_on_action_frame"]]))
	lib.add_animation(&"spawn", _clip(0.47, false, {
		"pose_grow": [[0.0, 0.15], [0.233, 1.14], [0.333, 0.94], [0.467, 1.0]],
		"pose_squash": [[0.0, -0.3], [0.233, 0.12], [0.333, -0.05], [0.467, 0.0]],
	}))
	lib.add_animation(&"chew", _clip(0.5, true, {
		"pose_squash": _wave(0.5, 0.07, 6),
		"pose_lean": _wave(0.5, 0.03, 6, 1.0),
	}))
	# Wilt: lean over, sag, fade. Event frees the node.
	lib.add_animation(&"die", _clip(0.5, false, {
		"pose_lean": [[0.0, 0.0], [0.5, 0.45]],
		"pose_squash": [[0.0, 0.0], [0.1, 0.08], [0.5, -0.55]],
		"pose_alpha": [[0.0, 1.0], [0.2, 1.0], [0.5, 0.0]],
	}, [[0.5, "_on_die_finished"]]))
	return lib

# --- zombies -----------------------------------------------------------------
func _zombie_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	# One clip = one full leg cycle (two steps). Speed scale is set from the
	# zombie's real ground speed so feet never slide. pose_cycle drives the legs.
	lib.add_animation(&"walk", _clip(1.0, true, {
		"pose_cycle": [[0.0, 0.0, 1.0], [1.0, 1.0, 1.0]],
		"pose_bob": [[0.0, 0.0], [0.25, 6.0], [0.5, 0.0], [0.75, 6.0], [1.0, 0.0]],
		"pose_lean": _wave(1.0, 0.035, 8, 0.0, -0.05),
		"pose_head": _wave(1.0, 0.09, 8, 0.6),
		"pose_arm": _wave(1.0, 0.18, 8, 1.4),
		"pose_squash": [[0.0, -0.035], [0.25, 0.03], [0.5, -0.035], [0.75, 0.03], [1.0, -0.035]],
	}, [[0.0, "_on_footstep"], [0.5, "_on_footstep"]]))
	# One clip = one bite. Lunge forward, jaw snaps on the bite frame.
	lib.add_animation(&"eat", _clip(1.0, true, {
		"pose_lean": [[0.0, -0.02], [0.4, -0.2], [0.5, -0.24], [0.7, -0.06], [1.0, -0.02]],
		"pose_jaw": [[0.0, 0.2], [0.35, 1.0], [0.5, 0.0], [0.7, 0.6], [1.0, 0.2]],
		"pose_head": [[0.0, 0.0], [0.45, 0.16], [0.6, -0.06], [1.0, 0.0]],
		"pose_arm": [[0.0, 0.0], [0.45, -0.35], [1.0, 0.0]],
		"pose_bob": [[0.0, 0.0], [0.5, -3.0], [1.0, 0.0]],
	}, [[0.5, "_on_bite_frame"]]))
	lib.add_animation(&"idle", _clip(2.0, true, {
		"pose_lean": _wave(2.0, 0.04, 8),
		"pose_head": _wave(2.0, 0.12, 8, 1.0),
		"pose_arm": _wave(2.0, 0.12, 8, 2.0),
		"pose_jaw": _wave(2.0, 0.3, 8, 0.0, 0.3, 2.0),
		"pose_bob": _wave(2.0, 2.0, 8, 0.0, 2.0, 2.0),
	}))
	# Climb up out of the street gutter.
	lib.add_animation(&"spawn", _clip(0.6, false, {
		"pose_rise": [[0.0, 1.0], [0.4, -0.08], [0.6, 0.0]],
		"pose_lean": [[0.0, 0.25], [0.4, -0.1], [0.6, -0.05]],
		"pose_head": [[0.0, -0.3], [0.6, 0.0]],
	}))
	# Fall backwards, head pops off, body sinks and fades.
	lib.add_animation(&"die", _clip(1.3, false, {
		"pose_head_off": [[0.0, 0.0], [0.1, 0.0], [0.6, 1.0]],
		"pose_fall": [[0.0, 0.0], [0.2, -0.12], [0.67, 1.0], [0.77, 0.92], [0.87, 1.0]],
		"pose_squash": [[0.0, 0.0], [0.67, 0.0], [0.77, -0.12], [0.9, 0.0]],
		"pose_arm": [[0.0, 0.0], [0.3, -0.8], [0.67, 0.6]],
		"pose_jaw": [[0.0, 0.0], [0.3, 1.0]],
		"pose_alpha": [[0.0, 1.0], [0.97, 1.0], [1.3, 0.0]],
	}, [[0.67, "_on_footstep"], [1.3, "_on_die_finished"]]))
	return lib
