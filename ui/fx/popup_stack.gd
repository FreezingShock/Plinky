class_name PopupStack
extends RefCounted
## While the pad is held there is ONE running popup that keeps climbing:
## each press adds its gain to the same number, bumps it, and it grows and
## brightens at 10, 100 and 1000+. Letting go holds it 0.5 s, then it floats
## off like a normal popup. A normal single click makes a normal PopupNumber.

## Active zone id for palette lookups ("meadow", "quarry"...). Set on zone entry.
static var zone := "meadow"
static var _run: PopupNumber
static var _total := 0.0
static var _release_timer: SceneTreeTimer

## held = true while the pad is held down (HoldPress.begin() was called).
static func spawn(parent: Node, pos: Vector2, amount: float, big := false, held := false, crit := false) -> PopupNumber:
	if not held:
		return PopupNumber.spawn(parent, pos, amount, big, crit)
	if is_instance_valid(_run) and _run.is_running:
		_total += amount
		_run.bump(_total)
	else:
		_total = amount
		_run = PopupNumber.spawn_running(parent, pos, amount)
	return _run

## Call from HoldPress.end(): the running popup holds, then floats away.
static func release(tree: SceneTree) -> void:
	if is_instance_valid(_run):
		_run.release()
