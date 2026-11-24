shader_type canvas_item;
// Heat shimmer over the Ember Quarry's lava and vents (world/quarry_light.gd). Moves the picture behind it by whole
// screen texels, in waves that rise off the heat. Strength falls off with distance from each source. Hidden under
// Reduce Motion by the script.

const int MAX_EMIT = 64;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 emit[MAX_EMIT];
uniform vec4 emit_col[MAX_EMIT];
uniform int emit_count = 0;
uniform float clock = 0.0;
uniform float amount = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	float heat = 0.0;
	for (int i = 0; i < MAX_EMIT; i++) {
		if (i >= emit_count) {
			break;
		}
		if (emit_col[i].a > 1.5) {
			continue;   // lava and vents only; braziers and lamps do not shimmer
		}
		vec4 e = emit[i];
		float d = distance(wpos, e.xy) / max(e.z * 2.0, 0.001);
		heat += max(0.0, 1.0 - d) * e.w;
	}
	heat = clamp(heat, 0.0, 1.0);
	float wave = sin(wpos.y * 0.35 - clock * 4.0 + sin(wpos.x * 0.12 + clock) * 1.5);
	float shift = round(wave * amount * heat);
	COLOR = texture(screen_tex, SCREEN_UV + vec2(shift * SCREEN_PIXEL_SIZE.x, 0.0));
}
