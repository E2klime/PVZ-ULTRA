extends Node
## Sfx autoload: music + pooled sound effects on "Music"/"SFX" buses.
## Sounds are procedural placeholders (tools/audio/gen_audio.py).

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const POOL := 12

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last: Dictionary = {}       # id -> msec, throttles spammy sounds
var _music: AudioStreamPlayer
var _music_id: StringName = &""
## Headless runs (tests, bots) use the dummy audio driver, which never mixes queued
## playbacks out: they were reported as leaks at exit. Nothing is audible there anyway.
var _silent: bool = DisplayServer.get_name() == "headless"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	Settings.apply()

## Stop and release every stream on quit: players still mixing at exit were
## reported as leaked AudioStreamPlayback instances and "resources still in use".
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	if _music:
		_music.stop()
		_music.stream = null
	_cache.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and bool(Settings.get_value(&"mute_unfocused")) and not OS.has_feature("mobile"):
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Settings.apply()

func _stream(dir: String, id: StringName) -> AudioStream:
	var key := dir + String(id)
	if _cache.has(key):
		return _cache[key]
	var path := dir + String(id) + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = s
	return s

## Plays a one-shot sound. `min_gap_ms` avoids stacking the same sound many times per frame.
func play(id: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06, min_gap_ms: int = 45) -> void:
	if _silent:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < min_gap_ms:
		return
	_last[id] = now
	var s := _stream(SFX_DIR, id)
	if s == null:
		return
	var best: AudioStreamPlayer = null
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _players[randi() % _players.size()]
	best.stream = s
	best.volume_db = volume_db
	best.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	best.play()

func play_music(id: StringName) -> void:
	if _silent:
		_music_id = id
		return
	if id == _music_id and _music.playing:
		return
	_music_id = id
	var s := _stream(MUSIC_DIR, id) as AudioStreamWAV
	if s == null:
		_music.stop()
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	# loop_end is in frames, not bytes.
	var bytes_per_frame := (2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if s.stereo else 1)
	s.loop_end = s.data.size() / bytes_per_frame
	_music.stream = s
	_music.volume_db = -4.0
	_music.play()

func stop_music() -> void:
	_music_id = &""
	_music.stop()
