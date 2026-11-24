class_name IndexPanel
extends PanelContainer
## The Stats and Attributes gallery. Two tabs of big icon cards in sections; hover or focus a card for its shared
## tooltip (TipText.index_row: level or amount, what it does now and next, its cost, a yellow "Click to open!"). Click
## it for a detail page with the total, what it does, and a gallery of its sources (where it comes from and how to get
## more). Pages change through a stepped dither wipe.
## Read only: it shows StatIndex and StatSources data and never changes the Sim. Arrows or the d-pad move between
## cards, Enter or pad A opens one, Esc or pad B goes back, then closes. Shoulder buttons switch tab.

signal closed

enum Tab { STATS, ATTRIBUTES }

const WIDTH: float = 404.0
const SCROLL_H: float = 200.0   ## the grid's height: the info strip under it is gone, so the grid shows more cards
const PAGE_OUT: float = 0.16
const PAGE_IN: float = 0.22
const REFRESH: float = 0.1
const TITLES: Array[String] = ["Stats", "Attributes"]
const SHEETS: Array[String] = ["stats_menu", "attrs_menu"]
const KIND_ICONS: Dictionary = {
	"base": "presses", "attribute": "attrs_menu", "relic": "relics/r_double", "mastery": "mastery",
	"prestige": "prestige", "zone": "walk", "action": "reb", "total": "clock",
}
const DTABS: Array[String] = ["About", "Sources", "Level"]
const DETAIL_H: float = 240.0

## Debug: F7 slows the open, close and page wipes 5x so they can be checked by eye.
static var slow_mo: bool = false

var tab: int = Tab.STATS
var sim: Sim
var detail_id: StringName = &""          ## the stat showing on the detail page, or &"" on the grid
var _icon: TextureRect
var _icon_sheet: Texture2D
var _title: Label
var _tabs: Array[PixelButton] = []
var _scroll: ScrollContainer
var _grid_box: VBoxContainer
var _detail_box: VBoxContainer
var _d_icon: TextureRect
var _d_name: Label
var _d_total: Label
var _d_buff: Label
var _d_tip: Label
var _d_bar: DitherBar
var _d_level: Label
var _d_head: PanelContainer
var _dtab: int = 0
var _dtabs: Array[PixelButton] = []
var _d_pages: Array[VBoxContainer] = []
var _buy: PixelButton
var _d_sources: HFlowContainer
var _back: PixelButton
var _anim: MenuAnim
var _cards: Dictionary = {}              # row id -> IndexCard
var _key: String = ""
var _clock: float = 0.0
var _busy: bool = false                  ## a page wipe is running
var _body: VBoxContainer                 ## the built contents, or null while the window is shut
var _page_tween: Tween                   ## the running page wipe
var _blink: Tween                        ## the total's blink after a buy
## Set by Main: buys the next level of an attribute (GameState.buy_attribute), so there is one purchase path.
var buyer: Callable = Callable()


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	# Only the frame exists while the window is shut. The body (header, tabs, cards, detail page) is built on open and
	# freed on hide, so the closed window holds no cards at boot.
	visibility_changed.connect(_on_visibility)


## Builds the body. Called by _ensure when the window opens, never at boot.
func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_body = v
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_icon)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	head.add_child(_title)
	var spacer := Control.new()   # pushes the close gap to the right edge of the header
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	var x_gap := Control.new()   # room for the close X floating in the corner
	x_gap.custom_minimum_size = Vector2(CloseX.HEADER_GAP, 1.0)
	head.add_child(x_gap)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	v.add_child(bar)
	for i in 2:
		var b := PixelButton.new()
		b.text = TITLES[i]
		b.icon = IconCache.texture("res://assets/icons/%s.png" % SHEETS[i])
		b.toggle_mode = true
		b.pressed.connect(set_tab.bind(i))
		Tip.bind(b, {"title": TITLES[i], "body": "Switch to the %s gallery." % TITLES[i].to_lower()})
		bar.add_child(b)
		_tabs.append(b)
	_back = PixelButton.new()
	_back.text = "< Back"
	_back.pressed.connect(back)
	_back.visible = false
	Tip.bind(_back, {"title": "Back", "body": "Return to the gallery."})
	bar.add_child(_back)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.custom_minimum_size = Vector2(WIDTH, SCROLL_H)
	v.add_child(_scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override("separation", 3)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid_box)
	_build_detail()
	_scroll.add_child(_detail_box)
	_detail_box.visible = false
	_icon_sheet = IconCache.texture("res://assets/icons/%s_sheet.png" % SHEETS[tab])
	_set_frame(0)


