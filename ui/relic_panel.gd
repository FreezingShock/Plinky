class_name RelicPanel
extends PanelContainer
## Relic gallery, sized to its content. Equip slots and active buffs on top (each buff with its stat icon), then rarity
## chips, then the relics of the open tier as small square cards. An unfound relic is a dark silhouette. Click a card to
## open its detail: art, ability, how to find it, and an Equip or Unequip button. With every slot full, Equip picks the
## relic, then click an equipped slot to swap. Cards are built only for the open tab, so the gallery stays light.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const GAP: int = 4
## Square cards across. The panel width follows from this, so no column is ever left empty.
const COLUMNS: int = 4
## Rarity chips across. Six tiers make two rows of three.
const TAB_COLUMNS: int = 3
const PANEL_W: float = COLUMNS * RelicCard.W + (COLUMNS - 1) * GAP
## The grid scrolls past this height. Shorter content just makes the panel shorter.
const MAX_GALLERY_HEIGHT: float = 150.0
## Room for the scrollbar when the grid scrolls.
const SCROLL_GUTTER: float = 10.0
const ICON_BIG: int = 24

var inventory: RelicInventory
var _ranks: Array[int] = []            ## tab order: rarity ranks that have relics
var _rank: int = 0                     ## the open tab
var _owned_only: bool = false
var _selected: StringName = &""        ## relic shown in the detail view
var _swap_from: StringName = &""       ## owned relic waiting for a slot to swap into
var _slots_row: HBoxContainer
var _bonus: HFlowContainer
var _count: Label
var _tabs: GridContainer
var _tab_buttons: Dictionary = {}      ## rank -> Button
var _show_btn: Button
var _scroll: ScrollContainer
var _page: VBoxContainer
var _grid: GridContainer
var _detail: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_meta: Label
var _detail_body: Label
var _detail_find: Label
var _detail_btn: PixelButton
var _hint: Label
var _slots_shown: Array[StringName] = []
var _slots_primed: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", GAP)
	add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	outer.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Relics"
	head.add_child(title)
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_color_override("font_color", RelicStyle.dim)
	head.add_child(_count)
	# Room for the close X in the corner, so the count is never under it (same spacer the other menus use).
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.HEADER_GAP, 1.0)
	head.add_child(x_gap)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", GAP)
	outer.add_child(_slots_row)
	_bonus = HFlowContainer.new()
	_bonus.add_theme_constant_override("h_separation", GAP)
	_bonus.add_theme_constant_override("v_separation", GAP)
	_bonus.custom_minimum_size.x = PANEL_W
	outer.add_child(_bonus)
	outer.add_child(PanelDivider.new(2))
	_tabs = GridContainer.new()
	_tabs.columns = TAB_COLUMNS
	_tabs.add_theme_constant_override("h_separation", GAP)
	_tabs.add_theme_constant_override("v_separation", GAP)
	_tabs.custom_minimum_size.x = PANEL_W
	outer.add_child(_tabs)
	var filter_row := HBoxContainer.new()
	outer.add_child(filter_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(spacer)
	_show_btn = _chip_button()
	_show_btn.pressed.connect(func() -> void:
		_owned_only = not _owned_only
		_swap_from = &""
		refresh())
	filter_row.add_child(_show_btn)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_W + SCROLL_GUTTER, 0.0)
	outer.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", GAP)
	_page.custom_minimum_size.x = PANEL_W
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_page.add_child(_grid)
	_detail = _build_detail()
	_page.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = PANEL_W
	outer.add_child(_hint)


