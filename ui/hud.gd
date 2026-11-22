class_name Hud
extends Control
## The in-game HUD, drawn in the same 640x360 texel space as the world. Reads the Sim at 10 Hz and
## calls the GameState API. Colours and fonts come from the theme on the root Control.

signal relic_panel_toggled(open: bool)
signal settings_toggled(open: bool)

## The frame the HUD lays out in (Main size). The gate panel and bottom bar hug its right and bottom edges.
var frame: Vector2 = Vector2(640.0, 360.0)
var _gate_panel: PanelContainer
var _bottom: HBoxContainer

const REFRESH: float = 0.1

var sim: Sim
var _rows: Dictionary = {}        # stat id -> [value Label, rate Label]
var _zone_label: Label
var _gate_label: Label
var _zone_buttons: HBoxContainer
var _rebirth: PixelButton
var _upgrades_panel: PanelContainer
var _upgrades_box: VBoxContainer
var _prestige_label: Label
var _offline: Label
var _clock: float = 0.0
var _attr_rows: Dictionary = {}   # attribute id -> [Label, Button]
var _zones_key: String = ""


func setup(p_sim: Sim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_stats()
	_build_gate()
	_build_bottom()
	_build_upgrades()
	_offline = Label.new()
	_offline.theme_type_variation = &"CaptionLabel"
	_offline.position = Vector2(200, 40)
	_offline.visible = false
	add_child(_offline)
	var bus: Node = get_node("/root/EventBus")
	bus.offline_gained.connect(_on_offline)
	var report: Dictionary = get_node("/root/Save").take_offline_report()
	if not report.is_empty():
		_on_offline(report["seconds"], report["gains"])
	_refresh()


func upgrades_open() -> bool:
	return _upgrades_panel.visible


func close_panels() -> void:
	_upgrades_panel.visible = false


func _panel(pos: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	return v


func _build_stats() -> void:
	var v: VBoxContainer = _panel(Vector2(4, 4))
	for sid: StringName in [&"cash", &"mult", &"reb", &"prestige"]:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var name_l := Label.new()
		name_l.text = def.display_name
		name_l.custom_minimum_size.x = 62
		name_l.modulate = Color(1, 1, 1, 0.7)
		h.add_child(name_l)
		var val := Label.new()
		val.custom_minimum_size.x = 56
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		var rate := Label.new()
		rate.modulate = Color(1, 1, 1, 0.7)
		h.add_child(rate)
		_rows[sid] = [val, rate]
	_prestige_label = _rows.get(&"prestige", [null, null])[1]


func _build_gate() -> void:
	var v: VBoxContainer = _panel(Vector2(456, 4))
	_gate_panel = v.get_parent() as PanelContainer
	_zone_label = Label.new()
	_zone_label.theme_type_variation = &"TitleLabel"
	v.add_child(_zone_label)
	_gate_label = Label.new()
	v.add_child(_gate_label)
	_zone_buttons = HBoxContainer.new()
	v.add_child(_zone_buttons)


func _build_bottom() -> void:
	var h := HBoxContainer.new()
	h.position = Vector2(4, 334)
	_bottom = h
	h.add_theme_constant_override("separation", 4)
	add_child(h)
	_rebirth = PixelButton.new()
	_rebirth.pressed.connect(func() -> void: GameState.try_rebirth())
	h.add_child(_rebirth)
	var up := PixelButton.new()
	up.text = "Upgrades [Tab]"
	up.pressed.connect(func() -> void: _upgrades_panel.visible = not _upgrades_panel.visible)
	h.add_child(up)
	if GameState.relics != null:
		var rb := PixelButton.new()
		rb.text = "Relics [R]"
		rb.pressed.connect(func() -> void: relic_panel_toggled.emit(true))
		h.add_child(rb)
	var st := PixelButton.new()
	st.text = "Settings [F10]"
	st.pressed.connect(func() -> void: settings_toggled.emit(true))
	h.add_child(st)


func _build_upgrades() -> void:
	_upgrades_panel = PanelContainer.new()
	_upgrades_panel.position = Vector2(4, 96)
	_upgrades_panel.visible = false
	add_child(_upgrades_panel)
	_upgrades_box = VBoxContainer.new()
	_upgrades_panel.add_child(_upgrades_box)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Upgrades"
	_upgrades_box.add_child(title)
	_prestige_avail = Label.new()
	_upgrades_box.add_child(_prestige_avail)
	var ids: Array = sim.attribute_defs.keys()
	ids.sort()
	for aid: StringName in ids:
		var a: AttributeDef = sim.attribute_defs[aid]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_upgrades_box.add_child(h)
		var l := Label.new()
		l.custom_minimum_size.x = 150
		h.add_child(l)
		var b := PixelButton.new()
		b.pressed.connect(func() -> void: GameState.buy_attribute(aid))
		h.add_child(b)
		_attr_rows[aid] = [l, b]

var _prestige_avail: Label


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_upgrades_panel.visible = not _upgrades_panel.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and GameState.relics != null:
			relic_panel_toggled.emit(true)
		elif event.keycode == KEY_F10:
			settings_toggled.emit(true)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_place()
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		_refresh()


## Right-hug the gate panel and bottom-hug the bottom bar, so a wider frame keeps them at its edges.
func _place() -> void:
	if _gate_panel != null:
		var gp: Vector2 = Vector2(frame.x - _gate_panel.size.x - 4.0, 4.0)
		if _gate_panel.position != gp:
			_gate_panel.position = gp
	if _bottom != null:
		var bp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - 4.0)
		if _bottom.position != bp:
			_bottom.position = bp


func _refresh() -> void:
	for sid: StringName in _rows:
		var pair: Array = _rows[sid]
		(pair[0] as Label).text = sim.get_stat(sid).format()
		var inc: BigNum = sim.income_per_second(sid)
		(pair[1] as Label).text = "+%s/s" % inc.format() if not inc.is_zero() else ""
	if _prestige_label != null:
		_prestige_label.text = "x%s" % sim.prestige_mult().format()
	var z: ZoneDef = sim.current_zone()
	_zone_label.text = z.display_name if z != null else ""
	_gate_label.text = _gate_text(z)
	_rebirth.disabled = not sim.can_rebirth()
	_rebirth.text = "Rebirth (+%s Prestige)" % sim.prestige_gain_preview().format() if sim.can_rebirth() else "Rebirth (need 1 Rebirths)"
	_refresh_zone_buttons()
	if _upgrades_panel.visible:
		_prestige_avail.text = "Prestige to spend: %s" % sim.prestige_available().format()
		for aid: StringName in _attr_rows:
			var a: AttributeDef = sim.attribute_defs[aid]
			var lv: int = sim.attr_level(aid)
			var row: Array = _attr_rows[aid]
			(row[0] as Label).text = "%s  %d/%d" % [a.display_name, lv, a.cap]
			var btn: PixelButton = row[1]
			btn.text = "MAX" if lv >= a.cap else "Buy %s" % sim.attribute_cost(aid).format()
			btn.disabled = lv >= a.cap or sim.prestige_available().lt(sim.attribute_cost(aid))


func _gate_text(z: ZoneDef) -> String:
	if z == null or z.gate_stat == &"":
		return "No gate here"
	if sim.is_gate_open(z.id):
		return "Gate open! Walk in."
	var have: float = minf(sim.get_stat(z.gate_stat).to_float(), z.gate_threshold)
	var cells: int = 10
	var filled: int = int(have / z.gate_threshold * float(cells))
	var name_s: String = (sim.stat_defs[z.gate_stat] as StatDef).display_name
	return "[%s%s] %d/%d %s" % ["#".repeat(filled), "-".repeat(cells - filled), int(have), int(z.gate_threshold), name_s]


## Buttons to travel to any unlocked zone other than the current one.
func _refresh_zone_buttons() -> void:
	var key: String = String(sim.zone_id)
	for zid: StringName in sim.zone_defs:
		if sim.is_zone_unlocked(zid):
			key += "|" + String(zid)
	if key == _zones_key:
		return
	_zones_key = key
	for c in _zone_buttons.get_children():
		c.queue_free()
	for zid: StringName in sim.zone_defs:
		if zid != sim.zone_id and sim.is_zone_unlocked(zid):
			var b := PixelButton.new()
			b.text = "Go: %s" % (sim.zone_defs[zid] as ZoneDef).display_name
			b.pressed.connect(func() -> void: GameState.enter_zone(zid))
			_zone_buttons.add_child(b)


func _on_offline(seconds: float, gains: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for sid: StringName in gains:
		parts.append("+%s %s" % [(gains[sid] as BigNum).format(), (sim.stat_defs[sid] as StatDef).display_name])
	_offline.text = "Welcome back! %d min away: %s" % [int(seconds / 60.0), ", ".join(parts)]
	_offline.visible = true
	var t := create_tween()
	t.tween_interval(5.0)
	t.tween_callback(func() -> void: _offline.visible = false)
