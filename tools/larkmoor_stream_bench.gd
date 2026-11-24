extends SceneTree
## Larkmoor streaming probe: the real main scene in Larkmoor, timed through four scenarios. Each one logs the frame
## time (avg, p95, p99, max, frames over 33 ms) and the PerfStats.lap traces the streaming code records (chunk loads,
## chunk unloads, the flower garden's redraw), summed per label.
##   idle_z1 / idle_z2 / idle_z4   the walker stands at the spawn, camera at zoom 1, 2 or 4
##   walk_z2                       the walker is carried through every pad, 3 texels a frame (chunks load and unload)
##   zoom_cycle                    the walker stands still and the camera steps 1 to 4 and back every 40 frames
##
## godot --path . --script tools/larkmoor_stream_bench.gd -- --label=before --frames=240
## Real window on the PC is the number that counts; headless reads frame time without a renderer. Writes
## shots/stream_<label>.json. Use it to A/B two builds on the same machine, never as an absolute fps.

const WARMUP_FRAMES: int = 90
const WALK_STEP: float = 3.0
const CYCLE_EVERY: int = 40
const WORST_SPOT: Vector2 = Vector2(1460.0, 800.0)
const PAD_PATH: String = "res://assets/art/zone1b/larkmoor/placements3d.json"

var frames: int = 240
var shots_only: bool = false   # --shots: save the view at three sun states with the sway frozen, then stop (A/B the look)
var label: String = "run"
var quality: int = -1
var results: Array[Dictionary] = []
var _main: Node = null


func _init() -> void:
	await process_frame  # autoloads register after the first frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = maxi(60, int(a.trim_prefix("--frames=")))
		elif a.begins_with("--label="):
			label = a.trim_prefix("--label=")
		elif a.begins_with("--quality="):
			quality = GraphicsQuality.parse(a.trim_prefix("--quality="))
		elif a == "--shots":
			shots_only = true
	PerfStats.tracing = true
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_main = main
	root.add_child(main)
	current_scene = main
	root.get_node("Save").set("enabled", false)
	var sim: Sim = main.get("sim") as Sim
	sim.new_game()
	await _frames(WARMUP_FRAMES)
	for z: ZoneDef in sim.zone_defs.values():
		if z.next_zone == &"larkmoor":
			sim.gates_open[z.id] = true
	if sim.zone_id != &"larkmoor" and not sim.enter_zone(&"larkmoor"):
		printerr("stream bench: could not enter Larkmoor")
		quit(1)
		return
	await _frames(180)
	_uncap()
	if quality >= 0:
		GraphicsQuality.set_level(quality, false)
	await _frames(30)

	var cam: WorldCamera = main.get("camera") as WorldCamera
	var walker: Node2D = main.get("walker") as Node2D
	var spawn: Vector2 = walker.position
	if shots_only:
		await _shots(cam)
		quit(0)
		return
	for line: String in PerfStats.trace:
		if line.begins_with("swap") or line.begins_with("garden atlas") or line.begins_with("chunk"):
			print("entry ", line)   # the zone swap and anything built on the first frames in Larkmoor
	var pads: Array[Vector2] = _pad_route()

	await _scene("idle_z1", frames, cam, 1, [], spawn)
	await _scene("idle_z2", frames, cam, 2, [], spawn)
	await _scene("idle_z4", frames, cam, 4, [], spawn)
	await _scene("walk_z2", frames * 3, cam, 2, pads, spawn)
	walker.position = spawn
	# the walker on the densest chunk ring the placements allow (159 props in its 5 by 5 chunks): the node ceiling's worst case
	walker.position = WORST_SPOT
	await _scene("worst_spot", frames, cam, 2, [], WORST_SPOT)
	walker.position = spawn
	await _scene("zoom_cycle", frames, cam, 2, [], spawn, true)

	_report()
	quit(0)


## The same view at noon, sunset and midnight with the sway frozen, saved as PNGs, so two builds can be compared pixel by pixel.
func _shots(cam: WorldCamera) -> void:
	MeadowLife.reduce_motion = true
	var zone: Node = _main.get("meadow") as Node
	print("shots: zone scene ", zone.scene_file_path if zone != null else "none", " walker ", (_main.get("walker") as Node2D).position, " props ", zone.call("loaded_prop_count") if zone != null and zone.has_method("loaded_prop_count") else -1)
	for ph: float in [0.5, 0.75, 0.0]:
		SkyCycle.debug_phase = ph
		await _frames(150)   # the sky eases toward each phase over frames: wait for it to settle before the shot
		var img: Image = get_root().get_texture().get_image()
		var out_dir: String = ProjectSettings.globalize_path("res://shots")
		DirAccess.make_dir_recursive_absolute(out_dir)
		img.save_png(out_dir + "/shot_%s_%03d.png" % [label, int(ph * 100.0)])
		print("saved shot ", label, " phase ", ph, " size ", img.get_size())
	SkyCycle.debug_phase = -1.0


