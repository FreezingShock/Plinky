class_name RelicPanel
extends PanelContainer
## Relic gallery, sized to its content. The header has the count, a Show filter and the close X's room. Under it, the
## equip slots with the active buffs beside them as icon chips. Then rarity chips, and the relics of the open tier as
## small square cards, six across.
##
## The hover or focus tooltip is where the detail lives: ability, state, how to find it, and the action a click does.
## Click an owned relic to equip it. A free slot takes it straight in. With every slot full, the relic waits, the
## equipped slots light up, and clicking one swaps it in. Clicking an equipped relic (or slot) unequips it, or swaps
## it out while a swap waits. Keyboard and pad: focus a card and press Enter or A. Esc cancels a waiting swap.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const GAP: int = 4
## Square cards across. The panel width follows from this, so no column is ever left empty.
const COLUMNS: int = 6
## Rarity chips across. Six tiers make two rows of three.
const TAB_COLUMNS: int = 3
const PANEL_W: float = COLUMNS * RelicCard.W + (COLUMNS - 1) * GAP
## Chips and tabs keep this height or more, so they are easy to hit with a mouse or a pad.
const CHIP_H: float = 20.0
## The grid scrolls past this height. Shorter content just makes the panel shorter.
const MAX_GALLERY_HEIGHT: float = 150.0
## Room for the scrollbar when the grid scrolls.
const SCROLL_GUTTER: float = 10.0

var inventory: RelicInventory
var _ranks: Array[int] = []            ## tab order: rarity ranks that have relics
var _rank: int = 0                     ## the open tab
var _owned_only: bool = false
var _swap_from: StringName = &""       ## owned relic waiting for a slot to swap into
var _head_count: Label
var _top: HBoxContainer
var _slots_row: HBoxContainer
var _bonus: HFlowContainer
var _tabs: GridContainer
var _tab_buttons: Dictionary = {}      ## rank -> Button
var _show_btn: Button
var _scroll: ScrollContainer
var _page: VBoxContainer
var _grid: GridContainer
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
	_head_count = Label.new()
	_head_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_count.add_theme_color_override("font_color", RelicStyle.dim)
	head.add_child(_head_count)
	_show_btn = _chip_button()
	_show_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_show_btn.pressed.connect(func() -> void:
		_owned_only = not _owned_only
		_swap_from = &""
		refresh())
	head.add_child(_show_btn)
	# Room for the close X in the corner, so the header text is never under it (same spacer the other menus use).
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.HEADER_GAP, 1.0)
	head.add_child(x_gap)
	# Equip slots on the left, the active buffs filling the rest of the row as chips.
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", GAP)
	outer.add_child(_top)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", GAP)
	_slots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(_slots_row)
	_bonus = HFlowContainer.new()
	_bonus.add_theme_constant_override("h_separation", GAP)
	_bonus.add_theme_constant_override("v_separation", GAP)
	_bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(_bonus)
	outer.add_child(PanelDivider.new(2))
	_tabs = GridContainer.new()
	_tabs.columns = TAB_COLUMNS
	_tabs.add_theme_constant_override("h_separation", GAP)
	_tabs.add_theme_constant_override("v_separation", GAP)
	_tabs.custom_minimum_size.x = PANEL_W
	outer.add_child(_tabs)
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
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = PANEL_W
	outer.add_child(_hint)


