shader_type canvas_item;
render_mode blend_mul;
// Cast shadow on the ground: a soft oval laid on the 2:1 iso ground by SkyShadows, long and to one side when
// the sun is low, short and close at noon. The quad is a 1x1 texture stretched into a parallelogram, so UV.y
// runs from the shadow's tip (0) to its near end (1) and UV.x across it. The shadow is dither, never an alpha
// fade: the density thins from the foot to the tip and toward the edges, picked against the 4x4 Bayer matrix
// in world texels (a soft penumbra that works with the dither).

uniform vec3 shade : source_color = vec3(0.50, 0.60, 0.72);
uniform float strength = 1.0;          // 0..1 overall
uniform float density_foot = 0.85;
uniform float density_tip = 0.25;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float edge = 1.0 - smoothstep(0.55, 1.0, length(q));      // 1 in the middle, 0 at the rim
	float along = 1.0 - UV.y;                                  // 0 at the foot end, 1 at the tip
	float dens = mix(density_foot, density_tip, along) * edge * strength;
	float thr = bayer4(ivec2(floor(wpos)));
	if (thr >= dens) {
		COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	} else {
		COLOR = vec4(shade, 1.0);
	}
}
