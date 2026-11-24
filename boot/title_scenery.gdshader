shader_type canvas_item;

// Scenery grade for the title and loading backdrop. The time-of-day tint multiplies every scenery texel, then a 4x4
// Bayer dither darkens a share of them by the night shade, like the meadow's day_night.gdshader. The mask uses
// whole screen texels of the 640x360 backdrop, so it stays pixel art at any window size.
uniform vec4 tint : source_color = vec4(1.0);
uniform float shade = 0.0;
uniform vec2 canvas_texels = vec2(640.0, 360.0);

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 px = floor(SCREEN_UV * canvas_texels);
	vec4 c = COLOR;
	c.rgb *= tint.rgb;
	if (shade > 0.0 && bayer4(px) + 0.03125 < shade) {
		c.rgb *= 0.72;
	}
	COLOR = c;
}
