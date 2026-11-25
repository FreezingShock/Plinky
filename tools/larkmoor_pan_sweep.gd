extends SceneTree
## Larkmoor pan sweep: the camera glides in a smooth sine pan (free mode, the walker stands still) at several speeds and
## zooms, and every frame is checked for pop-in: a chunk on screen that has props but is not loaded yet. It reports the
## pop-in frames, the worst missing count, the chunk loads and their cost, and the peak node count.
##   speed = texels per second the view moves at its fastest (the sine's peak), at zoom 1, 2 and 4.
##
## godot --path . --script tools/larkmoor_pan_sweep.gd -- --frames=360
## Headless: pop-in and chunk counts are real, frame times are not. Real window (xvfb + lavapipe) gives CPU cost per lap.

const SETTLE_FRAMES: int = 30
const STEP: float = 1.0 / 60.0          # fixed pan step per frame, so every run moves the same distance
const AMP: Vector2 = Vector2(700.0, 300.0)
const SPEEDS: Array[float] = [120.0, 300.0, 600.0]
const ZOOMS: Array[int] = [1, 2, 4]

var frames: int = 360
var label: String = "run"
var still_sway: bool = false   # --still-sway: Reduce Motion holds the flowers and stops their redraws, so only pan redraws are left
var _main: Node = null


func _init() -> void:
	await process_frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = maxi(60, int(a.trim_prefix("--frames=")))
		elif a.begins_with("--label="):
			label = a.trim_prefix("--label=")
		elif a == "--still-sway":
			still_sway = true
	MeadowLife.reduce_motion = still_sway
	PerfStats.tracing = true
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_main = main
	root.add_child(main)
	current_scene = main
	root.get_node("Save").set("enabled", false)
	var sim: Sim = main.get("sim") as Sim
	sim.new_game()
	await _frames(90)
	for z: ZoneDef in sim.zone_defs.values():
		if z.next_zone == &"larkmoor":
			sim.gates_open[z.id] = true
	if sim.zone_id != &"larkmoor" and not sim.enter_zone(&"larkmoor"):
		printerr("pan sweep: could not enter Larkmoor")
		quit(1)
		return
	await _frames(180)
	var cam: WorldCamera = main.get("camera") as WorldCamera
	var scene: Node = null
	for c: Node in (main.get("world") as Node).get_children():
		if c.has_method("loaded_prop_count"):
			scene = c
	if scene == null:
		printerr("pan sweep: no Larkmoor scene under world")
		quit(1)
		return
	cam.auto_return = false
	var rows: Array[Dictionary] = []
	for zoom: int in ZOOMS:
		cam.zoom_step(zoom - cam.zoom_level, cam.frame * 0.5)
		for speed: float in SPEEDS:
			rows.append(await _sweep(cam, scene, zoom, speed))
	cam.pan = Vector2.ZERO
	cam.auto_return = true
	print("label=%s quality=%s frames=%d" % [label, GraphicsQuality.label(), frames])
	print("zoom  speed  popin_frames  worst_missing  chunk_loads  load_max_ms  load_total_ms  max_nodes  loaded_props  wall_avg  wall_p99")
	for r: Dictionary in rows:
		print("%4d  %5.0f  %12d  %13d  %11d  %11.2f  %13.1f  %9d  %12d  %8.2f  %8.2f" % [int(r.zoom), float(r.speed), int(r.popin),
			int(r.worst), int(r.loads), float(r.load_max), float(r.load_total), int(r.max_nodes), int(r.props),
			float(r.frame_avg), float(r.frame_p99)])
		for key: String in (r.traces as Dictionary).keys():
			var t: Dictionary = (r.traces as Dictionary)[key]
			print("      %-16s n=%-5d total %8.1f ms  mean %6.3f  max %6.2f" % [key, int(t.n), float(t.total),
				float(t.total) / float(t.n), float(t.max)])
	var out_dir: String = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f: FileAccess = FileAccess.open(out_dir + "/pan_sweep_%s.json" % label, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"label": label, "rows": rows}, "\t"))
		print("wrote ", out_dir, "/pan_sweep_%s.json" % label)
	quit(0)


## One sweep: settle at the walker, then glide the view along a sine path for `frames` frames.
func _sweep(cam: WorldCamera, scene: Node, zoom: int, speed: float) -> Dictionary:
	cam.pan = Vector2.ZERO
	cam.set("_free", false)
	await _frames(SETTLE_FRAMES)
	var w: float = speed / AMP.x
	var popin: int = 0
	var worst: int = 0
	var max_nodes: int = 0
	var stats := PerfStats.new(frames)
	var last: int = Time.get_ticks_usec()
	PerfStats.trace.clear()
	for i: int in frames:
		var t: float = float(i) * STEP
		cam.hold_pan(Vector2(AMP.x * sin(w * t), AMP.y * sin(w * t * 0.6 + 1.0)))
		await process_frame
		var now: int = Time.get_ticks_usec()
		stats.push(float(now - last) / 1000.0)
		last = now
		var missing: int = _missing_on_screen(scene)
		if missing > 0:
			popin += 1
		worst = maxi(worst, missing)
		max_nodes = maxi(max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	var loads: int = 0
	var load_total: float = 0.0
	var load_max: float = 0.0
	var traces: Dictionary = {}
	for line: String in PerfStats.trace:
		var key: String = line.substr(0, line.rfind(" ", line.rfind(" ") - 1))
		var ms: float = _ms_of(line)
		var row: Dictionary = traces.get(key, {"n": 0, "total": 0.0, "max": 0.0})
		row.n = int(row.n) + 1
		row.total = float(row.total) + ms
		row.max = maxf(float(row.max), ms)
		traces[key] = row
		if key == "chunk load":
			loads += 1
			load_total += ms
			load_max = maxf(load_max, ms)
	PerfStats.trace.clear()
	var summary: Dictionary = stats.summary()
	return {"zoom": zoom, "speed": speed, "popin": popin, "worst": worst, "loads": loads, "load_total": load_total,
		"load_max": load_max, "max_nodes": max_nodes, "props": scene.call("loaded_prop_count"),
		"frame_avg": summary.avg, "frame_p99": summary.p99, "traces": traces}


## The ms value at the end of a "label N.N ms" trace line.
static func _ms_of(line: String) -> float:
	var cut: int = line.rfind(" ")
	var cut2: int = line.rfind(" ", cut - 1)
	return float(line.substr(cut2 + 1, cut - cut2 - 1))


## Chunks on screen (the view rect, no margin) that have props and are not loaded.
func _missing_on_screen(scene: Node) -> int:
	var view: Rect2i = scene.get("_view") as Rect2i
	var loaded: Dictionary = scene.get("_loaded") as Dictionary
	var index: Dictionary = scene.get("_prop_index") as Dictionary
	var n: int = 0
	for y: int in range(view.position.y, view.end.y):
		for x: int in range(view.position.x, view.end.x):
			var key: Vector2i = Vector2i(x, y)
			if index.has(key) and not loaded.has(key):
				n += 1
	return n


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
