shader_type canvas_item;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Full-frame light pass. Unlike the multiply overlays, this reads the finished picture underneath (ground, props,
// walker, water) and re-lights EVERY texel from it: a sun-side lift and an away-side shade across the whole frame,
// then a luminance split (highlights pick up the light colour, shadows go cool or magenta). Every change is stepped
// through the 4x4 Bayer matrix in world texels, so the result is still dither, not a smooth blend (art bible 2, 4).
// Driven by SkyCycle: amounts are 0..1 and already scaled by time of day and weather.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 area_center = vec2(320.0, 180.0);   // world texels
uniform vec2 area_half = vec2(430.0, 250.0);
uniform vec2 sun_dir = vec2(0.0, -1.0);          // toward the light, unit-ish
uniform vec3 light_col : source_color = vec3(1.0, 0.88, 0.62);
uniform vec3 shade_col : source_color = vec3(0.62, 0.68, 0.88);
uniform float side_amount = 0.0;                 // sun-side lift / away-side shade across the frame
uniform float split_amount = 0.0;                // highlight warm / shadow cool by luminance
uniform float flash = 0.0;                        // 0..1: lightning, a cool-white lift on the whole frame (SkyCycle; 0 under Reduce flashing)
uniform float sat = 1.0;                         // saturation about luminance, richer in the golden hours
uniform float contrast = 1.0;                    // about a dark-mid pivot, so shadows deepen and highlights open
uniform vec3 noon_tint = vec3(1.0);              // pulls the green out of a bright high-sun frame
uniform float exposure = 1.0;                    // below 1 at high noon, where the frame reads bleached
uniform float lift = 0.22;                       // how much brighter a lit texel gets

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 t = ivec2(floor(wpos));
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 q = (floor(wpos) + vec2(0.5) - area_center) / area_half;   // one value per world texel
	float side = clamp(dot(q, normalize(sun_dir)) * 0.9, -1.0, 1.0) * side_amount;
	// sun side: lift and warm. away side: shade and cool. A smooth wash, not a pattern.
	float sp = max(side, 0.0);
	float sn = max(-side, 0.0);
	c = c * mix(vec3(1.0), (1.0 + lift) * mix(vec3(1.0), light_col * 1.25, 0.65), sp * 0.5);
	c *= mix(vec3(1.0), shade_col, sn * 0.5);
	// luminance split: highlights warm, shadows cool, smoothly
	float hi = smoothstep(0.66, 0.95, lum) * split_amount;
	float lo = (1.0 - smoothstep(0.12, 0.45, lum)) * split_amount;
	c = c * mix(vec3(1.0), (1.0 + lift * 0.6) * mix(vec3(1.0), light_col * 1.2, 0.7), hi * 0.6);
	c *= mix(vec3(1.0), shade_col * 0.9, lo * 0.6);
	c *= exposure * noon_tint;
	float l2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l2), c, sat);
	c = (c - 0.42) * contrast + 0.42;
	c = mix(c, c * 1.35 + vec3(0.08, 0.09, 0.12), flash * 0.6);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
