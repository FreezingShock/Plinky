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
const COL_PAD: float = 2.0   ## slack added to a measured column so a one-pixel change never resizes the strip

var sim: Sim
var _rows: Dictionary = {}        # stat id -> [value Label, rate Label (left of the value)]
var _row_boxes: Dictionary = {}   # stat id -> HBoxContainer (Slag only shows once you are past zone 1)
var _zone_panel: ZonePanel
var _reset_chips: Dictionary = {}   # zone reset id -> its bottom-bar chip (generated from content/resets)
var _upgrades_panel: PanelContainer
var _upgrades_box: VBoxContainer
var _prestige_label: Label
var _modal: ModalCard            # rebirth confirm and the offline summary, centred
var _save_note: SaveIndicator    # "Saved" flash, left of the Menu chip
var _clock: float = 0.0
var _row_tips: Dictionary = {}    # attribute id -> tooltip spec Callable
var _attr_rows: Dictionary = {}   # attribute id -> UpgradeCard
const UPGRADE_LIST_WIDTH: float = 556.0   ## two cards across, plus the scrollbar, in the 640 px base
const UPGRADE_LIST_HEIGHT: float = 232.0  ## about four rows of cards so the panel fits above the bottom bar at 640x360; the rest scroll
var _tip_card: TipCard
var _gated: Array = []            # [node, feature] pairs; see gate()
var _gates_ready: bool = false    # false until the first pass, so nothing flashes at startup
var _momentum: MomentumMeter
var _stats_panel: PanelContainer
var _clock_widget: ClockWidget
var _menu_chip: ExpandChip   # hamburger, bottom right
var _key_chips: Array[ExpandChip] = []   # number keys 1 to 5 press these, in order 
var _centered: Array[Control] = []   # panels kept centred in the free area above the bottom bar

## The stat strip is customizable (core/hud_layout.gd, saved per game): right-click a row to hide it, or press the pencil for
## edit mode (move, hide, add from the icon chips, reset to Default). Settings > Gameplay has matching rows.
const GROUP: StringName = &"stat_strip"   ## Settings reaches the HUD through this group (the registry cannot name Hud)
var _stats_box: VBoxContainer
var _edit_mode: bool = false
var _edit_pending: bool = false          # Settings asked for edit mode; it starts once the menu is closed
var _edit_t: float = 0.0                 # 0 normal .. 1 edit mode, eased (see _ease_edit)
var _edit_tween: Tween
var _row_ctl: Dictionary = {}            # stat id -> Control holding the row's grip and hide mark
var _row_node: Dictionary = {}           # row box -> true (the nodes _set_row_shown fades)
var _fades: Dictionary = {}              # row box -> {"tw": Tween, "out": bool}
var _drag_sid: StringName = &""          # the row being dragged by its grip, or &""
var _known_chips: Dictionary = {}        # stat id -> true for the add chips already on screen (new ones pop in)
var _foot_normal: HBoxContainer          # the pencil
var _foot_clip: Control                  # clips the edit footer so the panel can ease open and shut
var _foot_edit: VBoxContainer            # chips to add, row count, Reset, Done
var _edit_btn: StripButton
var _reset_btn: StripButton
var _sug_grid: GridContainer
var _sug_note: Label
var _count_label: Label
var _layout_sig: String = ""
const SUG_COLUMNS: int = 4   ## add chips per line to start with; _place_edit refits it to the footer bar
var _foot_bar: HBoxContainer
const CTL_W: float = 28.0   ## width of the grip and hide mark that open at the left of every row in edit mode (the mark has room around it)


func setup(p_sim: Sim) -> void:
	sim = p_sim
	add_to_group(GROUP)
	PopupNumber.under_menu = point_under_menu
	PopupNumber.keep_clear = clear_rects
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
	Banner.avoid = _momentum   # a banner lifts clear of the meter rather than cover it
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


## Rectangles world popups must slide clear of: the zone panel while it is on screen (see PopupNumber.keep_clear).
func clear_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _zone_panel != null and _zone_panel.is_visible_in_tree():
		out.append(_zone_panel.get_global_rect())
	return out


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


## The rolling counter of a stat row (null when the stat has none). The Bloom animation drives it.
func stat_value(sid: StringName) -> RollValue:
	var pair: Array = _rows.get(sid, []) as Array
	return pair[0] as RollValue if not pair.is_empty() else null


## Every stat id that has a row on the HUD.
func stat_value_ids() -> Array:
	return _rows.keys()


## Bottom edge of the stats panel in HUD coordinates, so panels below it (relic bar) follow its height.
func stats_bottom() -> float:
	if _stats_panel == null:
		return 4.0
	return _stats_panel.position.y + _stats_panel.get_combined_minimum_size().y


