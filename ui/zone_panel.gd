class_name ZonePanel
extends PanelContainer
## Top-right zone panel: where you are (name, gate progress), a foldable travel menu of every location with its
## areas, and the card of the area you are viewing (description, pads, mastery). While the travel menu is open the
## card folds down to a dithered stub; closed, it shows in full. Every row is a focusable button, so keyboard and pad
## focus walk it. Colours come from each zone's own palette (ZoneDef.theme_role, AreaDef.theme_role and icon).
## The mastery row sums the area's pads from `sim.mastery`.

const WIDTH: float = 176.0
const INNER: float = WIDTH - 16.0
const PEEK: float = 3.5   ## seconds the area card stays open after you walk into an area

signal travel_toggled(open: bool)

var sim: Sim
var travel_open: bool = false
var _view_area: StringName = &""
var _zone: StringName = &""
var _title: Label
var _gate_box: VBoxContainer
var _gate_bar: DitherBar
var _gate_label: Label
var _travel_btn: PixelButton
var _travel: RevealBox
var _zone_rows: Dictionary = {}     # zone id -> ListRow
var _zone_toggles: Dictionary = {}  # zone id -> ListRow
var _zone_areas: Dictionary = {}    # zone id -> RevealBox
var _area_rows: Dictionary = {}     # area id -> ListRow
var _card: RevealBox
var _card_title: Label
var _card_desc: Label
var _card_pads: VBoxContainer
var _pad_rows: Dictionary = {}      # button id -> Label
var _mastery_label: Label
var _mastery_bar: DitherBar
var _card_area: StringName = &""
var _peek_tween: Tween
var _gated: Array[Control] = []     # parts that wait for the rebirth row to unlock


func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.panel())
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_sim: Sim) -> void:
	sim = p_sim
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	_travel_btn = PixelButton.new()
	_travel_btn.text = "Travel +"
	_travel_btn.pressed.connect(func() -> void: set_travel_open(not travel_open))
	_bind(_travel_btn, func() -> Array: return ["Travel", "Pick a place to go, or look at another area. Hide the menu to read the full area card."])
	head.add_child(_travel_btn)
	_gate_box = VBoxContainer.new()
	_gate_box.add_theme_constant_override("separation", 2)
	v.add_child(_gate_box)
	_gate_bar = DitherBar.new(INNER)
	_gate_box.add_child(_gate_bar)
	_gate_label = Label.new()
	_gate_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind(_gate_label, _gate_tip)
	_gate_box.add_child(_gate_label)
	_gated = [_gate_box, _travel_btn]
	_travel = RevealBox.new()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	_travel.add_child(list)
	v.add_child(_travel)
	_build_list(list)
	_travel.set_open(false, false)
	_card = RevealBox.new()
	_card.floor_px = 0.0
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	_card.add_child(card)
	v.add_child(_card)
	_build_card(card)


## Binds a shared tooltip whose text comes from `provider` ([title, body], or empty for none) each time it shows.
func _bind(ctrl: Control, provider: Callable) -> void:
	Tip.bind(ctrl, func() -> Variant:
		var a: Array = provider.call() as Array
		if a.is_empty():
			return null
		return {"title": String(a[0]), "body": String(a[1]) if a.size() > 1 else ""})


func gated_parts() -> Array[Control]:
	return _gated


# ------------------------------------------------------------ travel list

func _zones_sorted() -> Array[ZoneDef]:
	var out: Array[ZoneDef] = []
	for z: ZoneDef in sim.zone_defs.values():
		out.append(z)
	out.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool: return a.order < b.order)
	return out


func palette_of(zone_id: StringName) -> PackedColorArray:
	return Palettes.colors(Palettes.for_zone(zone_id))


func zone_colour(z: ZoneDef) -> Color:
	return palette_of(z.id)[clampi(z.theme_role, 0, 7)]


func area_colour(a: AreaDef) -> Color:
	return palette_of(a.zone)[clampi(a.theme_role, 0, 7)]


