shader_type canvas_item;
render_mode blend_add;
// God rays for dawn and dusk. Shafts fan out from a sun point above the frame. A texel is lit when the
// shaft intensity beats the 4x4 Bayer matrix, so the rays are dithered bands, not a smooth glow. Added on top
// of the scene at a fixed low value, so a lit texel is one step lighter than what is underneath.

uniform vec2 sun = vec2(-200.0, -150.0);   // sun point in world texels (off the frame)
uniform vec3 ray_col : source_color = vec3(1.0, 0.82, 0.55);
uniform float amount = 0.0;                // 0..1, already scaled by time of day and weather
uniform float sway = 0.0;                  // slow stepped phase, 0 when motion is reduced
uniform float reach = 860.0;

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
	ivec2 t = ivec2(floor(wpos));
	vec2 v = vec2(t) + 0.5 - sun;
	float ang = atan(v.x, v.y);
	float shaft = 0.5 + 0.5 * sin(ang * 31.0 + 1.3 + sway * 0.6);
	shaft *= 0.55 + 0.45 * sin(ang * 9.0 - 0.7 + sway * 0.35);
	shaft = pow(shaft, 1.6);
	float fall = 1.0 - smoothstep(reach * 0.25, reach, length(v));
	float inten = shaft * fall * amount;
	if (inten > bayer4(t) * 0.55 + 0.06) {
		COLOR = vec4(ray_col * ray_col * 0.26, 1.0);   // squared: keeps the colour warm instead of washing to grey
	} else {
		COLOR = vec4(0.0);
	}
}
