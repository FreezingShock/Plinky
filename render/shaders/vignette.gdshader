shader_type canvas_item;
render_mode blend_mul;
// Frame-fixed vignette. Two dithered steps darken the corners; the rest of the frame is untouched.
// Pattern is pinned to screen texels (this node is not in the camera's world), so it does not crawl when you pan.

uniform float strength = 0.35;    // 0 = off
uniform vec3 tint : source_color = vec3(0.60, 0.68, 0.80);
uniform vec3 deep : source_color = vec3(0.42, 0.50, 0.66);

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 spos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	spos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 q = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float d = length(q * vec2(0.9, 1.15));
	float v = smoothstep(0.62, 1.25, d) * strength;
	float thr = bayer4(ivec2(floor(spos)));
	vec3 m = vec3(1.0);
	if (thr < v) {
		m = (thr < v * 0.4) ? deep : tint;
	}
	COLOR = vec4(m, 1.0);
}
