extends Node
## First-hour playtest: a scripted player starts a fresh game, stands on the best pad it can afford and presses
## it at the walker's press rate, opens the zone gate, walks into Larkmoor and keeps playing toward the Ember gate.
## It saves a PNG at each milestone and prints one state line per milestone, so a person can read the pacing
## and the screens. Sim time is stepped by hand (GameState is paused), so an hour of play takes minutes of wall time.
## Run (windowed, under Xvfb on a machine without a display):
##   xvfb-run -a godot --path . --resolution 1280x720 res://tools/first_hour_playtest.tscn

const OUT_DIR: String = "res://shots/first_hour"
const STEPS_PER_SECOND: int = 10         ## fixed ticks per simulated second (matches GameState's tick_rate)
const MAX_SIM_SECONDS: float = 14400.0   ## stop after 4 sim hours if nothing else ends the run
const SHOT_MARKS: Array[float] = [60.0, 240.0, 400.0, 600.0]   ## sim seconds at which to save a screenshot
const LARK_MARKS: Array[float] = [30.0, 900.0, 1800.0, 3600.0, 7200.0]          ## seconds after Larkmoor opens

var main: Control
var root: Window
var gs: Node
var sim: Sim
var _onb: Onboarding
var _start_zone: StringName = &""
var _entered_at: float = -1.0
var _seen: Dictionary = {}
var _walking_to_gate: bool = false
var _last_zone: StringName = &""
var _tick_dt: float = 0.1
const TIPS: Array[StringName] = [&"welcome", &"first_press", &"walk", &"streak", &"critter", &"clover_row", &"relic", &"gate_open", &"rebirth_button", &"zone_reset", &"upgrades"]


func _ready() -> void:
	root = get_tree().root
	gs = get_node("/root/GameState")
	gs.paused = true   # this driver steps the sim itself
	sim = gs.sim
	_onb = gs.onboarding
	_tick_dt = 1.0 / float(sim.config.tick_rate)
	_start_zone = sim.zone_id
	_last_zone = sim.zone_id
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(90)
	await _shot("01_fresh_start")
	await _play()
	print("[playtest] done sim=%.0fs zone=%s presses=%d" % [sim.play_seconds, sim.zone_id, sim.press_count])
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(2)
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, shot_name]))
	print("[playtest] shot %s t=%.0fs zone=%s" % [shot_name, sim.play_seconds, sim.zone_id])


func _log(event: String) -> void:
	print("[playtest] %s t=%.0fs zone=%s presses=%d tips=[%s] stats={%s}" % [
		event, sim.play_seconds, sim.zone_id, sim.press_count, _tips_line(), _stats_line()])


## The tips the player has been shown so far (Onboarding remembers each one once per save).
func _tips_line() -> String:
	var parts: PackedStringArray = []
	for tip: StringName in TIPS:
		if _onb.is_seen(tip):
			parts.append(String(tip))
	return ", ".join(parts)


func _stats_line() -> String:
	var ids: Array = sim.stats.keys()
	ids.sort()
	var parts: PackedStringArray = []
	for id: Variant in ids:
		var v: BigNum = sim.stats[id] as BigNum
		if not v.is_zero():
			parts.append("%s=%s" % [id, v.format()])
	return ", ".join(parts)


## One simulated second: the sim runs its ticks and the onboarding clock runs as GameState would run it.
func _advance_second() -> void:
	for i in STEPS_PER_SECOND:
		sim.step(_tick_dt)
	_onb.update()


## The pad a sensible player would press next: the sim's own best-affordable pick (highest tier, then row),
## the same rule the Dew Sprites use. &"" when nothing is affordable.
func _best_affordable() -> StringName:
	return sim.auto_pick(true)


## The walker stands on a pad and presses it at the walker's press rate for one simulated second.
func _stand_and_press(id: StringName) -> void:
	var pad: Node2D = main.pads.get(id) as Node2D
	main.walker.position = pad.position + Vector2(0, 6)
	var presses: int = maxi(1, roundi(1.0 / sim.press_interval()))
	for i in presses:
		if sim.can_afford(id):
			pad.call("_press")


func _walk_to_gate() -> void:
	main.walker.position = main.gate.position + Vector2(0, 4)


func _once(key: String) -> bool:
	if _seen.has(key):
		return false
	_seen[key] = true
	return true


func _play() -> void:
	var first: StringName = _best_affordable()
	if first != &"":
		_stand_and_press(first)
	_log("first_press")
	await _shot("02_first_press")

	var shots_taken: Array[float] = []
	while sim.play_seconds < MAX_SIM_SECONDS:
		_advance_second()
		if _walking_to_gate:
			_walk_to_gate()
		else:
			var id: StringName = _best_affordable()
			if id != &"":
				_stand_and_press(id)
		await get_tree().process_frame
		var t: float = sim.play_seconds
		for mark: float in SHOT_MARKS:
			if t >= mark and not shots_taken.has(mark):
				shots_taken.append(mark)
				_log("mark_%d" % int(mark))
				await _shot("03_t%03d" % int(mark))
		var here: ZoneDef = sim.current_zone()
		if here != null and here.id != _last_zone:
			_last_zone = here.id
			_walking_to_gate = false
			_log("zone_entered_%s" % String(here.id))
			await _frames(60)
			await _shot("05_zone_%s" % String(here.id))
			if _entered_at < 0.0 and here.id != _start_zone:
				_entered_at = t
		if here != null and not _walking_to_gate and here.next_zone != &"" and sim.is_gate_open(here.id) and _once("gate_open_%s" % String(here.id)):
			_log("gate_open_%s" % String(here.id))
			await _shot("04_gate_open_%s" % String(here.id))
			_walking_to_gate = true
		if _entered_at >= 0.0:
			var since: float = t - _entered_at
			for mark: float in LARK_MARKS:
				var key: String = "lark_%d" % int(mark)
				if since >= mark and _once(key):
					_log(key)
					await _shot("06_%s" % key)
			if since >= LARK_MARKS[LARK_MARKS.size() - 1]:
				return
