class_name HoldRepeat
extends RefCounted
## Timing for hold-to-repeat buttons (Upgrades Buy). Pure: no nodes, so tests drive it with fake frame times.
## begin() on press, end() on release, step(delta) every frame returns how many repeats came due.
## The press itself is the first purchase (the caller makes it); repeats start after DELAY, then speed up
## from START_GAP to MIN_GAP the longer the button is held.

const DELAY: float = 0.35
const START_GAP: float = 0.2
const MIN_GAP: float = 0.04
const SPEEDUP_PER_SECOND: float = 0.07   ## gap shrinks by this much for each second held

var held: bool = false
var held_for: float = 0.0
var repeats: int = 0
var _timer: float = 0.0


func begin() -> void:
	held = true
	held_for = 0.0
	repeats = 0
	_timer = DELAY


func end() -> void:
	held = false


## Repeats due after `delta` seconds. Never more than 3 in one call, so a long frame cannot burst-spend.
func step(delta: float) -> int:
	if not held:
		return 0
	held_for += delta
	_timer -= delta
	var due: int = 0
	while _timer <= 0.0 and due < 3:
		due += 1
		_timer += gap()
	if _timer <= 0.0:
		_timer = gap()
	repeats += due
	return due


func gap() -> float:
	return maxf(MIN_GAP, START_GAP - held_for * SPEEDUP_PER_SECOND)