func _build_stats() -> void:
	var v: VBoxContainer = _panel(Vector2(4, 4))
	_stats_panel = v.get_parent() as PanelContainer
	_stats_panel.add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 5.0, 4.0))   # snug: the strip is dense
	_stats_panel.add_to_group(TipHost.AVOID_GROUP)
	_stats_box = v
	var row_ids: Array[StringName] = hud_stat_ids(sim)
	for sid: StringName in row_ids:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		# Compact strip: icon, then (small dim gain, value) pushed to the right edge. No names: the instant tooltip has them,
		# and the value takes the stat's colour. The panel is only as wide as its widest visible row.
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % String(sid)) as Texture2D
		icon.custom_minimum_size = Vector2(16, 16)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.custom_minimum_size.x = 4
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(gap)
		var rate := Label.new()
		rate.theme_type_variation = &"TitleLabel"
		rate.add_theme_font_size_override("font_size", STAT_RATE_SIZE)
		# The gain lives outside the panel, beside its row (see _place_rates): panel outline colour, ink stroke so it reads over the world.
		rate.add_theme_color_override("font_color", RelicStyle.edge)
		rate.add_theme_color_override("font_outline_color", RelicStyle.ink)
		rate.add_theme_constant_override("outline_size", 3)
		rate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rate.visible = false
		add_child(rate)
		var val := RollValue.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.add_theme_color_override("font_color", StatStyle.color(sid))
		h.add_child(val)
		_rows[sid] = [val, rate]
		Tip.bind_all(h, func() -> Variant:
			var inc: BigNum = sim.income_per_second(sid)
			var spec: Dictionary = TipText.stat(sid, def.display_name, sim.get_stat(sid).format(), "" if inc.is_zero() else inc.format())
			if _edit_mode:
				spec["hint"] = "Drag to reorder."
			return spec)
		_row_boxes[sid] = h
		_row_node[h] = true
		h.gui_input.connect(_on_row_input.bind(sid))
		_build_row_controls(h, sid)
		match sid:
			&"dewdrop": gate(h, Onboarding.F_DEWDROP)
			&"clover": gate(h, Onboarding.F_CLOVER_ROW)
			&"prestige": gate(h, Onboarding.F_UPGRADES)
		if sid in [&"dewdrop", &"clover", &"prestige"]:
			_gated_rows[sid] = true
	_prestige_label = _rows.get(&"prestige", [null, null])[1]
	_build_strip_footer(v)


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
	if not _layout_rows().has(sid):
		return false
	return _edit_mode or _earned(sid)


## Whether a stat is one of the current zone's own rows (the Default layout). Prestige and Rebirth Points are where
## Rebirth runs (not the meadow), Seeds once a Bloom has paid them.
func _zone_has(sid: StringName) -> bool:
	var d: StatDef = sim.stat_defs.get(sid) as StatDef
	if sid == &"prestige" or sid == &"rp":
		return sim.rebirth_here()
	if sim.reset_for_currency(sid) != null:
		return UpgradeText.group_shown(sim, sid) and (sim.reset_count(sim.reset_for_currency(sid).id) > 0 or not sim.get_stat(sid).is_zero())
	return d == null or d.in_zone(sim.zone_id)


## A row stays hidden until its stat has been held once (or earns income), then stays for the session, so spending to zero
## never makes a row vanish. The first stat on the ladder (what the pads pay) is always shown.
func _earned(sid: StringName) -> bool:
	if _earned_rows.has(sid) or _opt(&"strip_empty", false):
		return true
	var d: StatDef = sim.stat_defs.get(sid) as StatDef
	if (d != null and d.tier == 0) or not sim.get_stat(sid).is_zero() or not sim.income_per_second(sid).is_zero():
		_earned_rows[sid] = true
		return true
	return false


func _build_gate() -> void:
	_zone_panel = ZonePanel.new()
	_zone_panel.position = Vector2(632.0 - ZonePanel.WIDTH, 4)
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


