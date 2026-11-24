extends Node
## Garden tour: starts the real game in Larkmoor with every tier open, then frames each statistic's pad row at zoom 2 (and the
## whole row at zoom 1) and saves PNGs to shots/garden_<row>.png. Run: godot --path . tools/garden_shots.tscn
## (headless servers: xvfb-run with the software Vulkan driver). Look at the PNGs.

var main: Control
var root: Window

const ROWS: Array[StringName] = [&"lark_sprout", &"lark_clover", &"thistle", &"heather", &"foxglove", &"starbloom"]


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(20)


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	sim.dev_open_tiers()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	for tier: StringName in ROWS:
		var pts: Array[Vector2] = []
		for id: StringName in main.pads:
			var b: ButtonDef = sim.button_defs.get(id) as ButtonDef
			if b != null and b.row == tier:
				pts.append((main.pads[id] as Node2D).position)
		if pts.is_empty():
			continue
		var c := Vector2.ZERO
		for p: Vector2 in pts:
			c += p
		c /= float(pts.size())
		var lo: Vector2 = c
		for p: Vector2 in pts:
			lo = lo.max(p)
		await _goto(c + Vector2(0, 46), 2)
		await _shot("garden_%s" % tier)
		await _goto(c + Vector2(0, 46), 1)
		await _shot("garden_%s_wide" % tier)
	get_tree().quit(0)
