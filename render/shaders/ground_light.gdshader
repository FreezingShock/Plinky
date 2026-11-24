shader_type canvas_item;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Ground relight. The meadow ground is a baked render with a same-size G-buffer made by tools/art/gen_meadow3d.py:
//   nrm_tex  R,G normal (u, v), B material code, A baked light (see depth_pass.write_relight_data)
//   h_tex    world height, 1..255 over h_lo..h_hi, 0 outside the scene
// Every ground texel is re-lit: N.L against the moving sun, a height-march toward the sun for long cast shadows
// (terrain and slopes shade each other), then the colour is re-picked from the material ramp with a Bayer dither.
// Far texels (top of the frame) take a dithered depth fog. Everything stays on the palette.
#include "res://render/shaders/prop_ramps.gdshaderinc"
#include "res://render/shaders/season.gdshaderinc"
uniform sampler2D nrm_tex : filter_nearest;
uniform sampler2D h_tex : filter_nearest;
uniform vec3 sun_dir = vec3(-0.45, 0.45, 0.85);
uniform vec2 sun_px = vec2(-1.0, -1.0);         // screen direction toward the sun, texels per march step
uniform float relight = 0.0;                    // 0 = baked look
uniform float shadow_amt = 0.0;                 // how dark the cast shadow makes the light value
uniform float shadow_slope = 2.6;               // encoded height units a step may rise before it blocks the sun
uniform float ao_amt = 0.0;
uniform int march_steps = 12;                   // height-march taps toward the sun (GraphicsQuality: Low 6 at double the stride)
uniform int ao_taps = 4;                        // occlusion taps around the texel (Low 2)
uniform float shadow_reach = 2.0;               // texels per march step; longer when the sun is low
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.52, 0.80);   // cool colour multiplied into shadowed texels
uniform int debug_view = 0;                     // 0 off, 1 albedo, 2 normal, 3 height, 4 shadow only, 5 lit (F6 cycles)
uniform vec3 fog_col : source_color = vec3(0.7, 0.85, 0.7);
uniform float fog_amt = 0.0;                    // 0..1 at the far edge
// Rain (SkyCycle sets these; see wet_ground). wet darkens the soil and fills dips with water, splash is how much
// rain is landing now (0 under Reduce motion, so the rings stop but the puddles stay), glint is the sun on the water.
uniform float wet = 0.0;                        // 0..1, a lagged rain: a shower fills puddles and they drain after it
uniform float splash = 0.0;                     // 0..1 rain landing now: how many ground cells ring at once
uniform vec3 puddle_col : source_color = vec3(0.2, 0.36, 0.36);
uniform float glint = 0.0;                      // 0..1: sun on the water, sparkle and sky sheen
const vec3 BASE_DIR = vec3(-0.3495, 0.3828, 0.8557);
varying vec2 wpos;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