func _build_bottom() -> void:
	var h := HBoxContainer.new()
	h.position = Vector2(4, 334)
	_bottom = h
	h.add_theme_constant_override("separation", 4)
	add_child(h)
	for zr: ZoneResetDef in sim.resets_ordered():   # one chip per zone reset; only the current zone's shows
		var rid: StringName = zr.id
		var chip: ExpandChip = _chip(h, String(zr.currency), zr.display_name, zr.button_hint)
		chip.short_text = zr.display_name
		chip.pressed.connect(_on_zone_reset_pressed.bind(rid))
		var cname: String = (sim.stat_defs[zr.currency] as StatDef).display_name
		Tip.bind(chip, func() -> Variant: return TipText.zone_reset(zr, cname, sim.can_reset(rid), sim.reset_gain(rid), "Reach %s %s." % [BigNum.from_float(sim.reset_ref(rid)).format(), (sim.stat_defs[zr.source_stat] as StatDef).display_name]))
		chip.visible = false
		_reset_chips[rid] = chip
	var up: ExpandChip = _chip(h, "prestige", "Upgrades", "Spend what a reset pays on permanent gifts.", "Keys: %s or 1" % Keybinds.key_name(&"upgrades"))
	up.full_text = "Upgrades [Tab]"
	up.short_text = "Upgrades"
	up.pressed.connect(toggle_upgrades)
	_key_chips.append(up)
	gate(up, Onboarding.F_UPGRADES)
	if GameState.relics != null:
		var rb: ExpandChip = _chip(h, "relics/r_pulse", "Relics", "Equip relics you have found.", "Keys: %s or 2" % Keybinds.key_name(&"relics"))
		rb.full_text = "Relics [R]"
		rb.short_text = "Relics"
		rb.pressed.connect(func() -> void: relic_panel_toggled.emit(true))
		_key_chips.append(rb)
		gate(rb, Onboarding.F_RELICS)
	for t: int in 2:
		var nm: String = ["Stats", "Attributes"][t]
		var act: StringName = [&"stats", &"attributes"][t]
		var ib: ExpandChip = _chip(h, ["stats_menu", "attrs_menu"][t], nm, "Open the %s list." % nm.to_lower(), "Keys: %s or %d" % [Keybinds.key_name(act), 3 + t])
		ib.full_text = "%s [%s]" % [nm, Keybinds.key_name(act)]
		ib.short_text = nm
		ib.pressed.connect(func() -> void: index_requested.emit(t))
		_key_chips.append(ib)
		gate(ib, Onboarding.F_DEWDROP if t == 0 else Onboarding.F_UPGRADES)
	# Settings and the Update Log live in the hamburger menu, at the far right of the screen.
	_menu_chip = _chip(self, "big/menu_hamburger", "Menu", "Settings, the update log and every section.", "Keys: %s or 5" % Keybinds.key_name(&"menu"))
	_menu_chip.full_text = "Menu [%s]" % Keybinds.key_name(&"menu")
	_menu_chip.short_text = "Menu"
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
	_upgrades_box.add_theme_constant_override("separation", 3)
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
	# One tab per currency group (Prestige, Rebirth Perks, then each zone reset's gifts). Tabs are made from the data,
	# so a new zone reset gets its own tab with no change here.
	_upg_tabs = HBoxContainer.new()
	_upg_tabs.add_theme_constant_override("separation", 12)
	_upgrades_box.add_child(_upg_tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(UPGRADE_LIST_WIDTH, UPGRADE_LIST_HEIGHT)
	scroll.follow_focus = true
	_upgrades_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_upg_list = list
	_upgrades_panel.visibility_changed.connect(_on_upgrades_shown)


var _upg_list: VBoxContainer
var _upg_tabs: HBoxContainer
var _upg_order: Array[StringName] = []          # the currency of each tab, in menu order
var _upg_tab_btns: Dictionary = {}              # currency stat id -> its tab (MenuTextButton)
var _upg_pages: Dictionary = {}                 # currency stat id -> the page of that group's tiers
var _upg_tab: StringName = &""                  # the tab on show
var _cur_vals: Dictionary = {}     # currency stat id -> Label with the balance in the Upgrades header
var _cur_badges: Dictionary = {}   # currency stat id -> the badge box (icon + value)


## Opening the panel builds the cards the first time (the node budget), then shows only tabs the player can see.
func _on_upgrades_shown() -> void:
	if not _upgrades_panel.visible:
		return
	_fill_upgrades()
	_sync_upgrade_tabs()


## The cards are built the first time the menu opens, not at boot (node budget). Each currency gets a page of tiers;
## a tier is a heading and a two-across grid of cards, so a tier of gifts reads as one group.
func _fill_upgrades() -> void:
	if not _attr_rows.is_empty():
		return
	_upg_order = UpgradeText.tab_currencies(sim)
	for cur: StringName in _upg_order:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		page.visible = false
		_upg_list.add_child(page)
		_upg_pages[cur] = page
		var tab := MenuTextButton.new()
		tab.label = UpgradeText.tab_name(sim, cur)
		tab.accent_color = StatStyle.color(cur)
		tab.rest_color = RelicStyle.dim
		tab.pressed.connect(_select_upgrade_tab.bind(cur))
		_upg_tabs.add_child(tab)
		_upg_tab_btns[cur] = tab
	var grid: GridContainer = null
	var last_key: String = ""
	var last_cur: StringName = &""
	var tier_no: int = 0   # tiers number from 1 within each currency
	for a: AttributeDef in UpgradeText.ordered(sim):
		var cur: StringName = a.currency
		var page: VBoxContainer = _upg_pages.get(cur) as VBoxContainer
		if page == null:
			continue
		var key: String = "%s %s" % [cur, UpgradeText.tier_key(a)]
		if key != last_key:
			last_key = key
			tier_no = tier_no + 1 if cur == last_cur else 1
			last_cur = cur
			var tier := Label.new()
			tier.text = "Tier %d: %s" % [tier_no, UpgradeText.tier_head(sim, a)]
			tier.add_theme_color_override("font_color", RelicStyle.soft())
			page.add_child(tier)
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 5)
			page.add_child(grid)
		var card := UpgradeCard.new()
		grid.add_child(card)
		card.setup(a)
		card.fly_target = func() -> Vector2: return (_cur_badges[cur] as Control).global_position + Vector2(18.0, 0.0)
		card.buy_pressed.connect(_buy_upgrade)
		card.refresh(UpgradeText.state(sim, a))
		var eff: StringName = a.effect
		var spec: Callable = func() -> Variant: return UpgradeText.tip(card.state(), eff)
		_row_tips[a.id] = spec
		Tip.bind_all(card, spec)
		_attr_rows[a.id] = card
	_select_upgrade_tab(_first_shown_tab())


func _select_upgrade_tab(cur: StringName) -> void:
	_upg_tab = cur
	for c: StringName in _upg_pages:
		(_upg_pages[c] as Control).visible = c == cur
	for c2: StringName in _upg_tab_btns:
		var b: MenuTextButton = _upg_tab_btns[c2] as MenuTextButton
		b.rest_color = StatStyle.color(c2) if c2 == cur else RelicStyle.dim
		b.queue_redraw()


## Shows the tabs the player can see, and moves off a tab that has just been hidden. With no tab shown, every page is hidden.
func _sync_upgrade_tabs() -> void:
	for cur: StringName in _upg_tab_btns:
		(_upg_tab_btns[cur] as Control).visible = UpgradeText.group_shown(sim, cur)
	var want: StringName = _upg_tab if _upg_tab != &"" and UpgradeText.group_shown(sim, _upg_tab) else _first_shown_tab()
	if want != _upg_tab:
		_select_upgrade_tab(want)


