shader_type canvas_item;

// Scene wipe for the title and loading screens. A slanted, dithered sweep of ink with a one-texel sun-coloured lead
// line. `progress` runs 0 (nothing covered) to 1 (screen covered); `fade` is the whole overlay's alpha, used for the
// Reduce Motion cross-fade, where progress is held at full cover.
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform vec2 canvas_texels = vec2(640.0, 360.0);

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 px = floor(UV * canvas_texels);
	float th = bayer4(px) + 0.03125;
	// Slant the sweep so the edge runs diagonally, and dither the edge over a few texels.
	float x = UV.x + (UV.y - 0.5) * 0.25;
	float reach = progress * 1.3 - 0.15;
	float d = reach - x - (th - 0.5) * 0.05;
	vec4 col = vec4(0.0);
	if (d > 0.03) {
		col = ink;
	} else if (d > 0.0) {
		col = accent;
	}
	col.a *= fade;
	COLOR = col;
}
