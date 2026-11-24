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

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < MAX_EMIT; i++) {
		if (i >= emit_count) {
			break;
		}
		vec4 e = emit[i];
		float d = distance(wpos, e.xy) / max(e.z, 0.001);
		if (d >= 1.0) {
			continue;
		}
		float f = 1.0 - d;
		f = f * f * (3.0 - 2.0 * f);
		sum += emit_col[i].rgb * (f * e.w);
	}
	COLOR = vec4(sum * gain, 1.0);
}
