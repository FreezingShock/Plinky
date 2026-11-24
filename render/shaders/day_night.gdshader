shader_type canvas_item;
render_mode blend_mul;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Light and shade over the meadow. Every texel is either left alone or multiplied by one of a few tints,
// chosen by the 4x4 Bayer matrix in world texels, so the result is dither, never a smooth blend (art bible
// sections 2 and 4). Uniforms are densities 0..1 set by SkyCycle.
//  - night: one smooth cool tint over the whole frame. Where it thins (the edge of a light pool, dusk and dawn)
//    it is a smooth gradient, so night reads as a calm tone, never as a checkerboard or a grid.
//  - grade: the time-of-day colour grade (peach at sunrise, gold in the afternoon, orange and magenta at dusk).
//  - rain: cool grey.
//  - lights: pools around lanterns, shrine, gate, pads and the walker. Inside a pool the night shade thins out
//    and a warm tint comes in, so the light reads as clearing the dark, not as a sticker on top of it.

uniform float night = 0.0;
uniform float rain = 0.0;
uniform vec3 grade_col : source_color = vec3(1.0);
uniform float grade_amount = 0.0;
uniform vec3 night_tint : source_color = vec3(0.32, 0.40, 0.78);
uniform vec3 deep_tint : source_color = vec3(0.16, 0.20, 0.42);
uniform vec3 rain_tint : source_color = vec3(0.82, 0.88, 0.92);
uniform vec3 pool_tint : source_color = vec3(1.0, 0.86, 0.58);
uniform vec4 lights[48];       // xy centre (world texels), z radius, w strength 0..1 (0 = unused). Must match SkyCycle.MAX_LIGHTS.
uniform float pool_strength = 0.9;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	vec2 p = vec2(t) + 0.5;
	float thr = bayer4(t);
	// light pools: sum of falloffs on the 2:1 ground ellipse
	float pool = 0.0;
	for (int i = 0; i < 48; i++) {
		vec4 L = lights[i];
		if (L.w > 0.0) {
			float d = length((p - L.xy) * vec2(1.0, 2.0)) / max(L.z, 1.0);
			pool += clamp(1.0 - d, 0.0, 1.0) * L.w;
		}
	}
	pool = clamp(pool * pool_strength, 0.0, 1.0);
	vec3 m = vec3(1.0);
	// night: a smooth, solid cool multiply that thins toward the light pools. No dither at all: a pool edge or dusk
	// is a soft gradient over many world texels, so it reads as light, never as a grid.
	float dk = clamp(night * (1.0 - pool) / 0.8, 0.0, 1.0);
	m *= mix(vec3(1.0), night_tint, 0.62 * dk);
	// warm cast inside a pool, smooth the same way, so a lantern is a clean glow
	float wk = clamp(pool * (0.35 + 0.65 * night) * 2.2, 0.0, 1.0) * smoothstep(0.05, 0.2, pool);
	m *= mix(vec3(1.0), pool_tint, 0.8 * wk);
	// the time-of-day grade and rain are solid tints: a smooth change over hours, never a screen-wide pattern
	m *= mix(vec3(1.0), grade_col, clamp(grade_amount, 0.0, 1.0));
	m *= mix(vec3(1.0), rain_tint, clamp(rain * 0.5, 0.0, 1.0));
	COLOR = vec4(m, 1.0);
}
