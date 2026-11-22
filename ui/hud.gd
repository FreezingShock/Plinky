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
var _pad_list: PadList
var _gate_bar: DitherBar
var _momentum: MomentumMeter
var _stats_panel: PanelContainer


func setup(p_sim: Sim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_stats()
	_build_gate()
	_build_bottom()
	_build_upgrades()
	_build_pad_list()
	_momentum = MomentumMeter.new()
	add_child(_momentum)
	_momentum.setup(sim)
	_offline = Label.new()
	_offline.theme_type_variation = &"CaptionLabel"
	_offline.position = Vector2(8, 282)
	_offline.custom_minimum_size.x = 440
	_offline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	p.add_theme_stylebox_override("panel", AsciiBox.panel())
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	return v


func _build_stats() -> void:
	var v: VBoxContainer = _panel(Vector2(4, 4))
	_stats_panel = v.get_parent() as PanelContainer
	for sid: StringName in [&"cash", &"mult", &"reb", &"prestige"]:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % String(sid)) as Texture2D
		icon.custom_minimum_size = Vector2(16, 16)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
		var name_l := Label.new()
		name_l.text = def.display_name
		name_l.custom_minimum_size.x = 66
		name_l.add_theme_color_override("font_color", RelicStyle.dim)
		h.add_child(name_l)
		var val := RollValue.new()
		val.big_gain.connect(_float_gain.bind(val, def.display_name, sid))
		val.custom_minimum_size.x = 90
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		var rate := Label.new()
		rate.add_theme_color_override("font_color", RelicStyle.dim)
		h.add_child(rate)
		_rows[sid] = [val, rate]
	_prestige_label = _rows.get(&"prestige", [null, null])[1]


## Big jumps in a stat float up beside its counter. Cash is left out: every press already pops its own number.
func _float_gain(amount: BigNum, val: RollValue, stat_name: String, sid: StringName) -> void:
	if sid == &"cash":
		return
	# Beside the stats panel, level with the counter, so it never sits on the HUD text.
	var at: Vector2 = Vector2(_stats_panel.position.x + _stats_panel.size.x + 8.0, val.global_position.y - global_position.y)
	PopupNumber.spawn_text(self, at, "+%s %s" % [amount.format(), stat_name], true)


func _build_gate() -> void:
	var v: VBoxContainer = _panel(Vector2(456, 4))
	_gate_panel = v.get_parent() as PanelContainer
	_zone_label = Label.new()
	_zone_label.theme_type_variation = &"TitleLabel"
	v.add_child(_zone_label)
	_gate_label = Label.new()
	_gate_bar = DitherBar.new(150.0)
	v.add_child(_gate_bar)
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
	st.text = "Settings [%s]" % Keybinds.key_name(&"settings")
	st.pressed.connect(func() -> void: settings_toggled.emit(true))
	h.add_child(st)


func _build_pad_list() -> void:
	_pad_list = PadList.new()
	_pad_list.position = Vector2(456, 96)
	add_child(_pad_list)


func _build_upgrades() -> void:
	_upgrades_panel = PanelContainer.new()
	_upgrades_panel.add_theme_stylebox_override("panel", AsciiBox.panel())
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
		var ic := TextureRect.new()
		ic.texture = load("res://assets/icons/%s.png" % _attr_icon(a)) as Texture2D
		ic.custom_minimum_size = Vector2(16, 16)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var l := Label.new()
		l.custom_minimum_size.x = 170
		h.add_child(l)
		var b := PixelButton.new()
		b.pressed.connect(func() -> void: GameState.buy_attribute(aid))
		h.add_child(b)
		_attr_rows[aid] = [l, b]

var _prestige_avail: Label


func _attr_icon(a: AttributeDef) -> String:
	var map: Dictionary = {&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck", &"offline_gain": "offline"}
	return String(map.get(a.id, "prestige"))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if Keybinds.matches(&"upgrades", event):
			_upgrades_panel.visible = not _upgrades_panel.visible
			get_viewport().set_input_as_handled()
		elif Keybinds.matches(&"relics", event) and GameState.relics != null:
			relic_panel_toggled.emit(true)
		elif Keybinds.matches(&"settings", event):
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
	if size != frame:
		size = frame
	if _gate_panel != null:
		var gp: Vector2 = Vector2(frame.x - _gate_panel.size.x - 4.0, 4.0)
		if _gate_panel.position != gp:
			_gate_panel.position = gp
	if _bottom != null and _momentum != null:
		var mp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - _momentum.size.y - 8.0)
		if _momentum.position != mp:
			_momentum.position = mp
	if _bottom != null:
		var bp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - 4.0)
		if _bottom.position != bp:
			_bottom.position = bp


func _refresh() -> void:
	for sid: StringName in _rows:
		var pair: Array = _rows[sid]
		(pair[0] as RollValue).set_target(sim.get_stat(sid))
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
	_pad_list.refresh(sim)
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
		_gate_bar.visible = false
		return "No gate here"
	_gate_bar.visible = true
	if sim.is_gate_open(z.id):
		_gate_bar.value = 1.0
		return "Gate open! Walk in."
	var have: float = minf(sim.get_stat(z.gate_stat).to_float(), z.gate_threshold)
	_gate_bar.value = have / z.gate_threshold
	var name_s: String = (sim.stat_defs[z.gate_stat] as StatDef).display_name
	return "%d/%d %s" % [int(have), int(z.gate_threshold), name_s]


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
