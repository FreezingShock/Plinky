class_name TitleBackground
extends ColorRect
## The title and loading backdrop. title_background.gdshader draws the layers; this node runs the day clock (SkyModel
## over TitleMood), lerps the palette, sun or moon, stars and rays through the day, and feeds the mouse parallax.
## Skip moves the clock forward to the next time of day. Reduce Motion freezes the clock on golden hour and makes
## skips instant.

const SHADER: Shader = preload("res://boot/title_background.gdshader")
## Largest parallax shift of the nearest layer, in texels, at the screen edge.
const PARALLAX_TEXELS: float = 8.0
const EASE: float = 4.0
## A skip to the next time of day runs the sky forward over this many seconds.
const SEEK_SECONDS: float = 1.6

var parallax: Vector2 = Vector2.ZERO
## Session seconds on the day clock. The sky reads TitleMood.START_PHASE at 0.
var clock: float = 0.0
var sky: SkyModel = TitleMood.make_sky()

var _mat: ShaderMaterial
var _time: float = 0.0
var _seek_from: float = 0.0
var _seek_to: float = 0.0
## Seconds into the current skip, or -1 when no skip is running.
var _seek_t: float = -1.0
var _mood: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("canvas_texels", Vector2(640.0, 360.0))
	material = _mat
	if still():
		clock = TitleMood.seconds_for(sky, TitleMood.START_PHASE)
	_apply()


## True when motion is reduced: the clock holds, parallax stays put and skips are instant.
static func still() -> bool:
	return FxConfig.reduce_flashing or MeadowLife.reduce_motion


## Pure: mouse position in the title's rect -> target parallax in texels (-1..1 of PARALLAX_TEXELS on each axis,
## y damped). Clamped, so a cursor outside the window never flings the layers.
static func parallax_for(mouse: Vector2, rect_size: Vector2) -> Vector2:
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Vector2.ZERO
	var n := Vector2(clampf(mouse.x / rect_size.x * 2.0 - 1.0, -1.0, 1.0), clampf(mouse.y / rect_size.y * 2.0 - 1.0, -1.0, 1.0))
	return Vector2(-n.x, -n.y * 0.4) * PARALLAX_TEXELS


func _process(delta: float) -> void:
	_time += delta
	_mat.set_shader_parameter("time", _time)
	if _seek_t >= 0.0:
		_seek_t += delta
		var f: float = clampf(_seek_t / SEEK_SECONDS, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		clock = lerpf(_seek_from, _seek_to, f)
		if _seek_t >= SEEK_SECONDS:
			_seek_t = -1.0
	elif not still():
		clock += delta
	var want: Vector2 = Vector2.ZERO
	if not still():
		want = parallax_for(get_local_mouse_position(), size)
	parallax = parallax.lerp(want, clampf(EASE * delta, 0.0, 1.0))
	_mat.set_shader_parameter("parallax", parallax)
	_apply()


## Push the current time of day into the shader.
func _apply() -> void:
	_mood = TitleMood.sample(phase())
	var sky_cols: PackedColorArray = _mood["sky"]
	for i in 8:
		_mat.set_shader_parameter("c%d" % i, sky_cols[i])
	var ground_cols: PackedColorArray = _mood["ground"]
	for i in 4:
		_mat.set_shader_parameter("g%d" % i, ground_cols[i])
	_mat.set_shader_parameter("body_xy", TitleMood.body(sky, clock))
	_mat.set_shader_parameter("star_amt", TitleMood.stars(sky, clock))
	_mat.set_shader_parameter("rays", sky.rays(clock))
	_mat.set_shader_parameter("glow", sky.golden(clock))


## Position in the day, 0..1.
func phase() -> float:
	return sky.phase(clock)


## Name of the time of day on screen, for the time chip.
func time_name() -> String:
	return str(_mood.get("name", ""))


## The whole time-of-day sample (sky, ground, tint, shade, name), for the screens built over the backdrop.
func mood() -> Dictionary:
	return _mood


## The mood's colour at one sky role (0 ink .. 7 paper), for the screens built over the backdrop.
func role(i: int) -> Color:
	var sky_cols: PackedColorArray = _mood.get("sky", PackedColorArray())
	return sky_cols[clampi(i, 0, 7)] if sky_cols.size() == 8 else Color.BLACK


## Move the clock so the sky reads phase p at once (used to open a screen at a chosen time of day).
func set_phase_now(p: float) -> void:
	clock = TitleMood.seconds_for(sky, p)
	_seek_t = -1.0
	_apply()


## Run the sky forward to the next time of day on the chip. Instant under Reduce Motion.
func skip_to_next() -> void:
	if _seek_t >= 0.0:
		return
	var ahead: float = fposmod(TitleMood.next_phase(phase()) - phase(), 1.0)
	var seconds: float = ahead * sky.day_seconds
	if still():
		clock += seconds
		_apply()
		return
	_seek_from = clock
	_seek_to = clock + seconds
	_seek_t = 0.0


## 0 shows the scene, 1 covers it with ink.
func set_dissolve(amount: float) -> void:
	_mat.set_shader_parameter("dissolve", clampf(amount, 0.0, 1.0))
