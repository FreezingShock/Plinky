extends Node
## Garden tour: starts the real game in Larkmoor with every tier open, then frames each statistic's pad row at zoom 2 (and the
## whole row at zoom 1) and saves PNGs to shots/garden_<row>.png. Run: godot --path . tools/garden_shots.tscn
## (headless servers: xvfb-run with the software Vulkan driver). Look at the PNGs.
## Add `-- phase=0.95` to pin the time of day (0.5 noon, 0.66 golden hour, around 0.95 deep night); shots then end in _p095.

var main: Control
var root: Window
var suffix: String = ""

## Shot name -> [tier row, first pad index, last pad index]. Starbloom is two gardens: Emberwatch (pads 1 to 3) and Westmere (4 to 6).
const ROWS: Dictionary = {
	"lark_sprout": [&"lark_sprout", 0, 4], "lark_clover": [&"lark_clover", 0, 4], "thistle": [&"thistle", 0, 4], "heather": [&"heather", 0, 4],
	"foxglove": [&"foxglove", 0, 4], "starbloom": [&"starbloom", 0, 2], "westmere": [&"starbloom", 3, 5],
}


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Drops the offline-earnings card (ui/welcome_card.gd, ui/welcome_tile.gd) so the shots show the garden.
func _clear_overlays(n: Node) -> void:
	for c in n.get_children():
		var sp: Script = c.get_script() as Script
		if sp != null and (sp.resource_path.contains("welcome_card") or sp.resource_path.contains("welcome_tile")):
			if c is CanvasItem:
				(c as CanvasItem).visible = false   # hide, not free: the HUD keeps a reference to the card
		_clear_overlays(c)


func _shot(name: String) -> void:
	_clear_overlays(main)
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name, "  nodes ", get_tree().get_node_count())


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(40)


func _ready() -> void:
	root = get_tree().root
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("phase="):
			SkyCycle.debug_phase = float(a.substr(6))
			suffix = "_p" + a.substr(6).replace(".", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	sim.dev_open_tiers()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	for shot_name: String in ROWS:
		var spec: Array = ROWS[shot_name] as Array
		var tier: StringName = spec[0]
		var pts: Array[Vector2] = []
		for id: StringName in main.pads:
			var b: ButtonDef = sim.button_defs.get(id) as ButtonDef
			if b != null and b.row == tier and b.row_index >= int(spec[1]) and b.row_index <= int(spec[2]):
				pts.append((main.pads[id] as Node2D).position)
		if pts.is_empty():
			continue
		var c := Vector2.ZERO
		for p: Vector2 in pts:
			c += p
		c /= float(pts.size())
		await _goto(c + Vector2(0, 46), 2)
		await _shot("garden_%s%s" % [shot_name, suffix])
		await _goto(c + Vector2(0, 46), 1)
		await _shot("garden_%s_wide%s" % [shot_name, suffix])
	get_tree().quit(0)
