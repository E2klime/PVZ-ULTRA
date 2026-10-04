class_name WaveDirector
extends Node
## Pressure-based wave director.
## Alternates readable build windows with short assaults, limits elite spikes,
## balances lanes, and gently accelerates instead of only multiplying counts.

signal wave_started(index: int, total: int, is_flag: bool)
signal wave_warning(index: int, total: int, is_flag: bool, seconds: float)
signal all_spawned

const FLAG_MULT := 1.55
const WARNING_SECONDS := 4.0
const MIN_GAP := 14.0
const MAX_ELITE_SHARE := 0.42
const CLEAR_BREATHER := 12.0

var battle: Battle
var level: LevelData
var diff: DifficultyData
var wave: int = 0
var active: bool = false
var finished: bool = false
var _timer: float = 0.0
var _queue: Array[Dictionary] = []
var _clock: float = 0.0
var _recent_rows: Array[int] = []
var _warned_for_wave: int = -1
## Crowd extensions are bounded per wave so time-limit missions cannot stall forever.
const MAX_CROWD_HOLD := 15.0
var _crowd_hold: float = 0.0

func setup(b: Battle, l: LevelData, d: DifficultyData) -> void:
	battle = b
	level = l
	diff = d
	_timer = l.first_wave_delay

func start() -> void:
	active = true

func total_waves() -> int:
	return level.waves

func is_flag_wave(n: int) -> bool:
	if not level.wave_specs.is_empty() and n >= 1 and n <= level.wave_specs.size():
		return bool(level.wave_specs[n - 1].get("flag", false))
	return n == level.waves or (level.flag_every > 0 and n % level.flag_every == 0)

func seconds_to_next_wave() -> float:
	return maxf(0.0, _timer)

func progress() -> float:
	var base := float(wave) / float(maxi(1, level.waves))
	if wave < level.waves and active:
		var gap := _gap_for(wave + 1)
		base += (1.0 - clampf(_timer / gap, 0.0, 1.0)) / float(maxi(1, level.waves))
	return clampf(base, 0.0, 1.0)

func _gap_for(next_wave: int) -> float:
	var p := float(maxi(0, next_wave - 1)) / float(maxi(1, level.waves - 1))
	var accelerated := level.wave_interval * lerpf(1.1, 0.85, p)
	return maxf(MIN_GAP, accelerated * diff.spawn_interval_mult)

func _physics_process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	while not _queue.is_empty() and float(_queue[0]["t"]) <= _clock:
		var e: Dictionary = _queue.pop_front()
		battle.spawn_zombie(e["id"], e["row"])
	if wave >= level.waves:
		if _queue.is_empty() and not finished:
			finished = true
			all_spawned.emit()
		return
	_timer -= delta
	var next_wave := wave + 1
	if _timer <= WARNING_SECONDS and _warned_for_wave != next_wave:
		_warned_for_wave = next_wave
		wave_warning.emit(next_wave, level.waves, is_flag_wave(next_wave), maxf(0.0, _timer))
	# Clearing the lawn shortens the wait a little, but never below a breather.
	if wave > 0 and _queue.is_empty() and battle.alive_zombie_count() == 0 and _timer > CLEAR_BREATHER:
		_timer = CLEAR_BREATHER
	# A crowded lawn earns a bounded extension, preventing unfair overlap
	# without allowing the player to stall forever.
	if _timer <= 0.0 and battle.alive_zombie_count() > _crowd_limit() and _crowd_hold < MAX_CROWD_HOLD:
		_crowd_hold += 1.0
		_timer = 1.0
		return
	if _timer <= 0.0:
		_start_wave()

func skip_to_next_wave() -> void:
	_timer = 0.0

func _crowd_limit() -> int:
	return 6 + int(round(diff.zombie_count_mult * 2.0))

func _start_wave() -> void:
	wave += 1
	_crowd_hold = 0.0
	if not level.wave_specs.is_empty():
		_start_authored_wave()
		return
	var flag := is_flag_wave(wave)
	_timer = _gap_for(wave + 1)
	var p := float(wave - 1) / float(maxi(1, level.waves - 1))
	var budget := (level.threat_base + (wave - 1) * level.threat_growth) * diff.zombie_count_mult
	budget *= lerpf(0.94, 1.12, p)
	budget *= 1.08 if wave % 3 == 0 else 1.0
	if flag:
		budget *= FLAG_MULT
	var ids := _compose(budget, wave)
	if flag:
		ids.push_front(&"flagbearer")
	_schedule(ids, flag)
	wave_started.emit(wave, level.waves, flag)

