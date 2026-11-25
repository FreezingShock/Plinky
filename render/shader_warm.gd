class_name ShaderWarm
extends RefCounted
## Draws every world shader once, on screen, for a few frames at start. The first draw of a shader compiles it,
## which stalls one frame (measured 166 ms on a first Larkmoor sunset, tools/bench.gd). Done here the stall lands at
## start instead of mid-play. The quads are 2x2 texels at near-zero alpha. Off-screen or hidden draws do not
## compile anything, which is why a hidden-then-shown layer cannot warm itself.

const SHADERS: Array[String] = [
	"res://render/shaders/god_rays.gdshader",
	"res://render/shaders/light_shafts.gdshader",   # Larkmoor's canopy shafts: first draw at a sunset compiled mid-frame
	"res://render/shaders/sky_haze.gdshader",
	"res://render/shaders/day_night.gdshader",
	"res://render/shaders/wind_sway.gdshader",
	"res://render/shaders/cast_shadow.gdshader",
	"res://render/shaders/vignette.gdshader",
	"res://render/shaders/cross_wipe.gdshader",
	"res://render/shaders/ground_light.gdshader",
	"res://render/shaders/ground_fog.gdshader",
	"res://render/shaders/light_grade.gdshader",
	"res://render/shaders/quarry_prop.gdshader",   # the Ember Quarry's props, glow, haze and heat shimmer: a first
	"res://render/shaders/quarry_glow.gdshader",   # draw in the zone swap compiled them mid-wipe
	"res://render/shaders/quarry_haze.gdshader",
	"res://render/shaders/heat_shimmer.gdshader",
	"res://render/shaders/pad_shadow.gdshader",    # every pad plate: its first draw in a zone compiled mid-wipe
	"res://render/shaders/water_night.gdshader",   # the night glow on the lake and pond
	"res://render/shaders/toon.gdshader",
	"res://world/grass_blades.gdshader",          # interactive grass blades (Low keeps the baked tips)
	"res://ui/fx/bloom_veil.gdshader",            # gifts and ritual veil
]
const FRAMES: int = 4


static func run(parent: Node) -> void:
	RenderGlobals.ensure()
	var layer := CanvasLayer.new()
	layer.name = "ShaderWarm"
	layer.layer = 126
	parent.add_child(layer)
	for path: String in SHADERS:
		var sh: Shader = load(path) as Shader
		if sh == null:
			continue
		var r := ColorRect.new()
		r.size = Vector2(2.0, 2.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.modulate = Color(1.0, 1.0, 1.0, 0.01)
		var m := ShaderMaterial.new()
		m.shader = sh
		r.material = m
		layer.add_child(r)
	_finish(layer)


static func _finish(layer: CanvasLayer) -> void:
	for i: int in FRAMES:
		await layer.get_tree().process_frame
	layer.queue_free()
