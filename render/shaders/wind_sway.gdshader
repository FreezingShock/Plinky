shader_type canvas_item;
// Tree and bush sway. Rows lean sideways by whole texels, more toward the top (h squared), so the foot
// stays planted and the crown moves in clean pixel steps. The sprite is padded by SkyCycle.SWAY_PAD texels
// on each side so the lean is never clipped. `step_time` is stepped by SkyCycle, not continuous.

uniform float wind = 0.2;
uniform float step_time = 0.0;
uniform float max_texels = 3.0;
uniform float enabled = 1.0;
// Rim light: a lit texel next to the dark outline on the sun side. `rim_dir` is whole texels toward the light
// (x in -1..1, y -1 = up); `rim_amount` is the share of rim texels that light up (Bayer dither), 0 = off.
uniform vec2 rim_dir = vec2(-1.0, -1.0);
uniform float rim_amount = 0.0;
uniform vec3 rim_col : source_color = vec3(1.0, 0.95, 0.75);
varying float phase;
varying vec2 wpos;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.043 + MODEL_MATRIX[3].y * 0.017;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	if (rim_amount > 0.0 && c.a > 0.5 && lum(c.rgb) > 0.2) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec4 nh = texture(TEXTURE, uv + vec2(rim_dir.x, 0.0) * px);
		vec4 nv = texture(TEXTURE, uv + vec2(0.0, rim_dir.y) * px);
		bool edge_h = rim_dir.x != 0.0 && nh.a > 0.5 && lum(nh.rgb) < 0.2;
		bool edge_v = nv.a > 0.5 && lum(nv.rgb) < 0.2;
		if ((edge_h || edge_v) && bayer4(ivec2(floor(wpos))) < rim_amount) {
			c.rgb = mix(c.rgb, rim_col, 0.65);
		}
	}
	COLOR = c;
}
