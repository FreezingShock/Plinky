shader_type canvas_item;

// Reveal for scene changes (boot/scene_swap.gd). The captured frame of the screen being left covers the window.
// `progress` sweeps that cover away from the left as a slanted, Bayer-dithered edge with a one-texel sun-coloured lead
// line, so what sits underneath (the arriving scene, already drawn) is always the real picture. Nothing is drawn in a
// flat colour, so no frame goes black or grey. `fade` is the cover's alpha: Reduce Motion holds progress at 0 and fades
// the cover out instead.
uniform sampler2D snapshot : filter_nearest;
uniform vec4 accent : source_color = vec4(1.0, 0.85, 0.45, 1.0);
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
	// Slant the edge so it runs diagonally, and dither it over a few texels.
	float x = UV.x + (UV.y - 0.5) * 0.25;
	float reach = progress * 1.3 - 0.15;
	float d = x + (th - 0.5) * 0.05 - reach;
	vec4 col = texture(snapshot, UV);
	if (d < 0.0) {
		col.a = 0.0;
	} else if (d < 0.03) {
		col = accent;
	}
	col.a *= fade;
	COLOR = col;
}
