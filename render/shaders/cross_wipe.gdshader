shader_type canvas_item;
// Zone crossing wipe: a 4x4 Bayer dither fills the whole window with palette index 0 (ink), then clears.
// amount 0..1 is stepped by Transitions. px is the size of one dither cell in window pixels.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float px = 2.0;
uniform vec4 ink : source_color = vec4(0.078, 0.086, 0.110, 1.0);
const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

void fragment() {
	ivec2 c = ivec2(floor(FRAGCOORD.xy / px));
	float thr = (float(BAYER[(c.y & 3) * 4 + (c.x & 3)]) + 0.5) / 16.0;
	if (amount <= thr) {
		discard;
	}
	COLOR = ink;
}
