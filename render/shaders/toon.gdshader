shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// World pass. Writes a G-buffer, not a colour: R = palette index (texel centre), G = light 0..1,
// B = object id / 255. shaders/post_dither.gdshader turns it into the final dithered palette image.

global uniform float fx_time;
global uniform float fx_wind;

uniform int lit_index : hint_range(0, 7) = 3;      // palette index of the lit band
uniform int object_id : hint_range(1, 255) = 2;    // 1 = ground (no outline between ground texels)
uniform bool use_vertex_index = false;             // COLOR.r * 7 = palette index (glb vertex colours)
uniform vec3 light_dir = vec3(-0.45, 0.8, 0.4);    // world space, points toward the light
uniform float wind : hint_range(0.0, 1.0) = 0.0;   // sway by height on tagged meshes
uniform float shadow_drop : hint_range(0.0, 1.0) = 0.0; // >0 = blob shadow: drops one band, dithered at 0.6

varying float v_idx;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	float h = max(VERTEX.y, 0.0);
	float phase = fx_time * 1.6 + MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.5;
	VERTEX.x += sin(phase) * 0.06 * h * wind * fx_wind;
	v_idx = COLOR.r;
}

float bayer4(ivec2 p) {
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	ivec2 q = p & ivec2(3);
	return (float(m[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float l = clamp(dot(n, normalize(light_dir)), 0.0, 1.0);
	if (shadow_drop > 0.0 && bayer4(ivec2(FRAGCOORD.xy)) < 0.6) {
		l = max(l - shadow_drop, 0.0);
	}
	int idx = use_vertex_index ? int(round(v_idx * 7.0)) : lit_index;
	vec3 enc = vec3((float(clamp(idx, 0, 7)) + 0.5) / 8.0, l, float(object_id) / 255.0);
	ALBEDO = to_linear(enc);
}
