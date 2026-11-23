extends RefCounted
## Window placement suite: first-launch centring and clamping a restored window onto one usable screen,
## on a two-monitor desktop of different sizes with a dead zone. Run through tests/run.gd.

func run(t: SceneTree) -> void:
	var a := Rect2i(0, 0, 1920, 1040)       # 1080p, taskbar excluded
	var b := Rect2i(1920, 0, 1920, 1483)    # taller monitor to its right: 3840x1483 desktop, dead zone under A
	var screens: Array[Rect2i] = [a, b]
	var min_size := Vector2i(640, 360)

	# Straddling the seam: lands whole on the screen holding most of it.
	var r: Rect2i = WindowPlace.fit(Rect2i(1500, 300, 1280, 720), screens, min_size)
	t.ok(a.encloses(r) or b.encloses(r), "a window straddling the seam ends up on one screen")
	t.eq(r.size, Vector2i(1280, 720), "size is kept when it fits")
	t.ok(b.encloses(r), "420 px on A against 860 px on B: B holds most, so it lands on B")

	# More on B than A goes to B.
	r = Rect2i(1800, 200, 1280, 720)
	r = WindowPlace.fit(r, screens, min_size)
	t.ok(b.encloses(r), "mostly on B moves wholly onto B")

	# Sitting in the dead zone below A: nearest screen, fully inside.
	r = WindowPlace.fit(Rect2i(100, 1200, 1280, 720), screens, min_size)
	t.ok(a.encloses(r), "dead-zone window is pulled onto A")
	r = WindowPlace.fit(Rect2i(1000, 1300, 800, 600), screens, min_size)
	t.ok(a.encloses(r), "partly in the dead zone, mostly off A: still ends up wholly on A")

	# Off every screen.
	r = WindowPlace.fit(Rect2i(-5000, -5000, 1280, 720), screens, min_size)
	t.ok(a.encloses(r), "far off-screen window returns to the nearest screen")
	r = WindowPlace.fit(Rect2i(9000, 400, 1280, 720), screens, min_size)
	t.ok(b.encloses(r), "off the right edge returns to B")

	# Bigger than the screen shrinks to fit.
	r = WindowPlace.fit(Rect2i(0, 0, 4000, 3000), screens, min_size)
	t.ok(a.encloses(r) or b.encloses(r), "an oversized window is shrunk onto one screen")

	# Negative coordinates (a monitor left of or above the primary).
	var left: Array[Rect2i] = [Rect2i(-1920, 0, 1920, 1080), Rect2i(0, 0, 2560, 1440)]
	r = WindowPlace.fit(Rect2i(-1000, 900, 1280, 720), left, min_size)
	t.ok(left[0].encloses(r), "negative-coordinate screens work")

	# Already fine stays put.
	var ok_rect := Rect2i(200, 100, 1280, 720)
	t.eq(WindowPlace.fit(ok_rect, screens, min_size), ok_rect, "a window already on a screen is unchanged")

	# No screens: unchanged rather than a crash.
	var none: Array[Rect2i] = []
	t.eq(WindowPlace.fit(ok_rect, none, min_size), ok_rect, "no screens leaves the rect alone")

	# First launch: centred, capped at 90% of a small screen, never below the minimum.
	var c: Rect2i = WindowPlace.centered(b, Vector2i(1280, 720), min_size)
	t.eq(c.size, Vector2i(1280, 720), "1280x720 on a large screen")
	t.eq(c.position, Vector2i(1920 + (1920 - 1280) / 2, (1483 - 720) / 2), "centred on that screen")
	var small := Rect2i(0, 0, 1366, 728)
	c = WindowPlace.centered(small, Vector2i(1280, 720), min_size)
	t.ok(small.encloses(c) and c.size.y <= int(728 * 0.9), "capped to 90% on a short screen")
	c = WindowPlace.centered(Rect2i(0, 0, 800, 500), Vector2i(1280, 720), min_size)
	t.ok(Rect2i(0, 0, 800, 500).encloses(c), "a tiny screen still gets a window inside it")

	t.eq(WindowPlace.screen_at(Vector2i(2000, 1400), screens), 1, "cursor on B")
	t.eq(WindowPlace.screen_at(Vector2i(100, 1200), screens), -1, "cursor in the dead zone")
