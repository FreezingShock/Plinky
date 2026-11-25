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
uniform float shadow_soft = 0.0;                // 0 hard-edged march, 1 feathered penumbra that fades with distance (SkyConfig.shadow_softness)
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.52, 0.80);   // cool colour multiplied into shadowed texels
uniform int debug_view = 0;                     // 0 off, 1 albedo, 2 normal, 3 height, 4 shadow only, 5 lit (F6 cycles)
uniform vec3 fog_col : source_color = vec3(0.7, 0.85, 0.7);
uniform float fog_amt = 0.0;                    // 0..1 at the far edge
// Rain (SkyCycle sets these; see wet_ground). wet darkens the soil and fills dips with water, splash is how much
// rain is landing now (0 under Reduce motion, so the rings stop but the puddles stay), glint is the sun on the water.
uniform float wet = 0.0;                        // 0..1, a lagged rain: a shower fills puddles and they drain after it
uniform float wet_night = 0.0;                  // 0..1, night x wet: the wet soil and path go darker under the moon
uniform float splash = 0.0;                     // 0..1 rain landing now: how many ground cells ring at once
uniform vec3 puddle_col : source_color = vec3(0.2, 0.36, 0.36);
uniform float glint = 0.0;                      // 0..1: sun on the water, sparkle and sky sheen
// Ground mist (SkyCycle: thick at dawn, gone by midday). A dithered low haze drifts over the ground.
uniform float mist = 0.0;                       // 0..1
uniform vec3 mist_col : source_color = vec3(0.82, 0.9, 0.88);
// Fallen blossom (SkyCycle: spring outdoors, none under snow). Pale petals gather in soft drifts on the iso grid.
uniform float blossom = 0.0;                    // 0..1: spring x outdoor
uniform vec3 blossom_col : source_color = vec3(0.95, 0.72, 0.8);
uniform vec3 water_floor = vec3(0.184, 0.420, 0.333);   // #2f6b55: water never drops below this mid tone, at any hour (T6)
uniform float mist_drift = 1.0;                 // 0 under Reduce motion: the haze holds still
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
// How far this texel sits below its ring of texels four steps away: 0 on flat ground, 1 in a clear hollow.
float texel_dip(vec2 uv, vec2 px, float h0) {
	float ring_h = (texture(h_tex, uv + vec2(4.0, 0.0) * px).r + texture(h_tex, uv - vec2(4.0, 0.0) * px).r
			+ texture(h_tex, uv + vec2(0.0, 4.0) * px).r + texture(h_tex, uv - vec2(0.0, 4.0) * px).r) * 0.25 * 255.0;
	return clamp((ring_h - h0 - 0.5) / 2.0, 0.0, 1.0);
}

// Winter drifts: snow lies deeper in the hollows, with a dithered edge, so the low ground goes white first.
vec3 snow_drifts(vec3 c, vec2 uv, vec2 px, float thr, float h0) {
	float dip = texel_dip(uv, px, h0);
	float depth = smoothstep(0.15, 0.6, dip) * season_snow;
	float edge = thr * 0.5 + 0.12;
	if (depth > edge) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = clamp(vec3(0.86, 0.92, 1.0) * (0.8 + 0.25 * l), 0.0, 1.0);
		// a cool shadow on the lip of each drift, where it steps down into the flat snow
		if (depth < edge + 0.12) {
			c *= vec3(0.8, 0.87, 0.97);
		}
	}
	return c;
}

// Fallen petals: a patch mask gathers them in drifts, and a per-texel hash scatters a sparse few inside each drift.
vec3 fallen_blossom(vec3 c, vec2 wp, float thr) {
	vec2 iso = vec2(wp.x, wp.y * 2.0);
	float patch = season_vnoise(iso / 9.0 + 5.0) * 0.7 + season_vnoise(iso / 3.0 + 11.0) * 0.3;
	float dens = smoothstep(0.45, 0.75, patch) * blossom;
	if (dens > thr && season_hash(floor(iso) + 0.5) < 0.25) {
		c = mix(c, blossom_col, 0.9);
	}
	return c;
}

