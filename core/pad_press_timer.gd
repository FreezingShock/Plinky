class_name PadPressTimer
extends RefCounted
## The press clock for one pad. A walker standing on the pad and a held mouse button press on this same clock,
## so both give the same rate: one press at once, then one every Sim.press_interval() seconds.
## Pure: no nodes, so tests drive it with fake frame times.

var _timer: float = 0.0


## The next step fires at once (the walker just arrived on the pad).
func arm() -> void:
	_timer = 0.0


## A press was just made by hand (the first click of a hold): the next repeat comes one interval later.
func start(interval: float) -> void:
	_timer = interval


## Call every frame with whether anything is pressing the pad (walker standing on it, or mouse held on it).
## Returns true when a press lands this frame. At most one press per frame, so a long frame cannot burst.
func step(delta: float, pressing: bool, interval: float) -> bool:
	if not pressing:
		return false
	_timer -= delta
	if _timer > 0.0:
		return false
	_timer = interval
	return true
