shader_type canvas_item;
// Interactive grass blades for the zone 1 meadow. One quad covers the ground. Each blade is generated per texel
// from a hash, so there are no nodes per blade. The wind and the pushers lean blades in the shader.
// Blades are 3 texels tall: a dark base texel, then two light tip texels. They lean at most 2 texels.

uniform float t = 0.0;
uniform float wind = 0.2;
uniform vec2 pushers[6];
uniform int pusher_count = 0;
uniform vec2 pads[8];
uniform int pad_count = 0;
uniform vec4 tip_col : source_color = vec4(0.72, 0.86, 0.47, 1.0);
uniform vec4 base_col : source_color = vec4(0.18, 0.42, 0.33, 1.0);
uniform float max_density = 0.85;
// The ground the blades grow on: blades draw only on grass texels, so paths, dirt, water and pads stay clear.
uniform sampler2D ground_tex : filter_nearest;
uniform vec2 ground_origin = vec2(0.0);
uniform vec2 ground_size = vec2(840.0, 480.0);
uniform vec3 grass_a : source_color = vec3(0.373, 0.639, 0.416);
uniform vec3 grass_b : source_color = vec3(0.718, 0.851, 0.471);
uniform vec3 grass_c : source_color = vec3(0.184, 0.420, 0.333);

varying vec2 wp;

float hash2(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Patch density, stretched 2:1 for the iso plane. Blades gather into clumps with bare lawn between them.
float density(vec2 b) {
	float n = vnoise(vec2(b.x / 22.0, b.y * 2.0 / 22.0) + vec2(3.1, 7.7));
	return clamp((n - 0.44) * 2.6, 0.0, max_density);
}

// One blade base per 3x3 cell, at a hashed spot in the cell: the cell's root.
vec2 root_of(vec2 c) {
	return c * 3.0 + vec2(floor(hash2(c + 0.5) * 3.0), floor(hash2(c + 7.3) * 3.0));
}

// Does the cell grow a blade at all? Patch density decides, so blades gather into tufts with bare lawn between.
bool cell_has_blade(vec2 c, vec2 root) {
	return hash2(c + 11.0) < density(root);
}

// Lean of the blade rooted at texel b, in texels: -2..2. The wind wave runs across the field, as in LifeGround.
float lean(vec2 b) {
	float phase = b.x * 0.045 - t * 2.2 + b.y * 0.011;
	float w = sin(phase) + 0.35 * sin(phase * 2.3 + 1.7);
	w *= 0.7 + 0.9 * wind;
	float mag = abs(w) > 0.85 ? 2.0 : (abs(w) > 0.55 ? 1.0 : 0.0);
	float l = w > 0.0 ? mag : -mag;
	// The nearest walker or critter bends blades away from it (the same rule as LifeGround.bend).
	float best = 1e9;
	float push = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= pusher_count) {
			break;
		}
		vec2 d = b - pushers[i];
		d.y *= 2.0;
		float dist = length(d);
		if (dist < 16.0 && abs(d.x) >= 1.0 && dist < best) {
			best = dist;
			float pm = dist < 8.0 ? 2.0 : 1.0;
			push = d.x > 0.0 ? pm : -pm;
		}
	}
	if (best < 1e9) {
		l = push;
	}
	return l;
}

// Blades stay off the pad plates (the same clearance as the sway tips in the baked data).
bool near_pad(vec2 b) {
	for (int i = 0; i < 8; i++) {
		if (i >= pad_count) {
			break;
		}
		vec2 d = b - pads[i];
		d.y *= 2.0;
		if (length(d) < 22.0) {
			return true;
		}
	}
	return false;
}

void vertex() {
	wp = VERTEX;
}

// Is this texel grass? The ground is palette-exact, so grass texels match one of the three grass colours.
bool is_grass(vec2 p) {
	vec3 c = texture(ground_tex, (p - ground_origin) / ground_size).rgb;
	float d = min(min(distance(c, grass_a), distance(c, grass_b)), distance(c, grass_c));
	return d < 0.02;
}

void fragment() {
	vec2 p = floor(wp);
	vec4 col = vec4(0.0);
	bool found = false;
	// Only the cells that can hold a root within 2 texels to either side and 2 texels below the pixel are checked.
	if (is_grass(p)) {
		float cx0 = floor((p.x - 2.0) / 3.0);
		float cx1 = floor((p.x + 2.0) / 3.0);
		float cy0 = floor(p.y / 3.0);
		float cy1 = floor((p.y + 2.0) / 3.0);
		for (float cy = cy0; cy <= cy1; cy += 1.0) {
			for (float cx = cx0; cx <= cx1; cx += 1.0) {
				if (found) {
					break;
				}
				vec2 c = vec2(cx, cy);
				vec2 b = root_of(c);
				float k = b.y - p.y;
				if (k < 0.0 || k > 2.0 || abs(b.x - p.x) > 2.0) {
					continue;
				}
				if (!cell_has_blade(c, b) || near_pad(b)) {
					continue;
				}
				// The root sits k texels below the pixel, so the pixel is on that blade's column at height k.
				float off = round(lean(b) * k / 2.0);
				if (b.x + off == p.x) {
					col = k == 0.0 ? base_col : tip_col;
					found = true;
				}
			}
		}
	}
	COLOR = col;
}