func _build_list(list: VBoxContainer) -> void:
	for z in _zones_sorted():
		var zid: StringName = z.id
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 0)
		list.add_child(head)
		var tog := ListRow.new()
		tog.text = "+"
		tog.custom_minimum_size.x = 18
		tog.tint = zone_colour(z)
		tog.pressed.connect(func() -> void: _toggle_zone(zid))
		_bind(tog, func() -> Array: return ["Areas", "Show or hide the areas inside %s." % z.display_name])
		head.add_child(tog)
		_zone_toggles[zid] = tog
		var row := ListRow.new()
		row.tint = zone_colour(z)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(func() -> void: _go(zid, &""))
		_bind(row, func() -> Array: return _zone_tip(zid))
		head.add_child(row)
		_zone_rows[zid] = row
		var reveal := RevealBox.new()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		reveal.add_child(box)
		list.add_child(reveal)
		_zone_areas[zid] = reveal
		for a in sim.areas_in_zone(zid):
			var aid: StringName = a.id
			var ar := ListRow.new()
			ar.tint = area_colour(a)
			ar.text = "   " + a.display_name
			ar.area_icon = a.icon
			ar.pressed.connect(func() -> void: _go(zid, aid))
			_bind(ar, func() -> Array: return _area_tip(aid))
			box.add_child(ar)
			_area_rows[aid] = ar
		reveal.set_open(zid == sim.zone_id, false)


func _toggle_zone(zid: StringName, animate: bool = true) -> void:
	var r: RevealBox = _zone_areas[zid]
	r.set_open(not r._target, animate)
	_sync_toggles()


func _sync_toggles() -> void:
	for zid: StringName in _zone_toggles:
		(_zone_toggles[zid] as ListRow).text = "-" if (_zone_areas[zid] as RevealBox)._target else "+"


## Height of the folded card: the title row and exactly one description line, so no line is cut through.
func _stub_px() -> float:
	var font: Font = _card_desc.get_theme_font("font")
	var fs: int = _card_desc.get_theme_font_size("font_size")
	var line: float = maxf(_card_desc.get_line_height(), font.get_height(fs) if font != null else 0.0)
	return _card_title.get_combined_minimum_size().y + 2.0 + line + 3.0   # +3 keeps descenders (g, p, y) whole


func set_travel_open(on: bool, animate: bool = true) -> void:
	travel_open = on
	_travel.set_open(on, animate)
	if on:
		_card.floor_px = _stub_px()
		_card.set_open(false, animate)
	else:
		var b: Control = _card.body()
		var full: float = maxf(b.get_combined_minimum_size().y, 1.0) if b != null else 1.0
		_card.floor_px = 0.0
		_card.amount = minf(_stub_px() / full, 1.0)
		_card.set_open(true, animate)
	_travel_btn.text = "Travel -" if on else "Travel +"
	Tip.hide_all()
	travel_toggled.emit(on)


## Travel to `zid` if needed, then show `aid` (or the zone's first area).
func _go(zid: StringName, aid: StringName) -> void:
	if zid != sim.zone_id:
		if not sim.enter_zone(zid):
			return
	_zone = zid
	var areas: Array[AreaDef] = sim.areas_in_zone(zid)
	_view_area = aid if aid != &"" else (areas[0].id if not areas.is_empty() else &"")
	refresh()


## The walker walked into an area of the current zone.
func set_district(aid: StringName) -> void:
	if sim == null or not sim.area_defs.has(aid):
		return
	if (sim.area_defs[aid] as AreaDef).zone == sim.zone_id:
		var changed: bool = aid != _view_area
		_view_area = aid
		refresh()
		if changed:
			_peek()


## Entering an area shows its full card for PEEK seconds, then folds it to the one-line stub so it stops covering the world.
func _peek() -> void:
	if travel_open:
		return
	_card.floor_px = 0.0
	_card.set_open(true, true)
	if _peek_tween != null:
		_peek_tween.kill()
	_peek_tween = create_tween()
	_peek_tween.tween_interval(PEEK)
	_peek_tween.tween_callback(func() -> void:
		if not travel_open and not get_global_rect().has_point(get_global_mouse_position()):
			_card.floor_px = _stub_px()
			_card.set_open(false, true))


