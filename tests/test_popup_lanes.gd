extends RefCounted
## Press popup placement (ui/fx/popup_lanes.gd) and the merge rules in PressPopups: a caption counts toward a popup's
## space, a crowded pad stacks upward instead of overlapping, and same-currency presses from neighbouring pads fold into one.

func run(t: Object) -> void:
	# --- box geometry: the caption hangs below the number, so the box covers both
	var box: Vector2 = Vector2(40.0, 16.0)
	var r: Rect2 = PopupLanes.rect(Vector2(100.0, 100.0), box, 13.0)
	t.near(r.position.x, 80.0, 1e-6, "a box is centred on its origin")
	t.near(r.position.y, 97.0, 1e-6, "the box top is box height above the origin, less the caption drop")
	t.near(r.size.y, 16.0, 1e-6, "the box keeps its height")
	t.near(PopupLanes.rect(Vector2.ZERO, Vector2(190.0, 16.0), 0.0).size.x, 190.0, 1e-6, "a box is as wide as the caption it carries")

	# --- lanes: an empty screen keeps the first lane, and a clear lane wins over stacking
	var lanes: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-22.0, -6.0), Vector2(22.0, -6.0)]
	var none: Array[Rect2] = []
	t.eq(PopupLanes.pick(Vector2(200.0, 200.0), box, 13.0, none, lanes), Vector2(0.0, 0.0), "an empty screen uses the first lane")
	var side: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-60.0, 0.0)]
	var one: Array[Rect2] = [PopupLanes.rect(Vector2(200.0, 200.0), box, 13.0)]
	t.eq(PopupLanes.pick(Vector2(200.0, 200.0), box, 13.0, one, side), Vector2(-60.0, 0.0), "a taken first lane moves the popup to the next clear lane")

	# --- stacking: every fixed lane is covered, so the popup sits just above the one on top of it
	var origin: Vector2 = Vector2(200.0, 200.0)
	var wall: Array[Rect2] = [Rect2(100.0, 150.0, 220.0, 80.0)]
	var stacked: Vector2 = PopupLanes.pick(origin, box, 13.0, wall, lanes)
	t.eq(stacked.x, 0.0, "a stacked popup stays centred on its pad")
	t.ok(stacked.y < 0.0 and stacked.y >= -PopupLanes.MAX_RISE, "a stacked popup sits above the pad, within the rise limit (got %s)" % stacked.y)
	t.eq(PopupLanes.overlaps(PopupLanes.rect(origin + stacked, box, 13.0), wall), 0, "the stacked popup clears the one beneath it")

	# --- when the slot above is out of reach, a lane still comes back (the least crowded one)
	var high_wall: Array[Rect2] = [Rect2(100.0, 150.0, 220.0, 80.0), Rect2(100.0, 60.0, 220.0, 80.0)]
	var fallback: Vector2 = PopupLanes.pick(origin, box, 13.0, high_wall, lanes)
	t.ok(lanes.has(fallback) or fallback.y < 0.0, "with no clear slot a lane is still returned")

	# --- merging: same-currency presses on neighbouring pads fold into one number, other currencies do not
	var pp := PressPopups.new()
	pp._ready()
	pp.press(&"pad_a", Vector2(100.0, 100.0), 10.0, 0, false, false, false, 0.0, "Starbloom Petals", Color.WHITE)
	pp.press(&"pad_b", Vector2(180.0, 100.0), 5.0, 0, false, false, false, 0.0, "Starbloom Petals", Color.WHITE)
	t.eq(pp.live_count(), 1, "same-currency presses on pads about a pad apart fold into one popup")
	var merged: PressPopups.Pop = null
	for p in pp._pops:
		if p.live:
			merged = p
	t.ok(merged != null and absf(merged.total - 15.0) < 1e-6, "the merged popup carries both amounts")
	t.ok(merged != null and merged.cap_w > 0.0, "the merged popup keeps its currency caption width")
	pp.press(&"pad_c", Vector2(120.0, 100.0), 3.0, 0, false, false, false, 0.0, "Clover", Color.WHITE)
	t.eq(pp.live_count(), 2, "a different currency never folds in, even right beside the number")
	pp.press(&"pad_d", Vector2(600.0, 100.0), 4.0, 0, false, false, false, 0.0, "Starbloom Petals", Color.WHITE)
	t.eq(pp.live_count(), 3, "a same-currency press far across the screen starts its own number")
	PressPopups.instance = null
	pp.free()

	# --- a pooled popup forgets its caption, so a label never inherits one
	var pq := PressPopups.new()
	pq._ready()
	pq.press(&"pad_a", Vector2(100.0, 100.0), 10.0, 0, false, false, false, 0.0, "Starbloom Petals", Color.WHITE)
	pq.label(&"bonus", Vector2(300.0, 100.0), "+5", 1)
	var labelled: PressPopups.Pop = null
	for p in pq._pops:
		if p.live and p.text == "+5":
			labelled = p
	t.ok(labelled != null, "a label popup is live")
	t.eq(labelled.stat if labelled != null else "x", "", "a label popup carries no stat caption")
	t.eq(labelled.cap_w if labelled != null else 1.0, 0.0, "a label popup reserves no caption width")
	PressPopups.instance = null
	pq.free()
