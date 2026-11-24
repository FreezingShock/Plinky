extends SceneTree
## Frame-time benchmark of the real main scene. Per graphics quality level and phase it logs average, p95, p99
## and worst frame time, fps, draw calls, objects and node count, then writes shots/bench.json.
##
## On real hardware (what the target is judged on; a window, vsync off so the numbers are true cost):
##   godot --path . --import                              (once, to refresh the class cache)
##   godot --path . --script tools/bench.gd               (all three levels)
##   godot --path . --script tools/bench.gd -- --quality=low --frames=600
## Headless (no GPU: draw calls, objects and VRAM read 0, frame time is script and engine overhead only,
## still useful to catch a script regression):
##   godot --headless --path . --script tools/bench.gd -- --quality=high
## Per zone (meadow, then Larkmoor) and quality: idle at noon, sunset, night and in rain, then presses (a pad
## press every 6 frames: ripples, popups, particles) and zoom4 (idle at 4x zoom, the camera's closest level).

const WARMUP_FRAMES: int = 90
const DEFAULT_FRAMES: int = 300
const PRESS_EVERY: int = 6
const HITCH_MS: float = 40.0   # a frame this slow is logged as a HITCH line, whatever the averages say
## [name, SkyCycle phase (0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset), rain 0..1]
const SKY_STATES: Array = [["noon", 0.5, 0.0], ["sunset", 0.75, 0.0], ["night", 0.0, 0.0], ["rain", 0.5, 1.0]]

var frames: int = DEFAULT_FRAMES
var results: Array[Dictionary] = []
var _log: ErrorLog = ErrorLog.new()
var hitches: Array[String] = []
var total_frames: int = 0
var audio_cache: int = 0
var pipelines: int = 0
var skip_meadow: bool = false


## Collects script and shader errors from the engine log. A bench that logged one is a failed bench: a broken
## layer can make frames cheaper (it stops drawing), so fast numbers next to an error mean nothing.
class ErrorLog extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT or error_type == Logger.ERROR_TYPE_SHADER:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])


func _init() -> void:
	await process_frame  # autoloads register after the first frame
	var levels: Array[int] = [GraphicsQuality.Level.LOW, GraphicsQuality.Level.MEDIUM, GraphicsQuality.Level.HIGH]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = maxi(30, int(a.trim_prefix("--frames=")))
		elif a == "--skip-meadow":
			skip_meadow = true
		elif a.begins_with("--quality="):
			var q: int = GraphicsQuality.parse(a.trim_prefix("--quality="))
			if q >= 0:
				levels = [q]
	OS.add_logger(_log)
	PerfStats.tracing = true   # stage timings of the zone swap, printed in the report
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main  # Juice parents its popup layer to the current scene
	_uncap()
	# Never touch the player's save, and start from a fresh game, so the first zone really is the meadow even when
	# the saved game is already in Larkmoor or beyond.
	root.get_node("Save").set("enabled", false)
	var sim: Sim = main.get("sim") as Sim
	sim.new_game()
	await _frames(WARMUP_FRAMES)
	_uncap()  # main and the saved settings turn vsync back on, so force it off again after they have run

	for level: int in levels:
		GraphicsQuality.set_level(level, false)
		await _frames(30)  # let the level take effect
		if not skip_meadow:
			await _zone_runs(level, main, "meadow")
	# Which layer costs what: noon at the highest level, hiding one layer at a time.
	GraphicsQuality.set_level(GraphicsQuality.Level.HIGH, false)
	SkyCycle.debug_phase = 0.5
	SkyCycle.debug_rain = 0.0
	await _frames(30)
	results.append(await _phase(GraphicsQuality.Level.HIGH, "layers/all", main, false, 2))
	for node: Node in _layers(main):
		node.set("visible", false)
		await _frames(10)
		var r: Dictionary = await _phase(GraphicsQuality.Level.HIGH, "layers/-" + String(node.name), main, false, 2)
		node.set("visible", true)
		results.append(r)
	# Larkmoor last: it needs the meadow gate open, and there is no way back worth timing.
	for z: ZoneDef in sim.zone_defs.values():
		if z.next_zone == &"larkmoor":
			sim.gates_open[z.id] = true
	if sim.zone_id == &"larkmoor" or sim.enter_zone(&"larkmoor"):
		await _frames(180, "after entering Larkmoor")  # the zone transition plays out
		_uncap()
		for level: int in levels:
			GraphicsQuality.set_level(level, false)
			await _frames(30)
			await _zone_runs(level, main, "larkmoor")
	else:
		printerr("bench: could not enter Larkmoor (zone_id=%s, unlocked=%s, gates_open=%s). No Larkmoor rows." % [
			sim.zone_id, sim.is_zone_unlocked(&"larkmoor"), sim.gates_open])
	# The Ember Quarry last: its props, shadows and lava are a node each, so its node count is held to the same ceiling
	# (tools/check_frame_budget.py reads nodes_max for every row). Larkmoor leads into it.
	sim.gates_open[&"larkmoor"] = true
	if sim.zone_id == &"zone2" or sim.enter_zone(&"zone2"):
		await _frames(180, "after entering the quarry")
		_uncap()
		for level: int in levels:
			GraphicsQuality.set_level(level, false)
			await _frames(30)
			await _zone_runs(level, main, "quarry")
	else:
		printerr("bench: could not enter the Ember Quarry (zone_id=%s, unlocked=%s). No quarry rows, so no quarry node check." % [
			sim.zone_id, sim.is_zone_unlocked(&"zone2")])
	SkyCycle.debug_phase = -1.0
	SkyCycle.debug_rain = -1.0
	_report()
	OS.remove_logger(_log)
	var seen: Dictionary = {}
	for e: String in _log.errors:
		seen[e] = int(seen.get(e, 0)) + 1
	for e: String in seen:
		printerr("bench: SCRIPT ERROR x%d: %s" % [seen[e], e])
	quit(1 if not seen.is_empty() else 0)


