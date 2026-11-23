class_name Hud
extends Control
## The in-game HUD, drawn in the same 640x360 texel space as the world. Reads the Sim at 10 Hz and
## calls the GameState API. Colours and fonts come from the theme on the root Control.

signal relic_panel_toggled(open: bool)
signal settings_toggled(open: bool)
## The Upgrades chip or key was used. Main routes it through MenuRouter, so one menu is open at a time.
signal menu_toggled(kind: StringName)
signal index_requested(tab: int)   ## IndexPanel.Tab: the Stats or Attributes button or key

## The frame the HUD lays out in (Main size). The gate panel and bottom bar hug its right and bottom edges.
var frame: Vector2 = Vector2(640.0, 360.0)
var _gate_panel: PanelContainer
var _bottom: HBoxContainer

const REFRESH: float = 0.1

var sim: Sim
var _rows: Dictionary = {}        # stat id -> [value Label, rate Label]
var _row_boxes: Dictionary = {}   # stat id -> HBoxContainer (Slag only shows once you are past zone 1)
var _zone_panel: ZonePanel
var _rebirth: ExpandChip
var _upgrades_panel: PanelContainer
var _upgrades_box: VBoxContainer
var _prestige_label: Label
var _offline: Label
var _clock: float = 0.0
var _attr_rows: Dictionary = {}   # attribute id -> [Label, Button]
var _tip_card: TipCard
var _gated: Array = []            # [node, feature] pairs; see gate()
var _gates_ready: bool = false    # false until the first pass, so nothing flashes at startup
var _momentum: MomentumMeter
var _stats_panel: PanelContainer
var _menu_chip: ExpandChip   # hamburger, bottom right
var _key_chips: Array[ExpandChip] = []   # number keys 1 to 5 press these, in order (Rebirth is left out on purpose)
var _centered: Array[Control] = []   # panels kept centred in the free area above the bottom bar


func setup(p_sim: Sim) -> void:
	sim = p_sim
	GameState.onboarding.update()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_stats()
	_build_gate()
	_build_bottom()
	_build_upgrades()
	_build_tip_card()
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


func upgrades_panel() -> Control:
	return _upgrades_panel


func toggle_upgrades() -> void:
	menu_toggled.emit(&"upgrades")


## The hamburger chip, so Main can keep it above open menus.
func menu_chip() -> Control:
	return _menu_chip


## Travel: show the zone panel's Travel list (the gallery's Travel tile calls this).
func open_travel() -> void:
	_zone_panel.set_travel_open(true)


## The bottom bar. Main keeps it above every menu so its chips stay clickable while a menu is open.
func bottom_bar() -> Control:
	return _bottom


func owns_focus(c: Control) -> bool:
	return c != null and _bottom != null and _bottom.is_ancestor_of(c)


## Keep `p` centred in the free area above the bottom bar (clamped to stay on screen).
func keep_centered(p: Control) -> void:
	_centered.append(p)


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


## Bottom edge of the stats panel in HUD coordinates, so panels below it (relic bar) follow its height.
func stats_bottom() -> float:
	if _stats_panel == null:
		return 4.0
	return _stats_panel.position.y + _stats_panel.get_combined_minimum_size().y


func _build_stats() -> void:
	var v: VBoxContainer = _panel(Vector2(4, 4))
	_stats_panel = v.get_parent() as PanelContainer
	_stats_panel.add_to_group(TipHost.AVOID_GROUP)
	for sid: StringName in [&"cash", &"mult", &"reb", &"slag", &"prestige"]:
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
		Tip.bind_all(h, TipText.stat(sid, def.display_name))
		_row_boxes[sid] = h
		match sid:
			&"mult": gate(h, Onboarding.F_MULT)
			&"reb": gate(h, Onboarding.F_REBIRTH_ROW)
			&"prestige": gate(h, Onboarding.F_UPGRADES)
	_prestige_label = _rows.get(&"prestige", [null, null])[1]


## Big jumps in a stat float up beside its counter. Cash is left out: every press already pops its own number.
func _float_gain(amount: BigNum, val: RollValue, stat_name: String, sid: StringName) -> void:
	if sid == &"cash":
		return
	# Beside the stats panel, level with the counter, so it never sits on the HUD text.
	var at: Vector2 = Vector2(_stats_panel.position.x + _stats_panel.size.x + 8.0, val.global_position.y - global_position.y)
	PopupNumber.spawn_text(self, at, "+%s %s" % [amount.format(), stat_name], true)


