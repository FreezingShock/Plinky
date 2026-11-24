extends RefCounted

func run(t: Object) -> void:
	var none: Array[Rect2] = []
	t.eq(PopupClear.slide_clear(100.0, 40.0, 10.0, 16.0, none, 4.0, 4.0), 100.0, "no blockers leaves the popup where it is")
	var panel: Array[Rect2] = [Rect2(120.0, 0.0, 152.0, 200.0)]
	t.eq(PopupClear.slide_clear(100.0, 40.0, 10.0, 16.0, panel, 4.0, 4.0), 76.0, "a popup running under the panel slides left of it")
	t.eq(PopupClear.slide_clear(10.0, 40.0, 10.0, 16.0, panel, 4.0, 4.0), 10.0, "a popup clear of the panel is untouched")
	t.eq(PopupClear.slide_clear(100.0, 40.0, 300.0, 16.0, panel, 4.0, 4.0), 100.0, "a popup below the panel is untouched")
	var no_room: Array[Rect2] = [Rect2(30.0, 0.0, 152.0, 200.0)]
	t.ok(is_nan(PopupClear.slide_clear(20.0, 40.0, 10.0, 16.0, no_room, 4.0, 4.0)), "no room left of the panel skips the popup")
	var two: Array[Rect2] = [Rect2(120.0, 0.0, 50.0, 200.0), Rect2(60.0, 0.0, 50.0, 200.0)]
	t.eq(PopupClear.slide_clear(110.0, 20.0, 10.0, 16.0, two, 4.0, 4.0), 36.0, "a slide that lands on a second blocker keeps going")
