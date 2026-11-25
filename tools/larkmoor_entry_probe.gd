extends SceneTree
## Larkmoor entry probe: enters Larkmoor the way the CI bench does, then prints every frame of the entry that takes
## longer than --slow=<ms> (default 40), with the PerfStats laps that ran inside that frame. Use it to see which stage
## of the swap a slow frame is in, since bench.gd's trace lines are not tied to frames. Each slow frame also prints a
## split of its wall time: start to pre-draw (process, physics, sync), the draw, and post-draw to the next frame (the
## end-of-frame flush: deferred calls and node deletion).
##
## godot --headless --path . --script tools/larkmoor_entry_probe.gd -- --quality=low --frames=180 --slow=40

var frames: int = 180
var slow_ms: float = 40.0
var quality: int = 1
var target: StringName = &"larkmoor"
var pre_zone: StringName = &""
var _main: Node = null
var _frame_us: int = 0
var _pre_us: int = 0
var _post_us: int = 0
var _draw_ms: float = 0.0
var _hook_us: int = 0


## Runs last in each frame's process pass (process_priority is huge), so the gap from it to the next frame's start is the
## engine's own end-of-frame work: draw or sync, the deferred-call flush and node deletion.
class Hook extends Node:
	var stamp: Callable = Callable()

	func _process(_delta: float) -> void:
		stamp.call()


func _init() -> void:
	await process_frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--slow="):
			slow_ms = float(a.trim_prefix("--slow="))
		elif a.begins_with("--quality="):
			quality = GraphicsQuality.parse(a.trim_prefix("--quality="))
		elif a.begins_with("--zone="):
			target = StringName(a.trim_prefix("--zone="))
		elif a.begins_with("--pre="):
			pre_zone = StringName(a.trim_prefix("--pre="))
	PerfStats.tracing = true
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_us = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void:
		_post_us = Time.get_ticks_usec()
		_draw_ms = float(_post_us - _pre_us) / 1000.0)
	var hook := Hook.new()
	hook.process_priority = 1000000
	hook.stamp = func() -> void: _hook_us = Time.get_ticks_usec()
	root.add_child(hook)
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
	await _frames(30)
	GraphicsQuality.set_level(quality, false)
	DisplaySettings.vsync = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _frames(30)
	if pre_zone != &"":
		for z: ZoneDef in sim.zone_defs.values():
			if z.next_zone == pre_zone:
				sim.gates_open[z.id] = true
		if not sim.enter_zone(pre_zone):
			printerr("entry probe: could not enter %s" % pre_zone)
			quit(1)
			return
		await _frames(150)
		for z: ZoneDef in sim.zone_defs.values():
			if z.next_zone == target:
				sim.gates_open[z.id] = true
		await _frames(30)
	PerfStats.trace.clear()
	if not sim.enter_zone(target):
		printerr("entry probe: could not enter %s" % target)
		quit(1)
		return
	var total_ms: float = 0.0
	var worst: float = 0.0
	var last: int = Time.get_ticks_usec()
	for i: int in frames:
		var n0: int = PerfStats.trace.size()
		var c0: Array = [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
		_pre_us = 0
		_post_us = 0
		await process_frame
		_frame_us = Time.get_ticks_usec()
		var c1: Array = [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		total_ms += ms
		if ms >= slow_ms:
			var laps: Array[String] = []
			for j: int in range(n0, PerfStats.trace.size()):
				laps.append(PerfStats.trace[j])
			print("counts nodes %d->%d resources %d->%d orphans %d->%d" % [c0[0], c1[0], c0[1], c1[1], c0[2], c1[2]])
			print("split frame %d: start->last_process=%.1f last_process->next=%.1f ms (draw signal %s)" % [i,
				float(_hook_us - _frame_us) / 1000.0, float(_frame_us - _hook_us) / 1000.0, "seen" if _pre_us > 0 else "not seen"])
			print("phys2d active=%d pairs=%d islands=%d" % [int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)), int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT))])
			print("SLOW frame %d: %.1f ms  process=%.1f physics=%.1f draw=%.1f  laps=%s" % [i, ms,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				_draw_ms, str(laps)])
	print("entry summary: %s -> %s frames=%d worst=%.1f ms mean=%.2f ms quality=%s" % [pre_zone, target, frames, worst, total_ms / float(frames), GraphicsQuality.label()])
	quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
