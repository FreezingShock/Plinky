class_name TitleBackground
extends ColorRect
## The title screen's full-screen backdrop: title_background.gdshader draws the layered dusk meadow, and this node
## feeds it the palette, the clock and a smoothed mouse parallax (in texels). Reduce motion freezes the parallax.

const SHADER: Shader = preload("res://boot/title_background.gdshader")
## Largest parallax shift of the nearest layer, in texels, at the screen edge.
const PARALLAX_TEXELS: float = 8.0
const EASE: float = 4.0

var parallax: Vector2 = Vector2.ZERO

var _mat: ShaderMaterial
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var cols: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	for i in 8:
		_mat.set_shader_parameter("c%d" % i, cols[i])
	_mat.set_shader_parameter("canvas_texels", Vector2(640.0, 360.0))
	material = _mat


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
	var want: Vector2 = Vector2.ZERO
	if not (FxConfig.reduce_flashing or MeadowLife.reduce_motion):
		want = parallax_for(get_local_mouse_position(), size)
	parallax = parallax.lerp(want, clampf(EASE * delta, 0.0, 1.0))
	_mat.set_shader_parameter("parallax", parallax)


## 0 shows the scene, 1 covers it with ink.
func set_dissolve(amount: float) -> void:
	_mat.set_shader_parameter("dissolve", clampf(amount, 0.0, 1.0))