## Real cost, not a vsync- or cap-clamped 16.7 ms. Saved settings default vsync on.
func _uncap() -> void:
	DisplaySettings.vsync = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


## One zone at one quality: the sky states first (the lighting and rain cost), then presses and 4x zoom
## (presses are the heaviest thing the player does).
func _zone_runs(level: int, main: Node, zone: String) -> void:
	for st: Array in SKY_STATES:
		SkyCycle.debug_phase = float(st[1])
		SkyCycle.debug_rain = float(st[2])
		await _frames(20)
		results.append(await _phase(level, zone + "/" + String(st[0]), main, false, 2))
	SkyCycle.debug_phase = SKY_STATES[0][1]
	SkyCycle.debug_rain = SKY_STATES[0][2]
	await _frames(20)
	results.append(await _phase(level, zone + "/presses", main, true, 2))
	results.append(await _phase(level, zone + "/zoom4", main, false, 4))


## The layers worth timing, found by name under the main scene (the meadow's sky and life nodes, and the post pass).
func _layers(main: Node) -> Array[Node]:
	var out: Array[Node] = []
	for nm: String in ["Haze", "Rays", "Shade", "Rain", "LifeGround", "LifeAir", "ScreenLight", "Hud"]:
		for n: Node in main.find_children(nm + "*", "CanvasItem", true, false):
			if n is CanvasItem and not out.has(n):
				out.append(n)
				break
	for n: Node in main.find_children("*", "SkyShadows", true, false):
		out.append(n)  # all cast shadows at once
		break
	return out


func _audio_cache_size() -> int:
	var a: Node = root.get_node_or_null("Audio")
	return (a.get("_cache") as Dictionary).size() if a != null and a.get("_cache") != null else 0


func _frames(n: int, label: String = "settle") -> void:
	var last: int = Time.get_ticks_usec()
	for i: int in n:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		if ms > HITCH_MS and total_frames > 0:
			hitches.append("HITCH %s: frame %d of %d (%d since the run began), %.1f ms" % [label, i, n, total_frames, ms])
		total_frames += 1


func _phase(level: int, phase: String, main: Node, press: bool, zoom: int) -> Dictionary:
	var cam: WorldCamera = main.get("camera") as WorldCamera
	if cam != null and cam.zoom_level != zoom:
		cam.zoom_step(zoom - cam.zoom_level, cam.frame * 0.5)
	var pad_ids: Array = (main.get("pads") as Dictionary).keys()
	var stats := PerfStats.new(frames)
	var draw_calls: int = 0
	var objects: int = 0
	var nodes: int = 0
	var last: int = Time.get_ticks_usec()
	for i: int in frames:
		if press and not pad_ids.is_empty() and i % PRESS_EVERY == 0:
			get_root().get_node("EventBus").button_pressed.emit(pad_ids[(i / PRESS_EVERY) % pad_ids.size()], Vector3.ZERO, BigNum.one(), i % 4 == 0)
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		stats.push(ms)
		var cache_now: int = _audio_cache_size()
		var grew: bool = cache_now > audio_cache
		audio_cache = cache_now
		var pipes_now: int = PerfStats.pipeline_compiles()
		var new_pipes: int = pipes_now - pipelines
		pipelines = pipes_now
		if ms > HITCH_MS:
			# Enough to tell a one-time compile or load from a steady cost: where it fell, and what the engine held then.
			var c0: Dictionary = PerfStats.counters()
			hitches.append("HITCH %s %s: frame %d of the phase (%d since the run began), %.1f ms, nodes %d, objects %d, draws %d, vram %.0f MB, audio cache %s, script %.1f ms, physics %.1f ms, new pipelines %d" % [
				GraphicsQuality.LABELS[level], phase, i, total_frames, ms, int(c0.nodes), int(c0.objects), int(c0.draw_calls), float(c0.vram_mb), "GREW (a sound loaded)" if grew else "unchanged", float(c0.script_ms), float(c0.physics_ms), new_pipes])
		total_frames += 1
		last = now
		var c: Dictionary = PerfStats.counters()
		draw_calls = maxi(draw_calls, int(c.draw_calls))
		objects = maxi(objects, int(c.objects))
		nodes = maxi(nodes, int(c.nodes))
	var s: Dictionary = stats.summary()
	s["quality"] = GraphicsQuality.LABELS[level]
	s["phase"] = phase
	s["draw_calls_max"] = draw_calls
	s["objects_max"] = objects
	s["nodes_max"] = nodes
	return s


func _report() -> void:
	print("quality  phase                  fps    avg ms  p95    p99    max    >16.7ms  draws  objs  nodes")
	for r: Dictionary in results:
		print("%-8s %-22s %-6d %-7.2f %-6.2f %-6.2f %-6.2f %-8s %-6d %-5d %d" % [
			r.quality, r.phase, roundi(float(r.fps)), float(r.avg), float(r.p95), float(r.p99), float(r.max),
			"%d%%" % roundi(float(r.over_budget) * 100.0), int(r.draw_calls_max), int(r.objects_max), int(r.nodes_max)])
	for h: String in hitches:
		print(h)
	for t: String in PerfStats.trace:
		print("TRACE ", t)
	var out_dir: String = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f: FileAccess = FileAccess.open(out_dir + "/bench.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"date": Time.get_datetime_string_from_system(), "gpu": RenderingServer.get_video_adapter_name(),
			"window": DisplayServer.window_get_size(), "headless": DisplayServer.get_name() == "headless",
			"hitches": hitches, "results": results}, "\t"))
		print("wrote ", out_dir, "/bench.json")
