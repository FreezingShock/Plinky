class_name PadTooltip
extends PanelContainer
## Hover tooltip for a pad: what it costs, what it gives, and how far off you are.
## Uses the theme's panel and fonts. Never takes mouse input.

var _title: Label
var _cost: Label
var _gain: Label
var _state: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	v.add_child(_title)
	_cost = Label.new()
	v.add_child(_cost)
	_gain = Label.new()
	v.add_child(_gain)
	_state = Label.new()
	_state.modulate = Color(1, 1, 1, 0.75)
	v.add_child(_state)


## Fill for one button and place near `at` (screen texels), kept inside the 640x360 view.
func show_for(sim: Sim, button_id: StringName, at: Vector2) -> void:
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		hide_tip()
		return
	var cost_def: StatDef = sim.stat_defs[b.cost_stat] as StatDef
	var reward_def: StatDef = sim.stat_defs[b.reward_stat] as StatDef
	var cost: BigNum = Formulas.button_cost(b)
	var have: BigNum = sim.get_stat(b.cost_stat)
	_title.text = "%s %d" % [String(b.row).capitalize(), b.row_index + 1]
	_cost.text = "Costs %s %s" % [cost.format(), cost_def.display_name]
	_gain.text = "Gives +%s %s" % [sim.press_gain_preview(button_id).format(), reward_def.display_name]
	if have.gte(cost):
		_state.text = "Ready. Stand here or hold click."
	else:
		_state.text = "Need %s more" % cost.sub(have).format()
	visible = true
	reset_size()
	var p: Vector2 = at + Vector2(10.0, 12.0)
	p.x = clampf(p.x, 2.0, 640.0 - size.x - 2.0)
	if p.y + size.y > 358.0:
		p.y = at.y - size.y - 8.0
	position = p.round()


func hide_tip() -> void:
	visible = false
