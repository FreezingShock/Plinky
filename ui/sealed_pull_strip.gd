class_name SealedPullStrip
extends VBoxContainer
## The sealed caches row at the foot of the relic gallery. One card per cache (see SealedPullDef). Each card shows the pouch,
## its price in the reset's currency, and how many pulls are left this reset. Border colour: green when you can open it, red
## when you cannot, gold when this reset's pulls are used up, dimmed until its reset has been used once.
## Opening one spends the currency, rolls a relic and shows SealedPullOverlay. Tooltips use the shared Tip.

const GAP: int = 4
const CARD_H: float = 46.0
const PICTURE: float = 32.0
const CARD_GOLD: Color = Color("f2c94c")
const PULL_HINT: String = "Click to open!"

var _cards: Dictionary = {}   ## cache id -> Button
var _pictures: Dictionary = {}  ## cache id -> TextureRect
var _names: Dictionary = {}     ## cache id -> Label
var _prices: Dictionary = {}    ## cache id -> Label
var _counts: Dictionary = {}    ## cache id -> Label
var _borders: Dictionary = {}   ## cache id -> last border Color applied, so the styles are only rebuilt on a change
var _row: HBoxContainer
var _bus: Node = null


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = RelicPanel.PANEL_W
	var head := Label.new()
	head.text = "Sealed Caches"
	head.add_theme_color_override("font_color", RelicStyle.dim)
	add_child(head)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_row)


func _ready() -> void:
	_bus = get_node_or_null("/root/EventBus")
	if _bus != null:
		_bus.stat_changed.connect(_on_changed_stat)
		_bus.reset_done.connect(_on_changed_any)
		_bus.relic_gained.connect(_on_changed_relic)
	_build()
	refresh()


func _exit_tree() -> void:
	if _bus == null:
		return
	if _bus.stat_changed.is_connected(_on_changed_stat):
		_bus.stat_changed.disconnect(_on_changed_stat)
	if _bus.reset_done.is_connected(_on_changed_any):
		_bus.reset_done.disconnect(_on_changed_any)
	if _bus.relic_gained.is_connected(_on_changed_relic):
		_bus.relic_gained.disconnect(_on_changed_relic)


func _sealed() -> SealedPulls:
	return GameState.sim.sealed if GameState.sim != null else null


func _build() -> void:
	var sealed: SealedPulls = _sealed()
	if sealed == null:
		return
	for def: SealedPullDef in sealed.ordered():
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_ALL
		card.clip_text = true
		card.custom_minimum_size = Vector2(0.0, CARD_H)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = ""
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 6)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(inner)
		var pic := TextureRect.new()
		pic.texture = SealedArt.texture(def.palette)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.custom_minimum_size = Vector2(PICTURE, PICTURE)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(pic)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(col)
		var name_l := Label.new()
		name_l.theme_type_variation = &"TitleLabel"
		name_l.text = def.display_name
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_l)
		var price_l := Label.new()
		price_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(price_l)
		var count_l := Label.new()
		count_l.add_theme_color_override("font_color", RelicStyle.dim)
		count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(count_l)
		card.pressed.connect(_on_pressed.bind(def.id))
		Tip.bind(card, _tip_for.bind(def.id))
		_row.add_child(card)
		_cards[def.id] = card
		_pictures[def.id] = pic
		_names[def.id] = name_l
		_prices[def.id] = price_l
		_counts[def.id] = count_l


## Re-reads the caches: price, pulls left, whether the reset is used, and the border. Cheap; safe to call often.
func refresh() -> void:
	var sealed: SealedPulls = _sealed()
	if sealed == null or GameState.sim == null or _cards.is_empty():
		return
	var sim: Sim = GameState.sim
	for def: SealedPullDef in sealed.ordered():
		if not _cards.has(def.id):
			continue
		var card: Button = _cards[def.id]
		var reset_def: ZoneResetDef = sim.reset_defs.get(def.reset_id) as ZoneResetDef
		var currency: String = reset_def.display_name if reset_def != null else ""
		var unit: String = _currency_name(def.reset_id)
		var used: bool = sim.reset_count(def.reset_id) > 0
		var left: int = sealed.remaining(def)
		var price: BigNum = sealed.cost(def)
		var can: bool = _can_open(def)
		var border: Color
		if not used:
			border = RelicStyle.dim
		elif left <= 0:
			border = CARD_GOLD
		elif can:
			border = StatStyle.BUY_GREEN
		else:
			border = StatStyle.BUY_RED
		if _borders.get(def.id, Color(0.0, 0.0, 0.0, 0.0)) != border:   # restyle only when the state changes
			_apply_border(card, border)
			_borders[def.id] = border
		card.modulate = Color(1.0, 1.0, 1.0, 1.0) if used else Color(1.0, 1.0, 1.0, 0.5)
		(_prices[def.id] as Label).text = "%s %s" % [NumberFormat.format(price), unit] if used else "Locked"
		(_counts[def.id] as Label).text = ("%d of %d left this %s" % [left, def.cap_per_reset, currency]) if used else "Opens after your first %s" % currency
		(_counts[def.id] as Label).add_theme_color_override("font_color", border if left <= 0 or not used else RelicStyle.dim)
		(_prices[def.id] as Label).add_theme_color_override("font_color", border if used else RelicStyle.dim)


