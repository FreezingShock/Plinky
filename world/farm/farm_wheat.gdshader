shader_type canvas_item;

// Wheat that parts around the walker. A field sprite is a sheet of gust frames side by side, each frame_w texels wide.
// A texel is pushed away from the walker by an amount that falls off with distance and grows with height, so the base
// of each row stays rooted and the heads lean out of the way. Source texels are rounded, so the pixels stay crisp.
// Uniforms are set by FarmWheat, which owns these materials.

uniform vec2 walker_world = vec2(-99999.0, -99999.0);
uniform float frame_w = 96.0;
uniform float push_radius = 16.0;
uniform float push_amount = 4.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 px = floor(UV * size);
	float frame_x0 = floor(px.x / frame_w) * frame_w;
	// Tips move, the rows' bases (the bottom ~6 texels of the 44 tall sheet) stay put.
	float height_k = clamp((40.0 - px.y) / 16.0, 0.0, 1.0);
	vec2 d = world_pos - walker_world;
	float dist = length(d);
	float fall = 1.0 - smoothstep(0.0, push_radius, dist);
	vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
	vec2 src = px - dir * fall * height_k * push_amount;
	src.x = clamp(floor(src.x) + 0.5, frame_x0 + 0.5, frame_x0 + frame_w - 0.5);
	src.y = floor(src.y) + 0.5;
	COLOR = texture(TEXTURE, src / size);
}