## The first tab the player can see, or &"" when none is shown yet.
func _first_shown_tab() -> StringName:
	for cur: StringName in _upg_order:
		if UpgradeText.group_shown(sim, cur):
			return cur
	return &""


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
		var row: UpgradeCard = _attr_rows[aid]
		row.play_buy(UpgradeText.state(sim, sim.attribute_defs[aid]))   # lighter while a held Buy repeats
		# The header balance of that currency pops too, so the spend reads at the counter.
		var badge: Control = _cur_badges.get((sim.attribute_defs[aid] as AttributeDef).currency) as Control
		if badge != null and not (MeadowLife.reduce_motion or FxConfig.reduce_flashing):
			badge.pivot_offset = badge.size * 0.5
			badge.scale = Vector2(1.18, 1.18)
			var bt := create_tween()
			bt.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# A tooltip already showing (the pointer is on the button) must pick up the new level.
		for c: Node in [row] + row.get_children():
			if c is Control:
				Tip.set_spec(c as Control, _row_tips[aid])


func _input(event: InputEvent) -> void:   # _input, not unhandled: ui_focus_next would take Tab first
	if _drag_sid != &"" and _drag_input(event):
		return
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


## Centre the clock on the frame, between the stats panel on the left and the zone card on the right. The room is the
## narrower gap measured from the centre line, doubled, so the centred chip clears both neighbours. When that room is
## too small it squeezes (ClockWidget.set_squeeze) instead of overlapping either one.
func _place_clock(zone_left: float) -> void:
	var stats_right: float = 0.0
	if _stats_panel != null:
		stats_right = _stats_panel.position.x + maxf(_stats_panel.size.x, _stats_panel.get_combined_minimum_size().x) + _rates_w
	var mid: float = floorf(frame.x * 0.5)
	var half: float = minf(mid - (stats_right + 6.0), zone_left - 6.0 - mid)
	var cw: ClockWidget = _clock_widget
	var level: int = cw.squeeze_level()
	cw.remember_width()
	# Widest layout that fits; ClockWidget remembers each layout's width so this does not flap.
	var want: int = 2
	for l: int in 3:
		if cw.width_at(l) <= half * 2.0:
			want = l
			break
	if want != level:
		cw.set_squeeze(want)
	var w: float = maxf(cw.size.x, cw.get_combined_minimum_size().x)
	var x: float = maxf(minf(floorf(mid - w * 0.5), zone_left - 6.0 - w), stats_right + 6.0)
	var clk: Vector2 = Vector2(x, 4.0).floor()
	if cw.position != clk:
		cw.position = clk


## Right-hug the gate panel and bottom-hug the bottom bar, so a wider frame keeps them at its edges.
func _place() -> void:
	if size != frame:
		size = frame
	_place_edit()
	if _stats_panel != null:
		_place_rates()
	if _stats_panel != null:   # the strip hugs its rows: it shrinks when rows are hidden, not only grows
		var want: Vector2 = _stats_panel.get_combined_minimum_size()
		if _stats_panel.size != want:
			_stats_panel.size = want
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
	if _edit_pending and not PadInput.menu_open:
		_edit_pending = false
		set_edit_mode(true)
	elif _edit_mode and PadInput.menu_open:
		set_edit_mode(false)
	_sync_layout()
	if _foot_normal != null:
		_foot_normal.visible = not _edit_mode and GameState.onboarding.is_unlocked(Onboarding.F_DEWDROP)
	for sid2: StringName in _row_boxes:   # rows no tutorial step holds back follow the zone alone
		if not _gated_rows.has(sid2) and sid2 != &"rp":
			_set_row_shown(_row_boxes[sid2] as Control, _row_in_zone(sid2), _gates_ready)
	var rp_box: Control = _row_boxes.get(&"rp") as Control
	if rp_box != null:   # Rebirth Points show once you have rebirthed (or hold some)
		_set_row_shown(rp_box, _layout_rows().has(&"rp") and GameState.onboarding.is_unlocked(Onboarding.F_UPGRADES) and (_edit_mode or sim.rebirth_count > 0 or not sim.rp_available().is_zero()), _gates_ready)
	_apply_gates(_gates_ready)
	_gates_ready = true
	_poll_tips()
	var show_rates: bool = _opt(&"strip_rates", true)
	for sid: StringName in _rows:
		var pair: Array = _rows[sid]
		(pair[0] as RollValue).set_target(sim.get_stat(sid))
		var inc: BigNum = sim.income_per_second(sid)
		(pair[1] as Label).text = "+%s/s" % inc.format() if not inc.is_zero() else ""
		(pair[1] as Label).visible = show_rates
	_fit_columns()
	if _prestige_label != null:
		_prestige_label.text = NumberFormat.mult(sim.prestige_mult())
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
		_sync_upgrade_tabs()
		for aid: StringName in _attr_rows:
			(_attr_rows[aid] as UpgradeCard).refresh(UpgradeText.state(sim, sim.attribute_defs[aid]))


func _on_offline(seconds: float, gains: Dictionary) -> void:
	if seconds < 60.0 or gains.is_empty():
		return
	var lines: Array = [[_away_text(seconds), StatStyle.PAPER]]
	for sid: StringName in gains:
		var g: BigNum = gains[sid]
		if g.is_zero():
			continue
		lines.append(["+%s %s" % [g.format(), (sim.stat_defs[sid] as StatDef).display_name], StatStyle.color(sid)])
	var tend: Dictionary = sim.last_offline.get("tend", {})
	var spent: Dictionary = sim.last_offline.get("spent", {})
	for sp: StringName in spent:   # the gains above are income; tending paid these out of it
		lines.append(["-%s %s spent tending" % [(spent[sp] as BigNum).format(), (sim.stat_defs[sp] as StatDef).display_name], StatStyle.color(sp)])
	for tid: StringName in tend:
		var r: Dictionary = tend[tid]
		var tier: TierDef = sim.tier_defs.get(tid) as TierDef
		var what: String = "%s pad tended x%d" % [tier.display_name if tier != null else str(tid), int(r["presses"])]
		if int(r["levels"]) > 0:
			what += ", mastery +%d (Lv %d)" % [int(r["levels"]), int(r["level"])]
		lines.append([what, StatStyle.color(&"mastery")])
	var counts: Dictionary = {}   # relic id -> times found, in first-found order
	for rid: StringName in sim.last_offline.get("relics", []):
		counts[rid] = int(counts.get(rid, 0)) + 1
	for rid2: StringName in counts:
		var rd: RelicDef = sim.relics.defs.get(rid2) as RelicDef
		if rd != null:
			var n: int = int(counts[rid2])
			lines.append(["Found %s%s" % [rd.display_name, " x%d" % n if n > 1 else ""], rd.rarity.color])
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