func _schedule(ids: Array[StringName], flag: bool) -> void:
	if ids.is_empty():
		return
	var duration := clampf(4.0 + ids.size() * 0.8, 6.0, 20.0)
	if flag:
		duration += 3.0
	var groups := maxi(1, ceili(ids.size() / 3.0))
	for i: int in ids.size():
		var group := i % groups
		var slot := float(group) / float(maxi(1, groups - 1))
		var jitter := 0.0 if i == 0 else randf_range(-0.28, 0.38)
		var t := _clock + maxf(0.0, slot * duration + jitter)
		_queue.append({"t": t, "id": ids[i], "row": _pick_row()})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))

func _compose(budget: float, n: int) -> Array[StringName]:
	var pool: Array[ZombieData] = []
	for id: StringName in level.zombie_pool:
		var z := DB.zombie(id)
		if z:
			pool.append(z)
	if pool.is_empty():
		return []
	var out: Array[StringName] = []
	var spent := 0.0
	var elite_spent := 0.0
	var guard := 0
	var basic := _cheapest(pool)
	if basic:
		out.append(basic.id)
		spent += basic.threat_cost
	while spent < budget and guard < 200:
		guard += 1
		var options: Array[ZombieData] = []
		var total_weight := 0.0
		for z: ZombieData in pool:
			var next_spent := spent + z.threat_cost
			var elite := z.threat_cost >= 3.0
			var next_elite := elite_spent + (z.threat_cost if elite else 0.0)
			if next_spent > budget + basic.threat_cost * 0.45:
				continue
			if elite and next_elite / maxf(1.0, next_spent) > MAX_ELITE_SHARE and n < level.waves:
				continue
			var unlock_wave := 2 + int(floor(z.threat_cost * 0.8))
			if n < unlock_wave and n < level.waves:
				continue
			options.append(z)
			var novelty := 1.15 if out.is_empty() or out.back() != z.id else 0.65
			total_weight += z.weight * novelty
		if options.is_empty():
			break
		var roll := randf() * total_weight
		var pick := options[0]
		for z: ZombieData in options:
			var novelty := 1.15 if out.is_empty() or out.back() != z.id else 0.65
			roll -= z.weight * novelty
			if roll <= 0.0:
				pick = z
				break
		out.append(pick.id)
		spent += pick.threat_cost
		if pick.threat_cost >= 3.0:
			elite_spent += pick.threat_cost
	return out

func _cheapest(pool: Array[ZombieData]) -> ZombieData:
	var best: ZombieData
	for z: ZombieData in pool:
		if best == null or z.threat_cost < best.threat_cost:
			best = z
	return best

func _pick_row() -> int:
	var counts: Array[int] = []
	var minimum := 999
	for r: int in Board.ROWS:
		var count := battle.zombies_in_row(r).size()
		counts.append(count)
		minimum = mini(minimum, count)
	var candidates: Array[int] = []
	for r: int in Board.ROWS:
		if counts[r] <= minimum + 1 and not r in _recent_rows:
			candidates.append(r)
	if candidates.is_empty():
		for r: int in Board.ROWS:
			if counts[r] <= minimum + 1:
				candidates.append(r)
	var row: int = candidates.pick_random()
	_recent_rows.append(row)
	if _recent_rows.size() > 2:
		_recent_rows.pop_front()
	return row

func _start_authored_wave() -> void:
	var spec: Dictionary = level.wave_specs[wave - 1]
	var flag: bool = spec.get("flag", false)
	_timer = _gap_for(wave + 1)
	for spawn: Dictionary in spec["spawns"]:
		_queue.append({"t": _clock + float(spawn["delay"]), "id": StringName(spawn["id"]), "row": int(spawn["row"])})
	# Reinforce with basics only; never duplicate a boss through a difficulty roll.
	var extras := int(floor((diff.zombie_count_mult - 1.0) * (spec["spawns"] as Array).size()))
	for i: int in extras:
		_queue.append({"t": _clock + 5.0 + i * 2.5, "id": &"shambler", "row": (wave + i) % Board.ROWS})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	wave_started.emit(wave, level.waves, flag)
