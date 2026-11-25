extends SceneTree
## Playtest bot for CI. Plays the first in-game hour of a fresh save in the real main scene and records what a new
## player would run into: whether currency keeps growing, which milestones were reached, and every frame over budget.
## It only measures. tools/check_playtest.py turns the JSON it writes into pass or fail.
##
## Each simulated second the bot: presses pads at the active press rate (content/config/sim_profiles.tres), highest
## tier affordable pad first, as tools/sim.gd does; buys every upgrade it can afford; does the first Bloom reset once it
## pays at least BLOOM_MIN_GAIN seeds; and enters the next zone once its gate is open. It opens the Upgrades menu once
## so that build is timed. It does not walk to gates or click, so this checks the game's logic and presentation, not
## the controls.
##
## Time runs fast: each rendered frame advances the sim by SIM_PER_FRAME seconds in the game's own fixed ticks, with
## GameState's real-time tick paused. The player's save is never read or written (Save.enabled = false).
## Run: godot --headless --path . --script tools/playtest.gd [-- --minutes=60]
## Writes res://shots/playtest.json. Exits 1 on a script or shader error, or when the wall-clock limit ends the run.

const SIM_PER_FRAME: float = 1.0          ## sim seconds per rendered frame (10 fixed ticks each)
const WARMUP_FRAMES: int = 60             ## frames before the clock starts: shader warm-up and first build
const DEFAULT_MINUTES: float = 60.0
const DEFAULT_PRESS_RATE: float = 4.0     ## presses per second, used when the profile file cannot be read
const PROFILE_NAME: String = "active"
const PROFILES_PATH: String = "res://content/config/sim_profiles.tres"
const BLOOM_ID: StringName = &"bloom"
const BLOOM_MIN_GAIN: float = 2.0         ## seeds a Bloom must pay before the bot takes it
const STALL_SECONDS: float = 300.0        ## sim seconds with no income and no paid press before a stall is logged
const MENU_AT: float = 300.0              ## sim second the Upgrades menu opens
const MENU_HOLD: float = 30.0             ## seconds it stays open
const COVER_FRAMES: int = 180             ## frames after a zone entry that sit under the wipe (tools/bench.gd uses the same)
const HITCH_LOG_MS: float = 150.0         ## frames slower than this are listed; check_playtest.py sets the verdict
const MAX_HITCHES: int = 60
const LOG_EVERY: float = 600.0            ## sim seconds between progress lines
const WALL_LIMIT_MS: int = 240000         ## a hang must fail the job, not run to the CI timeout
const OUT_PATH: String = "res://shots/playtest.json"


## Sorts the engine log. Script, shader and script-call errors fail the run: a signal handler that cannot take its
## argument is an ERROR, not a SCRIPT ERROR, and it still breaks the feature. Other engine messages (a texture the
## renderer could not read, say) are kept as notes in the JSON and do not fail the run.
class ErrorLog extends Logger:
	var errors: Array[String] = []
	var notes: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		var at: String = "%s:%d %s %s" % [file, line, code, rationale]
		var script_level: bool = error_type == Logger.ERROR_TYPE_SCRIPT or error_type == Logger.ERROR_TYPE_SHADER \
				or file.begins_with("res://") or (code + rationale).contains("Error calling from signal")
		if script_level:
			errors.append(at)
		elif error_type == Logger.ERROR_TYPE_ERROR:
			notes.append(at)


var sim: Sim
var main: Node
var _menus: MenuRouter
var _game_state: Node
var _log: ErrorLog = ErrorLog.new()
var _t: float = 0.0                       ## sim seconds played
var _press_rate: float = DEFAULT_PRESS_RATE
var _press_acc: float = 0.0
var _order: Array[ButtonDef] = []
var _order_zone: StringName = &""
var _attr_ids: Array[StringName] = []
var _attributes_bought: int = 0
var _last_growth: float = 0.0
var _stalled: bool = false
var _next_log: float = LOG_EVERY
var _menu_opened: bool = false
var _menu_closed: bool = false
var _cover_left: int = 0
var _first_bought: Dictionary = {}       ## pad id -> sim minute of its first paid press
var _events: Array[Dictionary] = []
var _stalls: Array[Dictionary] = []
var _hitches: Array[Dictionary] = []
var _normal_ms: PackedFloat32Array = PackedFloat32Array()
var _normal_max: float = 0.0
var _covered_max: float = 0.0
var _covered_frames: int = 0


