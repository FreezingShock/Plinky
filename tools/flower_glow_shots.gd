extends Node
## Night mockups for the pad glow and the flower-field glow (world/flower_glow.gd): starts the real game in Larkmoor, pins the
## sky to midnight and saves PNGs to shots/ as flower_<tag>_<spot>.png. One process per variant, so each look starts clean.
##
## Run: xvfb-run -a godot --path . tools/flower_glow_shots.tscn -- <tag>
##   before   the pads' old big halo and no flower glow (the screenshot Nathan sent)
##   A        small pad glow, field light at the default head size
##   B        small pad glow, small head radius: each flower head reads as its own glint
##   C        small pad glow, broad soft field wash

const MIDNIGHT: float = 0.9
const DISTRICT: String = "reedgate"   # the Sprout row: its pads are the ones in Nathan's screenshot
const SMALL_PAD: Dictionary = {"GLOW_SPREAD_DAY": 0.25, "GLOW_SPREAD_NIGHT": 0.35, "HAZE_REACH": 0.6}
const VARIANTS: Dictionary = {
	"before": {"flower": false},
	"A": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 11.0, "SATURATE": 2.2, "NIGHT_ALPHA": 0.9}},
	"B": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 6.0, "SATURATE": 1.0, "NIGHT_ALPHA": 0.8}},
	"C": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 16.0, "SATURATE": 3.5, "NIGHT_ALPHA": 0.7}},
	"D": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 11.0, "SATURATE": 2.2, "NIGHT_ALPHA": 0.9, "SPILL_RADIUS": 26.0, "SPILL_SATURATE": 0.8, "SPILL_ALPHA": 0.6}},
	"E": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 11.0, "SATURATE": 2.2, "NIGHT_ALPHA": 0.9, "SPILL_RADIUS": 38.0, "SPILL_SATURATE": 1.0, "SPILL_ALPHA": 0.8}},
	"F": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 11.0, "SATURATE": 2.2, "NIGHT_ALPHA": 0.6, "SPILL_RADIUS": 26.0, "SPILL_SATURATE": 2.0, "SPILL_ALPHA": 0.3}},
	"G": {"pad": SMALL_PAD, "flower": {"HEAD_RADIUS": 11.0, "SATURATE": 2.2, "NIGHT_ALPHA": 0.6, "SPILL_RADIUS": 34.0, "SPILL_SATURATE": 2.5, "SPILL_ALPHA": 0.35}},
	"H": {"flower": {"HEAD_RADIUS": 6.0, "SATURATE": 1.2, "NIGHT_ALPHA": 0.6, "SPILL_RADIUS": 34.0, "SPILL_SATURATE": 2.5, "SPILL_ALPHA": 0.35}},
}

var main: Control
var root: Window
var tag: String = "before"


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


func _save(name: String) -> void:
	_clear_overlays()
	await _wait(2)
	root.get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://shots/flower_%s_%s.png" % [tag, name]))
	print("shot ", tag, " ", name)


## Hides the pop-ups a headless run gets in the way of: the HUD and its tip cards, the pad tooltip, and the pointer
## warped off the pads so no tooltip opens. The HUD is hidden too, so the glow is what the frame shows.
func _clear_overlays() -> void:
	main.hud.visible = false
	main.tooltip.hide_tip()   # the main loop re-shows the tooltip for a pad under the pointer, so keep the pointer off the pads
	root.warp_mouse(Vector2(2.0, 178.0))


func _ready() -> void:
	root = get_tree().root
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var v: Dictionary = VARIANTS.get(tag, VARIANTS["before"]) as Dictionary
	# The pad glow sizes are constants now (the shipped small ring), so the mockup knobs only drive the flower glow.
	var fl: Variant = v.get("flower", {})
	if fl is Dictionary:
		var f: Dictionary = fl as Dictionary
		if f.has("HEAD_RADIUS"):
			FlowerGlow.HEAD_RADIUS = float(f["HEAD_RADIUS"])
		if f.has("SATURATE"):
			FlowerGlow.SATURATE = float(f["SATURATE"])
		if f.has("NIGHT_ALPHA"):
			FlowerGlow.NIGHT_ALPHA = float(f["NIGHT_ALPHA"])
		if f.has("SPILL_RADIUS"):
			FlowerGlow.SPILL_RADIUS = float(f["SPILL_RADIUS"])
		if f.has("SPILL_SATURATE"):
			FlowerGlow.SPILL_SATURATE = float(f["SPILL_SATURATE"])
		if f.has("SPILL_ALPHA"):
			FlowerGlow.SPILL_ALPHA = float(f["SPILL_ALPHA"])
	else:
		FlowerGlow.enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	SkyCycle.debug_season = 0
	SkyCycle.debug_phase = MIDNIGHT
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(60)
	for id: StringName in sim.stat_defs.keys():   # every pad affordable (green), as in Nathan's screenshot
		sim.dev_set_stat(id, BigNum.make(1.0, 9))
	await _wait(10)
	var anchors: Node = main.meadow.get_node("Anchors")
	var m: Marker2D = anchors.get_node("District_" + DISTRICT) as Marker2D
	await _goto(m.position + Vector2(0, 10), 2)
	await _wait(30)
	_save("district_z2")
	await _goto(m.position + Vector2(0, 40), 3)
	await _wait(30)
	_save("pad_z3")
	await _goto(Vector2(760, 470), 1)
	await _wait(30)
	_save("overview")
	get_tree().quit(0)
