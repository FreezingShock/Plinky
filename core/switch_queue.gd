class_name SwitchQueue
extends RefCounted
## Decides what happens when window-mode switches are requested while one is already playing.
## One switch runs at a time. Requests that arrive meanwhile collapse to the latest one, and run after the
## current switch only if they still differ from the mode it ended in. Pure logic, no nodes.

const NONE: int = -1

var busy: bool = false
var pending: int = NONE  ## NONE, 0 (windowed) or 1 (fullscreen)


## A switch to `on` is requested. True means the caller starts it now; false means it was queued or dropped.
func request(on: bool) -> bool:
	if busy:
		pending = 1 if on else 0
		return false
	busy = true
	return true


## The running switch finished and the window is now in `current`. Returns the next target (0 or 1) to run,
## or NONE. When a target is returned the queue stays busy.
func finish(current: bool) -> int:
	var next: int = pending
	pending = NONE
	if next != NONE and next != (1 if current else 0):
		return next
	busy = false
	return NONE


## Drop everything (a watchdog uses this when a switch hangs).
func reset() -> void:
	busy = false
	pending = NONE
