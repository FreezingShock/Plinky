shader_type canvas_item;
// Ember Quarry props (world/quarry_light.gd). The sprite's normal map (tools/art/gen_quarry_normals.py) takes the light
// from the nearest lava, vent, brazier and lamp, and from the sun's rim. The light is added to the sprite's own colour.
// The alpha is untouched, and so are the dark outline texels (they are too dark to take light).

const int MAX_LIGHTS = 8;
uniform sampler2D nrm_tex : filter_nearest;
uniform vec4 lp[MAX_LIGHTS];   // xy source position in texels relative to the sprite's top-left, z lift, w falloff radius
uniform vec4 lc[MAX_LIGHTS];   // rgb colour, a strength after flicker
uniform int lcount = 0;
uniform vec3 sun_dir = vec3(0.0, -1.0, 1.0);   // toward the sun, texel space (y runs down)
uniform float sun_amount = 0.0;
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.75);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Fragment shaders cannot exit early, so the lit path sits in an else.
	if (c.a < 0.5) {
		COLOR = c;
	} else {
		COLOR = lit_colour(c, UV, TEXTURE_PIXEL_SIZE);
	}
}

vec4 lit_colour(vec4 c, vec2 uv, vec2 tex_px) {
	vec2 px = uv / tex_px;
	vec4 nm = texture(nrm_tex, uv);
	vec2 nxy = nm.rg * 2.0 - 1.0;
	vec3 n = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
	vec3 acc = sun_col * (max(dot(n, normalize(sun_dir)), 0.0) * sun_amount);
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= lcount) {
			break;
		}
		vec3 lv = vec3(lp[i].xy - px, lp[i].z);
		float dist = length(lv);
		float r = lp[i].w;
		if (dist >= r) {
			continue;
		}
		float f = 1.0 - dist / r;
		f *= f;
		float facing = clamp(dot(n, lv / max(dist, 0.001)) * 0.5 + 0.5, 0.0, 1.0);
		acc += lc[i].rgb * (lc[i].a * f * facing);
	}
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	acc *= smoothstep(0.08, 0.3, lum);
	return vec4(c.rgb + acc * (0.35 + 0.65 * c.rgb), c.a);
}
