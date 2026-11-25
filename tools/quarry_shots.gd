extends Node
## Ember Quarry tour: the hub, the gate and the lava pools at zoom 1 (the quarry is a 1400x760 canvas, so the view follows
## the walker), then one pad per row at zoom 3. Pass "locked" for the locked look. Pass "phase=0.0" (midnight)
## to "phase=0.5" (noon) to pin the sky's time of day, so before and after shots compare like for like.
## Run: godot --path . tools/quarry_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver)

var main: Control



func _shot(name: String) -> void:
	await ShotHelpers.wait(3)
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(20)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	var locked: bool = "locked" in OS.get_cmdline_user_args()
	var pinned: float = -1.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("phase="):
			pinned = arg.trim_prefix("phase=").to_float()
	sim.gates_open[&"zone1"] = true
	sim.gates_open[&"larkmoor"] = true
	sim.zone_id = &"zone2"
	if not locked:
		sim.dev_open_tiers()
	for k: StringName in [&"embers", &"cinder", &"ironore", &"slag", &"ingot", &"alloy", &"emberheart"]:
		sim.stats[k] = BigNum.from_float(1.0e5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var tag: String = "_locked" if locked else ""
	if pinned >= 0.0:
		var sky: SkyCycle = main.meadow.find_child("Sky", true, false) as SkyCycle
		if sky != null:
			sky.debug_phase = pinned
		tag += "_p%s" % str(pinned).replace(".", "")
		await ShotHelpers.wait(30)
	var spawn: Vector2 = main.walker.position
	await _goto(spawn, 1)
	await _shot("q_hub" + tag)
	var anchors: Node = main.meadow.get_node("Anchors")
	var lava_i: int = 0
	for c: Node in anchors.get_children():
		if String(c.name) in ["Gate", "Arch"] or (String(c.name).begins_with("Lava") and lava_i < 4):
			if String(c.name).begins_with("Lava"):
				lava_i += 1
			await _goto((c as Marker2D).position + Vector2(0, 18), 1)
			await _shot("q_%s%s" % [String(c.name).to_lower(), tag])
	var ids: Array = sim.current_zone().pad_buttons
	for row in 6:
		var pad: Node2D = main.pads.get(ids[row * 3 + 1]) as Node2D
		if pad == null:
			continue
		await _goto(pad.position + Vector2(0, 14), 3)
		await _shot("q_row%d%s" % [row + 1, tag])
	get_tree().quit(0)
