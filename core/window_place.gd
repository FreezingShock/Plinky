class_name WindowPlace
extends RefCounted
## Where a window may sit on a multi-monitor desktop. Pure rect math (no nodes), so it is testable headless.
## Screens are usable rects (taskbar and menu bar excluded) in desktop coordinates, which can be negative and
## can leave dead zones between monitors of different sizes.


static func overlap_area(a: Rect2i, b: Rect2i) -> int:
	var i: Rect2i = a.intersection(b)
	return maxi(0, i.size.x) * maxi(0, i.size.y)


## Index of the screen that holds most of `rect`. When it overlaps none (it sits in a dead zone or off every
## screen), the screen whose centre is nearest. -1 when there are no screens.
static func pick_screen(rect: Rect2i, screens: Array[Rect2i]) -> int:
	var best: int = -1
	var best_area: int = 0
	for i in screens.size():
		var a: int = overlap_area(rect, screens[i])
		if a > best_area:
			best_area = a
			best = i
	if best >= 0:
		return best
	var centre: Vector2 = Vector2(rect.position) + Vector2(rect.size) * 0.5
	var best_d: float = INF
	for i in screens.size():
		var d: float = centre.distance_squared_to(Vector2(screens[i].position) + Vector2(screens[i].size) * 0.5)
		if d < best_d:
			best_d = d
			best = i
	return best


## `rect` moved (and shrunk, never below `min_size` unless the screen is smaller) to sit wholly inside one screen.
static func fit(rect: Rect2i, screens: Array[Rect2i], min_size: Vector2i) -> Rect2i:
	var idx: int = pick_screen(rect, screens)
	if idx < 0:
		return rect
	var s: Rect2i = screens[idx]
	var size: Vector2i = Vector2i(
		mini(rect.size.x, s.size.x),
		mini(rect.size.y, s.size.y))
	size = Vector2i(maxi(size.x, mini(min_size.x, s.size.x)), maxi(size.y, mini(min_size.y, s.size.y)))
	var pos: Vector2i = Vector2i(
		clampi(rect.position.x, s.position.x, s.position.x + s.size.x - size.x),
		clampi(rect.position.y, s.position.y, s.position.y + s.size.y - size.y))
	return Rect2i(pos, size)


## A window of `want` size centred on `screen`, shrunk to at most `fraction` of it (but not under `min_size`).
static func centered(screen: Rect2i, want: Vector2i, min_size: Vector2i, fraction: float = 0.9) -> Rect2i:
	var cap: Vector2i = Vector2i(int(screen.size.x * fraction), int(screen.size.y * fraction))
	var size: Vector2i = Vector2i(mini(want.x, cap.x), mini(want.y, cap.y))
	size = Vector2i(maxi(size.x, min_size.x), maxi(size.y, min_size.y))
	size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
	return Rect2i(screen.position + (screen.size - size) / 2, size)


## Index of the screen containing point `p`, or -1.
static func screen_at(p: Vector2i, screens: Array[Rect2i]) -> int:
	for i in screens.size():
		if screens[i].has_point(p):
			return i
	return -1
