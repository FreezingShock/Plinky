class_name MomentumMeter
extends PanelContainer
## Walking charges momentum (0..1), standing drains it. Shows the bar and the income bonus it gives.
## Behind DisplaySettings.momentum_meter (on by default), so Nathan can judge it and switch it off.

const BAR_WIDTH: float = 96.0

var _sim: Sim
var _bar: DitherBar
var _value: Label
var _shown: float = 0.0
var _blink: float = 0.0


func setup(p_sim: Sim) -> void:
	_sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 8.0, 4.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var cap := Label.new()
	cap.text = "Momentum"
	cap.modulate = Color(1, 1, 1, 0.7)
	h.add_child(cap)
	var bar_box := CenterContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar_box)
	_bar = DitherBar.new(BAR_WIDTH)
	bar_box.add_child(_bar)
	_value = Label.new()
	_value.custom_minimum_size.x = 42
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_value)
	_apply()


func _process(delta: float) -> void:
	# Appears with the Multiplier row, so a brand new player sees Cash alone (see Onboarding).
	var on: bool = DisplaySettings.momentum_meter and _sim != null and GameState.onboarding.is_unlocked(Onboarding.F_MULT)
	if visible != on:
		visible = on
	if not on:
		return
	_shown = move_toward(_shown, _sim.momentum, delta * 1.5)
	_blink += delta
	_apply()


func _apply() -> void:
	_bar.value = _shown
	var full: bool = _sim.momentum >= 0.995
	var pulse: bool = full and not FxConfig.reduce_flashing and fmod(_blink, 0.6) < 0.3
	_bar.fill = RelicStyle.accent if full else RelicStyle.good
	_value.text = "+%d%%" % roundi(_sim.momentum * _sim.config.momentum_max_bonus * 100.0)
	_value.modulate = RelicStyle.accent if pulse else Color.WHITE