func _build_detail() -> void:
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Header: icon and name on the left (left-aligned), value and gain on the right (right-aligned), in a solid panel.
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 6.0, 4.0))
	_d_head = hp
	_detail_box.add_child(hp)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	hp.add_child(head)
	_d_icon = TextureRect.new()
	_d_icon.custom_minimum_size = Vector2(32, 32)
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_d_icon)
	_d_name = Label.new()
	_d_name.theme_type_variation = &"TitleLabel"
	_d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d_name.clip_text = true   # a long name never pushes the value out of the header
	_d_name.custom_minimum_size.x = 40
	head.add_child(_d_name)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # no gain line: the value sits centred against the icon
	head.add_child(right)
	_d_total = _right(right, RelicStyle.accent)
	_d_total.theme_type_variation = &"TitleLabel"
	_d_total.add_theme_font_size_override("font_size", 24)
	_d_total.custom_minimum_size.x = 56
	_d_buff = _right(right, RelicStyle.good)
	# Sub-tabs, so nothing is a long scroll: About / Sources / Level (Attributes only).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_detail_box.add_child(tabs)
	for k in 3:
		var b := PixelButton.new()
		b.text = DTABS[k]
		b.toggle_mode = true
		b.pressed.connect(_set_dtab.bind(k))
		tabs.add_child(b)
		_dtabs.append(b)
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 4)
		pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail_box.add_child(pg)
		_d_pages.append(pg)
	_d_tip = Label.new()
	_d_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_tip.custom_minimum_size.x = WIDTH - 12.0
	_d_tip.add_theme_color_override("font_color", RelicStyle.text)
	_d_pages[0].add_child(_d_tip)
	_d_sources = HFlowContainer.new()
	_d_sources.add_theme_constant_override("h_separation", 4)
	_d_sources.add_theme_constant_override("v_separation", 4)
	_d_pages[1].add_child(_d_sources)
	_d_bar = DitherBar.new(160.0)
	var bar_row := CenterContainer.new()
	bar_row.add_child(_d_bar)
	_d_pages[2].add_child(bar_row)
	_d_level = Label.new()
	_d_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_level.add_theme_color_override("font_color", RelicStyle.dim)
	_d_pages[2].add_child(_d_level)
	_buy = PixelButton.new()
	_buy.pressed.connect(_on_buy)
	Tip.bind(_buy, Callable(self, "_buy_spec"))
	var buy_row := CenterContainer.new()
	buy_row.add_child(_buy)
	_d_pages[2].add_child(buy_row)


## Tooltip of the Buy button: the next level's cost, and "Click to buy!" in yellow when the player can pay for it.
func _buy_spec() -> Variant:
	if sim == null or not detail_open() or tab != Tab.ATTRIBUTES or not sim.attribute_defs.has(detail_id):
		return null
	var ad: AttributeDef = sim.attribute_defs[detail_id] as AttributeDef
	var maxed: bool = sim.attr_level(detail_id) >= ad.cap
	var cost: BigNum = sim.attribute_cost(detail_id)
	var can: bool = not maxed and not sim.attribute_available(ad).lt(cost)
	return TipText.buy(String(ad.currency), UpgradeText.currency_name(ad), cost.format(), can, maxed)