// Rain on the ground, in world texels (iso: y is stretched 2:1 like the season blobs). Soil darkens and cools as it
// wets. Puddles are smooth noise plus a bonus for dips in the height map, with a Bayer edge, so they sit low and
// grow with the shower. Drops land as small rings (cells on the iso grid, each with its own drop point and phase).
// Under snow cover there is no open water: the wet and the puddles fade out.
vec3 wet_ground(vec3 c, vec2 wp, vec2 uv, vec2 px, float thr, float h0) {
	float open_k = 1.0 - smoothstep(0.1, 0.5, season_snow);
	float w = wet * open_k;
	if (w > 0.001) {
		c = mix(c, c * vec3(0.88, 0.92, 0.95), 0.6 * w);
		vec2 iso = vec2(wp.x, wp.y * 2.0);
		float n = season_vnoise(iso / 9.0 + 31.0) * 0.7 + season_vnoise(iso / 3.0 + 13.0) * 0.3;
		// the height of the texels four steps away: a texel lower than its surroundings is a dip that holds water
		float ring_h = (texture(h_tex, uv + vec2(4.0, 0.0) * px).r + texture(h_tex, uv - vec2(4.0, 0.0) * px).r
				+ texture(h_tex, uv + vec2(0.0, 4.0) * px).r + texture(h_tex, uv - vec2(0.0, 4.0) * px).r) * 0.25 * 255.0;
		float dip = clamp((ring_h - h0 - 0.5) / 2.0, 0.0, 1.0);
		float score = n + 0.25 * dip;
		float edge = 0.9 - 0.25 * w;
		float cover = smoothstep(edge - 0.04, edge + 0.04, score);   // the Bayer threshold makes the edge dither
		if (cover > thr) {
			float sheen = smoothstep(edge + 0.04, edge + 0.16, score);
			vec3 water = puddle_col * (0.85 + 0.25 * glint);
			water = mix(water, vec3(0.72, 0.85, 0.47), sheen * 0.6 * glint);   // the sky, lit: palette 4
			c = water;
			if (glint > 0.05 && season_hash(floor(wp) + 0.5) > 0.985 - 0.012 * glint) {
				c = PAL[7];
			}
		}
	}
	if (splash > 0.01) {
		vec2 iso = vec2(wp.x, wp.y * 2.0);
		vec2 cell = floor(iso / 9.0);
		float h = season_hash(cell + 3.7);
		if (h < 0.14 * splash) {
			float h2 = season_hash(cell * 1.7 + 9.1);
			float age = fract(TIME * (0.7 + 0.5 * h2) + h * 7.0);
			vec2 at = (cell + vec2(0.25 + 0.5 * h2, 0.25 + 0.5 * fract(h * 13.0))) * 9.0;
			float d = length(iso - at);
			float r = age * 5.0;
			if (abs(d - r) < 0.6 && age < 0.95) {
				c = mix(c, vec3(0.92, 0.95, 0.9), 0.65 * (1.0 - 0.6 * age));
			}
		}
	}
	return c;
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 base = c;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float thr = bayer4(ivec2(floor(wpos)));
	if (relight > 0.0 && c.a > 0.5) {
		vec4 d = texture(nrm_tex, UV);
		int code = int(d.b * 255.0 + 0.5);
		if (code >= 10 && code < 110 && RAMP_LEN[code] > 0) {
			vec3 n = vec3(d.rg * 2.0 - 1.0, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			float lb = d.a * 1.8 - 0.4;
			float l = lb + 1.05 * (max(dot(n, normalize(sun_dir)), 0.0) - max(dot(n, BASE_DIR), 0.0)) * relight;
			// height march toward the sun: a higher texel in the way puts this one in shadow; a high ring around it is occlusion
			float h0 = texture(h_tex, UV).r * 255.0;
			float sh = 0.0;
			float occ = 0.0;
			// No cast shadow and no occlusion to apply means no taps to spend (identical result, most of the day's cost).
			if (shadow_amt * relight > 0.002 || debug_view == 4) {
				for (int k = 1; k <= 12; k++) {
					if (k > march_steps) {
						break;
					}
					float hn = texture(h_tex, UV + sun_px * float(k) * shadow_reach * px).r * 255.0;
					if (hn > 0.5 && hn - h0 > shadow_slope * float(k) * shadow_reach) {
						sh = 1.0;
					}
				}
			}
			if (ao_amt > 0.0) {
				for (int j = 0; j < 4; j++) {
					if (j >= ao_taps) {
						break;
					}
					int k = (ao_taps == 2) ? j * 3 : j;   // two taps use the opposite diagonal pair
					vec2 o = vec2(float(k % 2) * 2.0 - 1.0, float(k / 2) * 2.0 - 1.0) * 3.0 * px;
					float hn = texture(h_tex, UV + o).r * 255.0;
					occ += clamp((hn - h0 - 4.0) / 24.0, 0.0, 1.0) / float(ao_taps);
				}
			}
			l -= sh * shadow_amt * relight + occ * ao_amt;
			if (abs(l - lb) > 0.03) {
				int cnt = RAMP_LEN[code] - 1;
				float v = clamp(l, 0.0, 0.9999) * float(cnt);
				float lo = floor(v);
				float f = clamp((v - lo - 0.44) / 0.12, 0.0, 1.0);   // a narrow blend band: steps are solid, the dither only softens the seam
				int step_i = int(lo) + ((f > thr && int(lo) < cnt) ? 1 : 0);
				c.rgb = PAL[RAMP_IDX[RAMP_START[code] + step_i]];
			}
			if (sh > 0.5) {
				c.rgb *= mix(vec3(1.0), shadow_tint, min(shadow_amt, 1.0));
			}
			if (debug_view == 4) {
				c.rgb = vec3(sh);
			}
		}
	}
	// Water (material 107) and its foam (108) keep their own palette in every season: the water ramp's greens
	// (47,107,85) pass the "green texel" test in season_recolor and were dyed orange like the grass.
	int mat_code = int(texture(nrm_tex, UV).b * 255.0 + 0.5);
	bool is_water = mat_code == 107 || mat_code == 108;
	if (c.a > 0.5 && debug_view == 0 && !is_water && (season_amt > 0.0 || season_snow > 0.0)) {
		c.rgb = season_recolor(c.rgb, wpos);
	}
	if (c.a > 0.5 && debug_view == 0 && !is_water && (wet > 0.001 || splash > 0.01)) {
		c.rgb = wet_ground(c.rgb, wpos, UV, px, thr, texture(h_tex, UV).r * 255.0);
	}
	// depth fog: the far (top) rows fade toward the haze colour, dithered
	float far_k = pow(1.0 - UV.y, 1.6) * fog_amt;
	if (c.a > 0.5) {
		c.rgb = mix(c.rgb, fog_col, clamp(far_k, 0.0, 1.0) * 0.6);
	}
	if (debug_view == 1) {
		c = base;
	} else if (debug_view == 2) {
		c = vec4(texture(nrm_tex, UV).rg, 0.5, base.a);
	} else if (debug_view == 3) {
		c = vec4(vec3(texture(h_tex, UV).r), base.a);
	}
	COLOR = c;
}
