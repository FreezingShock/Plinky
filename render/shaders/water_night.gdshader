shader_type canvas_item;
render_mode blend_add;
// Night glow for water (prototype for the mockups; not wired into gameplay yet).
// Water is material 107 and its foam 108 in the blue channel of ground_n.png (the same G-buffer as ground_light).
// Four layers, all added on top of the night shade and never darkening anything:
//   shimmer  moon glints on the water, thickest under a diagonal moon path, stepped in world texels
//   beams    soft moon shafts from a point off the frame, dithered where they land on water
//   halo     glow spilling off the shore onto the bank and above the water (the volume)
//   body     a lit rim just inside the shore, so the water glows at its edge and reads as deep, not flat
// Everything is in world texels (world_origin / world_scale, as the other world shaders), so nothing crawls when
// the camera moves. Colours are the meadow palette only: paper (f6efd9), lime (b7d978), deep green (2f6b55).

global uniform vec2 world_origin;
global uniform float world_scale;

uniform sampler2D nrm_tex : filter_nearest;
uniform vec2 tex_size = vec2(3040.0, 1840.0);   // ground_n.png in texels; world texels map 1:1 onto it (anchors do)
uniform vec2 tex_origin = vec2(0.0);            // world texel of the texture's top-left (the ground's position)

uniform float amount = 0.0;                     // 0..1, night (SkyCycle.night01) times the variant's strength
uniform float shimmer = 0.0;                    // moon glints on the water
uniform float beams = 0.0;                      // moon shafts that land on the water
uniform float halo = 0.0;                       // glow off the shore and above the water
uniform float body = 0.0;                       // lit rim inside the shore
uniform float road = 0.20;                      // brightness of the moon road on the water
uniform float road_width = 60.0;                // half-width of the moon road in texels
uniform float bloom = 0.0;                      // soft, unscattered bloom spilling off the moon road
uniform float haze = 0.0;                       // moonlit mist lifting off the water and over the shore
uniform vec2 moon_px = vec2(1000.0, 500.0);     // moon point in world texels, just north of Heronmere; the shafts fan out from it
uniform vec3 moon_col : source_color = vec3(0.965, 0.937, 0.851);
uniform vec3 glow_col : source_color = vec3(0.718, 0.851, 0.471);
uniform float sway = 0.0;                       // stepped clock; 0 under Reduce Motion, so glints and beams hold still
uniform float twinkle = 1.0;                    // 0 under Reduce Flashing: glints keep their places and stop changing
uniform float lift = 0.0;                      // sky reflection on the water at every hour (T6), 0 = off
uniform vec3 lift_col : source_color = vec3(0.965, 0.937, 0.851);
uniform int quality = 2;                        // GraphicsQuality.Level: 0 low (no rings, no beams), 1 medium, 2 high

varying vec2 wpos;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Material code of a world texel (0 outside the art).
int code_at(vec2 p) {
	vec2 t = floor(p - tex_origin);
	if (t.x < 0.0 || t.y < 0.0 || t.x >= tex_size.x || t.y >= tex_size.y) {
		return 0;
	}
	return int(texture(nrm_tex, (t + 0.5) / tex_size).b * 255.0 + 0.5);
}

// 1 where the world texel is water or foam, 0 on land and outside the art.
float water_at(vec2 p) {
	int code = code_at(p);
	return (code == 107 || code == 108 || code == 110 || code == 111) ? 1.0 : 0.0;
}

// Share of water on a ring of 8 taps at radius r, shifted by dy (negative reaches up the screen, i.e. above the water).
float ring_water(float r, float dy) {
	float s = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		s += water_at(wpos + vec2(cos(a), sin(a) * 0.5) * r + vec2(0.0, dy));
	}
	return s * 0.125;
}