# ---------------------------------------------------------------- stat strip customization

var _cached_rows: Array[StringName] = []   # the rows the layout shows in this zone, refreshed by _sync_layout
var _val_w: float = 0.0                     # widest value text shown so far in this layout (only grows)
var _rates_w: float = 0.0                   # width of the widest gain text outside the panel right now
var _slides: Dictionary = {}                # row box -> Tween (a row sliding to its new place)


## Reduced motion or flashing: the strip's animations snap instead.
func _calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_motion or FxConfig.reduce_flashing


## A true/false setting from the registry (Settings > Gameplay), or `fallback` when it is not registered.
func _opt(id: StringName, fallback: bool) -> bool:
	var v: Variant = SettingsRegistry.value(id)
	return fallback if v == null else bool(v)


## The zone's own rows in ladder order: the Default layout.
func _defaults() -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in hud_stat_ids(sim):
		if sim.stat_defs.has(sid) and _zone_has(sid):
			out.append(sid)
	return out


func _layout_rows() -> Array[StringName]:
	return _cached_rows


## Stats from other zones that you have met, offered after the zone's own hidden ones.
func _pool(defaults: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in hud_stat_ids(sim):
		if not defaults.has(sid) and (_earned_rows.has(sid) or not sim.get_stat(sid).is_zero()):
			out.append(sid)
	return out


static func _join(ids: Array[StringName]) -> String:
	var out: String = ""
	for id: StringName in ids:
		out += String(id) + ","
	return out


## Pull the on-screen rows in line with the layout: order, the hide marks, the count, the add chips.
## Cheap when nothing changed (it compares a signature), so the 10 Hz refresh calls it every time.
func _sync_layout() -> void:
	var defaults: Array[StringName] = _defaults()
	_cached_rows = sim.hud_layout.rows(sim.zone_id, defaults)
	var sig: String = String(sim.zone_id) + "|" + _join(_cached_rows)
	var sugg: Array[StringName] = []
	if _edit_mode:
		sugg = sim.hud_layout.suggestions(sim.zone_id, defaults, _pool(defaults))
		sig += "|e|" + _join(sugg)
	if sig == _layout_sig:
		return
	_layout_sig = sig
	_val_w = 0.0   # a new layout re-measures its columns
	var old_y: Dictionary = {}
	if _gates_ready and not _calm():
		for sid0: StringName in _row_boxes:
			var b0: Control = _row_boxes[sid0] as Control
			if b0.visible:
				old_y[sid0] = b0.position.y
	var idx: int = 0
	for sid: StringName in _cached_rows:
		var b: Control = _row_boxes.get(sid) as Control
		if b != null:
			_stats_box.move_child(b, idx)
			idx += 1
	for sid2: StringName in _row_boxes:
		if not _cached_rows.has(sid2):
			_stats_box.move_child(_row_boxes[sid2] as Control, idx)
			idx += 1
	if not old_y.is_empty():
		_slide_rows(old_y)
	for sid3: StringName in _row_ctl:
		var hm: StripButton = (_row_ctl[sid3] as Control).get_meta(&"hide") as StripButton
		hm.disabled = _cached_rows.size() <= 1
	var cap: int = HudLayout.cap_for(defaults)
	var is_default: bool = _cached_rows == defaults
	_count_label.text = "%s %d/%d" % ["Default" if is_default else "Custom", _cached_rows.size(), cap]
	_reset_btn.disabled = is_default
	if _edit_mode:
		_rebuild_suggestions(sugg, _cached_rows.size() >= cap)


## Size the value column to the widest value shown. It only grows within a layout, so a number ticking through
## decimals never resizes the strip.
func _fit_columns() -> void:
	for sid: StringName in _rows:
		var val: RollValue = (_rows[sid] as Array)[0] as RollValue
		if (_row_boxes[sid] as Control).visible:
			var vf: Font = val.get_theme_font(&"font")
			if vf != null:
				_val_w = maxf(_val_w, ceilf(vf.get_string_size(val.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, val.get_theme_font_size(&"font_size")).x))
	for sid2: StringName in _rows:
		((_rows[sid2] as Array)[0] as RollValue).custom_minimum_size.x = _val_w + COL_PAD


## Park each gain label just right of the panel, level with its row (and fading with it).
func _place_rates() -> void:
	var show_rates: bool = _opt(&"strip_rates", true)
	var right: float = _stats_panel.position.x + _stats_panel.size.x + 3.0
	var widest: float = 0.0
	for sid: StringName in _rows:
		var rate: Label = (_rows[sid] as Array)[1] as Label
		var box: Control = _row_boxes[sid] as Control
		var show: bool = show_rates and box.visible and rate.text != ""
		rate.visible = show
		if not show:
			continue
		var at: Vector2 = Vector2(right, box.global_position.y - global_position.y + floorf((box.size.y - rate.size.y) * 0.5)).floor()
		if rate.position != at:
			rate.position = at
		rate.modulate.a = box.modulate.a
		widest = maxf(widest, rate.size.x + 3.0)
	_rates_w = widest


## Rows glide to their new places after a reorder or a hide, instead of jumping.
func _slide_rows(old_y: Dictionary) -> void:
	await get_tree().process_frame   # the container has sorted by then
	for sid: StringName in old_y:
		var b: Control = _row_boxes.get(sid) as Control
		if b == null or not b.visible:
			continue
		var to_y: float = b.position.y
		var from_y: float = float(old_y[sid])
		if absf(from_y - to_y) < 1.0:
			continue
		var prev: Tween = _slides.get(b) as Tween
		if prev != null and prev.is_valid():
			prev.kill()
		b.position.y = from_y
		var tw: Tween = b.create_tween()
		_slides[b] = tw
		tw.tween_method(func(t: float) -> void: b.position.y = roundf(lerpf(from_y, to_y, 1.0 - (1.0 - t) * (1.0 - t))), 0.0, 1.0, 0.14)


func _rebuild_suggestions(sugg: Array[StringName], full: bool) -> void:
	for c: Node in _sug_grid.get_children():
		_sug_grid.remove_child(c)
		c.queue_free()
	var fresh: Dictionary = {}
	var n_new: int = 0
	for sid: StringName in sugg:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		var b: StripButton = StripButton.chip(load("res://assets/icons/%s.png" % String(sid)) as Texture2D)
		b.plus = true
		b.disabled = full
		b.pressed.connect(_add_row.bind(sid))
		var col: Color = StatStyle.color(sid)
		Tip.bind(b, {"title": def.display_name, "title_color": col, "color": col, "icon": String(sid),
			"body": "Add it to the strip.", "hint": "The strip is full. Hide a row first." if full else "Click to add."})
		_sug_grid.add_child(b)
		fresh[sid] = true
		if not _known_chips.has(sid):
			_pop(b, 0.03 * float(n_new))
			n_new += 1
	_known_chips = fresh
	_sug_grid.visible = _sug_grid.get_child_count() > 0
	_sug_note.visible = not _sug_grid.visible


## A stepped pop (small, a little over, settle) so a new chip lands with a bit of life. Snaps in reduced motion.
func _pop(c: Control, delay: float) -> void:
	if _calm() or not _gates_ready:
		return
	c.pivot_offset = c.custom_minimum_size * 0.5
	c.scale = Vector2(0.4, 0.4)
	var tw: Tween = c.create_tween()
	tw.tween_interval(delay)
	for k: float in [0.75, 1.15, 1.0]:
		tw.tween_callback(func() -> void: c.scale = Vector2(k, k))
		tw.tween_interval(0.04)


## The grip (drag to reorder) and the hide mark that open at the left of a row in edit mode.
func _build_row_controls(h: HBoxContainer, sid: StringName) -> void:
	var ctl := Control.new()
	ctl.custom_minimum_size = Vector2(0.0, StripButton.SIZE)   # width eases open with edit mode (see _set_edit_t)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ctl.clip_contents = true
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.visible = false
	h.add_child(ctl)
	h.move_child(ctl, 0)
	var grip: StripButton = StripButton.grip()
	var mark: StripButton = StripButton.hide_mark()
	mark.position = Vector2(12.0, 0.0)
	grip.grabbed.connect(_start_drag.bind(sid))
	grip.nudged.connect(_nudge.bind(sid))
	mark.pressed.connect(_hide_row.bind(sid))
	Tip.bind(grip, {"title": "Drag To Move", "body": "Drag this row up or down.", "hint": "Or press Up and Down while it is focused."})
	Tip.bind(mark, {"title": "Hide Row", "body": "Take it off the strip. Add it back from the chips below."})
	ctl.add_child(grip)
	ctl.add_child(mark)
	ctl.set_meta(&"hide", mark)
	_row_ctl[sid] = ctl


## The pencil (normal mode) and the edit footer: add chips, row count, Reset, Done.
func _build_strip_footer(v: VBoxContainer) -> void:
	_foot_normal = HBoxContainer.new()
	_foot_normal.custom_minimum_size.y = 14.0
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_normal.add_child(sp)
	_edit_btn = StripButton.make(StripButton.Glyph.EDIT)
	_edit_btn.modulate.a = 0.75
	_edit_btn.pressed.connect(set_edit_mode.bind(true))
	Tip.bind(_edit_btn, {"title": "Edit Stat Strip", "body": "Show, hide and reorder the rows.", "hint": "Right-click a row to hide it."})
	_foot_normal.add_child(_edit_btn)
	v.add_child(_foot_normal)
	_foot_normal.visible = false   # _refresh shows it once the tutorial reaches Dewdrops (a bare Sunlight counter needs no editing)

	_foot_clip = Control.new()
	_foot_clip.clip_contents = true
	_foot_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_foot_clip)
	_foot_edit = VBoxContainer.new()
	_foot_edit.add_theme_constant_override("separation", 3)
	_foot_edit.visible = false
	_foot_clip.add_child(_foot_edit)
	_foot_edit.add_child(PanelDivider.new())
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", STAT_RATE_SIZE)
	title.add_theme_color_override("font_color", RelicStyle.dim)
	title.text = "Add Stats"
	_foot_edit.add_child(title)
	_sug_grid = GridContainer.new()
	_sug_grid.columns = SUG_COLUMNS
	_sug_grid.add_theme_constant_override("h_separation", 2)
	_sug_grid.add_theme_constant_override("v_separation", 2)
	_foot_edit.add_child(_sug_grid)
	_sug_note = Label.new()
	_sug_note.text = "All stats added."
	_sug_note.add_theme_color_override("font_color", RelicStyle.dim)
	_foot_edit.add_child(_sug_note)
	var bar := HBoxContainer.new()
	_foot_bar = bar
	bar.add_theme_constant_override("separation", 3)
	_foot_edit.add_child(bar)
	_count_label = Label.new()
	_count_label.add_theme_color_override("font_color", RelicStyle.dim)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_count_label)
	_reset_btn = StripButton.make(StripButton.Glyph.RESET)
	_reset_btn.pressed.connect(reset_layout)
	Tip.bind(_reset_btn, func() -> Variant:
		return {"title": "Reset To Default", "body": "Put this zone's rows back in their usual order.",
			"hint": "Already on Default." if _reset_btn.disabled else "Click to reset."})
	bar.add_child(_reset_btn)
	var done: StripButton = StripButton.make(StripButton.Glyph.DONE)
	done.pressed.connect(set_edit_mode.bind(false))
	Tip.bind(done, {"title": "Done", "body": "Save the layout and leave edit mode."})
	bar.add_child(done)


