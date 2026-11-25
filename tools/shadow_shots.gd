extends Node
## Shadow review tour: the real Larkmoor scene at chosen sun phases, walker moved to each district and the gate.
## Saves PNGs to shots/shadow_<phase>_<place>.png. Used to tune cast and ground shadows (softness, strength, length).
## Run: godot --path . tools/shadow_shots.tscn [-- season=N] [-- phases=0.5,0.66] [-- places=heronmere,gate]
## Defaults: autumn (season 2), noon 0.5 and golden hour 0.66, at the Heronmere grove, Foxglove Rise, Emberwatch and the gate.

var main: Control



func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(20)


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	for a: String in args:
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


func _set_ground_debug(n: Node, v: int) -> void:
	if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial:
		var m: ShaderMaterial = (n as CanvasItem).material as ShaderMaterial
		if m.shader != null and m.shader.resource_path.ends_with("ground_light.gdshader"):
			m.set_shader_parameter("debug_view", v)
	for c: Node in n.get_children():
		_set_ground_debug(c, v)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	SkyCycle.debug_season = int(_arg(args, "season", "2"))
	var phases: PackedStringArray = _arg(args, "phases", "0.5,0.66").split(",")
	var places: PackedStringArray = _arg(args, "places", "heronmere,thistle,emberwatch,gate").split(",")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var anchors: Node = main.meadow.get_node("Anchors")
	if "noquads" in args:   # shadow-quad layer off: shows what the ground height march alone draws
		var sh: Node = main.meadow.get_node_or_null("Shadows")
		if sh != null:
			(sh as CanvasItem).visible = false
	var dview: int = int(_arg(args, "dview", "0"))
	if dview != 0:   # ground relight debug: 1 albedo, 2 normal, 3 height, 4 cast shadow only, 5 lit
		_set_ground_debug(main.meadow, dview)
	for ph: String in phases:
		SkyCycle.debug_phase = float(ph)
		for pl: String in places:
			var m: Marker2D = null
			if pl == "gate":
				m = anchors.get_node("Gate") as Marker2D
			else:
				m = anchors.get_node("District_" + pl) as Marker2D
			if m == null:
				continue
			var zoom: int = 3 if pl == "gate" else 2
			await _goto(m.position + Vector2(0, 10), zoom)
			await ShotHelpers.wait(30)
			var name: String = "shadow_%s_%s%s" % [ph.replace(".", ""), pl, ("_noquads" if "noquads" in args else "") + ("_dview%d" % dview if dview != 0 else "")]
			get_tree().root.get_viewport().get_texture().get_image().save_png(
					ProjectSettings.globalize_path("res://shots/%s.png" % name))
			print("shot ", name)
	get_tree().quit(0)
