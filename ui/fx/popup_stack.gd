class_name PopupStack
extends RefCounted
## Stacks popups upward while presses keep coming: each new number pushes the
## older ones up 14 texels (whole texels, stepped). Keeps at most 3 older ones,
## so a held pad shows a short readable column instead of a wall of numbers.
## Hold-combo total sits above the column (see HoldPress).

const STEP := 14
const MAX_OLDER := 3
static var _live: Array[PopupNumber] = []

static func spawn(parent: Node, pos: Vector2, amount: float, big := false) -> PopupNumber:
	_live = _live.filter(func(p): return is_instance_valid(p))
	for p in _live:
		p.position.y -= STEP
	while _live.size() > MAX_OLDER:
		_live.pop_front().queue_free()
	var n := PopupNumber.spawn(parent, pos, amount, big)
	_live.append(n)
	return n
