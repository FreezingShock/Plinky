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
const STAT_RATE_SIZE: int = 8    ## the small "+x/s" or "xN" gain text left of each value

var sim: Sim
var _rows: Dictionary = {}        # stat id -> [value Label, rate Label (left of the value)]
var _row_boxes: Dictionary = {}   # stat id -> HBoxContainer (Slag only shows once you are past zone 1)
var _zone_panel: ZonePanel
var _rebirth: ExpandChip
var _reset_chips: Dictionary = {}   # zone reset id -> its bottom-bar chip (generated from content/resets)
var _upgrades_panel: PanelContainer
var _upgrades_box: VBoxContainer
var _prestige_label: Label
var _modal: ModalCard            # rebirth confirm and the offline summary, centred
var _save_note: SaveIndicator    # "Saved" flash, left of the Menu chip
var _clock: float = 0.0
var _row_tips: Dictionary = {}    # attribute id -> tooltip spec Callable
var _attr_rows: Dictionary = {}   # attribute id -> UpgradeRow
const UPGRADE_LIST_HEIGHT: float = 168.0   ## about six rows so the panel fits above the bottom bar at 640x360; the rest scroll
var _tip_card: TipCard
var _gated: Array = []            # [node, feature] pairs; see gate()
var _gates_ready: bool = false    # false until the first pass, so nothing flashes at startup
var _momentum: MomentumMeter
var _stats_panel: PanelContainer
var _clock_widget: ClockWidget
var _menu_chip: ExpandChip   # hamburger, bottom right
var _key_chips: Array[ExpandChip] = []   # number keys 1 to 5 press these, in order (Rebirth is left out on purpose)
var _centered: Array[Control] = []   # panels kept centred in the free area above the bottom bar


func setup(p_sim: Sim) -> void:
	sim = p_sim
	PopupNumber.under_menu = point_under_menu
	GameState.onboarding.update()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_stats()
	_build_gate()
	_build_clock()
	move_child(_clock_widget, _zone_panel.get_index())   # the zone list drops over the clock, never under it
	_build_bottom()
	_build_upgrades()
	_build_tip_card()
	_momentum = MomentumMeter.new()
	add_child(_momentum)
	_momentum.setup(sim)
	_modal = ModalCard.new()
	add_child(_modal)
	_save_note = SaveIndicator.new()
	add_child(_save_note)
	var bus: Node = get_node("/root/EventBus")
	_save_note.connect_bus(bus)
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


## True if the screen point is under an open menu panel (see PopupNumber.under_menu).
func point_under_menu(pt: Vector2) -> bool:
	for p: Control in _centered:
		if p.is_visible_in_tree() and p.get_global_rect().has_point(pt):
			return true
	return false


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
	var row_ids: Array[StringName] = hud_stat_ids(sim)
	for sid: StringName in row_ids:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		# Compact strip: icon, then (small dim gain, value) pushed to the right edge. No names: the instant tooltip has them,
		# and the value takes the stat's colour. The panel is only as wide as its widest visible row.
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		v.add_child(h)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % String(sid)) as Texture2D
		icon.custom_minimum_size = Vector2(16, 16)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.custom_minimum_size.x = 6
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(gap)
		var rate := Label.new()
		rate.theme_type_variation = &"TitleLabel"
		rate.add_theme_font_size_override("font_size", STAT_RATE_SIZE)
		rate.add_theme_color_override("font_color", RelicStyle.dim)
		rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(rate)
		var val := RollValue.new()
		val.big_gain.connect(_float_gain.bind(val, def.display_name, sid))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.add_theme_color_override("font_color", StatStyle.color(sid))
		h.add_child(val)
		_rows[sid] = [val, rate]
		Tip.bind_all(h, func() -> Variant:
			var inc: BigNum = sim.income_per_second(sid)
			return TipText.stat(sid, def.display_name, sim.get_stat(sid).format(), "" if inc.is_zero() else inc.format()))
		_row_boxes[sid] = h
		match sid:
			&"dewdrop": gate(h, Onboarding.F_DEWDROP)
			&"clover": gate(h, Onboarding.F_CLOVER_ROW)
			&"prestige": gate(h, Onboarding.F_UPGRADES)
		if sid in [&"dewdrop", &"clover", &"prestige"]:
			_gated_rows[sid] = true
	_prestige_label = _rows.get(&"prestige", [null, null])[1]


