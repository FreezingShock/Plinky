extends Node
## Palette probe: renders the real Larkmoor start frame, lists the overlay nodes that can touch the
## picture after the palette step, and saves one PNG per overlay with that node hidden.
## Run (software Vulkan, Xvfb):
##   xvfb-run -a godot --path . tools/palette_probe.tscn -- dump
##   xvfb-run -a godot --path . tools/palette_probe.tscn -- ablate
## Output goes to res://shots/<tag>/ (default tag: palette). Not used by the game or the tests.

var main: Control
var root: Window
var out_dir: String = "res://shots/palette"
var _cands: Array[CanvasItem] = []


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(2)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [out_dir, name]))


func _collect(n: Node, depth: int) -> void:
	if depth > 4:
		return
	for c in n.get_children():
		if c is CanvasItem:
			var ci := c as CanvasItem
			var is_rect: bool = ci is ColorRect
			var has_mat: bool = ci.material is ShaderMaterial
			if is_rect or has_mat:
				_cands.append(ci)
		_collect(c, depth + 1)


func _quiet_ui() -> void:
	# Keep the picture (pv: 3D view plus post pass), the world and the sky-attached vignette. Hide the rest.
	var keep: Array = [main.pv, main.world, main.hud]
	for n in main.get_children():
		if n in keep or n.name == "ScreenLight" or n.name == "PadGlow":
			continue
		if n is CanvasItem or n is CanvasLayer:
			n.visible = false
	main.hud.visible = false
	for c in root.get_children():
		if c != main and (c is CanvasItem or c is CanvasLayer):
			c.visible = false
	print("ui hidden under main: ", main.get_children().map(func(x: Node) -> String: return x.name))


func _label(ci: CanvasItem) -> String:
	var sh := "-"
	if ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader != null:
		sh = (ci.material as ShaderMaterial).shader.resource_path.get_file()
	return "%s | %s | %s | vis=%s" % [main.get_path_to(ci), ci.get_class(), sh, ci.visible]


func _ready() -> void:
	root = get_tree().root
	var mode: String = "dump"
	var day_frac: float = -1.0   # -1 keeps the start clock; 0.5 is noon, 0.77 about dusk
	var tag: String = "palette"
	for a in OS.get_cmdline_user_args():
		if a == "ablate" or a == "dump":
			mode = a
		elif a.begins_with("day="):
			day_frac = float(a.substr(4))
		elif a.begins_with("tag="):
			tag = a.substr(4)
	out_dir = "res://shots/" + tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(60)

	if day_frac >= 0.0:
		sim.calendar.set_day_fraction(day_frac)
		await _wait(120)
	var pal: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	var hexes: PackedStringArray = []
	for c in pal:
		hexes.append(c.to_html(false))
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir + "/palette.txt"), FileAccess.WRITE)
	f.store_string(" ".join(hexes) + "\n")
	f.close()

	_cands.clear()
	_collect(main, 1)
	var lines: PackedStringArray = []
	for i in _cands.size():
		lines.append("%d | %s" % [i, _label(_cands[i])])
	var g := FileAccess.open(ProjectSettings.globalize_path(out_dir + "/candidates.txt"), FileAccess.WRITE)
	g.store_string("\n".join(lines) + "\n")
	g.close()
	print("candidates: ", _cands.size())

	# World-only frame: hide every UI node (HUD, tutorial, arrival banner) so the counts cover the world alone.
	_quiet_ui()
	# Freeze the clock and the animations so each capture differs only by the node we hide.
	await _wait(30)
	Engine.time_scale = 0.0
	await _wait(10)
	await _shot("base")
	if mode == "dump":
		get_tree().quit(0)
		return

	for i in _cands.size():
		var ci: CanvasItem = _cands[i]
		if not is_instance_valid(ci):
			continue
		var was: bool = ci.visible
		if not was:
			continue
		ci.visible = false
		await _shot("abl_%03d" % i)
		ci.visible = was
	await _shot("base_end")
	# Post pass hidden: does anything visible change? (the post ColorRect sits under the 2D world)
	main.pv.post.visible = false
	await _shot("abl_post_only")
	main.pv.post.visible = true
	print("ablate done")
	get_tree().quit(0)
