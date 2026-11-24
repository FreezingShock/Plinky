extends SceneTree
## Memory probe: walks the game through meadow -> Larkmoor -> Ember Quarry -> meadow and prints, at the end of each
## zone's settle, what the engine holds: GPU texture and buffer bytes, static RAM, resource and node counts, and the
## sizes of the caches that live in code (ZoneAssets, Audio, UpgradeCard icons, sealed art, dither tiles, the Tip host).
## A cache that is never released shows up as a number that only goes up across the walk.
##
## Needs a renderer for the GPU counters, so run it under xvfb (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --script tools/memory_probe.gd -- --frames=120

var frames: int = 120
var rows: Array[Dictionary] = []
var _main: Node = null


func _init() -> void:
	await process_frame  # autoloads register after the first frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = maxi(30, int(a.trim_prefix("--frames=")))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_main = main
	root.add_child(main)
	current_scene = main
	root.get_node("Save").set("enabled", false)
	var sim: Sim = main.get("sim") as Sim
	sim.new_game()
	await _settle(frames)
	_snap("start: meadow")

	sim.gates_open[&"zone1"] = true
	for z: ZoneDef in sim.zone_defs.values():
		if z.next_zone == &"larkmoor":
			sim.gates_open[z.id] = true
	if sim.zone_id == &"larkmoor" or sim.enter_zone(&"larkmoor"):
		await _settle(frames)
		_snap("larkmoor")
	else:
		printerr("memory_probe: could not enter Larkmoor")

	sim.gates_open[&"larkmoor"] = true
	if sim.zone_id == &"zone2" or sim.enter_zone(&"zone2"):
		await _settle(frames)
		_snap("ember quarry")
	else:
		printerr("memory_probe: could not enter the Ember Quarry")

	if sim.enter_zone(&"zone1"):
		await _settle(frames)
		_snap("back: meadow")

	if sim.enter_zone(&"larkmoor"):
		await _settle(frames)
		_snap("back: larkmoor")

	_report()
	quit(0)


func _settle(n: int) -> void:
	for i: int in n:
		await process_frame


func _mb(v: float) -> float:
	return v / 1048576.0


func _snap(label: String) -> void:
	var row: Dictionary = {
		"label": label,
		"tex_mb": _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buf_mb": _mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"vram_mb": _mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"static_mb": _mb(float(OS.get_static_memory_usage())),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"zone_assets": ZoneAssets._cache.size(),
		"audio_cache": _dict_size("Audio", "_cache"),
		"upgrade_icons": UpgradeCard._icons.size(),
		"sealed_art": SealedArt._cache.size(),
		"dither_tiles": DitherReveal._tiles.size(),
	}
	rows.append(row)
	if label.begins_with("back") or label == "start: meadow":
		_list_textures(label)


## Which zone textures are still alive after the zone was left. A weakref to a fresh load() only stays valid when some
## other owner (a preload constant, a static cache, a node) still holds that texture, so a live one is a leak to find.
func _list_textures(label: String) -> void:
	var alive: Array[String] = []
	var total: float = 0.0
	for dir: String in ["res://assets/art/zone1b/larkmoor/", "res://assets/art/zone1/meadow3d/", "res://assets/art/zone2/quarry/", "res://assets/art/zone1b/farm/"]:
		for p: String in _pngs(dir):
			var w: WeakRef = weakref(load(p))
			if w.get_ref() != null:
				var t: Texture2D = w.get_ref() as Texture2D
				var mb: float = _mb(float(t.get_width()) * float(t.get_height()) * 4.0 * 1.33)
				total += mb
				alive.append("  %6.2f MB  %4dx%-4d %s" % [mb, t.get_width(), t.get_height(), p])
	print("RETAINED at %s: %d zone textures alive, est %.1f MB" % [label, alive.size(), total])
	for a: String in alive:
		print(a)


func _pngs(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".png") and not f.ends_with("_n.png") and not f.ends_with("_h.png"):
			out.append(dir + f)
		elif f.ends_with(".png"):
			out.append(dir + f)
	for sub: String in d.get_directories():
		out.append_array(_pngs(dir + sub + "/"))
	return out


func _dict_size(autoload: String, prop: String) -> int:
	var n: Node = root.get_node_or_null(autoload)
	if n == null or n.get(prop) == null:
		return -1
	return (n.get(prop) as Dictionary).size()


func _report() -> void:
	print("label                  tex MB   buf MB   vram MB  static MB  res    nodes  orph  zoneA  audio  upIc  sealed  dither")
	for r: Dictionary in rows:
		print("%-22s %-8.1f %-8.1f %-8.1f %-10.1f %-6d %-6d %-5d %-6d %-6d %-5d %-7d %d" % [
			r.label, float(r.tex_mb), float(r.buf_mb), float(r.vram_mb), float(r.static_mb), int(r.resources),
			int(r.nodes), int(r.orphans), int(r.zone_assets), int(r.audio_cache), int(r.upgrade_icons),
			int(r.sealed_art), int(r.dither_tiles)])
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://shots") + "/memory.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "rows": rows}, "\t"))
