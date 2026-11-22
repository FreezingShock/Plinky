class_name HoldPress
extends Node
## Hold-to-repeat for a pad. Call begin() on mouse/touch down, end() on up.
## Emits `tick` for every repeat press (the first one is the normal click).
## Starts at one press per 0.16 s after a 0.3 s delay and speeds up to 0.07 s.

signal tick
signal combo_changed(total: float, active: bool)

var held_for := 0.0
var combo := 0.0
var _held := false
var _timer := 0.0
var _combo_hold := 0.0

func begin() -> void:
	_held = true
	held_for = 0.0
	_timer = 0.3

func end() -> void:
	_held = false

## Add each press's gain here so the combo total tracks what the player earned.
func add_gain(amount: float) -> void:
	combo += amount
	_combo_hold = 0.9

func _process(delta: float) -> void:
	if _held:
		held_for += delta
		_timer -= delta
		if _timer <= 0.0:
			_timer = maxf(0.07, 0.16 - held_for * 0.03)
			tick.emit()
	if _combo_hold > 0.0:
		_combo_hold -= delta
		if _combo_hold <= 0.0 and not _held:
			combo = 0.0
	# The combo total only shows after ~0.8 s of holding.
	combo_changed.emit(combo, combo > 0.0 and (held_for > 0.8 or _combo_hold > 0.0 and held_for > 0.8))
