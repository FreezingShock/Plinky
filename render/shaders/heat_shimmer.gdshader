shader_type canvas_item;
// Heat shimmer over the Ember Quarry's lava and vents (world/quarry_light.gd). Moves the picture behind it by whole
// screen texels, so the air above the heat wavers. The shift comes from slow 2D noise, not a row wave: a texel moves
// only where the noise beats its 4x4 Bayer threshold, so the edges dither in small patches instead of forming full
// width bands with straight cut-offs. Only the hottest ground (a soft heat threshold) shimmers. Hidden under
// Reduce Motion by the script.

const int MAX_EMIT = 64;
const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 emit[MAX_EMIT];
uniform vec4 emit_col[MAX_EMIT];
uniform int emit_count = 0;
uniform float clock = 0.0;
uniform float amount = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h2(i);
	float b = h2(i + vec2(1.0, 0.0));
	float c = h2(i + vec2(0.0, 1.0));
	float d = h2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void fragment() {
	float heat = 0.0;
	for (int i = 0; i < MAX_EMIT; i++) {
		if (i >= emit_count) {
			break;
		}
		if (emit_col[i].a > 1.5) {
			continue;   // lava and vents only; braziers and lamps do not shimmer
		}
		vec4 e = emit[i];
		float d = distance(wpos, e.xy) / max(e.z * 2.0, 0.001);
		heat += max(0.0, 1.0 - d) * e.w;
	}
	heat = clamp(heat, 0.0, 1.0);
	float mask = smoothstep(0.15, 0.6, heat) * clamp(amount, 0.0, 1.0);
	// Slow noise: long in x and short in y, so each patch is a few texels tall, never a full-width row.
	float n = vnoise(wpos * vec2(0.06, 0.22) + vec2(0.0, -clock * 1.5)) * 2.0 - 1.0;
	float thr = bayer4(ivec2(floor(wpos)));
	float shift = (abs(n) * mask > thr) ? sign(n) : 0.0;
	COLOR = texture(screen_tex, SCREEN_UV + vec2(shift * SCREEN_PIXEL_SIZE.x, 0.0));
}
