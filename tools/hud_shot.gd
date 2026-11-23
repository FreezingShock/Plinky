extends Node
## Captures the HUD stats panel (top-left currency rows) from main.tscn and saves PNGs, then quits.
## Run (windowed, not --headless): godot --path . tools/hud_shot.tscn -- [early|late] [out_dir]
##   early  fresh game: just the first rows
##   late   late-game fixture: every row visible (Slag, Prestige xN, Rebirth Points) with big numbers
##   edit   the late fixture in edit mode with one row hidden (move and hide controls, the add chips, Custom count)
## Writes <out_dir>/hud_<fixture>.png (full frame) and hud_<fixture>_panel_4x.png (panel crop, 4x).
## out_dir defaults to res://captures. Point APPDATA/user:// at a scratch folder so the real save is never touched.

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixture: String = args[0] if args.size() > 0 else "late"
	var out_dir: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	if fixture == "late" or fixture == "edit":
		var sim: Sim = GameState.sim
		GameState.onboarding.tips_enabled = false   # unlock every row and gate
		sim.rebirth_count = 12
		var big: float = 1.0e15
		for sid: StringName in sim.stat_defs:
			sim.stats[sid] = BigNum.from_float(big)
			big *= 37.0
		await _wait(60)   # rolling counters settle
	var hud: Hud = main.get("hud") as Hud
	if fixture == "edit" and hud != null:
		hud.call("_hide_row", &"clover")
		hud.set_edit_mode(true)
		await _wait(10)
	await _wait(10)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	print("save ", out_dir.path_join("hud_%s.png" % fixture), " err=", img.save_png(out_dir.path_join("hud_%s.png" % fixture)))
	var scale: float = float(img.get_width()) / 640.0
	var h: float = (hud.stats_bottom() + 4.0) * scale if hud != null else 120.0 * scale
	var crop: Image = img.get_region(Rect2i(0, 0, int(300.0 * scale), int(h)))
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	print("save ", out_dir.path_join("hud_%s_panel_4x.png" % fixture), " err=", crop.save_png(out_dir.path_join("hud_%s_panel_4x.png" % fixture)))
	get_tree().quit(0)
