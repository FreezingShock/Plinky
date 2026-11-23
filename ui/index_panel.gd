class_name IndexPanel
extends PanelContainer
## The Stats and Attributes gallery. Two tabs of big icon cards in sections; hover or focus a card for the amount, the
## buff and a hint in the info strip; click it for a detail page with the total, what it does, and a gallery of its
## sources (where it comes from and how to get more). Pages change through a stepped dither wipe.
## Read only: it shows StatIndex and StatSources data and never changes the Sim. Arrows or the d-pad move between
## cards, Enter or pad A opens one, Esc or pad B goes back, then closes. Shoulder buttons switch tab.

signal closed

enum Tab { STATS, ATTRIBUTES }

const WIDTH: float = 404.0
const SCROLL_H: float = 150.0
const SLIDE: float = 14.0
const OPEN_TIME: float = 0.42
const CLOSE_TIME: float = 0.28
const PAGE_OUT: float = 0.16
const PAGE_IN: float = 0.22
const REFRESH: float = 0.1
const TITLES: Array[String] = ["Stats", "Attributes"]
const SHEETS: Array[String] = ["stats_menu", "attrs_menu"]
const KIND_ICONS: Dictionary = {
	"base": "presses", "attribute": "attrs_menu", "relic": "relics/r_double", "mastery": "mastery",
	"prestige": "prestige", "zone": "walk", "action": "reb", "total": "clock",
}
const HINT: String = "Hover a card for details. Click it to see where it comes from."

## Debug: F7 slows the open, close and page wipes 5x so they can be checked by eye.
static var slow_mo: bool = false

var tab: int = Tab.STATS
var sim: Sim
var detail_id: StringName = &""          ## the stat showing on the detail page, or &"" on the grid
var _icon: TextureRect
var _icon_sheet: Texture2D
var _title: Label
var _sub: Label
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
var _buy: PixelButton
var _d_sources: HFlowContainer
var _back: PixelButton
var _strip: VBoxContainer
var _s_head: Label
var _s_buff: Label
var _s_tip: Label
var _reveal: DitherReveal
var _cards: Dictionary = {}              # row id -> IndexCard
var _key: String = ""
var _clock: float = 0.0
var _slide: float = 0.0
var _tween: Tween
var _closing: bool = false
var _busy: bool = false                  ## a page wipe is running
## Set by Main: buys the next level of an attribute (GameState.buy_attribute), so there is one purchase path.
var buyer: Callable = Callable()


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
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
	_sub = Label.new()
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sub.add_theme_color_override("font_color", RelicStyle.dim)
	head.add_child(_sub)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	v.add_child(bar)
	for i in 2:
		var b := PixelButton.new()
		b.text = TITLES[i]
		b.icon = load("res://assets/icons/%s.png" % SHEETS[i]) as Texture2D
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
	var close := PixelButton.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	close.pressed.connect(close_panel)
	bar.add_child(close)
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
	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 0)
	_strip.custom_minimum_size = Vector2(WIDTH, 40)
	v.add_child(_strip)
	_s_head = _strip_label(RelicStyle.text, false)
	_s_buff = _strip_label(RelicStyle.good, false)
	_s_tip = _strip_label(RelicStyle.dim, true)
	_reveal = DitherReveal.new()
	_reveal.z_index = 1   # above the panel; it is a sibling, added in bind, so nothing in the panel can cover it


