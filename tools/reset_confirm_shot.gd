extends Node
## Captures the zone reset confirm (ui/reset_confirm.gd) and the ritual flight from its icon, from main.tscn.
## Run (windowed): godot --path . tools/reset_confirm_shot.tscn -- [out_dir] [reset: nucleus|bloom]
## Frames: the card open, a half hold, a full hold (the ritual launches), then the coin mid-flight.

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await _wait(2)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	print("save ", path, " err=", img.save_png(path))


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://captures/reset_confirm")
	var reset_id: StringName = StringName(args[1]) if args.size() > 1 else &"nucleus"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.gates_open[&"larkmoor"] = true
	sim.gates_open[&"zone2"] = true
	sim.zone_id = &"zone2" if reset_id == &"nucleus" else &"zone1"
	sim.dev_open_tiers()
	var forge: float = sim.reset_ref(reset_id)
	sim.stats[&"emberheart" if reset_id == &"nucleus" else &"starbloom"] = BigNum.from_float(forge * 9.0)
	sim.stats[&"shards" if reset_id == &"nucleus" else &"seeds"] = BigNum.from_float(1204.0)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(60)
	GameState.onboarding.tips_enabled = false
	var hud: Hud = main.get("hud") as Hud
	var welcome: Control = hud.get("_welcome") as Control
	if welcome != null:
		welcome.visible = false   # the offline summary would cover the card
	Tip.hide_all()
	hud._on_zone_reset_pressed(reset_id)
	var confirm: ResetConfirm = hud.get("_reset_confirm") as ResetConfirm
	await _shot(out_dir.path_join("%s_0_open.png" % reset_id))
	# frame-count holds drift with render speed, so the capture pins the hold and stops the drain while it shoots
	confirm.set_process(false)
	for frac: float in [0.5, 0.9]:
		confirm._held = ResetConfirm.HOLD_TIME * frac
		confirm._refresh_fill()
		await _shot(out_dir.path_join("%s_%s.png" % [reset_id, "1_half" if frac < 0.7 else "2_near_full"]))
	# rings: a live hold for a few frames, so the rings spawn and grow over the badge
	confirm.set_process(true)
	confirm._held = ResetConfirm.HOLD_TIME * 0.4
	confirm._pressing = true
	await _wait(5)
	await _shot(out_dir.path_join("%s_1b_rings.png" % reset_id))
	confirm._pressing = false
	confirm._held = ResetConfirm.HOLD_TIME * 0.5
	# the hold strikes: the card hides and the ritual flies the coin from the badge
	confirm._held = ResetConfirm.HOLD_TIME * 0.9
	confirm._pressing = true
	var guard: int = 0
	while confirm.visible and guard < 120:
		guard += 1
		await get_tree().process_frame
	confirm._pressing = false
	await _wait(2)
	await _shot(out_dir.path_join("%s_3_struck.png" % reset_id))
	await _wait(18)
	await _shot(out_dir.path_join("%s_4_flight.png" % reset_id))
	get_tree().quit(0)
