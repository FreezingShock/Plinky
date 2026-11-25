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
// Softness: 0 gives a crisp-edged oval, 1 a wide feathered penumbra. SkyShadows sets it from SkyConfig.shadow_softness.
uniform float softness = 0.5;
// Per caster, set by SkyShadows as the MultiMesh instance's custom data (r: softness, g: strength, b: 1 for a pad copy):
// how much of the global softness it adds (a leaf canopy feathers more than a rock), how strong it is (a tree 1.0, a
// flower bed a third of that), and whether it is the copy drawn above the pads.
varying float v_soft;
varying float v_strength;
varying float v_overlay;

const float CORE_CAP = 0.6;   // the densest cells of any shadow: below 1.0, so no caster is ever a solid plate
const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
	v_soft = INSTANCE_CUSTOM.r;
	v_strength = INSTANCE_CUSTOM.g;
	v_overlay = INSTANCE_CUSTOM.b;
}

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	// No plateau: the body is a soft Gaussian that peaks at the centre and falls smoothly to nothing at the rim.
	// Softness sets how fast it falls (a crisp rock versus a wide leaf canopy). A short smoothstep forces the very
	// edge to zero, so there is no hard ring either.
	float soft = clamp(softness + v_soft, 0.0, 1.0);
	float r2 = dot(q, q);
	float k = mix(2.4, 0.7, soft);
	float body = exp(-k * r2) * (1.0 - smoothstep(0.7, 1.0, sqrt(r2)));
	float along = 1.0 - UV.y;                                  // 0 at the foot end, 1 at the tip
	float raw = clamp(mix(density_foot, density_tip, along * along) * body * strength * v_strength, 0.0, 1.0);
	// Never solid: even the darkest point is only CORE_CAP of the Bayer cells, so the shadow reads as dither all the way
	// in. The density is scaled, not clipped, so there is no flat top where the eye could find an edge.
	float dens = raw * CORE_CAP;
	float thr = bayer4(ivec2(floor(wpos)));
	bool on_pad = !clip;
	if (clip && v_overlay > 0.5) {   // only the pad copies are clipped; the other casters never paint above the plates
		for (int i = 0; i < 24; i++) {
			if (i < clip_count) {
				vec2 d = wpos - (clip_pads[i] + vec2(0.0, -1.0));
				if (abs(d.x) / clip_half.x + abs(d.y) / clip_half.y <= 1.0) {
					on_pad = true;
				}
			}
		}
	}
	if (!on_pad || thr >= dens) {
		COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	} else {
		COLOR = vec4(shade, 1.0);
	}
}