func _strip_label(c: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	l.clip_text = not wrap
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
	_strip.add_child(l)
	return l


func _build_detail() -> void:
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 3)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 1)
	_detail_box.add_child(top)
	_d_icon = TextureRect.new()
	_d_icon.custom_minimum_size = Vector2(64, 64)
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_d_icon)
	_d_name = _centered(top, RelicStyle.dim)
	_d_total = _centered(top, RelicStyle.accent)
	_d_total.theme_type_variation = &"TitleLabel"
	_d_total.add_theme_font_size_override("font_size", 32)
	_d_buff = _centered(top, RelicStyle.good)
	_d_tip = _centered(top, RelicStyle.dim)
	_d_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_tip.custom_minimum_size.x = WIDTH - 24.0
	var bar_row := CenterContainer.new()
	top.add_child(bar_row)
	_d_bar = DitherBar.new(160.0)
	bar_row.add_child(_d_bar)
	_buy = PixelButton.new()
	_buy.pressed.connect(_on_buy)
	Tip.bind(_buy, {"title": "Buy level", "body": "Spend Prestige on the next level."})
	var buy_row := CenterContainer.new()
	buy_row.add_child(_buy)
	top.add_child(buy_row)
	var cap := Label.new()
	cap.text = "SOURCES"
	cap.add_theme_color_override("font_color", RelicStyle.accent)
	_detail_box.add_child(cap)
	_d_sources = HFlowContainer.new()
	_d_sources.add_theme_constant_override("h_separation", 4)
	_d_sources.add_theme_constant_override("v_separation", 4)
	_detail_box.add_child(_d_sources)


func _centered(parent: Node, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", c)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func bind(p_sim: Sim) -> void:
	sim = p_sim
	var host: Node = get_parent()
	if host != null and _reveal.get_parent() == null:
		host.add_child(_reveal)


func _exit_tree() -> void:
	if _reveal != null and _reveal.get_parent() != null and not _reveal.is_queued_for_deletion():
		_reveal.queue_free()


## What Main's I and O keys and the HUD buttons call: open the tab, or close if it is already the one showing.
func toggle_tab(t: int) -> void:
	if is_open() and tab == t and detail_id == &"":
		close_panel()
	else:
		open_tab(t)


## True while the window is on screen and not on its way out.
func is_open() -> bool:
	return visible and not _closing


func detail_open() -> bool:
	return detail_id != &""


## True while the wipe overlay is on screen, sized to the panel, and drawn above it.
func wipe_showing() -> bool:
	return _reveal.visible and _reveal.size.x > 0.0 and _reveal.size.y > 0.0 and _reveal.z_index > z_index


func open_tab(t: int) -> void:
	if sim == null:
		return
	var was_open: bool = is_open()
	tab = clampi(t, 0, 1)
	_show_grid_now()
	_sync_tabs()
	if was_open:
		_focus_first()
		return
	_closing = false
	visible = true
	reset_size()
	_layout()
	_animate(true)
	_focus_first()


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
		_fill_detail(card.data)
		detail_id = id
		_grid_box.visible = false
		_detail_box.visible = true
		_back.visible = true
		_scroll.scroll_vertical = 0
		_strip_idle()
		_grab.call_deferred(_back))


func close_panel() -> void:
	if not visible or _closing:
		return
	_closing = true
	Tip.hide_all()
	if FxConfig.reduce_flashing:
		_finish_close()
		return
	_animate(false)


func _finish_close() -> void:
	_closing = false
	visible = false
	_reveal.set_cover(0.0)
	_slide = 0.0
	closed.emit()


# ---------------------------------------------------------------- animation

func _animate(opening: bool) -> void:
	if _tween != null:
		_tween.kill()
	_play_icon()
	if FxConfig.reduce_flashing:
		_set_t(1.0)
		return
	_set_t(0.0 if opening else 1.0)   # cover now, so the first drawn frame is already wiping, not opaque
	_tween = create_tween()
	_tween.set_speed_scale(0.2 if slow_mo else 1.0)
	_tween.tween_method(_set_t, 0.0 if opening else 1.0, 1.0 if opening else 0.0, OPEN_TIME if opening else CLOSE_TIME)
	if not opening:
		_tween.tween_callback(_finish_close)


## t 0 = hidden (inked, low), 1 = shown. Both effects step, so they read as pixel art.
func _set_t(t: float) -> void:
	var s: float = floorf(t * DitherReveal.STEPS) / DitherReveal.STEPS
	_slide = roundf((1.0 - s) * SLIDE)
	_reveal.set_cover(1.0 - s)