// Distance from p to the moon's reflection line (the path runs from the moon down toward the viewer).
float moon_path_dist(vec2 p) {
	vec2 d = normalize(vec2(-0.10, 1.0));
	vec2 v = p - moon_px;
	return abs(v.x * d.y - v.y * d.x);
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	float w = water_at(wpos);
	float near = 0.0;
	float far = 0.0;
	if (quality >= 1) {
		near = ring_water(5.0, 0.0);
	}
	if (quality >= 2) {
		far = ring_water(14.0, -4.0);   // reaches up the bank, so the glow sits above the shore too
	}
	float spill = near * (1.0 - w);   // the shore strip only (about 5 texels): the bank behind it stays dark

	float path = exp(-pow(moon_path_dist(wpos) / road_width, 2.0));
	float wide = exp(-pow(moon_path_dist(wpos) / (road_width * 2.6), 2.0));

	vec3 col = vec3(0.0);
	col += glow_col * halo * spill * 0.40;
	// bloom: the road's light spreads softly around it, over water and bank alike
	col += moon_col * bloom * wide * (0.35 + 0.65 * max(w, spill)) * 0.10;
	// volumetric haze: moonlit mist over the water, thickest where it meets the shore and drifting up the bank
	float mist = clamp(far * 0.7 + near * 0.3 + w * 0.4, 0.0, 1.0);
	col += moon_col * haze * mist * (0.45 + 0.55 * wide) * 0.09;                 // spill up the bank and above the shore
	col += glow_col * body * w * (1.0 - far) * 0.40;       // the water's own light, brightest along the shore inside
	// sky reflection: the water takes a little of the lit sky at dusk and night, so it reads as water, not a black hole.
	// Brightest along the shore, where the sky shows in the shallows, and never more than a soft lift over the base colour.
	// The lift is kept apart from the night amount, so it holds at dusk, noon and night alike.
	vec3 lift_add = vec3(0.0);
	if (lift > 0.0 && w > 0.5) {
		float edge = 1.0 - ring_water(6.0, 0.0);
		lift_add = lift_col * lift * w * (0.08 + 0.22 * edge);
	}

	// Glints: a 2x1 texel sparkle grid. Density rises under the moon path; foam sparkles more.
	if (shimmer > 0.0 && w > 0.5) {
		// the moon's own light lies on the water along its path: a soft band that is brighter at the centre
		// dithered, so the road is pixel art: a texel lights where the path beats the Bayer matrix
		col += moon_col * step(bayer4(t), path * 0.85) * shimmer * road * w;
		float foam = float(code_at(wpos) == 108);
		float density = 0.05 * path * path * shimmer * (1.0 + foam);   // glints gather on the moon road only
		vec2 cell = floor(wpos / vec2(3.0, 1.0));
		float clock = twinkle * floor(sway);
		float h = hash21(cell + vec2(clock * 17.3, clock * 5.1));
		float on = step(1.0 - density, h);
		col += moon_col * on * (0.55 + 0.45 * path) * 0.9;
	}

	// Moon shafts: fan out from the moon point, dithered where they fall on water.
	if (beams > 0.0 && quality >= 2) {
		vec2 v = wpos + vec2(0.5) - moon_px;
		float ang = atan(v.x, v.y);
		float s = 0.5 + 0.5 * sin(ang * 22.0 + 0.7 + sway * 0.5);
		s *= 0.65 + 0.35 * sin(ang * 9.0 - 0.3);
		s = clamp(s * 1.3 - 0.15, 0.0, 1.0);   // wider, brighter shafts with dark gaps between them
		float fall = 1.0 - smoothstep(300.0, 1200.0, length(v));
		float on_water = clamp(ring_water(18.0, 0.0) * 1.6, 0.0, 1.0);
		float shaft = s * fall * on_water * beams;
		float lit = step(bayer4(t), shaft * 1.2);
		col += moon_col * shaft * (0.45 + 0.35 * lit);
	}

	COLOR = vec4(col * amount + lift_add, 1.0);
}
