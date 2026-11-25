extends Node
## Shadow audit: the real Larkmoor scene with the HUD hidden, the walker moved to chosen districts at a chosen zoom and sun
## phase. Saves PNGs to shots/audit_<phase>_<place>_z<zoom>.png for a close look at which objects cast a shadow.
## Run: godot --path . tools/shadow_audit_shots.tscn [-- phases=0.5,0.66 places=heronmere,thistle zoom=2 season=2]

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(20)


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a: String in args:
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	SkyCycle.debug_season = int(_arg(args, "season", "2"))
	var phases: PackedStringArray = _arg(args, "phases", "0.5,0.66").split(",")
	var places: PackedStringArray = _arg(args, "places", "heronmere,thistle").split(",")
	var zoom: int = int(_arg(args, "zoom", "2"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	# hide the HUD, tooltips and panels so the frame shows only the world
	for n: String in ["hud", "tooltip", "relic_bar", "relic_panel", "index_panel", "display_panel", "feedback_panel", "gallery", "update_log", "history_panel", "ledger_panel", "dev_console", "window_frame"]:
		var node: Variant = main.get(n)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
	for c: Node in main.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	# look knobs for the mockups: flower shadow strength, shade colour, noon shadow length (sky config, runtime only)
	var sh: SkyShadows = main.meadow.get_node_or_null("Shadows") as SkyShadows
	var sky: SkyCycle = main.meadow.get_node_or_null("Sky") as SkyCycle
	if sh != null:
		sh.flower_strength = float(_arg(args, "flower", str(SkyShadows.FLOWER_STRENGTH)))
		sh.shade_tint = Color.html(_arg(args, "shade", "#" + SkyShadows.SHADE.to_html(false)))
		sh.set_flowers(main.meadow.get("_garden_flowers") as Array)
	if sky != null and sky.get("_config") != null:
		var cfg: Resource = sky.get("_config") as Resource
		cfg.set("shadow_len_noon", float(_arg(args, "noon", str(cfg.get("shadow_len_noon")))))
	var anchors: Node = main.meadow.get_node("Anchors")
	for ph: String in phases:
		SkyCycle.debug_phase = float(ph)
		for pl: String in places:
			var m: Marker2D = anchors.get_node_or_null("District_" + pl) as Marker2D
			if pl == "gate":
				m = anchors.get_node_or_null("Gate") as Marker2D
			if m == null:
				continue
			await _goto(m.position + Vector2(0, 10), zoom)
			await _wait(30)
			get_viewport().warp_mouse(Vector2(-200.0, -200.0))   # the pointer over a pad would summon its tooltip
			await _wait(10)
			var name: String = "audit_%s%s_%s_z%d" % [_arg(args, "tag", ""), ph.replace(".", ""), pl, zoom]
			get_tree().root.get_viewport().get_texture().get_image().save_png(
					ProjectSettings.globalize_path("res://shots/%s.png" % name))
			print("shot ", name)
	get_tree().quit(0)