func _build_gate() -> void:
	_zone_panel = ZonePanel.new()
	_zone_panel.position = Vector2(456, 4)
	add_child(_zone_panel)
	_zone_panel.setup(sim)
	_gate_panel = _zone_panel
	_zone_panel.add_to_group(TipHost.AVOID_GROUP)   # relic tooltips stay clear of it
	gate(_zone_panel, Onboarding.F_MULT)
	for part: Control in _zone_panel.gated_parts():
		gate(part, Onboarding.F_REBIRTH_ROW)


## The walker entered an area (Larkmoor district): the zone card follows.
func set_district(id: StringName) -> void:
	_zone_panel.set_district(id)


func _build_bottom() -> void:
	var h := HBoxContainer.new()
	h.position = Vector2(4, 334)
	_bottom = h
	h.add_theme_constant_override("separation", 4)
	add_child(h)
	_rebirth = _chip(h, "reb", "Rebirth", "Reset the run for Prestige.")
	_rebirth.pressed.connect(func() -> void: GameState.try_rebirth())
	Tip.bind(_rebirth, func() -> Variant: return TipText.rebirth(sim.can_rebirth(), sim.prestige_gain_preview().format()))
	gate(_rebirth, Onboarding.F_REBIRTH_BUTTON)
	var up: ExpandChip = _chip(h, "prestige", "Upgrades", "Spend Prestige on permanent upgrades.", "Keys: %s or 1" % Keybinds.key_name(&"upgrades"))
	up.full_text = "Upgrades [Tab]"
	up.pressed.connect(toggle_upgrades)
	_key_chips.append(up)
	gate(up, Onboarding.F_UPGRADES)
	if GameState.relics != null:
		var rb: ExpandChip = _chip(h, "relics/r_pulse", "Relics", "Equip relics you have found.", "Keys: %s or 2" % Keybinds.key_name(&"relics"))
		rb.full_text = "Relics [R]"
		rb.pressed.connect(func() -> void: relic_panel_toggled.emit(true))
		_key_chips.append(rb)
		gate(rb, Onboarding.F_RELICS)
	for t: int in 2:
		var nm: String = ["Stats", "Attributes"][t]
		var act: StringName = [&"stats", &"attributes"][t]
		var ib: ExpandChip = _chip(h, ["stats_menu", "attrs_menu"][t], nm, "Open the %s list." % nm.to_lower(), "Keys: %s or %d" % [Keybinds.key_name(act), 3 + t])
		ib.full_text = "%s [%s]" % [nm, Keybinds.key_name(act)]
		ib.pressed.connect(func() -> void: index_requested.emit(t))
		_key_chips.append(ib)
		gate(ib, Onboarding.F_MULT if t == 0 else Onboarding.F_UPGRADES)
	# Settings and the Update Log live in the hamburger menu, at the far right of the screen.
	_menu_chip = _chip(self, "big/menu_hamburger", "Menu", "Settings, the update log and every section.", "Keys: %s or 5" % Keybinds.key_name(&"menu"))
	_menu_chip.full_text = "Menu [%s]" % Keybinds.key_name(&"menu")
	_menu_chip.bubble_right = true   # its label opens leftwards, away from the screen edge
	_menu_chip.pressed.connect(func() -> void: menu_toggled.emit(&"gallery"))
	_key_chips.append(_menu_chip)


## A bottom-bar chip: icon at rest, icon + label on hover or focus. Tooltip names it while it is collapsed.
func _chip(parent: Control, icon_name: String, tip_title: String, tip_body: String, tip_hint: String = "") -> ExpandChip:
	var c := ExpandChip.new()
	c.icon = load("res://assets/icons/%s.png" % icon_name) as Texture2D
	c.expand_icon = false
	parent.add_child(c)
	Tip.bind(c, {"title": tip_title, "body": tip_body, "hint": tip_hint})
	return c


