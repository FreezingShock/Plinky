// Seasonal recolour for outdoor ground and props. Included by ground_light and wind_sway; SkyCycle sets the
// uniforms (world/sky_cycle.gd, core/season_look.gd). Green texels are re-tinted toward season_col / season_col2
// and winter lays snow on greens and highlights. Each texel switches on when the season amount passes a per-texel
// threshold (Bayer plus a coarse patch noise), so a change is a dithered scatter that grows, never a flat fade.
uniform vec3 season_col : source_color = vec3(1.0);
uniform vec3 season_col2 : source_color = vec3(1.0);
uniform float season_amt = 0.0;
uniform float season_snow = 0.0;

const int SEASON_BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float season_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 season_recolor(vec3 c, vec2 wp) {
	vec2 f = floor(wp);
	ivec2 q = ivec2(f) & ivec2(3);
	float b = (float(SEASON_BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
	float patch = season_hash(floor(wp / 5.0));
	float thr = 0.5 * b + 0.5 * patch;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float green = smoothstep(0.015, 0.09, c.g - max(c.r, c.b));
	if (green > 0.5 && season_amt > thr) {
		vec3 tone = season_hash(f * 0.37) > 0.62 ? season_col2 : season_col;
		c = clamp(tone * (0.45 + 1.1 * l), 0.0, 1.0);
	}
	if (season_snow > 0.0) {
		float light_k = smoothstep(0.2, 0.7, l);
		float cover = green > 0.5 ? season_snow : season_snow * 0.5 * step(0.55, l);
		float thr2 = 0.5 * float(SEASON_BAYER[(q.x * 3 + q.y * 5) & 15] + 1) / 16.0 + 0.5 * season_hash(floor(wp / 4.0) + 7.0);
		if (cover * (0.45 + 0.55 * light_k) > thr2) {
			c = clamp(vec3(0.86, 0.92, 1.0) * (0.78 + 0.3 * l), 0.0, 1.0);
		}
	}
	return c;
}
