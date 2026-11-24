class_name UpgradeGallery
extends VBoxContainer
## The body of the Upgrades menu: one tab per gift group (Bloom Gifts, Nucleus Gifts, and Prestige or Rebirth Perks when
## they show). Each tab is a list of tiers, open from the start and then after each reset or Rebirth count, and each tier is
## a grid of GiftCards. The current zone's tab opens first every time the menu opens.
##
## Pages and cards are built the first time their tab opens, so the node budget only pays for what is on screen. Tabs are
## made from UpgradeText.currencies(), so a new zone reset gets its own tab without this file changing.

signal buy_pressed(attr_id: StringName)

const COLUMNS: int = 3
const SEP: int = 4
const LIST_HEIGHT: float = 216.0   ## about three rows of cards; the rest scrolls

var _sim: Sim
var _badges: Dictionary = {}     ## currency -> the header badge (HUD); shown only while its group shows
var _tab_btns: Dictionary = {}   ## currency -> the tab Button
var _pages: Dictionary = {}      ## currency -> its page, built on first open of the tab
var _cards: Dictionary = {}      ## attribute id -> GiftCard, built with its page
var _specs: Dictionary = {}      ## attribute id -> tooltip spec Callable
var _selected: StringName = &""
var _tab_row: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer


## `badges` is the HUD's currency badge map; a card's cost flies toward its currency's badge.
func setup(p_sim: Sim, badges: Dictionary) -> void:
	_sim = p_sim
	_badges = badges
	add_theme_constant_override("separation", 6)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 4)
	add_child(_tab_row)
	for c: StringName in UpgradeText.currencies(_sim):
		var b := Button.new()
		b.toggle_mode = true
		b.text = UpgradeText.tab_title(_sim, c)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
		b.add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
		b.add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.SELECT, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
		b.add_theme_stylebox_override("hover_pressed", AsciiBox.make(AsciiBox.Kind.SELECT, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_pressed_color", RelicStyle.accent)
		b.add_theme_color_override("font_hover_pressed_color", RelicStyle.accent)
		b.pressed.connect(_on_tab.bind(c))
		_tab_row.add_child(b)
		_tab_btns[c] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_scroll.follow_focus = true
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	_scroll.add_child(_body)
	var hint := Label.new()
	hint.text = "Click a gift to buy it. Hold to keep buying."
	hint.add_theme_color_override("font_color", RelicStyle.soft())
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


## The menu opened: pick the current zone's tab and bring every card up to date.
func open() -> void:
	_select(UpgradeText.default_tab(_sim, UpgradeText.tabs(_sim)))
	refresh()


## Every tick while the menu is open: tab visibility and labels, then each built card from the sim.
func refresh() -> void:
	if _sim == null:
		return
	var shown: Array[StringName] = UpgradeText.tabs(_sim)
	var states: Dictionary = {}
	for a: AttributeDef in _sim.attribute_defs.values():
		states[a.id] = UpgradeText.state(_sim, a)
	for c: StringName in _tab_btns:
		var b: Button = _tab_btns[c] as Button
		var on: bool = shown.has(c)
		b.visible = on
		if on:
			var n: int = _ready_count(c, states)
			var label: String = UpgradeText.tab_title(_sim, c)
			if n > 0:
				label += " (%d)" % n   # gifts you can buy right now
			if b.text != label:
				b.text = label
	if not shown.has(_selected):
		_select(UpgradeText.default_tab(_sim, shown))
	for aid: StringName in _cards:
		(_cards[aid] as GiftCard).refresh(states[aid] as Dictionary)


## A buy went through: the card plays its animation and the header badge pops.
func played_buy(aid: StringName) -> void:
	var card: GiftCard = _cards.get(aid) as GiftCard
	if card == null:
		return
	var a: AttributeDef = _sim.attribute_defs[aid] as AttributeDef
	card.play_buy(UpgradeText.state(_sim, a))
	# A tooltip already showing (the pointer is on the card) must pick up the new level.
	if _specs.has(aid):
		Tip.set_spec(card, _specs[aid])
	var badge: Control = _badges.get(a.currency) as Control
	if badge != null and not GiftCard.calm():
		badge.pivot_offset = badge.size * 0.5
		badge.scale = Vector2(1.18, 1.18)
		var t := create_tween()
		t.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_tab(c: StringName) -> void:
	_select(c)
	var tree: SceneTree = get_tree()
	var au: Node = tree.root.get_node_or_null("Audio") if tree != null else null
	if au != null:
		au.call("play", &"ui_click", 1.1, -10.0, &"UI", false)


func _select(c: StringName) -> void:
	if c == &"":
		return
	_selected = c
	if not _pages.has(c):
		var page: VBoxContainer = _build_page(c)
		_body.add_child(page)
		_pages[c] = page
	for k: StringName in _pages:
		(_pages[k] as Control).visible = k == c
	for k2: StringName in _tab_btns:
		(_tab_btns[k2] as Button).button_pressed = k2 == c
	_scroll.scroll_vertical = 0


## Tiers of one group, each a heading and a grid of cards. attribute_defs come from UpgradeText.ordered(), so each tier's
## cards keep the menu order and the tiers come out lowest first.
func _build_page(c: StringName) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	var grids: Dictionary = {}   ## tier -> GridContainer
	for a: AttributeDef in UpgradeText.ordered(_sim):
		if a.currency != c:
			continue
		var tier: int = UpgradeText.tier_of(a)
		if not grids.has(tier):
			var head := Label.new()
			head.text = UpgradeText.tier_title(_sim, c, tier)
			head.add_theme_color_override("font_color", StatStyle.color(c))
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.add_child(head)
			var grid := GridContainer.new()
			grid.columns = COLUMNS
			grid.add_theme_constant_override("h_separation", SEP)
			grid.add_theme_constant_override("v_separation", SEP)
			page.add_child(grid)
			grids[tier] = grid
		var card := GiftCard.new()
		(grids[tier] as GridContainer).add_child(card)
		card.setup(a)
		card.fly_target = func() -> Vector2: return (_badges[c] as Control).global_position + Vector2(18.0, 0.0)
		card.buy_pressed.connect(_forward)
		var eff: StringName = a.effect
		var spec: Callable = func() -> Variant: return UpgradeText.tip(card.state(), eff)
		Tip.bind_all(card, spec)
		_specs[a.id] = spec
		_cards[a.id] = card
		card.refresh(UpgradeText.state(_sim, a))
	return page


func _forward(aid: StringName) -> void:
	buy_pressed.emit(aid)


## How many gifts in a group you can buy right now (unlocked, not maxed, affordable).
func _ready_count(c: StringName, states: Dictionary) -> int:
	var n: int = 0
	for a: AttributeDef in _sim.attribute_defs.values():
		if a.currency != c:
			continue
		var s: Dictionary = states[a.id] as Dictionary
		if bool(s["unlocked"]) and not bool(s["maxed"]) and bool(s["can_afford"]):
			n += 1
	return n
