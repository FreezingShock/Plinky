shader_type canvas_item;
// Post pass. Put on a ColorRect that shows the 642x362 world viewport.
// outline -> light bands -> 4x4 Bayer dither -> palette -> zone shift / invert / ASCII.

uniform sampler2D world : filter_nearest;
uniform sampler2D palette_a : filter_nearest;   // current palette, 8x4: x = role, y = ramp step (Palettes.texture)
uniform sampler2D palette_b : filter_nearest;   // palette being shifted to, same layout
uniform float shift : hint_range(0.0, 1.0) = 0.0;   // palette blend, dithered per texel
uniform float invert : hint_range(0.0, 1.0) = 0.0;  // 1 = palette index 7 - i
uniform float ascii : hint_range(0.0, 1.0) = 0.0;   // ASCII redraw wipe amount
uniform ivec2 dither_origin = ivec2(0);             // snapped camera offset in texels, pins Bayer to the world
uniform float shimmer_step = 0.0;                   // integer, stepped at 10 fps by Fx
uniform float shimmer_amount : hint_range(0.0, 0.3) = 0.10;
uniform int bg_index : hint_range(0, 7) = 1;
uniform int ground_id = 1;
uniform vec4 ripples[8];       // xy centre texel, z progress 0..1, w radius scale (0 = unused)

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
// 8x8 glyphs for " .:-=+*#%@", rows 0-3 in HI, rows 4-7 in LO, one byte per row.
const uint GLYPH_HI[10] = uint[10](0x0u, 0x0u, 0x181800u, 0x7e000000u, 0x7e0000u, 0x7e181800u, 0xff3c6600u, 0x24ff2424u, 0x180cc6c3u, 0xa599423cu);
const uint GLYPH_LO[10] = uint[10](0x0u, 0x181800u, 0x181800u, 0x0u, 0x7eu, 0x18187eu, 0x663cu, 0x2424ff24u, 0xc36330u, 0x3c4299u);

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float hash(ivec2 p, float s) {
	return fract(sin(dot(vec2(p) + s * vec2(17.1, 31.7), vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 fetch(ivec2 t) {
	ivec2 sz = textureSize(world, 0);
	return texelFetch(world, clamp(t, ivec2(0), sz - ivec2(1)), 0);
}

int object_id(vec4 c) {
	return int(round(c.b * 255.0));
}

vec3 palette_color(int idx, int step, ivec2 t) {
	idx = clamp(idx, 0, 7);
	step = clamp(step, 0, 3);
	vec3 a = texelFetch(palette_a, ivec2(idx, step), 0).rgb;
	vec3 b = texelFetch(palette_b, ivec2(idx, step), 0).rgb;
	return (shift > bayer4(t)) ? b : a;
}

// Returns (role, ramp step). Step 2 is the anchor colour; the light band picks 1 to 3, 0 is the deepest shade.
ivec2 shade_index(ivec2 t) {
	vec4 c = fetch(t);
	int id = object_id(c);
	if (id == 0) {
		return ivec2(bg_index, 2);
	}
	// 1. outline: this texel borders a different object (or empty)
	if (object_id(fetch(t + ivec2(1, 0))) != id || object_id(fetch(t + ivec2(-1, 0))) != id
			|| object_id(fetch(t + ivec2(0, 1))) != id || object_id(fetch(t + ivec2(0, -1))) != id) {
		return ivec2(0, 0);
	}
	int lit = int(floor(c.r * 8.0));
	// 2. three light bands. Flat areas (all 3x3 neighbours in the same band) get no dither, so grass and path read as
	// solid patches. Band seams keep a softer Bayer edge (0.2 amplitude) and the shimmer.
	float thr = bayer4(t + dither_origin);
	float shim = (hash(t, shimmer_step) - 0.5) * shimmer_amount * 2.0;
	float band_value = c.g * 3.0;
	float band_lo = floor(band_value);
	bool is_flat = true;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (floor(fetch(t + ivec2(dx, dy)).g * 3.0) != band_lo) {
				is_flat = false;
			}
		}
	}
	float s = is_flat ? band_value : band_value + (thr - 0.5) * 0.2 + shim;
	int level = clamp(int(floor(s)), 0, 2);
	// 3. press ripples: two rings on the ground plane (iso ellipse, 2:1) lighten one band
	if (id == ground_id && thr > 0.4) {
		vec2 p = vec2(t) + 0.5;
		for (int i = 0; i < 8; i++) {
			vec4 r = ripples[i];
			if (r.w > 0.0) {
				float d = length((p - r.xy) * vec2(1.0, 2.0));
				float k = r.z;
				if (abs(d - 30.0 * r.w * k) < 1.1 || abs(d - 52.0 * r.w * k) < 0.8) {
					level = min(level + 1, 2);
				}
			}
		}
	}
	int role = max(lit - (2 - level), min(lit, 1));
	// unlit texels take the deepest step; otherwise the light band sets the step (1 shade, 2 base, 3 lit)
	int step = (lit == 0) ? 0 : level + 1;
	return ivec2(role, step);
}

vec3 resolve(ivec2 t) {
	ivec2 s = shade_index(t);
	if (invert > 0.5) {
		s.x = 7 - s.x;
	}
	return palette_color(s.x, s.y, t);
}

void fragment() {
	ivec2 t = ivec2(UV * vec2(textureSize(world, 0)));
	vec3 col = resolve(t);
	if (ascii > 0.0) {
		ivec2 tt = t - ivec2(1);                       // align cells to the 640x360 area
		ivec2 cell = ivec2(floor(vec2(tt) / 8.0));
		if (ascii >= 1.0 || ascii > bayer4(cell)) {
			ivec2 base = cell * 8 + ivec2(1);
			vec3 avg = (resolve(base + ivec2(2, 2)) + resolve(base + ivec2(5, 2))
					+ resolve(base + ivec2(2, 5)) + resolve(base + ivec2(5, 5))) * 0.25;
			float lum = dot(avg, vec3(0.299, 0.587, 0.114));
			int g = clamp(int(lum * 9.999), 0, 9);
			ivec2 lp = tt - cell * 8;
			uint row = (lp.y < 4) ? GLYPH_HI[g] : GLYPH_LO[g];
			uint bits = (row >> uint((lp.y & 3) * 8)) & 255u;
			bool on = ((bits >> uint(7 - lp.x)) & 1u) == 1u;
			col = on ? avg : palette_color(0, 0, t);
		}
	}
	COLOR = vec4(col, 1.0);
}
