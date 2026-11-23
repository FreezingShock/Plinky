class_name RelicPanel
extends PanelContainer
## Relic screen: equip slots and the active bonuses on top, then the collection as rarity-framed cards
## (RelicCard) with sort and filter buttons, and a tooltip on hover or focus that compares the relic to what
## is equipped. Click a card to equip it. If slots are full, click it, then click the equipped relic to swap out.
## Click an equipped relic (in a slot) to unequip it.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const GAP: int = 5
const COLUMNS: int = 2
## Rows of cards visible before the collection scrolls.
const VISIBLE_HEIGHT: float = 104.0

var inventory: RelicInventory
var query := RelicQuery.new()
var _slots_row: HBoxContainer
var _bonus: HFlowContainer
var _grid: GridContainer
var _hint: Label
var _sort_btn: PixelButton
var _scope_btn: PixelButton
var _rarity_btn: PixelButton
var _swap_from: StringName = &""   ## inventory relic waiting for a slot to swap into

func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Relics"
	v.add_child(title)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", GAP)
	v.add_child(_slots_row)
	_bonus = HFlowContainer.new()
	_bonus.add_theme_constant_override("h_separation", 10)
	_bonus.add_theme_constant_override("v_separation", 0)
	_bonus.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	v.add_child(_bonus)
	v.add_child(PanelDivider.new(2))
	var sep := Label.new()
	sep.text = "Collection"
	sep.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(sep)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", GAP)
	bar.add_theme_constant_override("v_separation", GAP)
	bar.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	v.add_child(bar)
	_sort_btn = _tool_button(bar, func() -> void: query.cycle_sort())
	_scope_btn = _tool_button(bar, func() -> void: query.cycle_scope())
	_rarity_btn = _tool_button(bar, func() -> void: query.cycle_rarity(inventory))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(COLUMNS * RelicCard.W + GAP + 14.0, VISIBLE_HEIGHT)
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	scroll.add_child(_grid)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	v.add_child(_hint)


func _tool_button(parent: Control, on_press: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		on_press.call()
		_swap_from = &""
		refresh())
	parent.add_child(b)
	return b

func bind(inv: RelicInventory) -> void:
	if inventory != null:
		inventory.changed.disconnect(refresh)
	inventory = inv
	inv.changed.connect(refresh)
	refresh()

var _slots_shown: Array[StringName] = []
var _slots_primed: bool = false


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
	# Toolbar labels.
	_sort_btn.text = "Sort: %s" % query.sort_name()
	_scope_btn.text = "Show: %s" % query.scope_name()
	_rarity_btn.text = "Rarity: %s" % query.rarity_name(inventory)
	# Collection.
	var list: Array[RelicDef] = query.apply(inventory)
	var regrab: RelicCard = null
	for d in list:
		var card := RelicCard.new()
		card.setup(d, inventory.stacks_of(d.id), inventory.is_equipped(d.id), _swap_from == d.id)
		Tip.bind(card, func() -> Variant: return _tip_spec(d, false))
		card.pressed.connect(func(c: RelicCard) -> void: _on_pressed(c.relic, false))
		_grid.add_child(card)
		if d.id == refocus:
			regrab = card
	if regrab != null:
		regrab.grab_focus.call_deferred()
	_hint.text = _hint_text(inventory.owned.is_empty(), list.is_empty())


## Active bonuses from the equipped relics, one chip each so a bonus never breaks across lines.
func _fill_bonuses() -> void:
	for c in _bonus.get_children():
		_bonus.remove_child(c)
		c.queue_free()
	var list: Array[Dictionary] = inventory.active_bonuses()
	if list.is_empty():
		_bonus.add_child(_bonus_label("No bonuses active.", RelicStyle.dim))
		return
	for b: Dictionary in list:
		var e: RelicDef.Effect = b["effect"] as RelicDef.Effect
		_bonus.add_child(_bonus_label("%s %s" % [RelicDef.effect_name(e), RelicDef.effect_text(e, float(b["total"]))], RelicStyle.good))


func _bonus_label(t: String, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	return l


func _hint_text(no_relics: bool, none_shown: bool) -> String:
	if no_relics:
		return "No relics yet. Pads have a small chance to drop one."
	if none_shown:
		return "No relics match these filters."
	if _swap_from != &"":
		return "Pick an equipped relic to swap out. Click %s again to cancel." % inventory.defs[_swap_from].display_name
	return "%d of %d slots used." % [inventory.equipped.size(), inventory.slot_count()]


func _wire(s: RelicSlot, is_equip_slot: bool) -> void:
	Tip.bind(s, func() -> Variant: return _tip_spec(s.relic, is_equip_slot, s.locked_text))
	s.pressed.connect(func(sl: RelicSlot) -> void: _on_pressed(sl.relic, is_equip_slot))


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


func _on_pressed(def: RelicDef, is_equip_slot: bool) -> void:
	if def == null:
		return
	var id: StringName = def.id
	if is_equip_slot:
		if _swap_from != &"":
			var incoming: StringName = _swap_from
			_swap_from = &""
			inventory.swap(id, incoming)
		else:
			inventory.unequip(id)
		return
	if inventory.is_equipped(id):
		_swap_from = &""
		inventory.unequip(id)
	elif _swap_from == id:
		_swap_from = &""
		refresh()
	elif inventory.free_slots() > 0:
		inventory.equip(id)
	else:
		_swap_from = id
		refresh()
