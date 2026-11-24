extends Node
## Captures the Bloom animation from main.tscn: one PNG per moment plus a contact sheet, then quits.
## Run (windowed, not --headless): godot --path . tools/bloom_shot.tscn -- [full|calm] [out_dir]
##   full  the whole show (default)
##   calm  the gentle version (Reduce flashing / Still meadow): a fade, no flash, rings or particles
## Writes <out_dir>/bloom_<mode>_NN_tMMMM.png and <out_dir>/bloom_<mode>_sheet.png. out_dir defaults to res://captures/bloom.
## Point APPDATA/user:// at a scratch folder so the real save is never touched.

## The exit (after hold_end = 3.95 s, fly_end = 4.5 s in the full show) is sampled densely: the coin's steps, the ring and motes.
const MOMENTS: Array[float] = [0.0, 0.5, 1.0, 1.3, 1.52, 1.62, 1.75, 1.95, 2.3, 3.0, 3.9, 4.05, 4.2, 4.35, 4.5, 4.7]


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ritual(hud: Control) -> BloomRitual:
	for c: Node in hud.get_children():
		if c is BloomRitual:
			return c as BloomRitual
	return null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "full"
	var out_dir: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://captures/bloom")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "calm":
		FxConfig.reduce_flashing = true
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	if mode == "calm":
		FxConfig.reduce_flashing = true   # again, in case loading the game reset it
	var sim: Sim = GameState.sim
	GameState.onboarding.tips_enabled = false
	sim.gates_open[&"larkmoor"] = true
	sim.dev_force_zone(&"larkmoor")
	sim.dev_open_tiers()
	var reward: float = sim.reset_ref(&"bloom")
	for sid: StringName in [&"dewdrop", &"clover", &"thistle", &"heather", &"foxglove"]:
		sim.stats[sid] = BigNum.from_float(12345.0 * 7.0)
	sim.stats[&"starbloom"] = BigNum.from_float(reward * 9.0)
	sim.stats[&"sunlight"] = BigNum.from_float(98765.0)
	await _wait(60)   # rows appear and settle
	var hud: Hud = main.get("hud") as Hud
	var ritual: BloomRitual = _ritual(hud)
	var shots: Array[Image] = []
	print("bloom pays ", sim.reset_gain(&"bloom"), " seeds, mode ", mode)
	GameState.try_reset(&"bloom")
	var i: int = 0
	var guard: int = 0
	while i < MOMENTS.size() and guard < 2000:
		guard += 1
		await get_tree().process_frame
		var t: float = ritual.get("_t") as float
		if t < 0.0 and guard > 10:
			break
		if t >= MOMENTS[i]:
			var img: Image = get_tree().root.get_viewport().get_texture().get_image()
			var name: String = "bloom_%s_%02d_t%04d.png" % [mode, i, int(t * 1000.0)]
			print("save ", out_dir.path_join(name), " err=", img.save_png(out_dir.path_join(name)))
			shots.append(img)
			i += 1
	if shots.is_empty():
		get_tree().quit(1)
		return
	# Contact sheet: three columns, each frame at half size, nearest.
	var w: int = shots[0].get_width() / 2
	var h: int = shots[0].get_height() / 2
	var cols: int = 3
	var rows: int = int(ceil(float(shots.size()) / float(cols)))
	var sheet: Image = Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for k in shots.size():
		var small: Image = shots[k].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	var sheet_path: String = out_dir.path_join("bloom_%s_sheet.png" % mode)
	print("save ", sheet_path, " err=", sheet.save_png(sheet_path))
	get_tree().quit(0)
