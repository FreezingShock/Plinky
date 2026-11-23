shader_type canvas_item;
// The Bloom animation's screen light (ui/fx/bloom_ritual.gd sets the two strengths). Only 4x4 Bayer dither, no blending
// and no blur: a dark veil that creeps in from the edges, and a bright burst that opens from the middle.

uniform float veil : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 size_px = vec2(640.0, 360.0);
uniform vec4 veil_color : source_color = vec4(0.04, 0.02, 0.07, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);

float bayer4(vec2 p) {
	float x = mod(floor(p.x), 4.0);
	float y = mod(floor(p.y), 4.0);
	int i = int(y * 4.0 + x);
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = UV * size_px;
	float b = bayer4(px);
	vec2 c = (UV - vec2(0.5)) * vec2(size_px.x / size_px.y, 1.0);
	float d = length(c);
	float v = veil * smoothstep(0.1, 0.9, d + 0.3 * veil);
	float f = flash * (1.0 - smoothstep(0.0, 0.25 + 0.75 * flash, d));
	vec4 col = vec4(0.0);
	if (v > b) {
		col = vec4(veil_color.rgb, 1.0);
	}
	if (f > b) {
		col = vec4(flash_color.rgb, 1.0);
	}
	COLOR = col;
}