func _right(parent: Node, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", c)
	parent.add_child(l)
	return l


## Show one sub-page of the detail view. The Level page only exists for attributes.
func _set_dtab(k: int) -> void:
	_dtab = k if (k < 2 or tab == Tab.ATTRIBUTES) else 0
	for n in 3:
		_d_pages[n].visible = n == _dtab
		_dtabs[n].set_pressed_no_signal(n == _dtab)
	_dtabs[2].visible = tab == Tab.ATTRIBUTES
	_scroll.scroll_vertical = 0


func _centered(parent: Node, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", c)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func bind(p_sim: Sim) -> void:
	sim = p_sim
	if _anim == null:
		_anim = MenuAnim.attach(self)   # the shared dither wipe + slide; its overlay is a sibling above the panel


## What Main's I and O keys and the HUD buttons call: open the tab, or close if it is already the one showing.
func toggle_tab(t: int) -> void:
	if is_open() and tab == t and detail_id == &"":
		close_panel()
	else:
		open_tab(t)


## True while the window is on screen and not on its way out.
func is_open() -> bool:
	return _anim != null and _anim.is_open()


func detail_open() -> bool:
	return detail_id != &""


func open_tab(t: int) -> void:
	if sim == null:
		return
	var was_open: bool = is_open()
	tab = clampi(t, 0, 1)
	_ensure()
	_show_grid_now()
	_sync_tabs()
	if was_open:
		_focus_first()
		return
	_anim.open()
	reset_size()
	_layout()
	_play_icon()
	_focus_first(true)


func set_tab(t: int) -> void:
	if _busy or (t == tab and detail_id == &""):
		_sync_tabs()
		return
	_page(func() -> void:
		tab = t
		_show_grid_now()
		_sync_tabs()
		_play_icon()
		_focus_first())


## Esc and pad B: leave the detail page, or close the window from the gallery. Returns true if it did either.
func back_or_close() -> bool:
	if not is_open():
		return false
	if detail_open():
		back()
	else:
		close_panel()
	return true


func back() -> void:
	if _busy or not detail_open():
		return
	_page(func() -> void:
		var came_from: StringName = detail_id
		_show_grid_now()
		if _cards.has(came_from):
			_grab.call_deferred(_cards[came_from] as IndexCard)
		else:
			_focus_first())


func open_detail(id: StringName) -> void:
	if _busy or not _cards.has(id):
		return
	var card: IndexCard = _cards[id]
	_page(func() -> void:
		_dtab = 0
		_fill_detail(card.data)
		detail_id = id
		_grid_box.visible = false
		_detail_box.visible = true
		_back.visible = true
		_scroll.scroll_vertical = 0
		_wire_focus()
		_grab.call_deferred(_back))


func close_panel() -> void:
	if _anim != null:
		_anim.close()


## Builds the body if it is not there yet.
func _ensure() -> void:
	if _body == null:
		_build()


## Shown: build the body if open_tab has not. Hidden (the close wipe is done): free it.
func _on_visibility() -> void:
	if not visible:
		_teardown()
	elif _body == null:
		_build()
		_show_grid_now()
		_sync_tabs()


## Frees the body and every node and reference in it, after tooltips are hidden and running tweens are stopped, so
## nothing points at a freed node. The tab is kept, so the next open starts on the same one.
func _teardown() -> void:
	Tip.hide_all()
	if _page_tween != null:
		_page_tween.kill()
	if _blink != null:
		_blink.kill()
	_busy = false
	_clock = 0.0
	detail_id = &""
	_key = ""
	if _body != null:
		remove_child(_body)
		_body.queue_free()
	_body = null
	_icon = null
	_title = null
	_tabs.clear()
	_scroll = null
	_grid_box = null
	_detail_box = null
	_d_icon = null
	_d_name = null
	_d_total = null
	_d_buff = null
	_d_tip = null
	_d_bar = null
	_d_level = null
	_d_head = null
	_dtabs.clear()
	_d_pages.clear()
	_buy = null
	_d_sources = null
	_back = null
	_cards.clear()


# ---------------------------------------------------------------- animation


## Run `swap` under a dither wipe: ink in, swap, ink out. Instant when flashing is reduced.
func _page(swap: Callable) -> void:
	Tip.hide_all()
	if FxConfig.reduce_flashing or not is_open():
		swap.call()
		return
	_busy = true
	_page_tween = create_tween()
	var t: Tween = _page_tween
	t.set_speed_scale(0.2 if slow_mo else 1.0)
	t.tween_method(_anim.reveal.set_cover, 0.0, 1.0, PAGE_OUT)
	t.tween_callback(swap)
	t.tween_method(_anim.reveal.set_cover, 1.0, 0.0, PAGE_IN)
	t.tween_callback(func() -> void: _busy = false)


func _play_icon() -> void:
	_icon_sheet = IconCache.texture("res://assets/icons/%s_sheet.png" % SHEETS[tab])
	_set_frame(0)
	if FxConfig.reduce_flashing:
		return
	var t := create_tween()
	t.set_speed_scale(0.2 if slow_mo else 1.0)
	t.tween_method(func(f: float) -> void: _set_frame(int(f) % 4), 0.0, 8.0, 0.6)
	t.tween_callback(_set_frame.bind(0))


func _set_frame(f: int) -> void:
	var a := AtlasTexture.new()
	a.atlas = _icon_sheet
	a.region = Rect2(f * 16, 0, 16, 16)
	_icon.texture = a


# ---------------------------------------------------------------- content

func _sync_tabs() -> void:
	for i in 2:
		_tabs[i].set_pressed_no_signal(i == tab)
	_title.text = TITLES[tab]
	_back.visible = detail_open()


func _data() -> Array[Dictionary]:
	return StatIndex.stats(sim) if tab == Tab.STATS else StatIndex.attributes(sim)


func _show_grid_now() -> void:
	detail_id = &""
	_detail_box.visible = false
	_grid_box.visible = true
	_back.visible = false
	_key = ""
	_refresh(true)


func _refresh(force: bool = false) -> void:
	if sim == null or _body == null:
		return
	var rows: Array[Dictionary] = _data()
	var key: String = str(tab)
	for r: Dictionary in rows:
		key += "|%s%s" % [r["id"], "p" if r["pending"] else ""]
	if force or key != _key:
		_rebuild(rows, key)
	else:
		for r: Dictionary in rows:
			(_cards[r["id"]] as IndexCard).set_data(r)
	if detail_open() and _cards.has(detail_id):
		_fill_detail((_cards[detail_id] as IndexCard).data)


func _rebuild(rows: Array[Dictionary], key: String) -> void:
	_key = key
	_cards.clear()
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	var group: String = ""
	var flow: HFlowContainer = null
	for r: Dictionary in rows:
		if r["group"] != group:
			group = r["group"]
			var h := Label.new()
			h.text = group.to_upper()
			var gc: StringName = StringName(String(r.get("group_color_id", "")))
			h.add_theme_color_override("font_color", StatStyle.color(gc) if gc != &"" else RelicStyle.accent)
			_grid_box.add_child(h)
			flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 3)
			flow.add_theme_constant_override("v_separation", 4)
			_grid_box.add_child(flow)
		var card := IndexCard.new()
		card.set_data(r)
		card.pressed.connect(open_detail.bind(r["id"]))
		flow.add_child(card)
		_cards[r["id"]] = card
	var tail := Control.new()   # keeps the last card clear of the scroll edge
	tail.custom_minimum_size = Vector2(1, 4)
	_grid_box.add_child(tail)
	_wire_focus()


func _fill_detail(d: Dictionary) -> void:
	_d_icon.texture = IndexCard.icon_for(String(d["icon"]))
	_d_name.text = String(d["name"])
	var sc: Color = StatStyle.color(StringName(d.get("color_id", d["id"])))
	_d_name.add_theme_color_override("font_color", sc)
	var hb: AsciiBox = AsciiBox.make(AsciiBox.Kind.PANEL, 6.0, 4.0)
	hb.edge_override = sc.darkened(0.2)   # the header frame wears the stat's colour
	_d_head.add_theme_stylebox_override("panel", hb)
	_d_total.text = String(d["value"])
	_d_buff.text = String(d["note"])
	_d_buff.visible = _d_buff.text != ""
	_d_tip.text = String(d["tip"])
	if d.has("cap"):
		_d_bar.value = float(d["level"]) / maxf(float(d["cap"]), 1.0)
		_d_level.text = "Level %d / %d" % [int(d["level"]), int(d["cap"])]
	if tab == Tab.ATTRIBUTES:
		var lv: int = int(d["level"])
		var maxed: bool = lv >= int(d["cap"])
		var cost: BigNum = sim.attribute_cost(d["id"])
		var ad: AttributeDef = sim.attribute_defs[d["id"]] as AttributeDef
		var ok: bool = not maxed and not sim.attribute_available(ad).lt(cost)
		_buy.text = "MAX" if maxed else "Buy  %s" % cost.format()
		_buy.disabled = not ok
		var col: Color = RelicStyle.good if ok else Color(0.86, 0.35, 0.3)
		for k: String in ["font_color", "font_hover_color", "font_disabled_color", "font_pressed_color", "font_focus_color"]:
			_buy.add_theme_color_override(k, col)
	for c in _d_sources.get_children():
		_d_sources.remove_child(c)
		c.queue_free()
	for s: Dictionary in sim.stat_sources(d["id"], tab == Tab.ATTRIBUTES):
		_d_sources.add_child(_source_card(s))
	Tip.set_spec(_buy, Callable(self, "_buy_spec"))   # the price changes after a buy; refreshes the tip if it is up
	_set_dtab(_dtab)


func _on_buy() -> void:
	if not buyer.is_valid() or not detail_open() or not bool(buyer.call(detail_id)):
		return
	_refresh()
	if FxConfig.reduce_flashing:
		return
	_blink = create_tween()    # blink the total: stepped, like the other HUD pops
	var t: Tween = _blink
	for i in 3:
		t.tween_property(_d_total, "modulate", Color(2.0, 2.0, 1.5), 0.0)
		t.tween_interval(0.08)
		t.tween_property(_d_total, "modulate", Color.WHITE, 0.0)
		t.tween_interval(0.08)


func _source_card(s: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.BUTTON, 4.0, 3.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = IndexCard.icon_for(String(KIND_ICONS.get(s["kind"], "presses")))
	ic.custom_minimum_size = Vector2(16, 16)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name_l := Label.new()
	name_l.text = String(s["source"])
	v.add_child(name_l)
	var amt := Label.new()
	amt.text = String(s["amount"])
	amt.add_theme_color_override("font_color", RelicStyle.good)
	v.add_child(amt)
	var how := Label.new()
	how.text = String(s["how_to"])
	how.add_theme_color_override("font_color", RelicStyle.dim)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 150
	v.add_child(how)
	p.custom_minimum_size.x = 188
	return p


## Pure: the item `step` places from item `i` of a focus ring of `n` items, wrapping at both ends (step is 1 or -1).
static func ring_step(n: int, i: int, step: int) -> int:
	return posmod(i + step, n)


## Tab walks the two tabs, then the gift cards (or the Back button on a detail page), and wraps at both ends, forward
## and back. Godot wraps Tab forward by itself but not Shift+Tab from the first control, so the ring is wired here.
## Called whenever the cards are rebuilt and when a detail page opens.
func _wire_focus() -> void:
	if not is_inside_tree() or _tabs.is_empty() or _grid_box == null:
		return
	var ring: Array[Control] = []
	for t: PixelButton in _tabs:
		ring.append(t)
	if detail_open():
		ring.append(_back)
	else:
		for card: IndexCard in _cards.values():
			ring.append(card)
	var n: int = ring.size()
	for i in n:
		var c: Control = ring[i]
		c.focus_next = c.get_path_to(ring[ring_step(n, i, 1)])
		c.focus_previous = c.get_path_to(ring[ring_step(n, i, -1)])


func _focus_first(quiet: bool = false) -> void:
	if detail_open():
		_grab.call_deferred(_back, quiet)
		return
	for card: IndexCard in _cards.values():
		_grab.call_deferred(card, quiet)
		return


func _grab(c: Control, quiet: bool = true) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree() and is_open():
		if quiet:
			Tip.grab_quiet(c)
		else:
			c.grab_focus()


# ---------------------------------------------------------------- frame

func _layout() -> void:
	var host: Control = get_parent_control()
	if host == null:
		return
	# The detail page can grow taller than the grid, which is capped at SCROLL_H.
	var detail: bool = detail_open()
	var h: float = clampf(host.size.y - 130.0, 56.0, DETAIL_H if detail else SCROLL_H)
	if _scroll.custom_minimum_size.y != h:
		_scroll.custom_minimum_size.y = h
		reset_size()


func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	_clock += delta
	if _clock >= REFRESH and not _busy:
		_clock = 0.0
		_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7 and visible:
		slow_mo = not slow_mo
		get_viewport().set_input_as_handled()
		return
	if not is_open() or event.is_echo():
		return
	if event.is_action_pressed(&"plinky_back") and detail_open():   # Esc or pad B steps back before Main closes the window
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_tab_prev"):
		set_tab(maxi(tab - 1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_tab_next"):
		set_tab(mini(tab + 1, 1))
		get_viewport().set_input_as_handled()
