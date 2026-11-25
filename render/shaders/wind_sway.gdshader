shader_type canvas_item;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Tree and bush sway. Rows lean sideways by whole texels, more toward the top (h squared), so the foot
// stays planted and the crown moves in clean pixel steps. The sprite is padded by SkyCycle.SWAY_PAD texels
// on each side so the lean is never clipped. `step_time` is stepped by SkyCycle, not continuous.

uniform float wind = 0.2;
uniform float step_time = 0.0;
uniform float max_texels = 3.0;
uniform float enabled = 1.0;
// Rim light: a lit texel next to the dark outline on the sun side. `rim_dir` is whole texels toward the light
// (x in -1..1, y -1 = up); `rim_amount` is the share of rim texels that light up (Bayer dither), 0 = off.
uniform vec2 rim_dir = vec2(-1.0, -1.0);
uniform float rim_amount = 0.0;
uniform vec3 rim_col : source_color = vec3(1.0, 0.95, 0.75);
// Relight: per-sprite `nrm_tex` (tools/art/depth_pass.py) holds the baked normal, material and light. The shader moves
// each texel's light by the change in N.L between the baked sun and `sun_dir`, then re-picks the colour from the
// material's ramp with a Bayer dither, so props are lit from wherever the sun is. relight = 0 is off.
#include "res://render/shaders/prop_ramps.gdshaderinc"
#include "res://render/shaders/season.gdshaderinc"
uniform sampler2D nrm_tex : filter_nearest;
uniform vec3 sun_dir = vec3(-0.45, 0.45, 0.85);
uniform float relight = 0.0;
const vec3 BASE_DIR = vec3(-0.3495, 0.3828, 0.8557);   // LDIR in gen_meadow3d.py, normalised
varying float phase;
varying vec2 wpos;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.043 + MODEL_MATRIX[3].y * 0.017;
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	float h = 1.0 - UV.y;
	float height_px = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float size_k = clamp(height_px / 60.0, 0.3, 1.0);
	float s = sin(step_time * 1.6 + phase) * 0.55 + sin(step_time * 3.7 + phase * 2.0) * 0.45 * wind;
	float lean = (0.25 + 0.75 * wind) * s * h * h * max_texels * size_k * enabled;
	float off = floor(lean + 0.5);
	vec2 uv = UV - vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0) {
		c = vec4(0.0);
	}
	if (relight > 0.0 && c.a > 0.5) {
		vec4 d = texture(nrm_tex, uv);
		int code = int(d.b * 255.0 + 0.5);
		if (code >= 10 && code < 112 && RAMP_LEN[code] > 0) {
			vec3 n = vec3(d.rg * 2.0 - 1.0, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			float lb = d.a * 1.8 - 0.4;
			float l = lb + 1.05 * (max(dot(n, normalize(sun_dir)), 0.0) - max(dot(n, BASE_DIR), 0.0)) * relight;
			if (abs(l - lb) > 0.03) {
				int cnt = RAMP_LEN[code] - 1;
				float v = clamp(l, 0.0, 0.9999) * float(cnt);
				float lo = floor(v);
				float f = clamp((v - lo - 0.44) / 0.12, 0.0, 1.0);   // a narrow blend band: steps are solid, the dither only softens the seam
				int step_i = int(lo) + ((f > bayer4(ivec2(floor(wpos))) && int(lo) < cnt) ? 1 : 0);
				c.rgb = RAMP_PAL[RAMP_IDX[RAMP_START[code] + step_i]];
			}
		}
	}
	// Conifers (material code 12, M_PINE) keep their green all year: the spring blossom tint and autumn
	// recolour are for broadleaf foliage, and on pines they read as pink patches.
	bool conifer = relight > 0.0 && c.a > 0.5 && int(texture(nrm_tex, uv).b * 255.0 + 0.5) == 12;
	if (c.a > 0.5 && !conifer && (season_amt > 0.0 || season_snow > 0.0)) {
		c.rgb = season_recolor(c.rgb, wpos);
	}
	if (conifer && season_snow > 0.0) {
		c.rgb = season_pine_snow(c.rgb, wpos, texture(nrm_tex, uv).a);
	}
	if (rim_amount > 0.0 && c.a > 0.5 && lum(c.rgb) > 0.2) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec4 nh = texture(TEXTURE, uv + vec2(rim_dir.x, 0.0) * px);
		vec4 nv = texture(TEXTURE, uv + vec2(0.0, rim_dir.y) * px);
		bool edge_h = rim_dir.x != 0.0 && nh.a > 0.5 && lum(nh.rgb) < 0.2;
		bool edge_v = nv.a > 0.5 && lum(nv.rgb) < 0.2;
		if ((edge_h || edge_v) && bayer4(ivec2(floor(wpos))) < rim_amount) {
			c.rgb = mix(c.rgb, rim_col, 0.65);
		}
	}
	COLOR = c;
}
