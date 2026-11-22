shader_type canvas_item;
// Tree and bush sway. Rows lean sideways by whole texels, more toward the top (h squared), so the foot
// stays planted and the crown moves in clean pixel steps. The sprite is padded by SkyCycle.SWAY_PAD texels
// on each side so the lean is never clipped. `step_time` is stepped by SkyCycle, not continuous.

uniform float wind = 0.2;
uniform float step_time = 0.0;
uniform float max_texels = 3.0;
uniform float enabled = 1.0;
varying float phase;

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.043 + MODEL_MATRIX[3].y * 0.017;
}

void fragment() {
	float h = 1.0 - UV.y;
	float height_px = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float size_k = clamp(height_px / 60.0, 0.3, 1.0);
	float s = sin(step_time * 1.6 + phase) * 0.55 + sin(step_time * 3.7 + phase * 2.0) * 0.45 * wind;
	float lean = (0.25 + 0.75 * wind) * s * h * h * max_texels * size_k * enabled;
	float off = floor(lean + 0.5);
	vec2 uv = UV - vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0) {
		c = vec4(0.0);
	}
	COLOR = c;
}
