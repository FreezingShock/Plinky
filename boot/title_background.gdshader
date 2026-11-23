shader_type canvas_item;

// Title screen backdrop. Meadow palette indices 0 to 7 (docs/art-bible.md section 3), set from title_background.gd.
// Everything is drawn on the 640x360 texel grid, and every layer dithers on its own parallax-shifted texels, so the
// pattern travels with the layer it belongs to and never swims over it. Layers, far to near: dithered dusk sky with
// stars, sun and a drifting double cloud deck; far mountains with snow caps and mist; a mid ridge; a lake with a sun
// glitter column and shimmer; the near meadow with grass blades, flowers and a dithered dark foreground.
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;
uniform float time = 0.0;
uniform float dissolve = 0.0;
uniform vec2 canvas_texels = vec2(640.0, 360.0);
// Mouse parallax in texels, already smoothed by the script. Each layer shifts by its own whole-texel fraction.
uniform vec2 parallax = vec2(0.0);
// 0 = dusk (default), anything else is reserved for time-of-day variants.
uniform float mood = 0.0;

const vec2 SUN = vec2(470.0, 96.0);
const float LAKE_TOP = 214.0;

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.07 + 7.3) * 0.3 + vnoise(p * 4.1 + 2.1) * 0.1;
}

// 1 at a sharp peak, 0 in the valley.
float ridged(float x, float seed) {
	return 1.0 - abs(2.0 * vnoise(vec2(x, seed)) - 1.0);
}

vec4 pal(int i) {
	if (i == 0) { return c0; }
	if (i == 1) { return c1; }
	if (i == 2) { return c2; }
	if (i == 3) { return c3; }
	if (i == 4) { return c4; }
	if (i == 5) { return c5; }
	if (i == 6) { return c6; }
	return c7;
}

// One step darker on the palette's value ramp (the palette indices are not monotonic above 4).
int darker(int i) {
	if (i == 7) { return 4; }
	if (i == 6) { return 2; }
	if (i == 5) { return 3; }
	if (i == 0) { return 0; }
	return i - 1;
}

vec2 layer_shift(float k) {
	return floor(parallax * k + 0.5);
}

float far_ridge(float x) {
	return 170.0 - 50.0 * ridged(x * 0.017, 1.7) - 9.0 * vnoise(vec2(x * 0.06, 3.0));
}

// Mirrored by TitleScenery.mid_ridge().
float mid_ridge(float x) {
	return 200.0 - 7.0 * sin(x * 0.021 + 1.0) - 4.0 * sin(x * 0.067) - 3.0 * sin(x * 0.13 + 2.0);
}

// Near meadow silhouette: a hump on the left, a long low shore, a soft rise on the right. Mirrored by
// TitleScenery.near_hill(), so keep the two in step.
float near_hill(float x) {
	return 252.0 - 34.0 * exp(-pow(x / 140.0, 2.0)) - 7.0 * sin(x * 0.012 + 0.8) + 12.0 * smoothstep(430.0, 640.0, x) * -1.0;
}

