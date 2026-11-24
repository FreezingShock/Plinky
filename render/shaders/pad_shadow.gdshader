shader_type canvas_item;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: shadows must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Cast shadows on a pad. The pad is drawn on top of the baked ground, so the ground's height-march shadow
// (ground_light.gdshader) used to stop at its edge and the plate stayed fully lit inside a shadow. This does the same
// march from the pad's own top: the ground height under the fragment plus the slab's lift, toward the sun, with the
// same slope, reach and strength SkyCycle feeds the ground. A tree's shadow therefore falls across the pad too.
uniform sampler2D h_tex : filter_nearest;
uniform vec2 ground_origin = vec2(0.0);          // where the ground sprite sits in world texels
uniform float pad_lift = 6.0;                    // slab top above the ground, in encoded height units
uniform vec2 sun_px = vec2(-1.0, -1.0);
uniform float shadow_amt = 0.0;
uniform float shadow_slope = 2.6;
uniform float shadow_reach = 2.0;
uniform float shadow_soft = 0.0;                 // same feathered march as ground_light.gdshader
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.52, 0.80);

varying vec2 wpos;

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;
}

void fragment() {
	if (shadow_amt > 0.001) {
		vec2 sz = vec2(textureSize(h_tex, 0));
		vec2 px = 1.0 / sz;
		vec2 uv = (floor(wpos) + vec2(0.5) - ground_origin) / sz;
		float h0 = texture(h_tex, uv).r * 255.0 + pad_lift;
		float sh = 0.0;
		float pen = 0.5 + 6.0 * shadow_soft;
		for (int k = 1; k <= 12; k++) {
			float hn = texture(h_tex, uv + sun_px * float(k) * shadow_reach * px).r * 255.0;
			float over = hn - h0 - shadow_slope * float(k) * shadow_reach;
			float hit = smoothstep(-pen, pen, over) * step(0.5, hn);
			sh = max(sh, hit * (1.0 - shadow_soft * float(k) / 13.0));
		}
		COLOR.rgb *= mix(vec3(1.0), shadow_tint, min(shadow_amt, 1.0) * sh);
	}
}
