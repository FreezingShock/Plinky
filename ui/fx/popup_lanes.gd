class_name PopupLanes
extends RefCounted
## Pure geometry for press popup placement, so it can be tested without a scene. A popup's box is its number plus its
## stat caption. `c` is the popup's origin (the number's centre line), `drop` is how far the box hangs below `c` (the
## caption), and the box runs from `c.y - box.y + drop` down to `c.y + drop`, centred on `c.x`.

const STACK_GAP: float = 3.0     ## pixels kept between a stacked popup and the one it sits on
const MAX_RISE: float = 120.0    ## a stacked popup never sits higher than this above its pad


static func rect(c: Vector2, box: Vector2, drop: float) -> Rect2:
	return Rect2(c.x - box.x * 0.5, c.y - box.y + drop, box.x, box.y)


static func overlaps(r: Rect2, others: Array[Rect2]) -> int:
	var n: int = 0
	for o: Rect2 in others:
		if r.intersects(o):
			n += 1
	return n


## The lane offset (from origin) for a new popup. Fixed lanes are tried first, in order, so a quiet screen looks as it
## always did. If every fixed lane is taken, the popup stacks directly above another popup: the lowest such slot that
## clears every other box and stays within MAX_RISE. Only when nothing clears does it take the lane with fewest overlaps.
static func pick(origin: Vector2, box: Vector2, drop: float, others: Array[Rect2], lanes: Array[Vector2]) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_hits: int = 1000000
	for ln: Vector2 in lanes:
		var n: int = overlaps(rect(origin + ln, box, drop), others)
		if n == 0:
			return ln
		if n < best_hits:
			best_hits = n
			best = ln
	var found: bool = false
	var stack: Vector2 = Vector2.ZERO
	for o: Rect2 in others:
		# Sit so this box's bottom edge clears the top of `o` by STACK_GAP.
		var ln_y: float = o.position.y - STACK_GAP - drop - origin.y
		if ln_y < -MAX_RISE:
			continue
		var cand: Vector2 = Vector2(0.0, ln_y)
		if overlaps(rect(origin + cand, box, drop), others) != 0:
			continue
		if not found or cand.y > stack.y:
			stack = cand
			found = true
	return stack if found else best
