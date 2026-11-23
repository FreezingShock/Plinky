class_name ZonePanel
extends PanelContainer
## Top-right zone panel: where you are (name, gate progress), a foldable travel menu of the top-level areas (Meadow,
## Ember Quarry) plus a few locked teasers for what comes next, and the card of the district you are viewing (description, pads, mastery). While the travel menu is open the
## card folds down to a dithered stub; closed, it shows in full. Every row is a focusable button, so keyboard and pad
## focus walk it. Colours come from each zone's own palette (ZoneDef.theme_role, AreaDef.theme_role and icon).
## The mastery row sums the area's pads from `sim.mastery`.

const WIDTH: float = 176.0
const INNER: float = WIDTH - 16.0
const PEEK: float = 3.5   ## seconds the area card stays open after you walk into an area
const PADS_SHOWN: int = 4      ## pads listed when an area has more than PADS_FOLD of them; the rest fold behind "N more..."
const PADS_FOLD: int = 5
const PADS_MAX_PX: float = 96.0   ## tallest the expanded pad list grows before it scrolls, so the panel never leaves the screen

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
var _zone_rows: Dictionary = {}     # top-level zone id -> ListRow
var _teaser_rows: Array[ListRow] = []
var _card: RevealBox
var _card_title: Label
var _card_desc: Label
var _card_pads: VBoxContainer
var _pads_scroll: ScrollContainer
var _pads_more: Label
var _pads_expanded: bool = false
var _pad_rows: Dictionary = {}      # button id -> Label
var _mastery_label: Label
var _mastery_bar: DitherBar
var _card_area: StringName = &""
var _peek_tween: Tween
var _gated: Array[Control] = []     # parts that wait for the rebirth row to unlock


func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.panel())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A panel only ever grows by itself; let it shrink back when the card folds so no empty space is left below.
	minimum_size_changed.connect(func() -> void: set_deferred("size", Vector2(size.x, 0.0)))


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


## The top-level area a zone belongs to: Larkmoor is part of the Meadow, so it has no row of its own.
func top_of(zid: StringName) -> StringName:
	var cur: StringName = zid
	for _i in 8:
		var z: ZoneDef = sim.zone_defs.get(cur) as ZoneDef
		if z == null or z.travel_parent == &"" or not sim.zone_defs.has(z.travel_parent):
			break
		cur = z.travel_parent
	return cur


## Top-level areas in travel order.
func top_zones() -> Array[ZoneDef]:
	var out: Array[ZoneDef] = []
	for z in _zones_sorted():
		if top_of(z.id) == z.id:
			out.append(z)
	return out


## Where a click on a top-level row lands: the furthest unlocked zone inside it (the Meadow row opens Larkmoor once
## the Meadow gate is open), or the zone you are already in.
func destination(top: StringName) -> StringName:
	if top_of(sim.zone_id) == top:
		return sim.zone_id
	var best: StringName = top
	for z in _zones_sorted():
		if top_of(z.id) == top and sim.is_zone_unlocked(z.id):
			best = z.id
	return best


func _build_list(list: VBoxContainer) -> void:
	for z in top_zones():
		var zid: StringName = z.id
		var row := ListRow.new()
		row.tint = zone_colour(z)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(func() -> void: _go(destination(zid), &""))
		_bind(row, func() -> Array: return _zone_tip(zid))
		list.add_child(row)
		_zone_rows[zid] = row
	for i in sim.config.travel_teased_rows:
		var t := ListRow.new()
		t.text = "??? (soon)"
		t.tint = RelicStyle.dim
		t.disabled = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bind(t, func() -> Array: return ["Locked", "A new area is on the way."])
		list.add_child(t)
		_teaser_rows.append(t)


