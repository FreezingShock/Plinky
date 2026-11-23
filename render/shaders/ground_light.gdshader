shader_type canvas_item;
// Ground relight. The meadow ground is a baked render with a same-size G-buffer made by tools/art/gen_meadow3d.py:
//   nrm_tex  R,G normal (u, v), B material code, A baked light (see depth_pass.write_relight_data)
//   h_tex    world height, 1..255 over h_lo..h_hi, 0 outside the scene
// Every ground texel is re-lit: N.L against the moving sun, a height-march toward the sun for long cast shadows
// (terrain and slopes shade each other), then the colour is re-picked from the material ramp with a Bayer dither.
// Far texels (top of the frame) take a dithered depth fog. Everything stays on the palette.
#include "res://render/shaders/prop_ramps.gdshaderinc"
uniform sampler2D nrm_tex : filter_nearest;
uniform sampler2D h_tex : filter_nearest;
uniform vec3 sun_dir = vec3(-0.45, 0.45, 0.85);
uniform vec2 sun_px = vec2(-1.0, -1.0);         // screen direction toward the sun, texels per march step
uniform float relight = 0.0;                    // 0 = baked look
uniform float shadow_amt = 0.0;                 // how dark the cast shadow makes the light value
uniform float shadow_slope = 2.6;               // encoded height units a step may rise before it blocks the sun
uniform float ao_amt = 0.0;
uniform vec3 fog_col : source_color = vec3(0.7, 0.85, 0.7);
uniform float fog_amt = 0.0;                    // 0..1 at the far edge
const vec3 BASE_DIR = vec3(-0.3495, 0.3828, 0.8557);
varying vec2 wpos;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float thr = bayer4(ivec2(floor(wpos)));
	if (relight > 0.0 && c.a > 0.5) {
		vec4 d = texture(nrm_tex, UV);
		int code = int(d.b * 255.0 + 0.5);
		if (code >= 10 && code < 48 && RAMP_LEN[code] > 0) {
			vec3 n = vec3(d.rg * 2.0 - 1.0, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			float lb = d.a * 1.8 - 0.4;
			float l = lb + 1.05 * (max(dot(n, normalize(sun_dir)), 0.0) - max(dot(n, BASE_DIR), 0.0)) * relight;
			// height march toward the sun: a higher texel in the way puts this one in shadow; a high ring around it is occlusion
			float h0 = texture(h_tex, UV).r * 255.0;
			float sh = 0.0;
			float occ = 0.0;
			for (int k = 1; k <= 8; k++) {
				float hn = texture(h_tex, UV + sun_px * float(k) * 2.0 * px).r * 255.0;
				if (hn > 0.5 && hn - h0 > shadow_slope * float(k) * 2.0) {
					sh = 1.0;
				}
			}
			for (int k = 0; k < 4; k++) {
				vec2 o = vec2(float(k % 2) * 2.0 - 1.0, float(k / 2) * 2.0 - 1.0) * 3.0 * px;
				float hn = texture(h_tex, UV + o).r * 255.0;
				occ += clamp((hn - h0 - 4.0) / 24.0, 0.0, 1.0) * 0.25;
			}
			l -= sh * shadow_amt * relight + occ * ao_amt;
			if (abs(l - lb) > 0.03) {
				int cnt = RAMP_LEN[code] - 1;
				float v = clamp(l, 0.0, 0.9999) * float(cnt);
				float lo = floor(v);
				float f = clamp((v - lo - 0.30) / 0.40, 0.0, 1.0);
				int step_i = int(lo) + ((f > thr && int(lo) < cnt) ? 1 : 0);
				c.rgb = PAL[RAMP_IDX[RAMP_START[code] + step_i]];
			}
		}
	}
	// depth fog: the far (top) rows fade toward the haze colour, dithered
	float far_k = pow(1.0 - UV.y, 1.6) * fog_amt;
	if (c.a > 0.5 && far_k > thr) {
		c.rgb = mix(c.rgb, fog_col, 0.6);
	}
	COLOR = c;
}
