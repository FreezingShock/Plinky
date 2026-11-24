extends Node
## Water at night: starts the real game in Larkmoor, pins the sky to midnight and saves PNGs of the water to shots/
## (water_<tag>_<spot>.png): Heronmere lake and the eastern pond at zoom 2 and 3, plus a wide overview at zoom 1.
## Used for the night-glow mockups, so every variant shows the same spots under the same sky.
##
## Run: godot --path . tools/water_night_shots.tscn -- <tag>
##   before            the current night, no glow
##   A, B, C           the three mockup variants (render/shaders/water_night.gdshader), see VARIANTS
##   B_low             variant B at GraphicsQuality LOW (the fallback)
## Headless servers: xvfb-run with the software Vulkan driver.

const MIDNIGHT: float = 0.9
const SPOTS: Array = [["lake", "Water_lake", 2], ["lake_close", "Water_lake", 3], ["pond", "Water_pond", 2]]
const GLOW_SHADER: Shader = preload("res://render/shaders/water_night.gdshader")
## Per-variant knobs for the shader. Colours stay in the meadow palette (paper, lime, deep green).
const VARIANTS: Dictionary = {
	"A": {"shimmer": 1.0, "beams": 0.0, "halo": 0.35, "body": 0.3, "glow": Color(0.965, 0.937, 0.851)},
	"B": {"shimmer": 0.8, "beams": 1.0, "halo": 0.5, "body": 0.6, "glow": Color(0.965, 0.937, 0.851)},
	"C": {"shimmer": 0.2, "beams": 0.6, "halo": 1.0, "body": 1.0, "glow": Color(0.718, 0.851, 0.471)},
}

var main: Control
var root: Window
var tag: String = "before"
var _glow: ShaderMaterial


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


## Full-frame overlay inside the Sky node (z 5, after the shade and the light grade), so the glow adds on top of the night.
func _add_glow(sky: Node2D, variant: Dictionary) -> void:
	_glow = ShaderMaterial.new()
	_glow.shader = GLOW_SHADER
	_glow.set_shader_parameter("nrm_tex", load("res://assets/art/zone1b/larkmoor/ground_n.png"))
	_glow.set_shader_parameter("amount", 1.0)
	_glow.set_shader_parameter("shimmer", float(variant.shimmer))
	_glow.set_shader_parameter("beams", float(variant.beams))
	_glow.set_shader_parameter("halo", float(variant.halo))
	_glow.set_shader_parameter("body", float(variant.body))
	_glow.set_shader_parameter("glow_col", variant.glow)
	_glow.set_shader_parameter("sway", 2.0)
	_glow.set_shader_parameter("twinkle", 1.0)
	_glow.set_shader_parameter("quality", GraphicsQuality.level)
	var rect := ColorRect.new()
	rect.name = "WaterNightGlow"
	rect.position = sky.area.position
	rect.size = sky.area.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _glow
	sky.add_child(rect)


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://shots/water_%s_%s.png" % [tag, name]))
	print("shot ", tag, " ", name)


func _ready() -> void:
	root = get_tree().root
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var base: String = tag.trim_suffix("_low")
	if tag.ends_with("_low"):
		GraphicsQuality.set_level(GraphicsQuality.Level.LOW, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	SkyCycle.debug_season = 0
	SkyCycle.debug_phase = MIDNIGHT
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var sky: Node2D = main.meadow.get_node("Sky") as Node2D
	if VARIANTS.has(base):
		_add_glow(sky, VARIANTS[base])
		await _wait(10)
	var anchors: Node = main.meadow.get_node("Anchors")
	for spot: Array in SPOTS:
		var m: Marker2D = anchors.get_node(String(spot[1])) as Marker2D
		await _goto(m.position + Vector2(0, 40), int(spot[2]))
		await _wait(30)
		_save(String(spot[0]))
	await _goto(Vector2(949, 1028), 1)
	await _wait(30)
	_save("overview")
	get_tree().quit(0)
