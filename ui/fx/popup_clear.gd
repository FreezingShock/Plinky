class_name PopupClear
extends RefCounted
## Pure geometry for world popups beside HUD panels. A popup that runs under a panel slides left of it;
## if there is no room left of the panel it is skipped for the frame rather than cut off.


## Returns the popup's x, moved clear of the first blocker it overlaps (repeatedly, in case that
## move lands on another). NAN when no clear spot fits at or right of `min_x` on the left of a blocker.
static func slide_clear(x: float, width: float, top: float, height: float, blocked: Array[Rect2], min_x: float, gap: float) -> float:
	var at: float = x
	for _i in blocked.size() + 1:
		var box: Rect2 = Rect2(at, top, width, height)
		var hit: Rect2 = Rect2()
		var found: bool = false
		for b: Rect2 in blocked:
			if box.intersects(b):
				hit = b
				found = true
				break
		if not found:
			return at
		at = hit.position.x - gap - width
		if at < min_x:
			return NAN
	return NAN