func edit_mode() -> bool:
	return _edit_mode


## Edit mode: every row of the layout shows with a grip and a hide mark, and the add chips open under the strip.
func set_edit_mode(on: bool) -> void:
	if on == _edit_mode:
		return
	_edit_mode = on
	_end_drag()
	_known_chips.clear()
	_foot_normal.visible = not on and GameState.onboarding.is_unlocked(Onboarding.F_DEWDROP)
	_ease_edit(on)
	for sidc: StringName in _row_boxes:   # the whole row shows the drag hand in edit mode
		for c: Node in (_row_boxes[sidc] as Control).get_children():
			if c is Control and c != _row_ctl.get(sidc):
				(c as Control).mouse_default_cursor_shape = Control.CURSOR_DRAG if on else Control.CURSOR_ARROW
		(_row_boxes[sidc] as Control).mouse_default_cursor_shape = Control.CURSOR_DRAG if on else Control.CURSOR_ARROW
	Tip.hide_all()
	if not on:
		var sv: Node = get_node_or_null("/root/Save")
		if sv != null:
			sv.call("save_game")
	_after_layout_change()


## The strip opens and closes in a few steps (grips slide in, the footer grows). Reduced motion snaps.
func _ease_edit(on: bool) -> void:
	if _edit_tween != null and _edit_tween.is_valid():
		_edit_tween.kill()
	var goal: float = 1.0 if on else 0.0
	if _calm() or not is_inside_tree():
		_set_edit_t(goal)
		return
	_edit_tween = create_tween()
	_edit_tween.tween_method(_set_edit_t, _edit_t, goal, 0.18)