func _init() -> void:
	await process_frame  # autoloads register after the first frame
	var minutes: float = DEFAULT_MINUTES
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = maxf(1.0, float(a.trim_prefix("--minutes=")))
	OS.add_logger(_log)
	_game_state = root.get_node("GameState")
	_game_state.set("paused", true)   # the bot drives the clock; GameState's real-time tick would add to it
	root.get_node("Save").set("enabled", false)
	var profiles: SimProfiles = load(PROFILES_PATH) as SimProfiles
	if profiles != null:
		var i: int = profiles.profile_names.find(PROFILE_NAME)
		if i >= 0 and i < profiles.presses_per_second.size():
			_press_rate = float(profiles.presses_per_second[i])

	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main  # Juice parents its popup layer to the current scene
	sim = main.get("sim") as Sim
	_menus = main.get("menus") as MenuRouter
	sim.new_game()           # a fresh game, so the first zone really is the meadow
	sim.rng.seed = 1
	for k: StringName in sim.attribute_defs:
		_attr_ids.append(k)
	sim.button_pressed.connect(_on_pressed)
	sim.zone_entered.connect(_on_zone_entered)
	sim.gate_opened.connect(_on_gate_opened)
	sim.tier_opened.connect(_on_tier_opened)
	sim.reset_done.connect(_on_reset_done)

	var start_ms: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	var total: int = roundi(minutes * 60.0 / SIM_PER_FRAME)
	var timed_out: bool = false
	for i: int in WARMUP_FRAMES + total:
		var counted: bool = i >= WARMUP_FRAMES
		if counted:
			_advance(SIM_PER_FRAME)
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		if counted:
			_record_frame(ms)
		if Time.get_ticks_msec() - start_ms > WALL_LIMIT_MS:
			timed_out = true
			break
	_report(timed_out, float(Time.get_ticks_msec() - start_ms) / 1000.0)


## Advances the game by `seconds` of play in fixed ticks, the way GameState does, then runs the bot's decisions.
func _advance(seconds: float) -> void:
	var rate: int = maxi(sim.config.tick_rate, 1)
	var dt: float = 1.0 / float(rate)
	for k: int in roundi(seconds * float(rate)):
		sim.step(dt)
		_t += dt
		_press_acc += dt * _press_rate
		while _press_acc >= 1.0:
			_press_acc -= 1.0
			_press_once()
	_decide()


## One press: the highest tier pad in the zone that is affordable. Checks affordability first so an empty press does not
## emit a denied signal for every pad.
func _press_once() -> void:
	if sim.zone_id != _order_zone:
		_order = _order_for(sim.zone_id)
		_order_zone = sim.zone_id
	for b: ButtonDef in _order:
		if sim.can_afford(b.id) and sim.try_press(b.id):
			if not _first_bought.has(b.id):
				_first_bought[b.id] = snappedf(_t / 60.0, 0.01)
			return


func _order_for(zone: StringName) -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(zone)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		var ta: TierDef = sim.tier_of(a.id)
		var tb: TierDef = sim.tier_of(b.id)
		var oa: int = ta.order if ta != null else 0
		var ob: int = tb.order if tb != null else 0
		return oa > ob if oa != ob else a.row_index > b.row_index)
	return buttons


## Once per simulated second: progress checks, upgrades, the Bloom reset, zone crossing, and the menu.
func _decide() -> void:
	(_game_state.get("onboarding") as Onboarding).update()
	if _passive_income_running():
		_last_growth = _t
	var idle: float = _t - _last_growth
	if idle >= STALL_SECONDS and not _stalled:
		_stalled = true
		_stalls.append({"minute": snappedf(_t / 60.0, 0.01), "zone": String(sim.zone_id), "idle_minutes": snappedf(idle / 60.0, 0.01)})
	elif idle < STALL_SECONDS:
		_stalled = false
	for id: StringName in _attr_ids:
		if sim.buy_attribute(id):
			_attributes_bought += 1
	if sim.can_reset(BLOOM_ID) and sim.reset_gain(BLOOM_ID).gte(BigNum.from_float(BLOOM_MIN_GAIN)):
		sim.try_reset(BLOOM_ID)
	var z: ZoneDef = sim.current_zone()
	if z != null and z.next_zone != &"" and sim.is_gate_open(z.id):
		sim.enter_zone(z.next_zone)
	if not _menu_opened and _t >= MENU_AT and _menus != null:
		_menu_opened = true
		_menus.open(&"upgrades")
	if _menu_opened and not _menu_closed and _t >= MENU_AT + MENU_HOLD:
		_menu_closed = true
		_menus.close_all()
	if _t >= _next_log:
		_next_log += LOG_EVERY
		print("playtest: %.0f min, %s, %s sunlight, income %s/s, %d pads bought, %d upgrades" % [
			_t / 60.0, sim.zone_id, sim.get_stat(sim.config.income_stat).format(),
			sim.income_per_second(sim.config.income_stat).format(), _first_bought.size(), _attributes_bought])


## Any passive stat earning in the current zone: Sunlight in the meadow, the forge stats in Ember Quarry.
func _passive_income_running() -> bool:
	for s: StatDef in sim.stat_defs.values():
		if s.passive and sim.income_per_second(s.id).gt(BigNum.zero()):
			return true
	return false