void fragment() {
	vec2 px = floor(UV * canvas_texels);
	float t = time;
	float th = bayer4(px) + 0.03125;
	int idx = 1;

	// ---- Sky: four dithered bands, brightest at the horizon. -----------------------------------------------------
	float sk = px.y / 200.0;
	float v = sk + (th - 0.5) * 0.24;
	if (v < 0.17) { idx = 0; }
	else if (v < 0.40) { idx = 1; }
	else if (v < 0.63) { idx = 2; }
	else { idx = 3; }

	// Stars, twinkling on a slow stepped timer. Only in the dark bands.
	if (idx <= 1) {
		vec2 sp = px - layer_shift(0.05);
		float h = hash21(sp);
		if (h > 0.9955) {
			float tw = hash21(sp + floor(t * 1.3 + h * 40.0));
			if (tw > 0.25) { idx = 7; }
		} else if (h > 0.991 && hash21(sp + 9.0) > 0.5) {
			idx = 4;
		}
	}

	// Sun: disc, rim, a dithered halo, and a slow pulse.
	vec2 sp2 = px - layer_shift(0.08);
	float sd = length(sp2 - SUN);
	float sr = 20.0 + sin(t * 0.7) * 1.0;
	if (sd < sr) {
		idx = (sd > sr - 2.5) ? 4 : 5;
	} else if (sd < sr + 8.0 && th < 1.0 - (sd - sr) / 8.0) {
		idx = 4;
	} else if (sd < sr + 30.0 && th < 0.55 * (1.0 - (sd - sr - 8.0) / 22.0) && idx < 4) {
		idx = 3;
	}

	// Two cloud decks drifting at different speeds. Body is the base green, the lit top edge is the light index,
	// and the underside drops a band, so each cloud reads as a lit slab.
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		vec2 cp = px - layer_shift(0.10 + 0.08 * fl);
		float drift = t * (0.010 + 0.007 * fl);
		float alt = 70.0 + 52.0 * fl;
		float band = 1.0 - abs(cp.y - alt) / (34.0 + 8.0 * fl);
		if (band > 0.0) {
			float sx = cp.x * (0.0095 - 0.002 * fl) + drift + fl * 11.0;
			float n = fbm(vec2(sx, cp.y * 0.055 + fl * 5.0));
			float up = fbm(vec2(sx, (cp.y - 3.0) * 0.055 + fl * 5.0));
			float dn = fbm(vec2(sx, (cp.y + 3.0) * 0.055 + fl * 5.0));
			float thr = 0.50;
			if (n * band + 0.0 > thr * 0.62) {
				idx = 3;
				if (up * band < thr * 0.62) { idx = 4; }
				else if (dn * band < thr * 0.62) { idx = 2; }
			}
		}
	}

	// ---- Far mountains with snow caps, lit from the sun side. ----------------------------------------------------
	vec2 pa = px - layer_shift(0.18);
	float ha = far_ridge(pa.x);
	if (pa.y > ha) {
		float slope = far_ridge(pa.x + 3.0) - far_ridge(pa.x - 3.0);
		float depth = pa.y - ha;
		// Sun-lit faces only near the crest, thinning into shadow lower down, so faces read as slopes, not columns.
		float gully = sin(pa.x * 0.62 - pa.y * 0.95);
		bool lit = slope > 0.5 && depth < 46.0 && (gully > -0.3 || depth < 4.0) && bayer4(pa) + 0.03 < 1.0 - depth / 62.0;
		idx = lit ? 2 : 1;
		if (pa.y < ha + 1.5) { idx = 4; }
		// Snow: dithered cap on the high peaks.
		float snow = ha < 138.0 ? (138.0 - ha) / 14.0 : 0.0;
		if (pa.y < ha + 2.0 + snow * 7.0 && bayer4(pa) + 0.03 < 0.35 + snow * 0.65 && pa.y > ha + 1.0) {
			idx = (slope > 0.5) ? 7 : 4;
		}
		// Mist gathers at the foot and drifts.
		float mist = clamp((pa.y - 150.0) / 46.0, 0.0, 1.0);
		float flow = 0.5 + 0.5 * sin(pa.x * 0.03 - t * 0.25 + pa.y * 0.1);
		if (bayer4(pa) + 0.03 < mist * (0.55 + 0.4 * flow)) { idx = 3; }
	}

	// ---- Mid ridge, dark and wooded (trees are drawn by the scenery layer on top of it). -------------------------
	vec2 pb = px - layer_shift(0.38);
	float hb = mid_ridge(pb.x);
	if (pb.y > hb) {
		idx = 1;
		if (pb.y < hb + 1.5) { idx = 2; }
		float fade = clamp((pb.y - hb) / 14.0, 0.0, 1.0);
		if (bayer4(pb) + 0.03 < 0.5 * (1.0 - fade) && pb.y > hb + 1.5) { idx = 2; }
	}

	// ---- Lake: reflections of the sky, glitter under the sun, shimmer stepped at 10 fps. -------------------------
	vec2 pl = px - layer_shift(0.65);
	float shore = near_hill(px.x - layer_shift(1.0).x);
	if (pl.y > LAKE_TOP && px.y < shore) {
		float depth = (pl.y - LAKE_TOP) / max(shore - LAKE_TOP, 1.0);
		idx = 2;
		if (depth < 0.18 && bayer4(pl) + 0.03 > depth * 4.0) { idx = 3; }
		float ripple = sin(pl.y * 1.7 + floor(t * 10.0) * 0.9 + pl.x * 0.045) + sin(pl.y * 0.6 - t * 0.6);
		if (ripple > 1.55 && bayer4(pl) + 0.03 < 0.6) { idx = 4; }
		// Sun column: ragged, brighter the closer it is to the shore line.
		float dx = abs(pl.x - SUN.x);
		float wob = sin(pl.y * 0.9 + floor(t * 10.0) * 1.3) * 4.0;
		float width = 5.0 + depth * 18.0;
		if (abs(dx + wob) < width && bayer4(pl) + 0.03 < 0.65 - dx / width * 0.35 && ripple > -0.4) {
			idx = (ripple > 0.9) ? 5 : 4;
		}
		if (px.y > shore - 3.0) { idx = 1; }
	}

	// ---- Near meadow. --------------------------------------------------------------------------------------------
	vec2 pn = px - layer_shift(1.0);
	float hn = near_hill(pn.x);
	if (px.y >= hn) {
		idx = 3;
		float into = px.y - hn;
		if (into < 1.5) { idx = 4; }
		// Meadow shade: patches of the deep green, wind-bent grass blades, flowers.
		float patch = fbm(vec2(pn.x * 0.035, pn.y * 0.09));
		if (patch > 0.58 && bayer4(pn) + 0.03 < 0.45) { idx = 2; }
		vec2 cell = vec2(floor(pn.x / 6.0), floor(pn.y / 5.0));
		float hc = hash21(cell);
		float sway = floor(sin(t * 1.6 + cell.x * 0.7 + cell.y) * 0.5 + 1.0);
		vec2 lc = vec2(pn.x - cell.x * 6.0, pn.y - cell.y * 5.0);
		if (into > 4.0) {
			// Blade: a three texel stalk with a light tip that leans on the wind.
			float bx = floor(hc * 4.0) + 1.0 + sway * step(2.0, lc.y);
			if (hc > 0.35 && abs(lc.x - bx) < 0.5 && lc.y > 1.0 && lc.y < 4.0) { idx = (lc.y < 2.0) ? 4 : 2; }
			// Flowers: a petal dot with a paper or butter or earth colour, bobbing a texel now and then.
			if (hc > 0.955 && lc.x > 1.0 && lc.x < 3.0 && lc.y > 1.0 && lc.y < 3.0) {
				float k = hash21(cell + 4.0);
				idx = (k < 0.4) ? 5 : ((k < 0.75) ? 7 : 6);
				if (lc.x > 1.0 && lc.x < 2.0 && lc.y > 1.0 && lc.y < 2.0) { idx = 5; }
			}
		}
		// Foreground gets darker toward the bottom edge.
		float low = (px.y - 292.0) / 68.0;
		if (low > 0.0 && th < low * 1.25) { idx = (px.y > 338.0) ? 1 : 2; }
	}

	// ---- Soft dithered scrim behind the menu column, so the world never fights the text. ------------------------
	float sc = clamp((260.0 - px.x) / 140.0, 0.0, 1.0);
	if (sc > 0.0 && th < sc * 0.42) { idx = darker(idx); }

	// Dithered ink vignette.
	float vd = length((px / canvas_texels - 0.5) * vec2(1.0, 0.78));
	if (vd > 0.5 && th < (vd - 0.5) * 2.6) { idx = 0; }

	// Dissolve: ordered pixels flip to ink.
	if (th < dissolve) { idx = 0; }

	COLOR = pal(idx);
}