## True when a pull can happen right now: the reset is used, pulls are left, the currency covers the price and the pool has a relic.
func _can_open(def: SealedPullDef) -> bool:
	var sim: Sim = GameState.sim
	var reset_def: ZoneResetDef = sim.reset_defs.get(def.reset_id) as ZoneResetDef
	if reset_def == null or sim.reset_count(def.reset_id) <= 0 or sim.sealed.remaining(def) <= 0:
		return false
	if sim.get_stat(reset_def.currency).lt(sim.sealed.cost(def)):
		return false
	return not sim.sealed.pool(sim.relics, def.min_rank).is_empty()


func _currency_name(reset_id: StringName) -> String:
	var sim: Sim = GameState.sim
	var r: ZoneResetDef = sim.reset_defs.get(reset_id) as ZoneResetDef
	if r == null:
		return ""
	var stat: StatDef = sim.stat_defs.get(r.currency) as StatDef
	return stat.display_name if stat != null else String(r.currency).capitalize()


func _apply_border(card: Button, c: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		sb.set_border_width_all(1)
		sb.border_color = c.lightened(0.25) if state == "hover" or state == "focus" else c
		sb.set_content_margin_all(4)
		card.add_theme_stylebox_override(state, sb)


func _tip_for(id: StringName) -> Dictionary:
	var sealed: SealedPulls = _sealed()
	var def: SealedPullDef = sealed.def_of(id)
	var sim: Sim = GameState.sim
	var reset_def: ZoneResetDef = sim.reset_defs.get(def.reset_id) as ZoneResetDef
	var unit: String = _currency_name(def.reset_id)
	var used: bool = sim.reset_count(def.reset_id) > 0
	var left: int = sealed.remaining(def)
	var price: BigNum = sealed.cost(def)
	var lines: Array = [[Tip.seg(def.blurb, RelicStyle.dim)]]
	if not used:
		lines.append([Tip.seg("Opens after your first %s." % (reset_def.display_name if reset_def != null else "reset"), RelicStyle.dim)])
	else:
		lines.append([Tip.seg("Costs %s %s. %d of %d left this %s." % [NumberFormat.format(price), unit, left, def.cap_per_reset,
			reset_def.display_name if reset_def != null else "reset"], RelicStyle.dim)])
	var odds: Array = []
	var shares: Dictionary = sealed.odds(sim.relics, def.min_rank)
	var order: Array = shares.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return shares[a] > shares[b])
	for k: Variant in order:
		odds.append("%s %d%%" % [String(k).capitalize(), roundi(float(shares[k]) * 100.0)])
	if not odds.is_empty():
		lines.append([Tip.seg("Odds: " + ", ".join(PackedStringArray(odds)), RelicStyle.accent)])
	var spec: Dictionary = {"title": def.display_name, "lines": lines}
	if _can_open(def):
		spec["hint"] = PULL_HINT
	elif used and left > 0:
		spec["hint"] = "Costs more than you have."
	return spec


func _on_pressed(id: StringName) -> void:
	if GameState.sim == null:
		return
	var sim: Sim = GameState.sim
	var def: SealedPullDef = sim.sealed.def_of(id)
	if def == null or sim.reset_count(def.reset_id) <= 0:
		refresh()
		return
	var got: StringName = GameState.try_sealed_pull(id)
	refresh()
	if got == &"":
		return
	var relic: RelicDef = sim.relics.defs.get(got) as RelicDef
	if relic == null:
		return
	Tip.hide_all()
	SealedPullOverlay.open(get_tree(), def, relic, sim.relics.stacks_of(got))


func _on_changed_stat(_id: StringName, _v: BigNum) -> void:
	if is_visible_in_tree():
		refresh()


func _on_changed_any(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _on_changed_relic(_id: StringName, _n: int) -> void:
	refresh()
