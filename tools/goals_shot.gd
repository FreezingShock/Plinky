extends Node
## Captures the Next Goal ribbon (bottom right, beside the Menu chip) and the top-left stat strip from main.tscn, then quits.
## Run (windowed, not --headless): godot --path . tools/goals_shot.tscn -- [fresh|done|late] [out_dir]
##   fresh  Dewdrops unlocked, the first goal in progress
##   done   every mid-game goal reached (the card should be gone once the goals panel hides)
##   late   every stat row visible with big numbers, first goal in progress
## Writes <out_dir>/goals_<fixture>.png (full frame), goals_<fixture>_corner_4x.png (top-left crop, 4x) and
## goals_<fixture>_bottom_right_4x.png (the Menu chip row, 4x).
## out_dir defaults to res://captures. Point APPDATA/user:// at a scratch folder so the real save is never touched.

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixture: String = args[0] if args.size() > 0 else "fresh"
	var out_dir: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	GameState.onboarding.tips_enabled = false   # unlock every row and gate
	var sim: Sim = GameState.sim
	if fixture == "late" or fixture == "done":
		sim.rebirth_count = 12
		var big: float = 1.0e15
		for sid: StringName in sim.stat_defs:
			sim.stats[sid] = BigNum.from_float(big)
			big *= 37.0
	if fixture == "done":
		var counters: Dictionary = {}
		for d: GoalDef in sim.goals.sorted:
			counters[d.counter] = 1.0e18
		sim.goals.check(counters)
	await _wait(60)   # rolling counters and the card's refresh settle
	var hud: Hud = main.get("hud") as Hud
	await _wait(10)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	print("save ", out_dir.path_join("goals_%s.png" % fixture), " err=", img.save_png(out_dir.path_join("goals_%s.png" % fixture)))
	var scale: float = float(img.get_width()) / 640.0
	var h: float = (hud.stats_bottom() + 4.0) * scale if hud != null else 160.0 * scale
	var crop: Image = img.get_region(Rect2i(0, 0, int(200.0 * scale), int(h)))
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	print("save ", out_dir.path_join("goals_%s_corner_4x.png" % fixture), " err=", crop.save_png(out_dir.path_join("goals_%s_corner_4x.png" % fixture)))
	var bw: int = int(220.0 * scale)
	var bh: int = int(44.0 * scale)
	var br: Image = img.get_region(Rect2i(img.get_width() - bw, img.get_height() - bh, bw, bh))
	br.resize(br.get_width() * 4, br.get_height() * 4, Image.INTERPOLATE_NEAREST)
	print("save ", out_dir.path_join("goals_%s_bottom_right_4x.png" % fixture), " err=", br.save_png(out_dir.path_join("goals_%s_bottom_right_4x.png" % fixture)))
	get_tree().quit(0)
