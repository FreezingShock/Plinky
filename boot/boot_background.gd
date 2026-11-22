class_name BootBackground
extends ColorRect
## Full-screen animated backdrop for the boot screen: dithered sky, sun, two rolling hill bands,
## a moving wind shimmer and a dithered vignette. Colour comes only from meadow palette indices;
## all the drawing happens in boot_background.gdshader.

const SHADER: Shader = preload("res://boot/boot_background.gdshader")

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


func _process(delta: float) -> void:
	_time += delta
	_mat.set_shader_parameter("time", _time)


## 0 shows the scene, 1 covers it with ink. Driven by the boot screen's dissolve tween.
func set_dissolve(amount: float) -> void:
	_mat.set_shader_parameter("dissolve", clampf(amount, 0.0, 1.0))
