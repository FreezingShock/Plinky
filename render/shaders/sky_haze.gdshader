shader_type canvas_item;
// The WorldCamera's transform (RenderGlobals.set_world). MODEL_MATRIX includes it, so it is divided out to get
// true world texels: dither and lights must not shift when the camera pans or zooms.
global uniform vec2 world_origin;
global uniform float world_scale;
// Haze over the far mountains and drifting mist over the water. Both are dither: a texel is either lit with
// the haze colour or left alone, picked by comparing a density to the 4x4 Bayer matrix in world texels.
//  - mountains: density rises with distance from the island (atmospheric perspective) inside a horizon band.
//  - mist: slow stepped noise that drifts sideways, only over water (found by sampling the backdrop).
// `ground` is the backdrop texture, `ground_origin` where its texel (0, 0) sits in world texels.

uniform sampler2D ground : filter_nearest;
uniform vec2 ground_origin = vec2(-100.0, -60.0);
uniform vec3 haze_col : source_color = vec3(0.62, 0.82, 0.70);
uniform float haze = 0.6;          // mountain haze strength 0..1
uniform float mist = 0.5;          // mist strength 0..1 (already scaled by time of day and weather)
uniform float drift = 0.0;         // integer texels the mist has drifted
uniform float horizon_y = 150.0;   // world y of the horizon band centre
uniform float band_half = 46.0;
uniform float island_x = 320.0;
uniform float island_half = 250.0; // beyond this distance from island_x the mountains start
uniform vec4 island = vec4(295.0, 178.0, 265.0, 155.0);   // island ellipse: centre xy, radii xy (mist stays off it)
uniform vec4 ponds[3];                                     // lake and ponds: centre xy, radii xy (rx 0 = unused)

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
varying vec2 wpos;

float bayer4(ivec2 p) {
	ivec2 q = p & ivec2(3);
	return (float(BAYER[q.y * 4 + q.x]) + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin) / world_scale;   // world texels, not screen pixels
}

void fragment() {
	ivec2 t = ivec2(floor(wpos));
	vec2 p = vec2(t) + 0.5;
	float thr = bayer4(t);
	float dens = 0.0;
	// mountains: a band around the horizon, thicker the further from the island
	float band = 1.0 - smoothstep(0.0, band_half, abs(p.y - horizon_y));
	float away = smoothstep(island_half - 40.0, island_half + 110.0, abs(p.x - island_x));
	float land = smoothstep(0.22, 0.34, dot(texture(ground, (p - ground_origin) / vec2(textureSize(ground, 0))).rgb, vec3(0.299, 0.587, 0.114)));
	dens = haze * band * away * land;
	// mist: over water only (dark green backdrop texels), streaky: stretched along x, drifting.
	// The noise is the expensive part and the island and the sky have no mist, so it only runs where mist can show.
	vec2 gp = (p - ground_origin) / vec2(textureSize(ground, 0));
	vec3 g = texture(ground, gp).rgb;
	float water = 1.0 - smoothstep(0.30, 0.42, dot(g, vec3(0.299, 0.587, 0.114)));
	float below = smoothstep(horizon_y - 10.0, horizon_y + 30.0, p.y);
	vec2 iq = (p - island.xy) / island.zw;
	float sea = smoothstep(1.0, 1.1, length(iq));
	float on_pond = 0.0;
	for (int i = 0; i < 3; i++) {
		vec4 pd = ponds[i];
		if (pd.z > 0.0) {
			on_pond = max(on_pond, 1.0 - smoothstep(0.7, 1.15, length((p - pd.xy) / pd.zw)));
		}
	}
	float cover = max(water * below * sea, on_pond * 0.8);
	float m = 0.0;
	if (mist > 0.0 && cover > 0.0) {
		float n = vnoise(vec2((p.x - drift) * 0.045, p.y * 0.22)) * 0.65 + vnoise(vec2((p.x - drift * 1.7) * 0.11 + 7.0, p.y * 0.5)) * 0.35;
		m = mist * cover * smoothstep(0.38, 0.8, n);
	}
	// mist is the cool, pale part: the haze colour pulled toward grey so a sunset does not paint the water orange
	vec3 mist_col = mix(vec3(dot(haze_col, vec3(0.299, 0.587, 0.114))), haze_col, 0.3);
	float mist_d = m * 0.7;
	if (thr < mist_d && mist_d >= dens) {
		COLOR = vec4(mist_col, 0.5);
	} else if (thr < dens) {
		COLOR = vec4(haze_col, 0.62);   // one fixed step toward the haze colour; the dither does the fade
	} else {
		COLOR = vec4(0.0);
	}
}