func view_area() -> StringName:
	return _view_area


# ------------------------------------------------------------ card

func _build_card(card: VBoxContainer) -> void:
	_card_title = Label.new()
	_card_title.theme_type_variation = &"TitleLabel"
	card.add_child(_card_title)
	_card_desc = Label.new()
	_card_desc.custom_minimum_size.x = INNER
	_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_desc.add_theme_color_override("font_color", RelicStyle.text)
	card.add_child(_card_desc)
	_card_pads = VBoxContainer.new()
	_card_pads.add_theme_constant_override("separation", 0)
	card.add_child(_card_pads)
	_mastery_label = Label.new()
	_mastery_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind(_mastery_label, _mastery_tip)
	card.add_child(_mastery_label)
	_mastery_bar = DitherBar.new(INNER)
	card.add_child(_mastery_bar)


func _rebuild_card() -> void:
	_card_area = _view_area
	for c in _card_pads.get_children():
		c.queue_free()
	_pad_rows.clear()
	var a: AreaDef = sim.area_defs.get(_view_area) as AreaDef
	if a == null:
		var z: ZoneDef = sim.current_zone()
		_card_title.text = z.display_name if z != null else ""
		_card_desc.text = z.description if z != null else ""
		return
	var col: Color = area_colour(a)
	_card_title.text = a.display_name
	_card_title.add_theme_color_override("font_color", col)
	_card_desc.text = a.blurb
	_mastery_bar.fill = col
	for bid in a.pad_buttons:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var id: StringName = StringName(bid)
		_bind(l, func() -> Array: return _pad_tip(id))
		_card_pads.add_child(l)
		_pad_rows[id] = l


func _pad_tip(id: StringName) -> Array:
	var b: ButtonDef = sim.button_defs.get(id) as ButtonDef
	if b == null:
		return []
	var cost: BigNum = Formulas.button_cost(b)
	var cost_name: String = (sim.stat_defs[b.cost_stat] as StatDef).display_name
	var gain_name: String = (sim.stat_defs[b.reward_stat] as StatDef).display_name
	var state: String = "Ready. Stand on it or hold click." if sim.can_afford(id) else "Need %s more." % cost.sub(sim.get_stat(b.cost_stat)).format()
	return ["%s %d" % [String(b.row).capitalize(), b.row_index + 1], "Costs %s %s. Gives +%s %s.\n%s" % [cost.format(), cost_name, sim.press_gain_preview(id).format(), gain_name, state]]


func _area_pads(aid: StringName) -> PackedStringArray:
	var a: AreaDef = sim.area_defs.get(aid) as AreaDef
	return a.pad_buttons if a != null else PackedStringArray()


## [level sum, level cap sum, mean progress 0..1, best crit chance bonus, best crit damage bonus] for the area's pads.
func _mastery_of(aid: StringName) -> Array:
	var m: Mastery = sim.mastery
	var lv: int = 0
	var prog: float = 0.0
	var n: int = 0
	var cc: float = 0.0
	var cd: float = 0.0
	for bid in _area_pads(aid):
		var id: StringName = StringName(bid)
		lv += m.level(id)
		prog += m.progress(id)
		cc += m.crit_chance_bonus(id)
		cd += m.crit_damage_bonus(id)
		n += 1
	return [lv, n * m.config.max_level, prog / maxf(float(n), 1.0), cc, cd]


func _mastery_tip() -> Array:
	var ms: Array = _mastery_of(_view_area)
	return ["Mastery", "Every press trains its pad. Levels add crit chance and crit damage.\nThis area: +%d%% crit chance, +%.2f crit damage in total.\nThe bar is the average progress to each pad's next level." % [roundi(float(ms[3]) * 100.0), float(ms[4])]]