## The stat rows of the HUD, top to bottom: every stat by ladder position, then Prestige and Rebirth Points last.
## A row shows only in the zones its stat works in (StatDef.zones); Prestige and Rebirth Points show in every zone.
static func hud_stat_ids(sim: Sim) -> Array[StringName]:
	var defs: Array = sim.stat_defs.values()
	defs.sort_custom(func(a: StatDef, b: StatDef) -> bool: return a.tier < b.tier if a.tier != b.tier else String(a.id) < String(b.id))
	var ids: Array[StringName] = []
	for d: StatDef in defs:
		if d.id != &"prestige" and d.id != &"rp":
			ids.append(d.id)
	ids.append(&"prestige")
	ids.append(&"rp")
	return ids


## Whether a stat row belongs in the current zone. Prestige and Rebirth Points show where Rebirth runs (not the meadow),
## a zone reset's currency (Seeds) once it has paid them.
func _row_in_zone(sid: StringName) -> bool:
	var d: StatDef = sim.stat_defs.get(sid) as StatDef
	var in_zone: bool
	if sid == &"prestige" or sid == &"rp":
		in_zone = sim.rebirth_here()
	elif sim.reset_for_currency(sid) != null:
		in_zone = UpgradeText.group_shown(sim, sid) and (sim.reset_count(sim.reset_for_currency(sid).id) > 0 or not sim.get_stat(sid).is_zero())
	else:
		in_zone = d == null or d.in_zone(sim.zone_id)
	return in_zone and _earned(sid)


## A row stays hidden until its stat has been held once (or earns income), then stays for the session, so spending to zero
## never makes a row vanish. The first stat on the ladder (what the pads pay) is always shown.
func _earned(sid: StringName) -> bool:
	if _earned_rows.has(sid):
		return true
	var d: StatDef = sim.stat_defs.get(sid) as StatDef
	if (d != null and d.tier == 0) or not sim.get_stat(sid).is_zero() or not sim.income_per_second(sid).is_zero():
		_earned_rows[sid] = true
		return true
	return false


## Big jumps in a stat float up beside its counter. The first stat is left out: every press already pops its own number.
func _float_gain(amount: BigNum, val: RollValue, stat_name: String, sid: StringName) -> void:
	if sid == &"sunlight" or sid == &"cash":
		return
	# Beside the stats panel, level with the counter, so it never sits on the HUD text.
	var at: Vector2 = Vector2(_stats_panel.position.x + _stats_panel.size.x + 8.0, val.global_position.y - global_position.y)
	var text: String = "+%s %s" % [amount.format(), stat_name]
	if PressPopups.instance != null:
		# The shared popup field keeps stat floats off each other (and off press numbers) by taking a free lane.
		PressPopups.instance.label(StringName("stat_" + String(sid)), global_position + at + Vector2(40.0, 12.0), text, 0)
	else:
		PopupNumber.spawn_text(self, at, text, true)


func _build_gate() -> void:
	_zone_panel = ZonePanel.new()
	_zone_panel.position = Vector2(456, 4)
	add_child(_zone_panel)
	_zone_panel.setup(sim)
	_gate_panel = _zone_panel
	_zone_panel.add_to_group(TipHost.AVOID_GROUP)   # relic tooltips stay clear of it
	gate(_zone_panel, Onboarding.F_DEWDROP)
	for part: Control in _zone_panel.gated_parts():
		gate(part, Onboarding.F_CLOVER_ROW)


