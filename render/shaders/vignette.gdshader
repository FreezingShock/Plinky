shader_type canvas_item;
render_mode blend_mul;
// World-anchored edge shade. Two dithered steps darken the far edges of the playable area; the rest is untouched.
// Both the shape and the dither are pinned to world texels (w_origin, w_scale), so nothing here follows the camera:
// panning toward an edge darkens it, panning back clears it.

uniform vec2 w_origin = vec2(0.0);   // where the world origin sits in frame texels (set by ScreenLight)
uniform float w_scale = 1.0;        // frame texels per world texel (camera zoom)
uniform vec2 area_center = vec2(320.0, 180.0);   // world texels
uniform vec2 area_half = vec2(430.0, 250.0);
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
	vec2 wt = (spos - w_origin) / w_scale;
	vec2 q = (wt - area_center) / area_half;
	float d = length(q * vec2(0.9, 1.15));
	float v = smoothstep(0.80, 1.30, d) * strength;
	float thr = bayer4(ivec2(floor(wt)));
	vec3 m = vec3(1.0);
	if (thr < v) {
		m = (thr < v * 0.4) ? deep : tint;
	}
	COLOR = vec4(m, 1.0);
}