func _set_edit_t(t: float) -> void:
	_edit_t = clampf(roundf(t * 6.0) / 6.0, 0.0, 1.0)
	var w: float = roundf(CTL_W * _edit_t)
	for sid: StringName in _row_ctl:
		var c: Control = _row_ctl[sid] as Control
		c.custom_minimum_size.x = w
		c.visible = _edit_t > 0.0
	_foot_edit.modulate.a = _edit_t
	_foot_edit.visible = _edit_t > 0.0
	if _edit_t <= 0.0:
		_foot_clip.custom_minimum_size = Vector2.ZERO


## Every frame: size the edit footer to its content (the clip grows with the ease) and fade the marks of rows you are not on.
func _place_edit() -> void:
	if _foot_edit == null or _edit_t <= 0.0:
		return
	# The chips wrap into as many per line as the count, Reset and Done bar is wide, so the grid never widens the panel.
	var cols: int = clampi(int((_foot_bar.get_combined_minimum_size().x + 2.0) / (StripButton.CHIP_SIZE + 2.0)), 3, 6)
	if _sug_grid.columns != cols:
		_sug_grid.columns = cols
	var need: Vector2 = _foot_edit.get_combined_minimum_size()
	_foot_edit.position = Vector2.ZERO
	_foot_edit.size = Vector2(maxf(_foot_clip.size.x, need.x), need.y)
	_foot_clip.custom_minimum_size = Vector2(roundf(need.x * _edit_t), roundf(need.y * _edit_t))   # the footer sets the panel's width: Reset and Done are never clipped
	var mp: Vector2 = get_global_mouse_position()
	for sid: StringName in _row_ctl:
		var b: Control = _row_boxes.get(sid) as Control
		var hot: bool = sid == _drag_sid or (b != null and b.visible and b.get_global_rect().has_point(mp))
		(_row_ctl[sid] as Control).modulate.a = _edit_t * (1.0 if hot else 0.4)


## Settings > Gameplay > Edit Stat Strip: edit mode starts as soon as no menu is open.
func request_edit() -> void:
	_edit_pending = true


## Default layout for the zone you are in.
func reset_layout() -> void:
	sim.hud_layout.reset(sim.zone_id)
	_after_layout_change()


## Default layout for every zone (Settings > Gameplay > Reset Stat Strip).
func reset_all_layouts() -> void:
	sim.hud_layout.reset_all()
	_after_layout_change()


func _after_layout_change() -> void:
	_layout_sig = ""
	_refresh()


func _add_row(sid: StringName) -> void:
	if sim.hud_layout.add(sim.zone_id, sid, _defaults()):
		_after_layout_change()


