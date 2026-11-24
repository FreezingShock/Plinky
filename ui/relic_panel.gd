class_name RelicPanel
extends PanelContainer
## Relic gallery. Equip slots and active bonuses on top, then a row of rarity tabs and the relics of the open tier as
## cards. A relic you have not found shows as a dark silhouette with how to find it. Click a card to open its detail:
## art, ability, how to find it, and an Equip or Unequip button. With every slot full, Equip picks the relic, then click
## an equipped slot to swap. Cards are built only for the open tab, so the gallery stays light.
##
## Wire up with bind(inventory). The panel only calls RelicInventory methods and listens to `changed`.

const GAP: int = 5
const COLUMNS: int = 2
## Height of the scrolling gallery area before the page scrolls.
const VISIBLE_HEIGHT: float = 200.0
const ICON_BIG: int = 32

var inventory: RelicInventory
var _ranks: Array[int] = []            ## tab order: rarity ranks that have relics
var _rank: int = 0                     ## the open tab
var _owned_only: bool = false
var _selected: StringName = &""       ## relic shown in the detail view
var _swap_from: StringName = &""      ## owned relic waiting for a slot to swap into
var _slots_row: HBoxContainer
var _bonus: HFlowContainer
var _count: Label
var _tabs: HFlowContainer
var _tab_buttons: Dictionary = {}      ## rank -> PixelButton
var _show_btn: PixelButton
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
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)
	var head := HBoxContainer.new()
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
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", GAP)
	outer.add_child(_slots_row)
	_bonus = HFlowContainer.new()
	_bonus.add_theme_constant_override("h_separation", 10)
	_bonus.add_theme_constant_override("v_separation", 0)
	_bonus.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	outer.add_child(_bonus)
	outer.add_child(PanelDivider.new(2))
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", GAP)
	_tabs.add_theme_constant_override("v_separation", GAP)
	_tabs.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	outer.add_child(_tabs)
	_show_btn = _tool_button(outer, func() -> void: _owned_only = not _owned_only)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(COLUMNS * RelicCard.W + GAP + 14.0, VISIBLE_HEIGHT)
	outer.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", GAP)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	page.add_child(_grid)
	_detail = _build_detail()
	page.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	outer.add_child(_hint)


func _build_detail() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.custom_minimum_size.x = COLUMNS * RelicCard.W + GAP
	v.add_child(PanelDivider.new(2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
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
	_detail_body.custom_minimum_size.x = COLUMNS * RelicCard.W - ICON_BIG - 8
	v.add_child(_detail_body)
	_detail_find = Label.new()
	_detail_find.add_theme_color_override("font_color", RelicStyle.accent)
	_detail_find.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_find.custom_minimum_size.x = COLUMNS * RelicCard.W - ICON_BIG - 8
	v.add_child(_detail_find)
	_detail_btn = PixelButton.new()
	_detail_btn.focus_mode = Control.FOCUS_ALL
	_detail_btn.pressed.connect(_on_detail_pressed)
	v.add_child(_detail_btn)
	return v


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
	_ranks = inv.tier_ranks()
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_tab_buttons.clear()
	for r: int in _ranks:
		var b := PixelButton.new()
		b.focus_mode = Control.FOCUS_ALL
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
	_fill_grid(refocus)
	_fill_detail()
	var found: int = inventory.owned.size()
	_count.text = "%d of %d found" % [found, inventory.defs.size()]
	_hint.text = _hint_text(inventory.owned.is_empty())


## Tab labels show how many of each tier you have found, and the open tab is marked with a ">".
func _refresh_tabs() -> void:
	for r: int in _ranks:
		var b: PixelButton = _tab_buttons[r]
		var defs_here: Array[RelicDef] = inventory.defs_of_rank(r)
		var have: int = 0
		for d: RelicDef in defs_here:
			if inventory.stacks_of(d.id) > 0:
				have += 1
		var name_text: String = defs_here[0].rarity.display_name if not defs_here.is_empty() else "?"
		b.text = "%s%s %d/%d" % [">" if r == _rank else "", name_text, have, defs_here.size()]


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
	var tex: Texture2D = IconSet.get_icon(String(_selected), ICON_BIG)
	_detail_icon.texture = tex
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


func _hint_text(no_relics: bool) -> String:
	if no_relics:
		return "No relics yet. Pads have a small chance to drop one."
	if _swap_from != &"":
		return "Pick an equipped relic to swap out. Click %s again to cancel." % inventory.defs[_swap_from].display_name
	return "%d of %d slots used." % [inventory.equipped.size(), inventory.slot_count()]


func _wire(s: RelicSlot, is_equip_slot: bool) -> void:
	Tip.bind(s, func() -> Variant: return _tip_spec(s.relic, is_equip_slot, s.locked_text))
	s.pressed.connect(func(sl: RelicSlot) -> void: _on_slot_pressed(sl.relic))


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
