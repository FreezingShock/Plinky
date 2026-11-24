extends RefCounted
## The Larkmoor windmill sails (world/windmill_sails.gd): the sheet holds eight whole frames, its offset puts the hub on
## the sprite's foot with a whole-texel origin, the frames loop after eight steps, the pace rises with the wind and
## stays inside its bounds, and the sails hold still under Reduce Motion.


func run(t: Object) -> void:
	var m: Dictionary = WindmillSails.load_manifest()
	t.ok(not m.is_empty(), "the windmill sails manifest loads")
	if m.is_empty():
		return
	var frames: int = int(m.get("frames", 0))
	var fw: int = int(m.get("frame", 0))
	t.eq(frames, 8, "the sails turn in eight frames")
	t.ok(fw >= 8, "a sail frame is at least 8 texels across (%d)" % fw)
	var tex: Texture2D = load(WindmillSails.DIR + str(m.file)) as Texture2D
	t.ok(tex != null, "the sails sheet loads")
	if tex != null:
		t.eq(tex.get_width(), fw * frames, "the sheet is %d frames wide" % frames)
		t.eq(tex.get_height(), fw, "the sheet is one row of square frames")

	# The sprite's foot is the hub at (2180, 1009.4). The origin must land on whole texels, so the fraction sits in the offset.
	var off: Array = m.get("offset", []) as Array
	t.eq(off.size(), 2, "the offset has an x and a y")
	if off.size() == 2:
		var origin := Vector2(2180.0, 1009.4) + Vector2(float(off[0]), float(off[1]))
		t.ok(is_equal_approx(origin.x, roundf(origin.x)) and is_equal_approx(origin.y, roundf(origin.y)),
			"the sails' texture origin lands on whole texels (%s)" % str(origin))
		t.ok(absf(float(off[0])) == float(fw) * 0.5, "the hub sits at the middle of the frame, in x")

	# Frames: eight steps, then the loop closes (four arms repeat every 90 degrees, so the sheet is seamless).
	var seen: Dictionary = {}
	for acc in range(0, 8):
		seen[WindmillSails.frame_for(float(acc), frames, false)] = true
	t.eq(seen.size(), frames, "the sails visit every frame in one turn")
	t.eq(WindmillSails.frame_for(8.0, frames, false), 0, "the turn loops back to frame 0 after eight frames")
	t.eq(WindmillSails.frame_for(7.9, frames, false), 7, "frame 7 shows until the loop closes")

	# Reduce Motion: frame 0 at every turn.
	var still_ok: bool = true
	for acc in range(0, 32):
		if WindmillSails.frame_for(float(acc), frames, true) != 0:
			still_ok = false
	t.ok(still_ok, "the sails hold frame 0 under Reduce Motion")

	# Pace: the gust term stays in 0..1, and more wind turns the sails faster.
	var g_ok: bool = true
	for step in range(0, 400):
		var g: float = WindmillSails.gust01(step)
		if g < 0.0 or g > 1.0:
			g_ok = false
	t.ok(g_ok, "the gust term stays between 0 and 1")
	var calm: float = WindmillSails.rate_at(40, 0.0)
	var windy: float = WindmillSails.rate_at(40, 1.0)
	t.ok(windy > calm, "a windy day turns the sails faster than a calm one (%f > %f)" % [windy, calm])
	t.ok(calm > 0.0, "the sails turn even on a calm day")
	t.ok(windy < 1.0, "the sails never turn a whole frame in one life step")

	# Attach: the sprite shows one frame and gets the stepping node as a child, which frees with it.
	var sp := Sprite2D.new()
	var node: WindmillSails = WindmillSails.attach(sp, m)
	t.ok(node != null and node.get_parent() == sp, "the sails node is a child of the sails sprite")
	t.ok(sp.region_enabled, "the sails sprite shows a region of the sheet")
	t.eq(int(sp.region_rect.size.x), fw, "the sails sprite shows one frame wide")
	sp.free()
