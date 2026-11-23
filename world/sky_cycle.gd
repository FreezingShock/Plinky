class_name SkyCycle
extends Node2D
## Day/night cycle, rain and wind for the meadow. MeadowScene adds it as a child. It owns:
##  - a dithered shade overlay (render/shaders/day_night.gdshader) at z 5, above the walker, pads and props
##    and below LifeAir (z 10), so fireflies, lantern and shrine glow stay bright at night;
##  - SkyRain at z 11;
##  - the sway material that MeadowScene puts on trees and bushes, and the shared wind value that LifeGround reads.
## All timing comes from SkyModel (core/sky_model.gd), tuned by content/config/sky.tres.
## Reduce motion (MeadowLife.reduce_motion): no rain streaks, no sway. The shade still turns, slowly.

const CONFIG_PATH: String = "res://content/config/sky.tres"
const SHADE_SHADER: Shader = preload("res://render/shaders/day_night.gdshader")
const SWAY_SHADER: Shader = preload("res://render/shaders/wind_sway.gdshader")
const AREA: Rect2 = Rect2(-110.0, -70.0, 860.0, 500.0)   # covers the 840x480 bleed at (-100, -60) plus margin
const SWAY_PAD: int = 4                                    # transparent texels added each side of a swaying sprite
const SWAY_STEP: float = 1.0 / 8.0

## Debug and screenshot overrides. Negative = off.
static var debug_phase: float = -1.0
static var debug_rain: float = -1.0

## The rect the shade and rain cover. The meadow uses AREA; bigger scenes (Larkmoor) set their own before add_child.
var area: Rect2 = AREA
var model: SkyModel = SkyModel.new()
var sway_material: ShaderMaterial
var rain_layer: SkyRain
var _shade_mat: ShaderMaterial
var _config: SkyConfig
var _t: float = 0.0
var _sway_step: int = -1


func _ready() -> void:
	z_index = 5
	_config = load(CONFIG_PATH) as SkyConfig
	if _config == null:
		_config = SkyConfig.new()
	_apply_config()
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.position = area.position
	shade.size = area.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = SHADE_SHADER
	shade.material = _shade_mat
	add_child(shade)
	rain_layer = SkyRain.new()
	rain_layer.name = "Rain"
	rain_layer.z_index = 6   # relative to this node: z 11 overall
	rain_layer.area = area
	rain_layer.drops = int(round(float(_config.rain_drops) * minf(area.get_area() / AREA.get_area(), 2.0)))   # denser over a bigger field, capped for cost
	add_child(rain_layer)
	sway_material = ShaderMaterial.new()
	sway_material.shader = SWAY_SHADER
	sway_material.set_shader_parameter("max_texels", _config.sway_max_texels)
	_update(0.0)


func _apply_config() -> void:
	model.day_seconds = _config.day_seconds
	model.start_phase = _config.start_phase
	model.night_strength = _config.night_strength
	model.dusk_strength = _config.dusk_strength
	model.rain_period_a = _config.rain_period_a
	model.rain_period_b = _config.rain_period_b
	model.rain_phase_a = _config.rain_phase_a
	model.rain_phase_b = _config.rain_phase_b
	model.rain_threshold = _config.rain_threshold
	model.rain_max = _config.rain_max
	model.wind_calm = _config.wind_calm
	model.wind_rain_boost = _config.wind_rain_boost
	model.gust_period_a = _config.gust_period_a
	model.gust_period_b = _config.gust_period_b


func _process(delta: float) -> void:
	_t += delta
	_update(_t)


## Time to feed the model: a debug phase pins the time of day, otherwise session time runs.
func _model_time(t: float) -> float:
	if debug_phase >= 0.0:
		return (debug_phase - model.start_phase) * model.day_seconds
	return t


func _update(t: float) -> void:
	var mt: float = _model_time(t)
	_shade_mat.set_shader_parameter("night", model.night(mt))
	_shade_mat.set_shader_parameter("dusk", model.dusk(mt))
	var rain: float = model.rain(t) if debug_rain < 0.0 else debug_rain
	var wind: float = model.wind(t)
	if debug_rain >= 0.0:
		wind = maxf(wind, 0.5)
	_shade_mat.set_shader_parameter("rain", rain)
	MeadowLife.wind = 0.0 if MeadowLife.reduce_motion else wind
	rain_layer.visible = not MeadowLife.reduce_motion
	rain_layer.intensity = rain / maxf(model.rain_max, 0.001)
	rain_layer.wind = wind
	var s: int = int(t / SWAY_STEP)
	if s != _sway_step:
		_sway_step = s
		sway_material.set_shader_parameter("step_time", float(s) * SWAY_STEP)
		sway_material.set_shader_parameter("wind", wind)
		sway_material.set_shader_parameter("enabled", 0.0 if MeadowLife.reduce_motion else 1.0)


## Copy of `tex` with SWAY_PAD transparent texels each side, so a leaning crown is not clipped by the sprite edge.
static func padded(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out: Image = Image.create(img.get_width() + SWAY_PAD * 2, img.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(SWAY_PAD, 0))
	return ImageTexture.create_from_image(out)
