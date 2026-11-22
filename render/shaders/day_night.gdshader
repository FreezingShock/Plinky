shader_type canvas_item;
render_mode blend_mul;
// Day/night shade over the meadow. Every texel is either left alone or multiplied by one of a few tints,
// chosen by the 4x4 Bayer matrix in world texels, so the shade is dither, never a smooth blend (art bible
// sections 2 and 4). Uniforms are densities 0..1 set by SkyCycle.

uniform float night = 0.0;
uniform float dusk = 0.0;
uniform float rain = 0.0;
uniform vec3 night_tint : source_color = vec3(0.50, 0.58, 0.82);
uniform vec3 deep_tint : source_color = vec3(0.30, 0.36, 0.62);
uniform vec3 dusk_tint : source_color = vec3(1.0, 0.76, 0.64);
uniform vec3 rain_tint : source_color = vec3(0.82, 0.88, 0.92);

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	float thr = bayer4(t);
	vec3 m = vec3(1.0);
	if (thr < night) {
		m *= (thr < night * 0.45) ? deep_tint : night_tint;
	}
	// dusk uses the opposite half of the matrix so it reads as a second, offset pattern
	if (1.0 - thr < dusk) {
		m *= dusk_tint;
	}
	if (thr > 1.0 - rain * 0.5) {
		m *= rain_tint;
	}
	COLOR = vec4(m, 1.0);
}