## A compact chip button: a bordered label, used for rarity tabs and the Show filter. Tall enough to hit easily.
func _chip_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.custom_minimum_size = Vector2(0.0, CHIP_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## Styles a chip: a border in `tint`, a `fill`, and the label colour `text_c`. Focus gets the accent border, so the
## focused chip is always visible. These are plain AsciiBox kinds with our own colours.
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
	# Equip slots: filled, empty, then locked ones with their unlock text. A waiting swap lights every slot.
	var total: int = inventory.slot_count()
	for i in total:
		var s := RelicSlot.new()
		if i < inventory.equipped.size():
			var id: StringName = inventory.equipped[i]
			s.setup(inventory.defs[id], inventory.stacks_of(id), false)
			s.set_highlight(_swap_from != &"")
			if _slots_primed and not _slots_shown.has(id) and not FxConfig.reduce_flashing:
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
	_head_count.text = "%d of %d found" % [inventory.owned.size(), inventory.defs.size()]
	_hint.text = _hint_text(inventory.owned.is_empty())
	call_deferred("_fit_scroll")


## The gallery is only as tall as its content, up to MAX_GALLERY_HEIGHT. Past that it scrolls.
func _fit_scroll() -> void:
	if not is_inside_tree():
		return
	_scroll.custom_minimum_size.y = minf(_page.get_combined_minimum_size().y, MAX_GALLERY_HEIGHT)


## Each chip shows the tier name and how many of it you have, in the tier's colour. The open tab is filled.
func _refresh_tabs() -> void:
	for r: int in _ranks:
		var b: Button = _tab_buttons[r]
		var defs_here: Array[RelicDef] = inventory.defs_of_rank(r)
		if defs_here.is_empty():
			continue
		var have: int = 0
		for d: RelicDef in defs_here:
			if inventory.stacks_of(d.id) > 0:
				have += 1
		var rarity: RarityDef = defs_here[0].rarity
		b.text = "%s %d/%d" % [rarity.display_name, have, defs_here.size()]
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
		else:
			card.setup(d, 0, false, false, true)
		Tip.bind(card, func() -> Variant: return _card_tip(d))
		card.pressed.connect(func(c: RelicCard) -> void: _activate(c.relic.id))
		_grid.add_child(card)
		shown += 1
		if d.id == refocus:
			regrab = card
	if regrab != null:
		regrab.grab_focus.call_deferred()
	_grid.visible = shown > 0


## What a card's tooltip shows. An owned relic gets the full relic tip with the action in its hint. An unfound one
## shows its tier, its ability (so you can read ahead), and how to find it.
func _card_tip(def: RelicDef) -> Dictionary:
	var owned: int = inventory.stacks_of(def.id)
	if owned > 0:
		return _tip_spec(def, false)
	var rc: Color = def.rarity.readable_color(RelicStyle.ink)
	return {"title": "Not Found Yet", "title_color": RelicStyle.dim, "body": def.describe(1),
		"lines": [[Tip.seg(def.rarity.display_name, rc)],
			[Tip.seg("How to find: " + inventory.acquire_text(def.id), RelicStyle.accent)]],
		"hint": "You have not found this one yet.", "beside": true}


## One click on an owned relic does the obvious thing. Equipped: unequip (or swap it out while a swap waits). A free
## slot: equip. Every slot full: wait for a swap, then click an equipped slot. Clicking the waiting relic again cancels.
func _activate(id: StringName) -> void:
	if inventory.stacks_of(id) <= 0:
		return
	if inventory.is_equipped(id):
		if _swap_from != &"":
			_on_slot_pressed(inventory.defs[id])
		else:
			inventory.unequip(id)
	elif _swap_from == id:
		_swap_from = &""
		refresh()
	elif inventory.free_slots() > 0:
		inventory.equip(id)
	else:
		_swap_from = id
		refresh()


## Esc cancels a waiting swap, so it never closes the menu by accident while one is waiting.
func _unhandled_input(event: InputEvent) -> void:
	if _swap_from != &"" and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		_swap_from = &""
		refresh()
		get_viewport().set_input_as_handled()


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


## Active buffs as chips: the stat's icon and the total in the gain green. The name is in the tooltip. Wraps.
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
	row.add_child(_bonus_text(RelicDef.effect_text(e, total), StatStyle.gain()))
	var name_text: String = RelicDef.effect_name(e)
	var body: String = "From your equipped relics: %s." % RelicDef.effect_text(e, total)
	Tip.bind(chip, func() -> Variant: return TipText.slot_note(name_text, body))
	return chip


## The stat icon a relic effect is shown with: the HUD and Stats icon for the nearest stat.
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
		return "Click an equipped slot to swap %s in. Esc cancels." % inventory.defs[_swap_from].display_name
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
	var spec: Dictionary = TipText.relic(def, inventory.stacks_of(id), inventory.is_equipped(id), _hint_for(id, is_equip_slot))
	var lines: Array = spec["lines"]
	for l in _compare_lines(def, is_equip_slot):
		lines.append(l)
	return spec


## The one-line action a click does on this relic, given the state right now.
func _hint_for(id: StringName, is_equip_slot: bool) -> String:
	if _swap_from != &"":
		if is_equip_slot:
			return "Click to swap %s in." % inventory.defs[_swap_from].display_name
		if id == _swap_from:
			return "Waiting to swap. Click an equipped slot, or click again to cancel."
		if inventory.is_equipped(id):
			return "Click to swap this one out."
	if is_equip_slot:
		return "Click to unequip."
	if inventory.is_equipped(id):
		return "Equipped. Click to unequip."
	if inventory.free_slots() > 0:
		return "Click to equip."
	return "Slots full. Click, then an equipped slot to swap."


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
