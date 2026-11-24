extends RefCounted
## Popup banners: spec normalising, queue and dedupe, centre-out typing, timeline, reduced motion, area composition.

func run(t: Object) -> void:
	var n: Dictionary = BannerQueue.normalize({"title": "Heronmere", "lines": ["a", "", "b"], "duration": 99})
	t.eq(n["lines"], ["a", "b"], "empty lines are dropped")
	t.eq(n["duration"], BannerQueue.MAX_DURATION, "duration is clamped")
	t.eq(BannerQueue.normalize({"title": "X"})["duration"], BannerQueue.DEFAULT_DURATION, "duration defaults")
	t.eq(BannerQueue.normalize({"title": "X", "key": "k"})["key"], "k", "an explicit key is kept")

	var q := BannerQueue.new()
	t.ok(not q.push({}, 0.0), "an empty banner is dropped")
	t.ok(q.push({"title": "A"}, 0.0), "a banner queues")
	t.ok(not q.push({"title": "A"}, 0.1), "a duplicate of a waiting banner is dropped")
	t.eq(q.next()["title"], "A", "next returns the head")
	t.ok(not q.push({"title": "A"}, 0.2), "a duplicate of the current banner is dropped")
	q.finish(1.0)
	t.ok(not q.push({"title": "A"}, 2.0), "a repeat just after it finished is dropped")
	t.ok(q.push({"title": "A"}, 1.0 + BannerQueue.REPEAT_WINDOW + 0.1), "it can show again after the repeat window")
	q.clear()
	for i in 6:
		q.push({"title": "B%d" % i}, 100.0)
	t.eq(q.pending.size(), BannerQueue.MAX_PENDING, "the queue holds at most MAX_PENDING")
	t.eq(q.pending[0]["title"], "B2", "the oldest waiting banner is the one dropped")
	q.next()
	q.push({"title": "Now", "interrupt": true}, 100.0)
	t.eq(q.pending.size(), 1, "an interrupt clears the queue")
	t.ok(q.wants_interrupt(), "an interrupt asks to end the current banner")

	t.eq(BannerQueue.slice("abcdef", 0.0), "", "nothing shows at progress 0")
	t.eq(BannerQueue.slice("abcdef", 1.0), "abcdef", "everything shows at progress 1")
	t.eq(BannerQueue.slice("abcdef", 0.5), "bcd", "half shows from the centre")
	t.eq(BannerQueue.slice("abcde", 0.2), "c", "one character is the middle one")
	t.eq(BannerQueue.window_start(7, 3), 2, "the window starts so the run is centred")
	var prev: int = 0
	var grows: bool = true
	for i in 21:
		var k: int = BannerQueue.visible_count(9, i / 20.0)
		grows = grows and k >= prev
		prev = k
	t.ok(grows and prev == 9, "typing never shrinks on the way in")

	var tl: Dictionary = BannerQueue.timeline(20, 2.5, false)
	t.ok(tl["in"] >= 0.25 and tl["in"] <= 0.9 and tl["out"] < tl["in"], "in is bounded and out is quicker")
	t.near(BannerQueue.total_time(3, tl), 2.0 * tl["stagger"] + tl["in"] + 2.5 + tl["out"], 0.0001, "total time adds up")
	t.eq(BannerQueue.line_progress(0.0, 0, 3, tl), 0.0, "line 0 starts empty")
	t.ok(BannerQueue.line_progress(0.0, 2, 3, tl) == 0.0 and BannerQueue.line_progress(tl["stagger"], 2, 3, tl) == 0.0, "later lines start later")
	t.eq(BannerQueue.line_progress(BannerQueue.out_start(3, tl) - 0.01, 1, 3, tl), 1.0, "every line is whole while it holds")
	t.eq(BannerQueue.line_progress(BannerQueue.total_time(3, tl), 1, 3, tl), 0.0, "everything has collapsed at the end")
	var mid: float = BannerQueue.line_progress(BannerQueue.out_start(3, tl) + tl["out"] * 0.5, 0, 3, tl)
	t.ok(mid > 0.0 and mid < 1.0, "the collapse is gradual")
	var snap: Dictionary = BannerQueue.timeline(20, 2.5, true)
	t.eq(BannerQueue.line_progress(0.0, 0, 3, snap), 1.0, "reduced motion shows the banner whole at once")
	t.eq(BannerQueue.total_time(3, snap), 2.5, "reduced motion has no typing or collapse time")

	# Word bands take a clock fraction (daylight 0.6: sunrise 04:48 = 0.2, sunset 19:12 = 0.8).
	t.eq(AreaBanner.period_of(0.0), "Night", "midnight is night")
	t.eq(AreaBanner.period_of(0.2), "Dawn", "sunrise (04:48) is dawn")
	t.eq(AreaBanner.period_of(0.5), "Midday", "noon is midday")
	t.eq(AreaBanner.period_of(0.8), "Dusk", "sunset (19:12) is dusk")
	t.eq(AreaBanner.period_of(0.728), "Afternoon", "17:28, the golden pin, is afternoon and not dusk")
	t.eq(AreaBanner.compose("X", {}, 0.728)["lines"][0], "17:28 - Afternoon", "the fallback clock reads 17:28 as afternoon")
	t.eq(AreaBanner.clock_of(0.25), {"hour": 6, "minute": 0}, "clock 0.25 is 06:00")
	t.eq(AreaBanner.clock_text(6, 5), "06:05", "the clock is zero padded")
	var b: Dictionary = AreaBanner.compose("Larkmoor", {}, 0.5, "lake")
	t.eq(b["title"], "Larkmoor", "the area name is the title")
	t.eq(b["lines"], ["12:00 - Midday"], "no calendar: only the sky time shows")
	var c: Dictionary = AreaBanner.compose("Larkmoor", {"season_name": "Spring", "month_name": "Early Spring", "day": 3, "hour": 7, "minute": 30}, 0.5)
	t.eq(c["lines"], ["Early Spring - Day 3", "07:30 - Morning"], "a calendar adds month, day and its own time")
	t.eq(AreaBanner.compose("X", {"season": 3}, 0.0)["lines"][0], "Winter", "a season index maps to its name")

	# Zone banners carry their palette: the fill passes through to the shown banner, and an unset fill stays null.
	t.eq(BannerQueue.normalize({"title": "Meadow", "fill": Color.BLACK})["fill"], Color.BLACK, "a zone fill is kept")
	t.eq(BannerQueue.normalize({"title": "Meadow"})["fill"], null, "no fill means the default panel")
	var zq := BannerQueue.new()
	zq.push({"title": "Larkmoor", "fill": Color.BLACK, "key": "zone:larkmoor"}, 0.0)
	t.eq(zq.next()["fill"], Color.BLACK, "the fill reaches the banner that is shown")

	# A lazy banner (built when it shows) can be queued with no text yet, and is repeat-checked by its resolved key.
	var lazy_q := BannerQueue.new()
	t.ok(lazy_q.push({"key": "zone_arrival", "resolve": func() -> Dictionary: return {}}, 0.0), "a lazy banner queues without text")
	t.ok(BannerQueue.normalize({"title": "X", "resolve": func() -> Dictionary: return {}})["resolve"] is Callable, "normalize keeps the resolver")
	lazy_q.next()
	lazy_q.finish(5.0)
	t.ok(lazy_q.is_repeat("zone:larkmoor", 6.0) == false, "a different resolved key is not a repeat")
	lazy_q.current = {"key": "zone:larkmoor"}
	lazy_q.finish(5.0)
	t.ok(lazy_q.is_repeat("zone:larkmoor", 6.0), "the same resolved key within the window is a repeat")
	t.ok(not lazy_q.is_repeat("zone:larkmoor", 5.0 + BannerQueue.REPEAT_WINDOW + 0.1), "and it is not one after the window")

	# Momentum-style avoid rect: 640x360 host, meter bottom-left (x 4..264, y 270..310 in top coordinates).
	var host := Vector2(640, 360)
	var meter := Rect2(4, 270, 260, 40)
	t.near(BannerQueue.bottom_clearance(host, Vector2(320, 50), meter, 34.0, 6.0), 96.0, 0.001, "a banner over the meter lifts above it")
	t.near(BannerQueue.bottom_clearance(host, Vector2(100, 50), meter, 34.0, 6.0), 34.0, 0.001, "a narrow banner clear of the meter stays low")
	t.near(BannerQueue.bottom_clearance(host, Vector2(320, 50), Rect2(500, 270, 130, 40), 34.0, 6.0), 34.0, 0.001, "a banner clear of the meter horizontally stays low")
	t.near(BannerQueue.bottom_clearance(host, Vector2(320, 50), Rect2(4, 20, 260, 40), 34.0, 6.0), 34.0, 0.001, "a meter far above the banner does not lift it")
