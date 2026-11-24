shader_type canvas_item;
// Ember Quarry haze (world/quarry_light.gd). Drifting smoke that runs warm where lava and vents are close and cool
// and denser in the recesses away from them. Soft alpha, no dither. Light shafts fall in slanted bands from the top
// of the quarry. Clock is zero under Reduce Motion, so the haze holds still.

const int MAX_EMIT = 64;
uniform vec4 emit[MAX_EMIT];
uniform vec4 emit_col[MAX_EMIT];
uniform int emit_count = 0;
uniform float clock = 0.0;
uniform float density = 0.3;
uniform float shaft = 0.12;
uniform float night = 0.0;
uniform vec3 cool_col = vec3(0.35, 0.24, 0.36);
uniform vec3 warm_col = vec3(0.82, 0.38, 0.18);
uniform vec3 shaft_col = vec3(0.91, 0.66, 0.27);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h2(i);
	float b = h2(i + vec2(1.0, 0.0));
	float c = h2(i + vec2(0.0, 1.0));
	float d = h2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 drift = vec2(clock * 3.0, clock * -1.2);
	float n = fbm(wpos * 0.012 + drift * 0.01);
	float heat = 0.0;
	for (int i = 0; i < MAX_EMIT; i++) {
		if (i >= emit_count) {
			break;
		}
		if (emit_col[i].a > 1.5) {
			continue;   // braziers and lamps light the air but do not heat it
		}
		vec4 e = emit[i];
		float d = distance(wpos, e.xy) / max(e.z * 2.5, 0.001);
		heat += max(0.0, 1.0 - d) * e.w;
	}
	heat = clamp(heat, 0.0, 1.0);
	vec3 col = mix(cool_col, warm_col, heat);
	float a = density * (0.4 + 0.6 * n) * mix(1.0, 0.45, heat);
	float u = wpos.x * 0.55 - wpos.y * 0.85;
	float band = 0.5 + 0.5 * sin(u * 0.045 + fbm(vec2(u * 0.01, clock * 0.05)) * 3.0);
	band = pow(band, 5.0);
	float top = 1.0 - smoothstep(60.0, 420.0, wpos.y);
	float sh = band * top * shaft * (1.0 - 0.5 * night);
	col = mix(col, shaft_col, clamp(sh / max(a + sh, 0.001), 0.0, 1.0));
	a = clamp(a + sh, 0.0, 0.6);
	COLOR = vec4(col, a);
}
