class_name WaterNightGlow
extends ColorRect
## Night glow on Larkmoor's water: variant E of render/shaders/water_night.gdshader. One moon light lies on the
## water as a dithered road with glints, and the shore glows inside the water and spills up the bank.
## It sits in the Sky node after the shade and the light grade, so it adds on top of the night and never darkens.
## Strength follows SkyCycle.night01, so it is off by day and the rect is hidden then. GraphicsQuality LOW drops the
## rings, and Reduce Motion and Reduce Flashing freeze the glints.

const GLOW_SHADER: Shader = preload("res://render/shaders/water_night.gdshader")
## Clock steps per second for the glints (stepped, so they blink on a beat rather than flicker).
const GLINT_STEP: float = 1.25

var _sky: SkyCycle


## Adds the glow over the world area of `sky`, for the water in the ground G-buffer `nrm` (its material codes), drawn with
## the texture's top-left at world texel `origin` (the ground's position). Reads the night level every frame.
func setup(sky: SkyCycle, nrm: Texture2D, origin: Vector2) -> void:
	_sky = sky
	name = "WaterNightGlow"
	position = sky.area.position
	size = sky.area.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("nrm_tex", nrm)
	m.set_shader_parameter("tex_size", Vector2(nrm.get_width(), nrm.get_height()))
	m.set_shader_parameter("tex_origin", origin)
	# variant E: a single moon light, a stronger road and a shore glow, no shafts
	m.set_shader_parameter("shimmer", 1.0)
	m.set_shader_parameter("beams", 0.0)
	m.set_shader_parameter("halo", 0.9)
	m.set_shader_parameter("body", 0.8)
	m.set_shader_parameter("road", 0.34)
	m.set_shader_parameter("glow_col", Color(0.965, 0.937, 0.851))
	material = m
	visible = false


func _process(_delta: float) -> void:
	if _sky == null:
		return
	var night: float = _sky.night01
	visible = night > 0.01
	if not visible:
		return
	var m: ShaderMaterial = material as ShaderMaterial
	m.set_shader_parameter("amount", night)
	m.set_shader_parameter("sway", 0.0 if MeadowLife.reduce_motion else floorf(Time.get_ticks_msec() / 1000.0 * GLINT_STEP))
	m.set_shader_parameter("twinkle", 0.0 if FxConfig.reduce_flashing else 1.0)
	m.set_shader_parameter("quality", GraphicsQuality.level)