func _build_detail() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.custom_minimum_size.x = PANEL_W
	v.add_child(PanelDivider.new(2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(ICON_BIG, ICON_BIG)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_detail_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_detail_name = Label.new()
	col.add_child(_detail_name)
	_detail_meta = Label.new()
	_detail_meta.add_theme_color_override("font_color", RelicStyle.dim)
	col.add_child(_detail_meta)
	_detail_body = Label.new()
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size.x = PANEL_W
	v.add_child(_detail_body)
	_detail_find = Label.new()
	_detail_find.add_theme_color_override("font_color", RelicStyle.accent)
	_detail_find.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_find.custom_minimum_size.x = PANEL_W
	v.add_child(_detail_find)
	_detail_btn = PixelButton.new()
	_detail_btn.focus_mode = Control.FOCUS_ALL
	_detail_btn.pressed.connect(_on_detail_pressed)
	v.add_child(_detail_btn)
	return v


## A compact chip button: a small bordered label, used for rarity tabs and the Show filter.
func _chip_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.custom_minimum_size = Vector2(0.0, 16.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## Styles a chip: a border in `tint`, a `fill`, and the label colour `text_c`. No cream or dotted fill: that was the
## PixelButton focus look, so these chips use plain AsciiBox kinds with our own colours.
func _apply_chip(b: Button, tint: Color, text_c: Color, fill: Color) -> void:
	b.add_theme_stylebox_override("normal", _chip_box(AsciiBox.Kind.BUTTON, tint, fill))
	b.add_theme_stylebox_override("hover", _chip_box(AsciiBox.Kind.HOVER, tint, fill))
	b.add_theme_stylebox_override("pressed", _chip_box(AsciiBox.Kind.PRESSED, tint, fill))
	b.add_theme_stylebox_override("focus", _chip_box(AsciiBox.Kind.HOVER, RelicStyle.accent, fill))
	b.add_theme_color_override("font_color", text_c)
	b.add_theme_color_override("font_hover_color", text_c)
	b.add_theme_color_override("font_pressed_color", text_c)
	b.add_theme_color_override("font_focus_color", text_c)


func _chip_box(kind: AsciiBox.Kind, edge: Color, fill: Color) -> AsciiBox:
	var b := AsciiBox.make(kind, 3.0, 1.0)
	b.edge_override = edge
	b.fill_override = fill
	return b



func bind(inv: RelicInventory) -> void:
	if inventory != null:
		inventory.changed.disconnect(refresh)
	inventory = inv
	inv.changed.connect(refresh)
	_ranks = inv.tier_ranks()
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_tab_buttons.clear()
	for r: int in _ranks:
		var b := _chip_button()
		b.pressed.connect(func() -> void:
			_rank = r
			_swap_from = &""
			_selected = &""
			refresh())
		_tabs.add_child(b)
		_tab_buttons[r] = b
	if not _ranks.is_empty() and not _ranks.has(_rank):
		_rank = _ranks[0]
	refresh()


func refresh() -> void:
	if inventory == null:
		return
	var refocus: StringName = &""
	var owner_ctl: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_ctl is RelicCard and (owner_ctl as RelicCard).relic != null:
		refocus = (owner_ctl as RelicCard).relic.id
	for c in _slots_row.get_children():
		_slots_row.remove_child(c)
		c.queue_free()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	Tip.hide_all()
	# Equip slots: filled, empty, then locked ones with their unlock text.
	var total: int = inventory.slot_count()
	for i in total:
		var s := RelicSlot.new()
		if i < inventory.equipped.size():
			var id: StringName = inventory.equipped[i]
			s.setup(inventory.defs[id], inventory.stacks_of(id), false)
			s.set_highlight(_swap_from != &"")
			if _slots_primed and not _slots_shown.has(id):
				s.pop()
		else:
			s.setup(null)
		_wire(s, true)
		_slots_row.add_child(s)
	for r in inventory.config.slot_unlock_rebirths:
		if inventory.rebirths < r:
			var s := RelicSlot.new()
			s.locked_text = "Unlocks at %d rebirths" % r
			s.setup(null)
			_wire(s, true)
			_slots_row.add_child(s)
	_slots_shown = inventory.equipped.duplicate()
	_slots_primed = true
	_fill_bonuses()
	_refresh_tabs()
	_show_btn.text = "Show: %s" % ("Owned" if _owned_only else "All")
	_apply_chip(_show_btn, RelicStyle.edge, RelicStyle.text, RelicStyle.ink)
	_fill_grid(refocus)
	_fill_detail()
	var found: int = inventory.owned.size()
	_count.text = "%d of %d found" % [found, inventory.defs.size()]
	_hint.text = _hint_text(inventory.owned.is_empty())
	call_deferred("_fit_scroll")


## The gallery is only as tall as its content, up to MAX_GALLERY_HEIGHT. Past that it scrolls.
func _fit_scroll() -> void:
	if not is_inside_tree():
		return
	_scroll.custom_minimum_size.y = minf(_page.get_combined_minimum_size().y, MAX_GALLERY_HEIGHT)


## Each chip shows the tier name and how many of it you have, in the tier's own colour. The open tab is filled.
func _refresh_tabs() -> void:
	for r: int in _ranks:
		var b: Button = _tab_buttons[r]
		var defs_here: Array[RelicDef] = inventory.defs_of_rank(r)
		var have: int = 0
		for d: RelicDef in defs_here:
			if inventory.stacks_of(d.id) > 0:
				have += 1
		if defs_here.is_empty():
			continue
		var rarity: RarityDef = defs_here[0].rarity
		b.text = "%s %d/%d" % [rarity.display_name, have, defs_here.size()]
		# The open tab fills with its tier colour; its label is lifted until it reads on that fill.
		var tint: Color = rarity.tint()
		var on: bool = r == _rank
		var fill: Color = RelicStyle.ink.lerp(tint, 0.3) if on else RelicStyle.ink
		_apply_chip(b, tint, rarity.readable_color(fill), fill)


func _fill_grid(refocus: StringName) -> void:
	var regrab: RelicCard = null
	var shown: int = 0
	for d: RelicDef in inventory.defs_of_rank(_rank):
		var owned: bool = inventory.stacks_of(d.id) > 0
		if _owned_only and not owned:
			continue
		var card := RelicCard.new()
		if owned:
			card.setup(d, inventory.stacks_of(d.id), inventory.is_equipped(d.id), _swap_from == d.id)
			Tip.bind(card, func() -> Variant: return _tip_spec(d, false))
		else:
			card.setup(d, 0, false, false, true)
			var find: String = inventory.acquire_text(d.id)
			Tip.bind(card, func() -> Variant: return TipText.slot_note("Not Found Yet", find))
		card.pressed.connect(func(c: RelicCard) -> void: _select(c.relic.id))
		_grid.add_child(card)
		shown += 1
		if d.id == refocus:
			regrab = card
	if regrab != null:
		regrab.grab_focus.call_deferred()
	_grid.visible = shown > 0


func _select(id: StringName) -> void:
	_selected = id
	refresh()


## The detail view for the selected relic. Ability text shows for every relic, so you can read ahead.
func _fill_detail() -> void:
	if _selected == &"" or not inventory.defs.has(_selected):
		_detail.visible = false
		return
	_detail.visible = true
	var d: RelicDef = inventory.defs[_selected]
	var owned: int = inventory.stacks_of(_selected)
	var equipped_now: bool = inventory.is_equipped(_selected)
	_detail_icon.texture = IconSet.get_icon(String(_selected), ICON_BIG)
	_detail_icon.modulate = Color.WHITE if owned > 0 else Color(0.2, 0.2, 0.26, 1.0)
	_detail_name.text = d.display_name if owned > 0 else "???"
	_detail_name.add_theme_color_override("font_color", d.rarity.readable_color(RelicStyle.ink) if owned > 0 else RelicStyle.dim)
	var state: String = "Owned %d" % owned if owned > 0 else "Not found yet"
	if equipped_now:
		state += ", equipped"
	_detail_meta.text = "%s · %s" % [d.rarity.display_name, state]
	_detail_body.text = d.describe(maxi(owned, 1))
	_detail_find.text = "How to find: " + inventory.acquire_text(_selected)
	if owned <= 0:
		_detail_btn.text = "Not Found Yet"
		_detail_btn.disabled = true
	elif equipped_now:
		_detail_btn.text = "Unequip"
		_detail_btn.disabled = false
	elif _swap_from == _selected:
		_detail_btn.text = "Cancel Swap"
		_detail_btn.disabled = false
	elif inventory.free_slots() > 0:
		_detail_btn.text = "Equip"
		_detail_btn.disabled = false
	else:
		_detail_btn.text = "Equip: Pick A Slot To Swap"
		_detail_btn.disabled = false


func _on_detail_pressed() -> void:
	var id: StringName = _selected
	if id == &"" or not inventory.defs.has(id):
		return
	if inventory.is_equipped(id):
		_swap_from = &""
		inventory.unequip(id)
	elif _swap_from == id:
		_swap_from = &""
		refresh()
	elif inventory.stacks_of(id) > 0 and inventory.free_slots() > 0:
		inventory.equip(id)
	elif inventory.stacks_of(id) > 0:
		_swap_from = id
		refresh()


## Clicking an equipped slot: swap in the picked relic if one is waiting, else unequip this one.
func _on_slot_pressed(def: RelicDef) -> void:
	if def == null:
		return
	var id: StringName = def.id
	if _swap_from != &"":
		var incoming: StringName = _swap_from
		_swap_from = &""
		inventory.swap(id, incoming)
	else:
		inventory.unequip(id)


## Active buffs as chips: the stat's own icon, the name, and the total in the gain green. Wraps, never truncates.
func _fill_bonuses() -> void:
	for c in _bonus.get_children():
		_bonus.remove_child(c)
		c.queue_free()
	var list: Array[Dictionary] = inventory.active_bonuses()
	if list.is_empty():
		_bonus.add_child(_bonus_text("No bonuses active.", RelicStyle.dim))
		return
	for b: Dictionary in list:
		var e: RelicDef.Effect = b["effect"] as RelicDef.Effect
		_bonus.add_child(_bonus_chip(e, float(b["total"])))


func _bonus_chip(e: RelicDef.Effect, total: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _chip_box(AsciiBox.Kind.BUTTON, RelicStyle.edge, RelicStyle.ink))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = IconSet.get_icon(_effect_icon(e), 12)
	icon.custom_minimum_size = Vector2(12.0, 12.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(_bonus_text(RelicDef.effect_name(e), RelicStyle.dim))
	row.add_child(_bonus_text(RelicDef.effect_text(e, total), StatStyle.gain()))
	return chip


## The stat icon a relic effect is shown with. These are the HUD and Stats icons for the nearest stat.
static func _effect_icon(e: RelicDef.Effect) -> String:
	match e:
		RelicDef.Effect.CASH_MULT: return "cash"
		RelicDef.Effect.MULT_GAIN: return "mult"
		RelicDef.Effect.PRESS_RATE: return "rate"
		RelicDef.Effect.CRIT_DAMAGE: return "crit_dmg"
		RelicDef.Effect.CRIT_CHANCE: return "crit"
		RelicDef.Effect.DROP_CHANCE: return "luck"
		RelicDef.Effect.OFFLINE_RATE: return "offline"
		RelicDef.Effect.SURGE: return "rate"
		RelicDef.Effect.ZONE_GAIN: return "mult"
		RelicDef.Effect.MASTERY_XP: return "mastery"
		RelicDef.Effect.HOT_GAIN: return "heat"
		RelicDef.Effect.PITY_SPEED: return "clock"
		RelicDef.Effect.DROP_REWARD: return "fortune"
	return "presses"


func _bonus_text(t: String, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", c)
	return l


func _hint_text(no_relics: bool) -> String:
	if no_relics:
		return "No relics yet. Pads have a small chance to drop one."
	if _swap_from != &"":
		return "Pick an equipped relic to swap out. Click %s again to cancel." % inventory.defs[_swap_from].display_name
	return "%d of %d slots used." % [inventory.equipped.size(), inventory.slot_count()]


func _wire(s: RelicSlot, is_equip_slot: bool) -> void:
	Tip.bind(s, func() -> Variant: return _tip_spec(s.relic, is_equip_slot, s.locked_text))
	s.pressed.connect(func(sl: RelicSlot) -> void: _on_slot_pressed(sl.relic))


func _tip_spec(def: RelicDef, is_equip_slot: bool, locked_text: String = "") -> Dictionary:
	if def == null:
		if locked_text != "":
			return TipText.slot_note("Locked Slot", locked_text)
		return TipText.slot_note("Empty Slot", "Click a relic in your collection to equip it here.")
	var id: StringName = def.id
	var hint: String
	if is_equip_slot:
		hint = "Click to swap in the picked relic." if _swap_from != &"" else "Click to unequip."
	elif inventory.is_equipped(id):
		hint = "Equipped. Click to unequip."
	elif inventory.free_slots() > 0:
		hint = "Click to equip."
	else:
		hint = "Slots full. Click, then pick a relic to swap out."
	var spec: Dictionary = TipText.relic(def, inventory.stacks_of(id), inventory.is_equipped(id), hint)
	var lines: Array = spec["lines"]
	for l in _compare_lines(def, is_equip_slot):
		lines.append(l)
	return spec


## Compare-on-hover: what the change would do to the equipped bonuses, as tooltip lines.
## Hovering a collection relic compares equipping it (a free slot, or in place of the equipped relic that shares
## its effect). Hovering an equipped slot while a swap is pending compares the swap.
func _compare_lines(def: RelicDef, is_equip_slot: bool) -> Array:
	var change: Array[Dictionary] = []
	var header: String = ""
	if is_equip_slot:
		if _swap_from == &"" or def.id == _swap_from:
			return []
		change = inventory.preview_change(_swap_from, def.id)
		header = "If swapped for %s" % inventory.defs[_swap_from].display_name
	elif inventory.is_equipped(def.id):
		return []
	elif inventory.free_slots() > 0:
		change = inventory.preview_change(def.id)
		header = "If equipped"
	else:
		var twin: StringName = &""
		for eid in inventory.equipped:
			if (inventory.defs[eid] as RelicDef).effect == def.effect:
				twin = eid
				break
		if twin == &"":
			return []
		change = inventory.preview_change(def.id, twin)
		header = "If swapped for %s" % inventory.defs[twin].display_name
	var out: Array = [[Tip.seg(header, RelicStyle.accent)]]
	if change.is_empty():
		out.append([Tip.seg("No change to your bonuses.", RelicStyle.dim)])
		return out
	for c: Dictionary in change:
		var e: RelicDef.Effect = c["effect"] as RelicDef.Effect
		var b: float = float(c["before"])
		var a: float = float(c["after"])
		out.append([RelicDef.effect_name(e) + " ", Tip.seg(RelicDef.effect_text(e, b), RelicStyle.dim), " to ",
			Tip.seg(RelicDef.effect_text(e, a), StatStyle.BUY_GREEN if a >= b else StatStyle.BUY_RED)])
	return out