func _uncap() -> void:
	DisplaySettings.vsync = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


## The pad anchors in file order (they run along the rows), each one a waypoint of the walk.
func _pad_route() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PAD_PATH)) as Dictionary
	for a: Dictionary in data.anchors:
		if String(a.kind) == "pad":
			out.append(Vector2(float(a.sx), float(a.sy)))
	return out


func _scene(name: String, n: int, cam: WorldCamera, zoom: int, route: Array, spawn: Vector2, cycle: bool = false) -> void:
	var walker: Node2D = _main.get("walker") as Node2D
	var stats := PerfStats.new(n)
	PerfStats.trace.clear()
	var peak_static: float = 0.0
	var leg: int = 0
	var at: Vector2 = spawn
	var go: Vector2 = spawn
	var dir: int = 1
	if cam.zoom_level != zoom:
		cam.zoom_step(zoom - cam.zoom_level, cam.frame * 0.5)
	await _frames(20)
	var last: int = Time.get_ticks_usec()
	var big_ms: int = 0
	var draws_sum: int = 0
	var draws_max: int = 0
	for i: int in n:
		if not route.is_empty():
			if at.distance_to(go) < WALK_STEP:
				leg = (leg + 1) % route.size()
				go = route[leg]
			at = at.move_toward(go, WALK_STEP)
			walker.position = at
		if cycle and i > 0 and i % CYCLE_EVERY == 0:
			cam.zoom_step(dir, cam.frame * 0.5)
			if cam.zoom_level == 4:
				dir = -1
			elif cam.zoom_level == 1:
				dir = 1
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		stats.push(ms)
		if ms > 33.0:
			big_ms += 1
		last = now
		var draws: int = int(PerfStats.counters().draw_calls)
		draws_sum += draws
		draws_max = maxi(draws_max, draws)
		peak_static = maxf(peak_static, float(OS.get_static_memory_usage()) / 1048576.0)
	var s: Dictionary = stats.summary()
	s["scenario"] = name
	s["zoom"] = zoom
	s["over_33ms"] = big_ms
	s["draws_mean"] = float(draws_sum) / float(n)
	s["draws_max"] = draws_max
	s["static_mb_peak"] = peak_static
	s["nodes"] = int(PerfStats.counters().nodes)
	var zone: Node = _main.get("meadow") as Node
	s["loaded_props"] = int(zone.call("loaded_prop_count")) if zone != null and zone.has_method("loaded_prop_count") else -1
	s["trace"] = _summarise_trace(PerfStats.trace)
	results.append(s)


## Sums "label N.N ms" lines by label: count, total and max, so a run's chunk loads and redraws read in one row each.
func _summarise_trace(lines: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for line: String in lines:
		var cut: int = line.rfind(" ")
		var cut2: int = line.rfind(" ", cut - 1)
		var key: String = line.substr(0, cut2)
		var ms: float = float(line.substr(cut2 + 1, cut - cut2 - 1))
		var row: Dictionary = out.get(key, {"count": 0, "total_ms": 0.0, "max_ms": 0.0})
		row.count = int(row.count) + 1
		row.total_ms = float(row.total_ms) + ms
		row.max_ms = maxf(float(row.max_ms), ms)
		out[key] = row
	return out


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _report() -> void:
	print("label=%s quality=%s" % [label, GraphicsQuality.label()])
	print("scenario      frames  avg ms  p95    p99    max    >33ms  nodes  draws mean/max")
	for r: Dictionary in results:
		print("%-13s %-7d %-7.2f %-6.2f %-6.2f %-6.2f %-6d %-6d %.0f / %d" % [r.scenario, int(r.frames), float(r.avg),
			float(r.p95), float(r.p99), float(r.max), int(r.over_33ms), int(r.nodes), float(r.draws_mean), int(r.draws_max)])
		for key: String in (r.trace as Dictionary).keys():
			var t: Dictionary = (r.trace as Dictionary)[key]
			print("    %-34s n=%-5d total %8.1f ms  mean %6.3f ms  max %6.2f ms" % [key, int(t.count), float(t.total_ms),
				float(t.total_ms) / float(t.count), float(t.max_ms)])
	var out_dir: String = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f: FileAccess = FileAccess.open(out_dir + "/stream_%s.json" % label, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"label": label, "results": results}, "\t"))
		print("wrote ", out_dir, "/stream_%s.json" % label)