## The walker entered an area (Larkmoor district): the zone card follows.
func set_district(id: StringName) -> void:
	_zone_panel.set_district(id)


## The clock sits left of the zone card and hugs it as the frame widens (see _layout below).
func _build_clock() -> void:
	_clock_widget = ClockWidget.new()
	_clock_widget.position = Vector2(318, 4)
	add_child(_clock_widget)
	_clock_widget.setup(sim)
	gate(_clock_widget, Onboarding.F_DEWDROP)


## A zone reset asks first too (the same Settings switch). Its words come from its ZoneResetDef; the numbers are read when
## it is pressed.
func _on_zone_reset_pressed(rid: StringName) -> void:
	var r: ZoneResetDef = sim.reset_defs.get(rid) as ZoneResetDef
	if r == null or not sim.can_reset(rid):
		return
	if not ModalCard.rebirth_confirm:
		GameState.try_reset(rid)
		return
	var cname: String = (sim.stat_defs[r.currency] as StatDef).display_name
	var lines: Array = [
		[r.resets_text, StatStyle.PAPER],
		["+%d %s" % [sim.reset_gain(rid), cname], StatStyle.color(r.currency)],
		["Every pad pays %d%% more, for good." % int(roundf(r.bonus_per_use * 100.0)), StatStyle.gain()],
	]
	_modal.open("%s?" % r.display_name, lines, r.display_name, "Not yet", func() -> void: GameState.try_reset(rid))


## Rebirth asks first (Settings > Gameplay > Confirm rebirth turns that off). The numbers are read when it is pressed.
func _on_rebirth_pressed() -> void:
	if not sim.can_rebirth():
		return
	if not ModalCard.rebirth_confirm:
		GameState.try_rebirth()
		return
	var lines: Array = [
		["Resets your Cash and pads.", StatStyle.PAPER],
		["+%s Prestige" % sim.prestige_gain_preview().format(), StatStyle.color(&"prestige")],
		["+%d Rebirth Points" % sim.rp_gain_preview(), StatStyle.color(&"rp")],
	]
	_modal.open("Rebirth?", lines, "Rebirth", "Not yet", func() -> void: GameState.try_rebirth())


func _build_bottom() -> void:
	var h := HBoxContainer.new()
	h.position = Vector2(4, 334)
	_bottom = h
	h.add_theme_constant_override("separation", 4)
	add_child(h)
	_rebirth = _chip(h, "reb", "Rebirth", "Reset the run for Prestige.")
	_rebirth.pressed.connect(_on_rebirth_pressed)
	Tip.bind(_rebirth, func() -> Variant: return TipText.rebirth(sim.can_rebirth(), sim.prestige_gain_preview().format(), str(sim.rp_gain_preview()) if sim.can_rebirth() else ""))
	gate(_rebirth, Onboarding.F_REBIRTH_BUTTON)
	for zr: ZoneResetDef in sim.resets_ordered():   # one chip per zone reset; only the current zone's shows
		var rid: StringName = zr.id
		var chip: ExpandChip = _chip(h, String(zr.currency), zr.display_name, zr.button_hint)
		chip.pressed.connect(_on_zone_reset_pressed.bind(rid))
		var cname: String = (sim.stat_defs[zr.currency] as StatDef).display_name
		Tip.bind(chip, func() -> Variant: return TipText.zone_reset(zr, cname, sim.can_reset(rid), sim.reset_gain(rid), "Reach %s %s." % [BigNum.from_float(sim.reset_ref(rid)).format(), (sim.stat_defs[zr.source_stat] as StatDef).display_name]))
		chip.visible = false
		_reset_chips[rid] = chip
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
		gate(ib, Onboarding.F_DEWDROP if t == 0 else Onboarding.F_UPGRADES)
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_upgrades_box.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Upgrades"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var heads: Array[StringName] = UpgradeText.currencies(sim)
	heads.reverse()   # right-aligned balances, the one on the far right is Prestige
	for sid: StringName in heads:
		_cur_badges[sid] = _currency_badge(head, sid)
	var x_gap := Control.new()   # keeps the balances clear of the close X in the corner
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	_upgrades_box.add_child(PanelDivider.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, UPGRADE_LIST_HEIGHT)
	scroll.follow_focus = true
	_upgrades_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var group: StringName = &"prestige"
	for a: AttributeDef in UpgradeText.ordered(sim):
		if a.currency != group:   # a small heading where each perk group starts
			group = a.currency
			var gh := Label.new()
			gh.text = UpgradeText.group_head(sim, group)
			gh.add_theme_color_override("font_color", StatStyle.color(group))
			list.add_child(gh)
			_group_heads[group] = gh
		var row := UpgradeRow.new()
		list.add_child(row)
		row.setup(a)
		var cur: StringName = a.currency
		row.fly_target = func() -> Vector2: return (_cur_badges[cur] as Control).global_position + Vector2(18.0, 0.0)
		row.buy_pressed.connect(_buy_upgrade)
		row.refresh(UpgradeText.state(sim, a))
		var eff: StringName = a.effect
		var spec: Callable = func() -> Variant: return UpgradeText.tip(row.state(), eff)
		_row_tips[a.id] = spec
		Tip.bind_all(row, spec)
		_attr_rows[a.id] = row

