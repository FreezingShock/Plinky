class_name RelicPanel
extends PanelContainer
## Relic screen: equip slots on top, inventory grid below, tooltip on hover or focus.
## Click an inventory relic to equip it. If slots are full, click an equipped relic to swap.
## Click an equipped relic (in a slot) to unequip it.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const COLUMNS: int = 2
const GAP: int = 4

var inventory: RelicInventory
var _slots_row: HBoxContainer
var _grid: GridContainer
var _hint: Label
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
	v.add_child(PanelDivider.new(2))
	var sep := Label.new()
	sep.text = "Collection"
	sep.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(sep)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	v.add_child(_grid)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 6 * (RelicSlot.SIZE + GAP) - GAP
	v.add_child(_hint)

func bind(inv: RelicInventory) -> void:
	if inventory != null:
		inventory.changed.disconnect(refresh)
	inventory = inv
	inv.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if inventory == null:
		return
	for c in _slots_row.get_children():
		c.queue_free()
		_slots_row.remove_child(c)
	for c in _grid.get_children():
		c.queue_free()
		_grid.remove_child(c)
	Tip.hide_all()
	# Equip slots: filled, empty, then locked ones with their unlock text.
	var total: int = inventory.slot_count()
	for i in total:
		var s := RelicSlot.new()
		if i < inventory.equipped.size():
			var id: StringName = inventory.equipped[i]
			s.setup(inventory.defs[id], inventory.stacks_of(id), false)
			s.set_highlight(_swap_from != &"")
		else:
			s.setup(null)
		_wire(s, i, true)
		_slots_row.add_child(s)
	for r in inventory.config.slot_unlock_rebirths:
		if inventory.rebirths < r:
			var s := RelicSlot.new()
			s.locked_text = "Unlocks at %d rebirths" % r
			s.setup(null)
			_wire(s, -1, true)
			_slots_row.add_child(s)
	# Collection.
	var list: Array[RelicDef] = inventory.sorted_owned()
	for d in list:
		var s := RelicSlot.new()
		s.setup(d, inventory.stacks_of(d.id), inventory.is_equipped(d.id))
		_wire(s, -1, false)
		_grid.add_child(_card(s, d))
	_hint.text = _hint_text(list.is_empty())

## Card: the slot plus name and rarity line, so the collection reads at a glance.
func _card(s: RelicSlot, d: RelicDef) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size.x = 96
	h.add_child(s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := Label.new()
	n.text = d.display_name
	v.add_child(n)
	var st := Label.new()
	st.text = "x%d" % inventory.stacks_of(d.id)
	st.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(st)
	return h

func _hint_text(no_relics: bool) -> String:
	if no_relics:
		return "No relics yet. Pads have a small chance to drop one."
	if _swap_from != &"":
		return "Pick an equipped relic to swap out. Click %s again to cancel." % inventory.defs[_swap_from].display_name
	return "%d of %d slots used." % [inventory.equipped.size(), inventory.slot_count()]

func _wire(s: RelicSlot, slot_index: int, is_equip_slot: bool) -> void:
	Tip.bind(s, func() -> Variant: return _tip_spec(s, is_equip_slot))
	s.pressed.connect(func(sl: RelicSlot) -> void: _on_pressed(sl, is_equip_slot))

func _tip_spec(s: RelicSlot, is_equip_slot: bool) -> Dictionary:
	if s.relic == null:
		if s.locked_text != "":
			return TipText.slot_note("Locked slot", s.locked_text)
		return TipText.slot_note("Empty slot", "Click a relic in your collection to equip it here.")
	var id: StringName = s.relic.id
	var hint: String
	if is_equip_slot:
		hint = "Click to swap in the picked relic." if _swap_from != &"" else "Click to unequip."
	elif inventory.is_equipped(id):
		hint = "Equipped. Click to unequip."
	elif inventory.free_slots() > 0:
		hint = "Click to equip."
	else:
		hint = "Slots full. Click, then pick a relic to swap out."
	return TipText.relic(s.relic, inventory.stacks_of(id), inventory.is_equipped(id), hint)

func _on_pressed(s: RelicSlot, is_equip_slot: bool) -> void:
	if s.relic == null:
		return
	var id: StringName = s.relic.id
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
