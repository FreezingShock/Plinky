shader_type canvas_item;
render_mode blend_add, unshaded;
// Ember Quarry light (world/quarry_light.gd): lava, vent, brazier and lamp glow added onto the picture, so it lights
// the ground and every prop it reaches. Each emitter is a point with a smooth falloff. The script folds each source's
// 6 fps flicker (core/lava_flicker.gd) into its strength, so this shader only sums.

const int MAX_EMIT = 64;
uniform vec4 emit[MAX_EMIT];       // xy centre in quarry texels, z falloff radius, w strength (flicker applied)
uniform vec4 emit_col[MAX_EMIT];   // rgb colour, a kind: 0 lava, 1 vent, 2 brazier, 3 lamp
uniform int emit_count = 0;
uniform float gain = 1.0;
uniform float halo_reach = 2.6;   // the soft halo reaches this many times each source's falloff radius
uniform float halo_gain = 0.6;    // halo strength against the body of the glow
uniform float hot_gain = 0.8;     // white-hot centre of each source, which makes lava read as emissive

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

// Each source adds three things: a body that falls off smoothly, a white-hot centre, and a wide halo. The halo is a
// second, softer falloff in the same additive layer, so the lava and heat sources bloom without a screen-wide blur.
void fragment() {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < MAX_EMIT; i++) {
		if (i >= emit_count) {
			break;
		}
		vec4 e = emit[i];
		float dist = distance(wpos, e.xy);
		float d = dist / max(e.z, 0.001);
		vec3 col = emit_col[i].rgb;
		if (d < 1.0) {
			float f = 1.0 - d;
			f = f * f * (3.0 - 2.0 * f);
			float hot = f * f * f;
			sum += col * (f * e.w) + mix(col, vec3(1.0, 0.92, 0.75), 0.6) * (hot * e.w * hot_gain);
		}
		float halo_d = dist / max(e.z * halo_reach, 0.001);
		if (halo_d < 1.0) {
			float h = 1.0 - halo_d;
			sum += col * (h * h * e.w * halo_gain);
		}
	}
	COLOR = vec4(sum * gain, 1.0);
}