func _on_pressed(_id: StringName, _pos: Vector3, _gain: BigNum, _crit: bool) -> void:
	_last_growth = _t


func _on_zone_entered(id: StringName) -> void:
	_cover_left = COVER_FRAMES
	_events.append({"minute": snappedf(_t / 60.0, 0.01), "kind": "zone", "id": String(id)})


func _on_gate_opened(id: StringName) -> void:
	_events.append({"minute": snappedf(_t / 60.0, 0.01), "kind": "gate", "id": String(id)})


func _on_tier_opened(id: StringName) -> void:
	_events.append({"minute": snappedf(_t / 60.0, 0.01), "kind": "tier", "id": String(id)})


func _on_reset_done(id: StringName, gained: BigNum) -> void:
	_events.append({"minute": snappedf(_t / 60.0, 0.01), "kind": "reset", "id": String(id), "gained": gained.format()})


## A frame counts as covered while the zone wipe runs (COVER_FRAMES after a zone entry). check_playtest.py holds
## covered frames to a looser budget, so a freeze under the wipe still fails.
func _record_frame(ms: float) -> void:
	if _cover_left > 0:
		_cover_left -= 1
		_covered_frames += 1
		_covered_max = maxf(_covered_max, ms)
		if ms > HITCH_LOG_MS:
			_hitch(ms, true)
		return
	_normal_ms.append(ms)
	_normal_max = maxf(_normal_max, ms)
	if ms > HITCH_LOG_MS:
		_hitch(ms, false)


func _hitch(ms: float, covered: bool) -> void:
	if _hitches.size() < MAX_HITCHES:
		_hitches.append({"minute": snappedf(_t / 60.0, 0.01), "ms": snappedf(ms, 0.1), "covered": covered, "zone": String(sim.zone_id)})


func _percentile(sorted: PackedFloat32Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(int(p * float(sorted.size())), sorted.size() - 1)]


## "message (xN)" for each distinct line, so a repeated error reads as one line with a count.
func _counted(lines: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	for line: String in lines:
		seen[line] = int(seen.get(line, 0)) + 1
	var out: Array[String] = []
	for line: String in seen:
		out.append("%s (x%d)" % [line, seen[line]])
	return out


func _report(timed_out: bool, wall_seconds: float) -> void:
	OS.remove_logger(_log)
	var sorted: PackedFloat32Array = _normal_ms.duplicate()
	sorted.sort()
	var errors: Array[String] = _counted(_log.errors)
	for e: String in errors:
		printerr("playtest: SCRIPT ERROR " + e)
	var notes: Array[String] = _counted(_log.notes)
	for n: String in notes:
		print("playtest: note (engine, not a failure) " + n)
	var bought: Dictionary = {}
	for id: StringName in _first_bought:
		bought[String(id)] = _first_bought[id]
	var data: Dictionary = {
		"sim_minutes": snappedf(_t / 60.0, 0.01),
		"wall_seconds": snappedf(wall_seconds, 0.1),
		"timed_out": timed_out,
		"headless": DisplayServer.get_name() == "headless",
		"zone_final": String(sim.zone_id),
		"income_stat": String(sim.config.income_stat),
		"press_rate": _press_rate,
		"stall_seconds": STALL_SECONDS,
		"stalls": _stalls,
		"errors": errors,
		"engine_notes": notes,
		"events": _events,
		"first_bought": bought,
		"attributes_bought": _attributes_bought,
		"frames": {
			"normal": sorted.size(),
			"normal_max_ms": snappedf(_normal_max, 0.1),
			"normal_p95_ms": snappedf(_percentile(sorted, 0.95), 0.1),
			"normal_p99_ms": snappedf(_percentile(sorted, 0.99), 0.1),
			"covered": _covered_frames,
			"covered_max_ms": snappedf(_covered_max, 0.1),
		},
		"hitches": _hitches,
	}
	var out_dir: String = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f: FileAccess = FileAccess.open(out_dir + "/playtest.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	print("playtest: %.1f sim minutes in %.1f s wall, zone %s, %d events, %d stalls, %d upgrades, %d frames (normal max %.1f ms, p99 %.1f ms, covered max %.1f ms)" % [
		_t / 60.0, wall_seconds, sim.zone_id, _events.size(), _stalls.size(), _attributes_bought, sorted.size(), _normal_max, _percentile(sorted, 0.99), _covered_max])
	for e: Dictionary in _events:
		print("playtest:   %.2f min %s %s" % [e.minute, e.kind, e.id])
	if timed_out:
		printerr("playtest: wall-clock limit reached at %.1f sim minutes" % [_t / 60.0])
	print("wrote ", out_dir, "/playtest.json")
	quit(1 if not errors.is_empty() or timed_out else 0)
