extends RefCounted
## Every world shader that dithers or places light in world texels divides the WorldCamera transform out of
## MODEL_MATRIX (globals world_origin / world_scale). Without that, dither cells are screen pixels at zoom 2+ and
## the pattern shimmers across the ground while the camera pans.

const SHADERS: Array[String] = [
	"cast_shadow", "day_night", "god_rays", "ground_fog", "ground_light", "light_grade", "light_shafts", "sky_haze", "wind_sway",
]

func run(t: Object) -> void:
	for n: String in SHADERS:
		var src: String = FileAccess.get_file_as_string("res://render/shaders/%s.gdshader" % n)
		t.ok(src.contains("global uniform vec2 world_origin;") and src.contains("global uniform float world_scale;"), "%s declares the world transform globals" % n)
		t.ok(src.contains("- world_origin) / world_scale"), "%s converts wpos to world texels" % n)
	var vig: String = FileAccess.get_file_as_string("res://render/shaders/vignette.gdshader")
	t.ok(vig.contains("global uniform vec2 world_origin;") and vig.contains("- world_origin) / world_scale"), "vignette reads the camera globals")
	var pad: String = FileAccess.get_file_as_string("res://render/shaders/pad_shadow.gdshader")
	t.ok(pad.contains("- world_origin) / world_scale") and pad.contains("h_tex"), "pad shadow shader is world-anchored and reads the height map")
	RenderGlobals.set_world(Vector2(12.0, -7.0), 3.0)
	t.ok(true, "set_world runs")
	RenderGlobals.set_world(Vector2.ZERO, 1.0)
