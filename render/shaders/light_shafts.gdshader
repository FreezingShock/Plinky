shader_type canvas_item;
render_mode blend_add;
// Light shafts that fall through the canopy. Sunlight comes in as parallel lanes that run along the sun's travel
// direction (world texels). Each lane is hashed on its own: some carry a beam, some do not, and each beam has its
// own width and offset. A slow noise field breaks the beams into pieces and thins them where the canopy is dense,
// so the light reads as gaps in the trees rather than an even sheen. The result is a Bayer threshold, so every edge
// is a dither step, not a smooth fade. Two layers share one pass: wide soft beams and thin fine rays.
// Added on top of the scene (blend_add), so a lit texel is one step lighter than what is underneath.
// Only the golden hour drives it (SkyModel.shafts); it is off at night and in rain.

global uniform vec2 world_origin;
global uniform float world_scale;

uniform float amount_beam = 0.0;     // 0..1 strength of the wide beams, already scaled by time of day
uniform float amount_ray = 0.0;      // 0..1 strength of the thin rays
uniform vec2 travel = vec2(0.5, 1.0);   // direction the light travels, world texels (normalised in the shader)
uniform vec3 ray_col : source_color = vec3(1.0, 0.82, 0.55);
uniform float beam_spacing = 96.0;   // lane width across the travel direction, texels
uniform float beam_density = 0.55;   // share of lanes that carry a beam
uniform float beam_segment = 150.0;  // length of one lit stretch along a beam, texels
uniform float ray_spacing = 34.0;
uniform float ray_density = 0.4;
uniform float ray_segment = 90.0;
uniform float gap_scale = 230.0;     // size of the canopy-gap noise, texels
uniform float sway = 0.0;            // stepped phase, 0 when motion is reduced (the beams hold still)

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// One layer of lanes. Returns 0..1: how bright this point of the layer is before dithering.
float shaft_layer(vec2 p, vec2 d, vec2 pp, float spc, float wmin, float wmax, float dens, float seg_len, float seed) {
	float u = dot(p, pp) / spc;
	float lane = floor(u);
	float f = fract(u);
	float h_on = hash21(vec2(lane, seed));
	float h_w = hash21(vec2(lane, seed + 3.1));
	float h_c = hash21(vec2(lane, seed + 7.7));
	float on = step(h_on, dens);
	float w = mix(wmin, wmax, h_w);
	float centre = 0.5 + (h_c - 0.5) * (1.0 - w);      // keeps the band inside its lane
	float across = 1.0 - smoothstep(w * 0.35, w * 0.5, abs(f - centre));
	float along = dot(p, d) + sway * 9.0 * h_c;
	float seg = smoothstep(0.25, 0.6, value_noise(vec2(along / seg_len, lane * 3.7 + seed)));
	float gap = smoothstep(0.3, 0.7, value_noise(p / gap_scale + vec2(lane * 0.37, seed * 1.3)));
	return on * across * seg * gap;
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	vec2 p = vec2(t) + 0.5;
	vec2 d = normalize(travel);
	vec2 pp = vec2(-d.y, d.x);
	float beam = shaft_layer(p, d, pp, beam_spacing, 0.22, 0.5, beam_density, beam_segment, 1.7) * amount_beam;
	float ray = shaft_layer(p, d, pp, ray_spacing, 0.08, 0.2, ray_density, ray_segment, 5.3) * amount_ray;
	float inten = clamp((beam + ray) * 1.4, 0.0, 1.0);
	float lit = step(bayer4(t), inten);   // dithered: a texel lights where its intensity beats the matrix
	COLOR = vec4(ray_col * ray_col * 0.55, lit * 0.5);
}
