shader_type canvas_item;
render_mode blend_mul;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Cast shadow on the ground: a soft oval laid on the 2:1 iso ground by SkyShadows, long and to one side when
// the sun is low, short and close at noon. The quad is a 1x1 texture stretched into a parallelogram, so UV.y
// runs from the shadow's tip (0) to its near end (1) and UV.x across it. The shadow is dither, never an alpha
// fade: the density thins from the foot to the tip and toward the edges, picked against the 4x4 Bayer matrix
// in world texels (a soft penumbra that works with the dither).

uniform vec3 shade : source_color = vec3(0.28, 0.38, 0.56);
uniform float strength = 1.0;          // 0..1 overall
// Pad overlay copy: when `clip` is set this material is drawn ABOVE the pad plates and only paints inside a pad's
// diamond, so a prop's shadow falls across the plate instead of stopping at its edge.
uniform bool clip = false;
uniform int clip_count = 0;
uniform vec2 clip_pads[24];            // pad centres in world texels
uniform vec2 clip_half = vec2(15.0, 8.0);
uniform float density_foot = 0.85;
uniform float density_tip = 0.25;

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
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float core = clamp((1.0 - length(q)) * 3.0, 0.0, 1.0);     // solid inside, dithered only on the rim
	float along = 1.0 - UV.y;                                  // 0 at the foot end, 1 at the tip
	float dens = mix(density_foot, density_tip, along * along) * core * strength;
	// solid body, dithered rim and tip: anything above 0.6 is fully shadowed, the rest ramps through the Bayer matrix
	dens = clamp(dens / 0.6, 0.0, 1.0);
	float thr = bayer4(ivec2(floor(wpos)));
	bool on_pad = !clip;
	if (clip) {
		for (int i = 0; i < 24; i++) {
			if (i < clip_count) {
				vec2 d = wpos - (clip_pads[i] + vec2(0.0, -1.0));
				if (abs(d.x) / clip_half.x + abs(d.y) / clip_half.y <= 1.0) {
					on_pad = true;
				}
			}
		}
	}
	if (!on_pad || (dens < 1.0 && thr >= dens)) {
		COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	} else {
		COLOR = vec4(shade, 1.0);
	}
}
