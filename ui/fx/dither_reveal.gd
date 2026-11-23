class_name DitherReveal
extends ColorRect
## Ink overlay that wipes a panel in or out as a 4x4 Bayer dither, stepped (no smooth fades).
## cover 1 = fully inked, 0 = clear. Sits on top of a panel, ignores the mouse.

const STEPS: int = 6
const SHADER: String = """
shader_type canvas_item;
uniform float cover = 1.0;
uniform vec4 ink : source_color = vec4(0.08, 0.09, 0.11, 1.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	float b = (BAYER[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
	COLOR = vec4(ink.rgb, cover > b ? 1.0 : 0.0);
}
"""

var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	visible = false


## Set the cover, snapped to STEPS levels. Hidden when clear.
func set_cover(v: float) -> void:
	var s: float = floorf(clampf(v, 0.0, 1.0) * STEPS) / STEPS
	visible = s > 0.0
	_mat.set_shader_parameter("cover", s)
	_mat.set_shader_parameter("ink", RelicStyle.ink)
