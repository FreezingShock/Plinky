class_name RelicPanel
extends PanelContainer
## Relic screen: equip slots on top, inventory grid below, tooltip on hover or focus.
## Click an inventory relic to equip it. If slots are full, click an equipped relic to swap.
## Click an equipped relic (in a slot) to unequip it.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const COLUMNS: int = 6
const GAP: int = 4

var inventory: RelicInventory
var _slots_row: HBoxContainer
var _grid: GridContainer
var _hint: Label
var _tip: RelicTooltip
var _swap_from: StringName = &""   ## inventory relic waiting for a slot to swap into

func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 10.0, 8.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := Label.new()
	title.text = "Relics"
	title.add_theme_color_override("font_color", RelicStyle.good)
	v.add_child(title)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", GAP)
	v.add_child(_slots_row)
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
	_hint.custom_minimum_size.x = COLUMNS * (RelicSlot.SIZE + GAP) - GAP
	v.add_child(_hint)
	_tip = RelicTooltip.new()

func _ready() -> void:
	add_child(_tip)
	_tip.top_level = true

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
	_tip.hide_tip()
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
		_grid.add_child(s)
	_hint.text = _hint_text(list.is_empty())

func _hint_text(no_relics: bool) -> String:
	if no_relics:
		return "No relics yet. Pads have a small chance to drop one."
	if _swap_from != &"":
		return "Pick an equipped relic to swap out. Click %s again to cancel." % inventory.defs[_swap_from].display_name
	return "%d of %d slots used." % [inventory.equipped.size(), inventory.slot_count()]

func _wire(s: RelicSlot, slot_index: int, is_equip_slot: bool) -> void:
	s.hovered.connect(func(sl: RelicSlot) -> void: _show_tip(sl, is_equip_slot))
	s.unhovered.connect(func(_sl: RelicSlot) -> void: _tip.hide_tip())
	s.pressed.connect(func(sl: RelicSlot) -> void: _on_pressed(sl, is_equip_slot))

func _rect(s: Control) -> Rect2:
	return Rect2(Vector2(global_position.x, s.global_position.y), Vector2(size.x, s.size.y))

func _show_tip(s: RelicSlot, is_equip_slot: bool) -> void:
	if s.relic == null:
		if s.locked_text != "":
			_tip.show_text("Locked slot", s.locked_text, _rect(s))
		else:
			_tip.show_text("Empty slot", "Click a relic in your collection to equip it here.", _rect(s))
		return
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
	_tip.show_relic(s.relic, inventory.stacks_of(id), inventory.is_equipped(id), hint, _rect(s))

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
