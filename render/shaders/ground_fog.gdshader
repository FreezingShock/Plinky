shader_type canvas_item;
// Drifting ground fog over the land. Two slow bands of streaky noise slide sideways at different speeds, thicker
// toward the top (far) of the frame. A texel takes the fog colour when the density beats the 4x4 Bayer matrix in
// WORLD texels (wpos), so the dots move with the ground, never with the screen.
uniform vec3 fog_col : source_color = vec3(0.72, 0.86, 0.72);
uniform float amount = 0.0;      // 0..1, scaled by time of day and weather in SkyCycle
uniform float drift = 0.0;       // integer texels the fog has drifted
uniform float top_y = -60.0;     // world y of the far edge of the frame
uniform float span_y = 420.0;    // world height the fog gradient covers

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	vec2 p = vec2(t) + 0.5;
	float far_k = 1.0 - clamp((p.y - top_y) / span_y, 0.0, 1.0);
	float n = vnoise(vec2((p.x - drift) * 0.018, p.y * 0.07)) * 0.6 + vnoise(vec2((p.x - drift * 1.8) * 0.045 + 11.0, p.y * 0.16)) * 0.4;
	float dens = amount * smoothstep(0.32, 0.78, n) * (0.35 + 0.65 * far_k);
	if (dens > bayer4(t) * 0.6 + 0.04) {
		COLOR = vec4(fog_col, 0.55);
	} else {
		COLOR = vec4(0.0);
	}
}
