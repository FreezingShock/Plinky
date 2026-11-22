class_name PadList
extends PanelContainer
## Docked list of every pad in the current zone: row, cost and a ready marker.
## Refreshed by the Hud at 10 Hz. Swap or drop it by not adding it in Hud._build_pad_list.

var _rows: Dictionary = {}   ## button id -> Label
var _zone: StringName = &""


func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 10.0, 8.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(sim: Sim) -> void:
	if sim.zone_id != _zone:
		_zone = sim.zone_id
		for c in get_children():
			c.queue_free()
		_rows.clear()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		add_child(v)
		var t := Label.new()
		t.theme_type_variation = &"TitleLabel"
		t.text = "Pads"
		v.add_child(t)
		var defs: Array[ButtonDef] = []
		for b: ButtonDef in sim.button_defs.values():
			if b.zone == _zone:
				defs.append(b)
		defs.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool: return a.row_index < b.row_index if a.row == b.row else String(a.row) < String(b.row))
		for b in defs:
			var l := Label.new()
			v.add_child(l)
			_rows[b.id] = l
	for bid: StringName in _rows:
		var b: ButtonDef = sim.button_defs[bid]
		var l: Label = _rows[bid]
		var ready: bool = sim.can_afford(bid)
		l.text = "%s %s %d  %s" % ["*" if ready else "-", String(b.row).capitalize(), b.row_index + 1, Formulas.button_cost(b).format()]
		l.add_theme_color_override("font_color", RelicStyle.accent if ready else RelicStyle.dim)