func _hide_row(sid: StringName) -> void:
	if sim.hud_layout.hide(sim.zone_id, sid, _defaults()):
		_after_layout_change()


func _move_row(sid: StringName, dir: int) -> void:
	if sim.hud_layout.move(sim.zone_id, sid, dir, _defaults()):
		_after_layout_change()


func _nudge(dir: int, sid: StringName) -> void:
	_move_row(sid, dir)


## Right-click a row to hide it (Settings > Gameplay > Right-click hides a row turns that off).
func _on_row_input(event: InputEvent, sid: StringName) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# In edit mode the whole row is a drag handle (icon, value, the gaps), except the hide mark and the space around it.
		if _edit_mode and _edit_t >= 0.5 and _drag_sid == &"":
			var mark: Control = (_row_ctl[sid] as Control).get_meta(&"hide") as Control
			if not mark.get_global_rect().grow(3.0).has_point(get_global_mouse_position()):
				(_row_boxes[sid] as Control).accept_event()
				_start_drag(sid)
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and _opt(&"strip_rclick", true):
		(_row_boxes[sid] as Control).accept_event()
		_hide_row(sid)


# ---- drag to reorder

func _start_drag(sid: StringName) -> void:
	_drag_sid = sid
	Tip.hide_all()
	var b: Control = _row_boxes.get(sid) as Control
	if b != null:
		b.z_index = 1
		b.modulate = Color(1.25, 1.25, 1.0, b.modulate.a)


func _end_drag() -> void:
	if _drag_sid == &"":
		return
	var b: Control = _row_boxes.get(_drag_sid) as Control
	if b != null:
		b.z_index = 0
		b.modulate = Color(1.0, 1.0, 1.0, b.modulate.a)
	_drag_sid = &""


## While a row is held: the mouse moving or letting go belongs to the drag. True if it took the event.
func _drag_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_drag_step()
		get_viewport().set_input_as_handled()
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()
		return true
	return false


## Move the held row one place when the mouse crosses the middle of its neighbour (one place per motion, so it never overshoots).
func _drag_step() -> void:
	var rows: Array[StringName] = _cached_rows
	var i: int = rows.find(_drag_sid)
	if i < 0:
		return
	var my: float = _stats_box.get_local_mouse_position().y
	var centres: Dictionary = {}
	var y: float = 0.0
	for sid: StringName in rows:
		var b: Control = _row_boxes.get(sid) as Control
		if b == null or not b.visible:
			continue
		centres[sid] = y + b.size.y * 0.5
		y += b.size.y
	var j: int = i - 1
	while j >= 0 and not centres.has(rows[j]):
		j -= 1
	if j >= 0 and my < float(centres[rows[j]]):
		_move_row(_drag_sid, -1)
		return
	j = i + 1
	while j < rows.size() and not centres.has(rows[j]):
		j += 1
	if j < rows.size() and my > float(centres[rows[j]]):
		_move_row(_drag_sid, 1)


# ---- row fades

## Show or hide a strip row. A row leaving fades out in a few steps before it goes; one arriving fades in when `fade_in`.
## Reduced motion, and startup, snap.
func _set_row_shown(node: CanvasItem, want: bool, fade_in: bool) -> void:
	var f: Dictionary = _fades.get(node, {}) as Dictionary
	if want:
		if bool(f.get("out", false)):   # it was leaving: it stays
			(f["tw"] as Tween).kill()
			_fades.erase(node)
			node.modulate.a = 1.0
		if node.visible:
			return
		node.visible = true
		if fade_in and not _calm():
			node.modulate.a = 0.0
			_fade(node, false)
		return
	if not node.visible or bool(f.get("out", false)):
		return
	if _gates_ready and not _calm():
		_fade(node, true)
	else:
		node.visible = false


func _fade(node: CanvasItem, out: bool) -> void:
	var f: Dictionary = _fades.get(node, {}) as Dictionary
	if f.has("tw"):
		(f["tw"] as Tween).kill()
	var tw: Tween = node.create_tween()
	_fades[node] = {"tw": tw, "out": out}
	for i: int in 3:
		var a: float = float(i + 1) / 3.0
		tw.tween_callback(func() -> void: node.modulate.a = (1.0 - a) if out else a)
		tw.tween_interval(0.04)
	tw.tween_callback(func() -> void:
		_fades.erase(node)
		if out:
			node.visible = false
		node.modulate.a = 1.0)


# ---------------------------------------------------------------- staged unlocks and tips

## Show `node` only once `feature` is unlocked (see Onboarding). Call right after the node is built.
## The node must not be shown or hidden by anything else.
func gate(node: CanvasItem, feature: StringName) -> void:
	_gated.append([node, feature])
	node.visible = GameState.onboarding.is_unlocked(feature)


## A gated stat row also has to belong to the current zone; any other gated node always does.
func _gated_in_zone(node: CanvasItem) -> bool:
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
		if _row_node.has(node):   # stat rows fade out when the layout drops them; an unlock still flashes
			var was: bool = node.visible
			_set_row_shown(node, want, false)
			if want and not was and flash:
				_flash(node)
			continue
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
	_tip_card.held = PadInput.menu_open or Tip.is_showing() or _modal.visible or Banner.is_showing()   # tips never cover an open menu, a tooltip, a confirm card or a banner
	var ob: Onboarding = GameState.onboarding
	if not ob.tips_enabled:
		if _tip_card.is_showing():
			_tip_card.dismiss()
		return
	if Banner.is_showing():
		return  # the next tip waits for the banner to clear rather than being marked shown behind it
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