func _build_upgrades() -> void:
	_upgrades_panel = PanelContainer.new()
	_upgrades_panel.add_theme_stylebox_override("panel", AsciiBox.panel())
	_upgrades_panel.visible = false
	add_child(_upgrades_panel)
	keep_centered(_upgrades_panel)
	_upgrades_box = VBoxContainer.new()
	_upgrades_box.add_theme_constant_override("separation", 2)
	_upgrades_panel.add_child(_upgrades_box)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Upgrades"
	_upgrades_box.add_child(title)
	_prestige_avail = Label.new()
	_prestige_avail.add_theme_color_override("font_color", RelicStyle.dim)
	_upgrades_box.add_child(_prestige_avail)
	_upgrades_box.add_child(PanelDivider.new())
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
		Tip.bind_all(h, func() -> Variant:
			return TipText.attribute(a, sim.attr_level(aid), sim.attribute_cost(aid).format(), not sim.prestige_available().lt(sim.attribute_cost(aid))))

var _prestige_avail: Label


func _attr_icon(a: AttributeDef) -> String:
	var map: Dictionary = {&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck", &"offline_gain": "offline"}
	return String(map.get(a.id, "prestige"))


func _input(event: InputEvent) -> void:   # _input, not unhandled: ui_focus_next would take Tab first
	if event.is_echo():
		return
	var typing: Control = get_viewport().gui_get_focus_owner()
	if typing is LineEdit or typing is TextEdit:
		return   # letters like R belong to the text box
	if event.is_action_pressed(&"plinky_upgrades") or Keybinds.matches(&"upgrades", event):
		if GameState.onboarding.is_unlocked(Onboarding.F_UPGRADES):
			toggle_upgrades()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed(&"plinky_relics") or Keybinds.matches(&"relics", event)) and GameState.relics != null:
		if GameState.onboarding.is_unlocked(Onboarding.F_RELICS):
			relic_panel_toggled.emit(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_stats") or Keybinds.matches(&"stats", event):
		if GameState.onboarding.is_unlocked(Onboarding.F_MULT):
			index_requested.emit(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_attributes") or Keybinds.matches(&"attributes", event):
		if GameState.onboarding.is_unlocked(Onboarding.F_UPGRADES):
			index_requested.emit(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and _number_key_chip(event as InputEventKey) != null:
		var nc: ExpandChip = _number_key_chip(event as InputEventKey)
		if nc.is_visible_in_tree() and not nc.disabled:
			nc.pressed.emit()
		get_viewport().set_input_as_handled()
	elif Keybinds.matches(&"menu", event):
		menu_toggled.emit(&"gallery")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_settings") or Keybinds.matches(&"settings", event):
		settings_toggled.emit(true)
		get_viewport().set_input_as_handled()


## The chip a plain 1 to 5 key press maps to (no modifiers), or null: 1 Upgrades, 2 Relics, 3 Stats, 4 Attributes, 5 Menu.
## The numbers are fixed (they match the tooltips); a chip that is not in the bar yet simply does nothing.
func _number_key_chip(e: InputEventKey) -> ExpandChip:
	if not e.pressed or e.echo or e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
		return null
	var n: int = e.keycode - KEY_1
	if n < 0 or n >= _key_chips.size():
		return null
	return _key_chips[n]


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
	if _tip_card != null and _tip_card.visible and _bottom != null:
		# Bottom right, above the bottom bar: clear of the pads, the walker's start and the stats panel.
		var cp: Vector2 = Vector2(frame.x - _tip_card.size.x - 4.0, frame.y - _bottom.size.y - _tip_card.size.y - 8.0).floor()
		if _tip_card.position != cp:
			_tip_card.position = cp
	if _gate_panel != null:
		var gp: Vector2 = Vector2(frame.x - _gate_panel.size.x - 4.0, 4.0)
		if _gate_panel.position != gp:
			_gate_panel.position = gp
	if _bottom != null and _momentum != null:
		var mp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - _momentum.size.y - 8.0)
		if _momentum.position != mp:
			_momentum.position = mp
	for cp2: Control in _centered:
		if cp2.visible:
			var free_h: float = frame.y - (_bottom.size.y if _bottom != null else 0.0) - 8.0
			var psz: Vector2 = cp2.size.max(cp2.get_combined_minimum_size())
			var at: Vector2 = Vector2(floorf((frame.x - psz.x) * 0.5), maxf(4.0, floorf((free_h - psz.y) * 0.5)))
			if cp2.position != at:
				cp2.position = at
	if _menu_chip != null:
		var mc: Vector2 = Vector2(frame.x - _menu_chip.size.x - 4.0, frame.y - _menu_chip.size.y - 4.0)
		if _menu_chip.position != mc:
			_menu_chip.position = mc
	if _bottom != null:
		var bp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - 4.0)
		if _bottom.position != bp:
			_bottom.position = bp


func _refresh() -> void:
	var slag_box: Control = _row_boxes.get(&"slag") as Control
	if slag_box != null:
		var cz: ZoneDef = sim.current_zone()
		slag_box.visible = (cz != null and cz.id == &"zone2") or not sim.get_stat(&"slag").is_zero()
	_apply_gates(_gates_ready)
	_gates_ready = true
	_poll_tips()
	for sid: StringName in _rows:
		var pair: Array = _rows[sid]
		(pair[0] as RollValue).set_target(sim.get_stat(sid))
		var inc: BigNum = sim.income_per_second(sid)
		(pair[1] as Label).text = "+%s/s" % inc.format() if not inc.is_zero() else ""
	if _prestige_label != null:
		_prestige_label.text = "x%s" % sim.prestige_mult().format()
	_rebirth.disabled = not sim.can_rebirth()
	_rebirth.full_text = "Rebirth (+%s Prestige)" % sim.prestige_gain_preview().format() if sim.can_rebirth() else "Rebirth (need 1 Rebirths)"
	_zone_panel.refresh()
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


func _on_offline(seconds: float, gains: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for sid: StringName in gains:
		parts.append("+%s %s" % [(gains[sid] as BigNum).format(), (sim.stat_defs[sid] as StatDef).display_name])
	_offline.text = "Welcome back! %d min away: %s" % [int(seconds / 60.0), ", ".join(parts)]
	_offline.visible = true
	var t := create_tween()
	t.tween_interval(5.0)
	t.tween_callback(func() -> void: _offline.visible = false)


# ---------------------------------------------------------------- staged unlocks and tips

## Show `node` only once `feature` is unlocked (see Onboarding). Call right after the node is built.
## The node must not be shown or hidden by anything else.
func gate(node: CanvasItem, feature: StringName) -> void:
	_gated.append([node, feature])
	node.visible = GameState.onboarding.is_unlocked(feature)


func _apply_gates(flash: bool) -> void:
	var ob: Onboarding = GameState.onboarding
	for pair: Array in _gated:
		var node: CanvasItem = pair[0] as CanvasItem
		if node == null or not is_instance_valid(node):
			continue
		var want: bool = ob.is_unlocked(pair[1] as StringName)
		if node.visible == want:
			continue
		node.visible = want
		if want and flash:
			_flash(node)
	if not ob.is_unlocked(Onboarding.F_UPGRADES):
		_upgrades_panel.visible = false


## A system just appeared: blink it three times, stepped, so it catches the eye.
func _flash(node: CanvasItem) -> void:
	var base: Color = node.modulate
	var t: Tween = node.create_tween()
	for i in 3:
		t.tween_property(node, "modulate", Color(2.0, 2.0, 1.5, base.a), 0.0)
		t.tween_interval(0.12)
		t.tween_property(node, "modulate", base, 0.0)
		t.tween_interval(0.12)


func _build_tip_card() -> void:
	_tip_card = TipCard.new()
	_tip_card.closed.connect(_on_tip_closed)
	add_child(_tip_card)


func _poll_tips() -> void:
	var ob: Onboarding = GameState.onboarding
	if not ob.tips_enabled:
		if _tip_card.is_showing():
			_tip_card.dismiss()
		return
	var id: StringName = ob.next_tip()
	if id == &"":
		return
	if _tip_card.is_showing() and not ob.is_urgent(id):
		return  # let the open card finish
	ob.tip_shown(id)
	_tip_card.show_tip(ob.tip_title(id), ob.tip_text(id), ob.cfg.tip_lifetime)


func _on_tip_closed(skipped: bool) -> void:
	if not skipped:
		return
	GameState.onboarding.tips_enabled = false
	TipsSettings.set_enabled(false)
	_apply_gates(false)  # skipping the tutorial shows every system at once
