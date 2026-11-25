// Seasonal recolour for outdoor ground and props. Included by ground_light and wind_sway; SkyCycle sets the
// uniforms (world/sky_cycle.gd, core/season_look.gd). Green texels are re-tinted toward season_col / season_col2
// and winter lays snow on greens and highlights. Each texel switches on when the season amount passes a per-texel
// threshold (Bayer plus a smooth patch noise), so a change is a dithered scatter that grows, never a flat fade.
// The patch and tone noise are smooth value noise on the world texel grid, stretched 2:1 to match the iso view, so
// the recolour spreads as organic blobs. (It was a hash per 5x5 block, which drew a square patchwork.)
uniform vec3 season_col : source_color = vec3(1.0);
uniform vec3 season_col2 : source_color = vec3(1.0);
uniform float season_amt = 0.0;
uniform float season_snow = 0.0;

const int SEASON_BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float season_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth value noise, one value per world position; the argument is in noise units (world texels divided by the feature size).
float season_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(season_hash(i), season_hash(i + vec2(1.0, 0.0)), f.x), mix(season_hash(i + vec2(0.0, 1.0)), season_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 season_recolor(vec3 c, vec2 wp) {
	vec2 f = floor(wp);
	ivec2 q = ivec2(f) & ivec2(3);
	float b = (float(SEASON_BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
	vec2 iso = vec2(wp.x, wp.y * 2.0);   // 2:1 stretch: blobs are ellipses on the ground plane
	float n = season_vnoise(iso / 11.0 + 1.0) * 0.6 + season_vnoise(iso / 5.0 + 7.0) * 0.4;
	float patch = clamp((n - 0.25) / 0.5, 0.0, 1.0);
	float thr = 0.12 * b + 0.88 * patch;   // mostly smooth patches: the change spreads as soft blobs, not a texel mosaic
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float green = smoothstep(0.015, 0.09, c.g - max(c.r, c.b));
	if (green > 0.5 && season_amt > thr) {
		vec3 tone = season_vnoise(iso / 3.2 + 3.0) > 0.58 ? season_col2 : season_col;   // tone blobs, a few texels across
		c = clamp(tone * (0.45 + 1.1 * l), 0.0, 1.0);
	}
	if (season_snow > 0.0) {
		float light_k = smoothstep(0.2, 0.7, l);
		float cover = green > 0.5 ? season_snow : season_snow * 0.5 * step(0.55, l);
		float thr2 = 0.12 * float(SEASON_BAYER[(q.x * 3 + q.y * 5) & 15] + 1) / 16.0 + 0.88 * clamp((season_vnoise(iso / 7.0 + 11.0) - 0.25) / 0.5, 0.0, 1.0);
		if (cover * (0.45 + 0.55 * light_k) > thr2) {
			c = clamp(vec3(0.86, 0.92, 1.0) * (0.78 + 0.3 * l), 0.0, 1.0);
		}
	}
	return c;
}

// Pines (conifers) take snow only on their tier tops. The baked light in the normal map's alpha is highest on the
// upward-facing ledges (about the top 10 to 15 percent of pine texels), so cover is that light times season_snow, run
// through the same Bayer and patch threshold as the ground. A dithered scatter that grows with the season.
vec3 season_pine_snow(vec3 c, vec2 wp, float top_l) {
	float top = smoothstep(0.7, 0.85, top_l);
	if (top <= 0.0) {
		return c;
	}
	ivec2 q = ivec2(floor(wp)) & ivec2(3);
	float b = (float(SEASON_BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
	vec2 iso = vec2(wp.x, wp.y * 2.0);
	float patch = clamp((season_vnoise(iso / 7.0 + 11.0) - 0.25) / 0.5, 0.0, 1.0);
	float thr = 0.12 * b + 0.88 * patch;
	if (season_snow * top > thr) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = clamp(vec3(0.86, 0.92, 1.0) * (0.78 + 0.3 * l), 0.0, 1.0);
	}
	return c;
}
