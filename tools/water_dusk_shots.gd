extends Node
## Water at dusk and night, Starting Clearing: pins the sky to dusk (or night), adds the water sky-reflection overlay
## (render/shaders/water_night.gdshader, parameter lift) and saves PNGs of the lake to shots/ (dusk_<tag>_<spot>.png).
## Used for the T6 dusk lift mockup, so every variant shows the same spots under the same sky.
##
## Run: godot --path . tools/water_dusk_shots.tscn -- <tag>
##   before            the current dusk, no overlay
##   L1, L2            the lift at 0.6 and 1.0 (the shader's lift parameter)
## Add _night to the tag to pin midnight, or _noon for noon, instead of dusk. Headless servers: xvfb-run with the software Vulkan driver.

const DUSK: float = 0.74
const NOON: float = 0.5
const MIDNIGHT: float = 0.9
const SPOTS: Array = [["lake", "Water_lake", 2], ["lake_close", "Water_lake", 3], ["pond", "Water_pond", 3], ["sea", "Water_lake", 1]]
const MEADOW_OVERVIEW: Vector2 = Vector2(415, 258)
const GLOW_SHADER: Shader = preload("res://render/shaders/water_night.gdshader")
const LIFTS: Dictionary = {"L1": 0.6, "L2": 1.0}

var main: Control
var root: Window
var tag: String = "before"



func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(20)


## Takes over the game's own water glow node (world/water_night_glow.gd: same G-buffer, texel origin and sky area), so the
## lift lands on the right water. Its per-frame night driver is switched off, and only the lift is left on.
func _add_lift(sky: Node2D, strength: float) -> void:
	var node := sky.get_node_or_null("WaterNightGlow") as ColorRect
	if node == null:
		push_error("no WaterNightGlow node under Sky")
		return
	node.set_process(false)
	node.visible = true
	var m := node.material as ShaderMaterial
	m.set_shader_parameter("amount", 1.0)
	m.set_shader_parameter("shimmer", 0.0)
	m.set_shader_parameter("beams", 0.0)
	m.set_shader_parameter("halo", 0.0)
	m.set_shader_parameter("body", 0.0)
	m.set_shader_parameter("haze", 0.0)
	m.set_shader_parameter("bloom", 0.0)
	m.set_shader_parameter("lift", strength)
	m.set_shader_parameter("lift_col", Color(0.965, 0.937, 0.851))
	m.set_shader_parameter("sway", 0.0)
	m.set_shader_parameter("twinkle", 0.0)


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://shots/dusk_%s_%s.png" % [tag, name]))
	print("shot ", tag, " ", name)


func _ready() -> void:
	root = get_tree().root
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var parts: PackedStringArray = tag.split("_")
	var base: String = parts[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"zone1"
	SkyCycle.debug_season = 0
	SkyCycle.debug_phase = MIDNIGHT if "night" in parts else (NOON if "noon" in parts else DUSK)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var sky: Node2D = main.meadow.get_node("Sky") as Node2D
	if LIFTS.has(base):
		_add_lift(sky, float(LIFTS[base]))
		await ShotHelpers.wait(10)
	var anchors: Node = main.meadow.get_node("Anchors")
	for spot: Array in SPOTS:
		var m: Marker2D = anchors.get_node(String(spot[1])) as Marker2D
		var offset: Vector2 = Vector2(0, 70) if String(spot[0]) == "sea" else Vector2(0, 40)
		await _goto(m.position + offset, int(spot[2]))
		await ShotHelpers.wait(30)
		_save(String(spot[0]))
	await _goto(MEADOW_OVERVIEW, 1)
	await ShotHelpers.wait(30)
	_save("overview")
	get_tree().quit(0)
