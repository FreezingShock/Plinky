class_name HoldPress
extends Node
## Hold-to-repeat for a pad. Call begin() on mouse/touch down, end() on up.
## Emits `tick` for every repeat press (the first one is the normal click).
## Starts at one press per 0.16 s after a 0.3 s delay and speeds up to 0.07 s.

signal tick
signal released

var held_for := 0.0
var _held := false
var _timer := 0.0

func begin() -> void:
	_held = true
	held_for = 0.0
	_timer = 0.3

func end() -> void:
	_held = false
	PressPopups.release_runs()
	released.emit()

func _process(delta: float) -> void:
	if _held:
		held_for += delta
		_timer -= delta
		if _timer <= 0.0:
			_timer = maxf(0.07, 0.16 - held_for * 0.03)
			tick.emit()
