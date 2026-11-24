class_name TitleWipe
extends ColorRect
## Themed scene change for the title and loading screens: a slanted, dithered sweep of the time of day's ink, with a
## sun-coloured lead line, drawn over the whole screen. Under Reduce Motion nothing sweeps: the overlay cross-fades
## in over FADE_SECONDS instead. Built and played by the screen that is leaving.

const SHADER: Shader = preload("res://boot/title_wipe.gdshader")
const FADE_SECONDS: float = 0.3

var _mat: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("canvas_texels", Vector2(640.0, 360.0))
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade", 1.0)
	material = _mat


## Colours from the mood the wipe leaves: ink covers, accent leads.
func setup(ink: Color, accent: Color) -> void:
	_mat.set_shader_parameter("ink", ink)
	_mat.set_shader_parameter("accent", accent)


## Play the wipe, then call on_covered once the screen is ink.
func play(seconds: float, reduce: bool, on_covered: Callable) -> void:
	var tw := create_tween()
	if reduce:
		_mat.set_shader_parameter("progress", 2.0)
		_mat.set_shader_parameter("fade", 0.0)
		tw.tween_method(_set_fade, 0.0, 1.0, FADE_SECONDS)
	else:
		tw.tween_method(_set_progress, 0.0, 1.0, maxf(seconds, 0.05))
	tw.tween_callback(on_covered)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	_mat.set_shader_parameter("fade", 1.0)


func _set_fade(v: float) -> void:
	_mat.set_shader_parameter("fade", v)