vec3 wet_ground(vec3 c, vec2 wp, vec2 uv, vec2 px, float thr, float h0) {
	float open_k = 1.0 - smoothstep(0.1, 0.5, season_snow);
	float w = wet * open_k;
	if (w > 0.001) {
		c = mix(c, c * mix(vec3(0.88, 0.92, 0.95), vec3(0.66, 0.72, 0.8), wet_night), 0.6 * w);
		vec2 iso = vec2(wp.x, wp.y * 2.0);
		float n = season_vnoise(iso / 9.0 + 31.0) * 0.7 + season_vnoise(iso / 3.0 + 13.0) * 0.3;
		// a dip holds water (texel_dip)
		float dip = texel_dip(uv, px, h0);
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
		if (code >= 10 && code < 112 && RAMP_LEN[code] > 0) {
			vec3 n = vec3(d.rg * 2.0 - 1.0, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			float lb = d.a * 1.8 - 0.4;
			float l = lb + 1.05 * (max(dot(n, normalize(sun_dir)), 0.0) - max(dot(n, BASE_DIR), 0.0)) * relight;
			// height march toward the sun: a higher texel in the way puts this one in shadow; a high ring around it is occlusion
			float h0 = texture(h_tex, UV).r * 255.0;
			float sh = 0.0;
			float occ = 0.0;
			// No cast shadow and no occlusion to apply means no taps to spend (identical result, most of the day's cost).
			// Soft march: a blocker well above the sun ray gives full shadow, a near miss a partial one, so the edge
			// of a shadow feathers (the palette steps and the Bayer blend turn that into dither). Softer shadows also
			// thin with distance, so a far wall does not lay a hard strip across the ground.
			if (shadow_amt * relight > 0.002 || debug_view == 4) {
				float pen = 0.5 + 6.0 * shadow_soft;
				for (int k = 1; k <= 12; k++) {
					if (k > march_steps) {
						break;
					}
					float hn = texture(h_tex, UV + sun_px * float(k) * shadow_reach * px).r * 255.0;
					float over = hn - h0 - shadow_slope * float(k) * shadow_reach;   // > 0: this blocker stands above the sun ray
					float hit = smoothstep(-pen, pen, over) * step(0.5, hn);
					float fall = 1.0 - shadow_soft * float(k) / float(march_steps + 1);
					sh = max(sh, hit * fall);
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
				c.rgb = RAMP_PAL[RAMP_IDX[RAMP_START[code] + step_i]];
			}
			c.rgb *= mix(vec3(1.0), shadow_tint, min(shadow_amt, 1.0) * sh);
			if (debug_view == 4) {
				c.rgb = vec3(sh);
			}
		}
	}
	// Water (material 107) and its foam (108) keep their own palette in every season: the water ramp's greens
	// (47,107,85) pass the "green texel" test in season_recolor and were dyed orange like the grass.
	int mat_code = int(texture(nrm_tex, UV).b * 255.0 + 0.5);
	bool is_water = mat_code == 107 || mat_code == 108 || mat_code == 110 || mat_code == 111;
	if (c.a > 0.5 && debug_view == 0 && !is_water && (season_amt > 0.0 || season_snow > 0.0)) {
		c.rgb = season_recolor(c.rgb, wpos);
	}
	if (c.a > 0.5 && debug_view == 0 && !is_water && season_snow > 0.2) {
		c.rgb = snow_drifts(c.rgb, UV, px, thr, texture(h_tex, UV).r * 255.0);
	}
	if (c.a > 0.5 && debug_view == 0 && !is_water && (wet > 0.001 || splash > 0.01)) {
		c.rgb = wet_ground(c.rgb, wpos, UV, px, thr, texture(h_tex, UV).r * 255.0);
	}
	if (c.a > 0.5 && debug_view == 0 && !is_water && blossom > 0.01) {
		c.rgb = fallen_blossom(c.rgb, wpos, thr);
	}
	if (c.a > 0.5 && debug_view == 0 && mist > 0.01) {
		// a low haze in soft patches on the iso grid; it lies thicker in the hollows (texel_dip), and the edge is dithered
		vec2 iso = vec2(wpos.x, wpos.y * 2.0);
		float m = season_vnoise(iso / 16.0 + vec2(TIME * 0.6, 0.0) * mist_drift) * 0.7
				+ season_vnoise(iso / 6.0 - vec2(TIME * 0.9, 0.0) * mist_drift) * 0.3;
		float dens = smoothstep(0.3, 0.75, m) * mist * (0.55 + 0.45 * texel_dip(UV, px, texture(h_tex, UV).r * 255.0));
		if (dens > thr) {
			c.rgb = mix(c.rgb, mist_col, 0.45);
		}
	}
	// depth fog: the far (top) rows fade toward the haze colour, dithered
	float far_k = pow(1.0 - UV.y, 1.6) * fog_amt;
	if (c.a > 0.5) {
		c.rgb = mix(c.rgb, fog_col, clamp(far_k, 0.0, 1.0) * 0.6);
	}
	// T6 water band floor: water texels (and foam) are lifted to at least the mid water tone, never below it, so the
	// lake cannot fall to near-black at noon, dusk or night. Lift only, and water texels only.
	if (is_water && c.a > 0.5 && debug_view == 0) {
		c.rgb = max(c.rgb, water_floor);
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