## Height of the folded card: the title row and the whole (wrapped) description, so no line is cut through.
func _stub_px() -> float:
	var font: Font = _card_desc.get_theme_font("font")
	var fs: int = _card_desc.get_theme_font_size("font_size")
	var h: float = _card_desc.get_line_height()
	if font != null:
		h = maxf(h, font.get_multiline_string_size(_card_desc.text, HORIZONTAL_ALIGNMENT_LEFT, INNER, fs).y)
	return _card_title.get_combined_minimum_size().y + 2.0 + h + 3.0   # +3 keeps descenders (g, p, y) whole


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
	_pads_scroll = ScrollContainer.new()
	_pads_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pads_scroll.custom_minimum_size.x = INNER
	_pads_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(_pads_scroll)
	_card_pads = VBoxContainer.new()
	_card_pads.add_theme_constant_override("separation", 0)
	_card_pads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pads_scroll.add_child(_card_pads)
	_pads_more = Label.new()
	_pads_more.mouse_filter = Control.MOUSE_FILTER_STOP
	_pads_more.focus_mode = Control.FOCUS_ALL
	_pads_more.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pads_more.add_theme_color_override("font_color", RelicStyle.dim)
	_pads_more.gui_input.connect(_on_more_input)
	_pads_more.draw.connect(func() -> void:   # underline
		var f: Font = _pads_more.get_theme_font("font")
		var fs: int = _pads_more.get_theme_font_size("font_size")
		var w: float = f.get_string_size(_pads_more.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = f.get_ascent(fs) + 2.0
		_pads_more.draw_rect(Rect2(0.0, y, w, 1.0), RelicStyle.dim))
	_bind(_pads_more, func() -> Array: return ["Pads", "Click to show or hide the rest of this area's pads."])
	card.add_child(_pads_more)
	_mastery_label = Label.new()
	_mastery_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind(_mastery_label, _mastery_tip)
	card.add_child(_mastery_label)
	_mastery_bar = DitherBar.new(INNER)
	card.add_child(_mastery_bar)


func _on_more_input(ev: InputEvent) -> void:
	var hit: bool = ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if hit or ev.is_action_pressed(&"ui_accept"):
		_pads_expanded = not _pads_expanded
		_pads_more.accept_event()
		Tip.hide_all()
		_layout_pads()


## Shows the pads that matter first. Up to PADS_FOLD pads all show. Longer lists show PADS_SHOWN of them, starting
## one before the first pad you cannot afford yet (so the next goals lead), and fold the rest behind a "N more..." line.
func _layout_pads() -> void:
	var ids: Array = _pad_rows.keys()
	var n: int = ids.size()
	var fold: bool = n > PADS_FOLD
	var start: int = 0
	if fold and not _pads_expanded:
		var first_wait: int = n
		for i in n:
			if not sim.can_afford(ids[i] as StringName):
				first_wait = i
				break
		start = clampi(first_wait - 1, 0, n - PADS_SHOWN)
	for i in n:
		(_pad_rows[ids[i]] as Label).visible = not fold or _pads_expanded or (i >= start and i < start + PADS_SHOWN)
	_pads_more.visible = fold
	if fold:
		_pads_more.text = "Show less" if _pads_expanded else "%d more..." % (n - PADS_SHOWN)
		_pads_more.queue_redraw()
	var rows: int = n if (_pads_expanded or not fold) else PADS_SHOWN
	var line: float = 12.0
	if n > 0:
		line = maxf((_pad_rows[ids[0]] as Label).get_combined_minimum_size().y, 1.0)
	_pads_scroll.custom_minimum_size.y = minf(float(rows) * line, PADS_MAX_PX)
	_pads_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if _pads_expanded else ScrollContainer.SCROLL_MODE_DISABLED


func _rebuild_card() -> void:
	_card_area = _view_area
	_pads_expanded = false
	for c in _card_pads.get_children():
		c.queue_free()
	_pad_rows.clear()
	var a: AreaDef = sim.area_defs.get(_view_area) as AreaDef
	if a == null:
		var z: ZoneDef = sim.current_zone()
		_card_title.text = z.display_name if z != null else ""
		_card_desc.text = z.description if z != null else ""
		_layout_pads()
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
	_layout_pads()
	if travel_open:
		_card.floor_px = _stub_px()


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
				prev = top_name_of(o.id)
		return ["Locked", "Open the gate in %s to come here." % prev]
	var n_pads: int = 0
	for o in _zones_sorted():
		if top_of(o.id) == zid:
			n_pads += o.pad_buttons.size()
	var state: String = "You are here." if top_of(sim.zone_id) == zid else "Click to travel."
	return [z.display_name, "%s\n%d pads." % [state, n_pads]]


func top_name_of(zid: StringName) -> String:
	return (sim.zone_defs[top_of(zid)] as ZoneDef).display_name


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
	if _card_area != _view_area or _pad_rows.is_empty() and _view_area != &"":
		_rebuild_card()
	_title.text = z.display_name
	_title.add_theme_color_override("font_color", zone_colour(z))
	_fit_title()
	var here: StringName = top_of(sim.zone_id)
	for zid: StringName in _zone_rows:
		var zd: ZoneDef = sim.zone_defs[zid] as ZoneDef
		var row: ListRow = _zone_rows[zid]
		var open: bool = sim.is_zone_unlocked(zid)
		row.text = ("%s (here)" % zd.display_name if zid == here else zd.display_name) if open else "??? (locked)"
		row.disabled = not open
		row.marked = zid == here
	for bid: StringName in _pad_rows:
		var b: ButtonDef = sim.button_defs[bid]
		var ready: bool = sim.can_afford(bid)
		var l: Label = _pad_rows[bid]
		l.text = "%s %s %d  %s" % ["*" if ready else "-", String(b.row).capitalize(), b.row_index + 1, Formulas.button_cost(b).format()]
		l.add_theme_color_override("font_color", RelicStyle.accent if ready else RelicStyle.dim)
	if not _pads_expanded and _pad_rows.size() > PADS_FOLD:
		_layout_pads()
	var ms: Array = _mastery_of(_view_area)
	_mastery_label.text = "Mastery  Lv %d/%d" % [int(ms[0]), int(ms[1])]
	_mastery_label.add_theme_color_override("font_color", RelicStyle.text)
	_mastery_bar.value = float(ms[2])
	_gate_text(z)


## Long zone names ("Ember Quarry") drop to the small title size instead of running under the Travel button.
func _fit_title() -> void:
	var font: Font = _title.get_theme_font("font")
	var avail: float = INNER - _travel_btn.get_combined_minimum_size().x - 4.0
	var big: int = _title.get_theme_font_size("font_size")
	_title.remove_theme_font_size_override("font_size")
	big = _title.get_theme_font_size("font_size")
	if font != null and font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x > avail:
		_title.add_theme_font_size_override("font_size", 12)


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