## Run `swap` under a dither wipe: ink in, swap, ink out. Instant when flashing is reduced.
func _page(swap: Callable) -> void:
	Tip.hide_all()
	if FxConfig.reduce_flashing or not is_open():
		swap.call()
		return
	_busy = true
	var t := create_tween()
	t.set_speed_scale(0.2 if slow_mo else 1.0)
	t.tween_method(_reveal.set_cover, 0.0, 1.0, PAGE_OUT)
	t.tween_callback(swap)
	t.tween_method(_reveal.set_cover, 1.0, 0.0, PAGE_IN)
	t.tween_callback(func() -> void: _busy = false)


func _play_icon() -> void:
	_icon_sheet = load("res://assets/icons/%s_sheet.png" % SHEETS[tab]) as Texture2D
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
	_strip_idle()


func _refresh(force: bool = false) -> void:
	if sim == null:
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
	_sub.text = "Prestige to spend: %s" % sim.prestige_available().format() if tab == Tab.ATTRIBUTES else ""


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
			h.add_theme_color_override("font_color", RelicStyle.accent)
			_grid_box.add_child(h)
			flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 4)
			flow.add_theme_constant_override("v_separation", 4)
			_grid_box.add_child(flow)
		var card := IndexCard.new()
		card.set_data(r)
		card.mouse_entered.connect(_preview.bind(card))
		card.focus_entered.connect(_preview.bind(card))
		card.mouse_exited.connect(_strip_idle)
		card.pressed.connect(open_detail.bind(r["id"]))
		flow.add_child(card)
		_cards[r["id"]] = card
	var tail := Control.new()   # keeps the last card clear of the scroll edge
	tail.custom_minimum_size = Vector2(1, 4)
	_grid_box.add_child(tail)


func _preview(card: IndexCard) -> void:
	var d: Dictionary = card.data
	_s_head.text = "%s   %s" % [d["name"], d["value"]]
	_s_buff.text = String(d["note"]) if String(d["note"]) != "" else " "
	_s_tip.text = String(d["tip"]).split("\n")[0]


func _strip_idle() -> void:
	_s_head.text = HINT
	_s_buff.text = " "
	_s_tip.text = ""


func _fill_detail(d: Dictionary) -> void:
	_d_icon.texture = IndexCard.icon_for(String(d["icon"]))
	_d_name.text = String(d["name"]).to_upper()
	_d_total.text = String(d["value"])
	_d_buff.text = String(d["note"]) if String(d["note"]) != "" else " "
	_d_tip.text = String(d["tip"])
	_d_bar.visible = d.has("cap")
	if d.has("cap"):
		_d_bar.value = float(d["level"]) / maxf(float(d["cap"]), 1.0)
	_buy.get_parent().visible = tab == Tab.ATTRIBUTES
	if tab == Tab.ATTRIBUTES:
		var lv: int = int(d["level"])
		var maxed: bool = lv >= int(d["cap"])
		var cost: BigNum = sim.attribute_cost(d["id"])
		var ok: bool = not maxed and not sim.prestige_available().lt(cost)
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


func _on_buy() -> void:
	if not buyer.is_valid() or not detail_open() or not bool(buyer.call(detail_id)):
		return
	_refresh()
	if FxConfig.reduce_flashing:
		return
	var t := create_tween()    # blink the total: stepped, like the other HUD pops
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


func _focus_first() -> void:
	if detail_open():
		_grab.call_deferred(_back)
		return
	for card: IndexCard in _cards.values():
		_grab.call_deferred(card)
		return


func _grab(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree() and is_open():
		c.grab_focus()


# ---------------------------------------------------------------- frame

func _layout() -> void:
	var host: Control = get_parent_control()
	if host == null:
		return
	var avail: float = host.size.y - 170.0
	var h: float = clampf(avail, 56.0, SCROLL_H)
	if _scroll.custom_minimum_size.y != h:
		_scroll.custom_minimum_size.y = h
		reset_size()
	position = ((host.size - size) * 0.5).floor() + Vector2(0.0, _slide)
	_reveal.global_position = global_position
	_reveal.size = size.max(get_combined_minimum_size())


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