var _group_heads: Dictionary = {}   # currency stat id -> the small heading above its upgrades
var _cur_vals: Dictionary = {}     # currency stat id -> Label with the balance in the Upgrades header
var _cur_badges: Dictionary = {}   # currency stat id -> the badge box (icon + value)


## "[icon] 793" in the stat's colour, with the stat tooltip. Returns the box; the value label is in _cur_vals.
func _currency_badge(parent: Control, sid: StringName) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", 3)
	parent.add_child(b)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % String(sid)) as Texture2D
	ic.custom_minimum_size = Vector2(16, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var v := Label.new()
	v.add_theme_color_override("font_color", StatStyle.color(sid))
	b.add_child(v)
	_cur_vals[sid] = v
	var nm: String = (sim.stat_defs[sid] as StatDef).display_name
	Tip.bind_all(b, func() -> Variant: return TipText.stat(sid, nm, _balance(sid).format()))
	return b


## What the player can spend of a currency: unspent Prestige, or the Rebirth Points in hand.
func _balance(sid: StringName) -> BigNum:
	if sim.reset_for_currency(sid) != null:
		return sim.get_stat(sid)
	return sim.rp_available() if sid == &"rp" else sim.prestige_available()


## A row asked to buy. The sim decides; the row plays the animation only if it went through.
func _buy_upgrade(aid: StringName) -> void:
	if GameState.buy_attribute(aid):
		var row: UpgradeRow = _attr_rows[aid]
		row.play_buy(UpgradeText.state(sim, sim.attribute_defs[aid]))   # lighter while a held Buy repeats
		# A tooltip already showing (the pointer is on the button) must pick up the new level.
		for c: Node in [row] + row.get_children():
			if c is Control:
				Tip.set_spec(c as Control, _row_tips[aid])


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
		if GameState.onboarding.is_unlocked(Onboarding.F_DEWDROP):
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


## Park the clock left of the zone card and right of the stats panel. When the gap is too small it squeezes
## (ClockWidget.set_squeeze) instead of overlapping either neighbour.
func _place_clock(zone_left: float) -> void:
	var stats_right: float = 0.0
	if _stats_panel != null:
		stats_right = _stats_panel.position.x + maxf(_stats_panel.size.x, _stats_panel.get_combined_minimum_size().x)
	var room: float = zone_left - 6.0 - (stats_right + 6.0)
	var cw: ClockWidget = _clock_widget
	var level: int = cw.squeeze_level()
	cw.remember_width()
	# Widest layout that fits; ClockWidget remembers each layout's width so this does not flap.
	var want: int = 2
	for l: int in 3:
		if cw.width_at(l) <= room:
			want = l
			break
	if want != level:
		cw.set_squeeze(want)
	var w: float = maxf(cw.size.x, cw.get_combined_minimum_size().x)
	var clk: Vector2 = Vector2(maxf(zone_left - w - 6.0, stats_right + 6.0), 4.0).floor()
	if cw.position != clk:
		cw.position = clk


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
		var gsz: Vector2 = _gate_panel.size.max(_gate_panel.get_combined_minimum_size())
		var gp: Vector2 = Vector2(frame.x - gsz.x - 4.0, 4.0)
		if _gate_panel.position != gp:
			_gate_panel.position = gp
		if _clock_widget != null:
			_place_clock(gp.x)
	if _modal != null and _modal.visible:
		var mp0: Vector2 = ((frame - _modal.size) * 0.5).floor()
		mp0.y = minf(mp0.y, roundf(frame.y * 0.3))
		if _modal.position != mp0:
			_modal.position = mp0
	if _save_note != null and _menu_chip != null:
		var sp: Vector2 = Vector2(_menu_chip.position.x - _save_note.size.x - 6.0, frame.y - _save_note.size.y - 6.0).floor()
		if _save_note.position != sp:
			_save_note.position = sp
	if _bottom != null and _momentum != null:
		var mp: Vector2 = Vector2(4.0, frame.y - _bottom.size.y - _momentum.size.y - 8.0)
		if _momentum.position != mp:
			_momentum.position = mp
	for cp2: Control in _centered:
		if is_instance_valid(cp2) and cp2.visible:
			var free_h: float = frame.y - (_bottom.size.y if _bottom != null else 0.0) - 8.0
			var psz: Vector2 = cp2.size.max(cp2.get_combined_minimum_size())
			var at: Vector2 = Vector2(floorf((frame.x - psz.x) * 0.5), maxf(4.0, floorf((free_h - psz.y) * 0.5)) + float(cp2.get_meta(&"menu_slide", 0.0)))
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


var _earned_rows: Dictionary = {}   # stat id -> true once the row has been shown (see _earned)
var _gated_rows: Dictionary = {}   # stat id -> true for rows a tutorial step holds back (see gate())


func _refresh() -> void:
	for sid2: StringName in _row_boxes:   # rows no tutorial step holds back follow the zone alone
		if not _gated_rows.has(sid2) and sid2 != &"rp":
			(_row_boxes[sid2] as Control).visible = _row_in_zone(sid2)
	var rp_box: Control = _row_boxes.get(&"rp") as Control
	if rp_box != null:   # Rebirth Points show once you have rebirthed (or hold some)
		rp_box.visible = GameState.onboarding.is_unlocked(Onboarding.F_UPGRADES) and (sim.rebirth_count > 0 or not sim.rp_available().is_zero()) and sim.rebirth_here()
	_apply_gates(_gates_ready)
	_gates_ready = true
	_poll_tips()
	for sid: StringName in _rows:
		var pair: Array = _rows[sid]
		(pair[0] as RollValue).set_target(sim.get_stat(sid))
		var inc: BigNum = sim.income_per_second(sid)
		(pair[1] as Label).text = "+%s/s" % inc.format() if not inc.is_zero() else ""
	if _prestige_label != null:
		_prestige_label.text = NumberFormat.mult(sim.prestige_mult())
	_rebirth.disabled = not sim.can_rebirth()
	_rebirth.full_text = "Rebirth (+%s Prestige)" % sim.prestige_gain_preview().format() if sim.can_rebirth() else "Rebirth (need %s %s)" % [BigNum.from_float(sim.config.rebirth_min_value).format(), (sim.stat_defs[sim.prestige_source()] as StatDef).display_name]
	for rid: StringName in _reset_chips:
		var rd: ZoneResetDef = sim.reset_defs[rid] as ZoneResetDef
		var rc: ExpandChip = _reset_chips[rid] as ExpandChip
		var mine: bool = rd == sim.reset_for_zone()
		rc.visible = mine and (sim.can_reset(rid) or sim.reset_count(rid) > 0)
		rc.disabled = not sim.can_reset(rid)
		var cn: String = (sim.stat_defs[rd.currency] as StatDef).display_name
		rc.full_text = "%s (+%d %s)" % [rd.display_name, sim.reset_gain(rid), cn] if sim.can_reset(rid) else "%s (need %s %s)" % [rd.display_name, BigNum.from_float(sim.reset_ref(rid)).format(), (sim.stat_defs[rd.source_stat] as StatDef).display_name]
	_zone_panel.refresh()
	if _upgrades_panel.visible:
		for sid: StringName in _cur_vals:
			(_cur_vals[sid] as Label).text = _balance(sid).format()
		for cur: StringName in _cur_badges:
			(_cur_badges[cur] as Control).visible = UpgradeText.group_shown(sim, cur)
		for cur2: StringName in _group_heads:
			(_group_heads[cur2] as Control).visible = UpgradeText.group_shown(sim, cur2)
		for aid2: StringName in _attr_rows:
			(_attr_rows[aid2] as Control).visible = UpgradeText.group_shown(sim, sim.attribute_defs[aid2].currency)
		for aid: StringName in _attr_rows:
			(_attr_rows[aid] as UpgradeRow).refresh(UpgradeText.state(sim, sim.attribute_defs[aid]))


func _on_offline(seconds: float, gains: Dictionary) -> void:
	if seconds < 60.0 or gains.is_empty():
		return
	var lines: Array = [[_away_text(seconds), StatStyle.PAPER]]
	for sid: StringName in gains:
		var g: BigNum = gains[sid]
		if g.is_zero():
			continue
		lines.append(["+%s %s" % [g.format(), (sim.stat_defs[sid] as StatDef).display_name], StatStyle.color(sid)])
	if seconds >= sim.offline_cap_seconds() - 1.0:
		lines.append(["That is the most you can bank offline.", RelicStyle.dim])
	if lines.size() < 2:
		return
	_modal.open("Welcome Back", lines, "Collect")


## "You were away 2 h 5 min." Whole minutes, hours once there are any.
static func _away_text(seconds: float) -> String:
	var mins: int = int(seconds / 60.0)
	if mins < 60:
		return "You were away %d min." % mins
	var hrs: int = floori(mins / 60.0)
	if hrs < 48:
		return "You were away %d h %d min." % [hrs, mins % 60]
	return "You were away %d days %d h." % [floori(hrs / 24.0), hrs % 24]


# ---------------------------------------------------------------- staged unlocks and tips

## Show `node` only once `feature` is unlocked (see Onboarding). Call right after the node is built.
## The node must not be shown or hidden by anything else.
func gate(node: CanvasItem, feature: StringName) -> void:
	_gated.append([node, feature])
	node.visible = GameState.onboarding.is_unlocked(feature)


## A gated stat row also has to belong to the current zone; any other gated node always does.
func _gated_in_zone(node: CanvasItem) -> bool:
	if node == _rebirth:   # Rebirth lives where Cash and Multiplier do; the meadow has Bloom
		return sim.rebirth_here()
	for sid: StringName in _gated_rows:
		if _row_boxes.get(sid) == node:
			return _row_in_zone(sid)
	return true


func _apply_gates(flash: bool) -> void:
	var ob: Onboarding = GameState.onboarding
	for pair: Array in _gated:
		var node: CanvasItem = pair[0] as CanvasItem
		if node == null or not is_instance_valid(node):
			continue
		var want: bool = ob.is_unlocked(pair[1] as StringName) and _gated_in_zone(node)
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
	_tip_card.held = PadInput.menu_open or _modal.visible   # tips never cover an open menu or a confirm card
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
