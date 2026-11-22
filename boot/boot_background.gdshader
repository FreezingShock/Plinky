shader_type canvas_item;

// Meadow palette, indices 0 to 7 (docs/art-bible.md section 3). Set from boot_background.gd.
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;
uniform float time = 0.0;
// 0 = scene visible. 1 = the whole screen is covered by ink (used to dissolve into the game).
uniform float dissolve = 0.0;
uniform vec2 canvas_texels = vec2(640.0, 360.0);

// Ordered (Bayer 4x4) threshold, 0 to 15/16 in steps of 1/16.
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
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

// Far ridge (deep) and near hill (base), in UV units, drifting slowly.
float ridge_far(float x, float t) {
	return 0.50 + 0.035 * sin(x * 6.0 + t * 0.15) + 0.015 * sin(x * 17.0 - t * 0.2);
}

float ridge_near(float x, float t) {
	return 0.70 + 0.04 * sin(x * 3.5 - t * 0.1 + 1.1);
}

void fragment() {
	// Everything is drawn on the texel grid, so the backdrop stays crisp at any window size.
	vec2 px = floor(UV * canvas_texels);
	vec2 p = (px + 0.5) / canvas_texels;
	float th = bayer4(px) + 0.03125;
	float t = time;
	// Shimmer: noise nudges the dither threshold, stepped at 10 fps (art bible section 4).
	float shimmer = (hash(floor(t * 10.0) * 3.1 + px.x * 0.13 + px.y * 0.71) - 0.5) * 0.10;

	float rf = ridge_far(p.x, t);
	float rn = ridge_near(p.x, t);

	// Sky: shadow at the top, deep near the far ridge, dithered between.
	float sky_k = p.y / max(rf, 0.001);
	int idx = 2;
	if (sky_k + (th - 0.5) * 0.35 + shimmer < 0.6) {
		idx = 1;
	}

	// Sun: an accent disc with a dithered light halo. Pulses slowly.
	vec2 sun_c = vec2(0.80, 0.20);
	float sun_r = 24.0 + sin(t * 0.8) * 1.5;
	float d = length((p - sun_c) * canvas_texels);
	if (d < sun_r) {
		idx = 5;
	} else if (d < sun_r + 10.0 && th < 1.0 - (d - sun_r) / 10.0) {
		idx = 4;
	}

	// Far ridge.
	if (p.y > rf) {
		idx = 2;
	}

	// Near hill with a one-texel light rim, a moving wind shimmer and a dithered dark ground.
	if (p.y > rn) {
		idx = 3;
		float rim = p.y - rn;
		if (rim < 1.5 / canvas_texels.y) {
			idx = 4;
		}
		float wave = sin(p.x * 9.0 + p.y * 4.0 - t * 1.4);
		if (wave > 0.82 && th < 0.55) {
			idx = 4;
		}
		if (p.y > 0.88 && th < (p.y - 0.88) * 9.0) {
			idx = 2;
		}
	}

	// Dithered ink vignette in the corners.
	float vd = length((p - 0.5) * vec2(1.0, 0.8));
	if (vd > 0.46 && th < (vd - 0.46) * 2.4) {
		idx = 0;
	}

	// Dissolve into the game: ordered pixels flip to ink.
	if (th < dissolve) {
		idx = 0;
	}

	COLOR = pal(idx);
}