func _zone_tip(zid: StringName) -> Array:
	var z: ZoneDef = sim.zone_defs[zid] as ZoneDef
	if not sim.is_zone_unlocked(zid):
		var prev: String = ""
		for o: ZoneDef in sim.zone_defs.values():
			if o.next_zone == zid:
				prev = o.display_name
		return ["Locked", "Open the gate in %s to come here." % prev]
	var n_pads: int = z.pad_buttons.size()
	var state: String = "You are here." if zid == sim.zone_id else "Click to travel."
	return [z.display_name, "%s\n%d areas, %d pads." % [state, sim.areas_in_zone(zid).size(), n_pads]]


func _area_tip(aid: StringName) -> Array:
	var a: AreaDef = sim.area_defs[aid] as AreaDef
	var here: String = " You are in this zone." if a.zone == sim.zone_id else " Click to travel there."
	return [a.display_name, "%s\n%d pads.%s" % [a.blurb, a.pad_buttons.size(), here]]


func _gate_tip() -> Array:
	var z: ZoneDef = sim.current_zone()
	if z == null or z.gate_stat == &"":
		return []
	var nm: String = (sim.stat_defs[z.gate_stat] as StatDef).display_name
	return ["Gate", "Reach %d %s to open the way on. Walk into the gate once it glows." % [int(z.gate_threshold), nm]]


# ------------------------------------------------------------ refresh (10 Hz from the Hud)

func refresh() -> void:
	var z: ZoneDef = sim.current_zone()
	if z == null:
		return
	if z.id != _zone:
		_zone = z.id
		var areas: Array[AreaDef] = sim.areas_in_zone(z.id)
		if not sim.area_defs.has(_view_area) or (sim.area_defs[_view_area] as AreaDef).zone != z.id:
			_view_area = areas[0].id if not areas.is_empty() else &""
		for zid: StringName in _zone_areas:
			(_zone_areas[zid] as RevealBox).set_open(zid == z.id)
		_sync_toggles()
	if _card_area != _view_area or _pad_rows.is_empty() and _view_area != &"":
		_rebuild_card()
	_title.text = z.display_name
	_title.add_theme_color_override("font_color", zone_colour(z))
	for zid: StringName in _zone_rows:
		var zd: ZoneDef = sim.zone_defs[zid] as ZoneDef
		var row: ListRow = _zone_rows[zid]
		var open: bool = sim.is_zone_unlocked(zid)
		row.text = ("%s (here)" % zd.display_name if zid == sim.zone_id else zd.display_name) if open else "??? (locked)"
		row.disabled = not open
		(_zone_toggles[zid] as ListRow).disabled = not open
		(_zone_areas[zid] as RevealBox).visible = open
	for aid: StringName in _area_rows:
		(_area_rows[aid] as ListRow).marked = aid == _view_area
	for bid: StringName in _pad_rows:
		var b: ButtonDef = sim.button_defs[bid]
		var ready: bool = sim.can_afford(bid)
		var l: Label = _pad_rows[bid]
		l.text = "%s %s %d  %s" % ["*" if ready else "-", String(b.row).capitalize(), b.row_index + 1, Formulas.button_cost(b).format()]
		l.add_theme_color_override("font_color", RelicStyle.accent if ready else RelicStyle.dim)
	var ms: Array = _mastery_of(_view_area)
	_mastery_label.text = "Mastery  Lv %d/%d" % [int(ms[0]), int(ms[1])]
	_mastery_label.add_theme_color_override("font_color", RelicStyle.text)
	_mastery_bar.value = float(ms[2])
	_gate_text(z)


func _gate_text(z: ZoneDef) -> void:
	if z.gate_stat == &"":
		_gate_bar.visible = false
		_gate_label.text = "No gate here"
		return
	_gate_bar.visible = true
	if sim.is_gate_open(z.id):
		_gate_bar.value = 1.0
		_gate_label.text = "Gate open! Walk in." if z.next_zone != &"" else "Gate open! Nothing past it yet."
		return
	var have: float = minf(sim.get_stat(z.gate_stat).to_float(), z.gate_threshold)
	_gate_bar.value = have / z.gate_threshold
	_gate_label.text = "%d/%d %s" % [int(have), int(z.gate_threshold), (sim.stat_defs[z.gate_stat] as StatDef).display_name]
