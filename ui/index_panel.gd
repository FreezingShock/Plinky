class_name IndexPanel
extends PanelContainer
## The Stats and Attributes index: one themed window, two tabs, a scrolling list of rows with icons and tooltips.
## Opens and closes with a stepped dither wipe and a short slide; the header icon plays a 4 frame loop on open.
## Read only: it shows StatIndex rows and never changes the Sim. Keyboard and pad walk the rows (arrows, d-pad),
## shoulder buttons or the tab buttons switch tab, Esc or pad B closes (handled by Main).

signal closed

enum Tab { STATS, ATTRIBUTES }

const WIDTH: float = 326.0
const SCROLL_H: float = 150.0
const SLIDE: float = 14.0
const OPEN_TIME: float = 0.42
const CLOSE_TIME: float = 0.28
const REFRESH: float = 0.1
const TITLES: Array[String] = ["Stats", "Attributes"]
const SHEETS: Array[String] = ["stats_menu", "attrs_menu"]

var tab: int = Tab.STATS
var sim: Sim
var _icon: TextureRect
var _icon_sheet: Texture2D
var _title: Label
var _sub: Label
var _tabs: Array[PixelButton] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _hint: Label
var _reveal: DitherReveal
var _tip: RelicTooltip
var _tip_row: IndexRow
var _rows: Dictionary = {}     # row id -> IndexRow
var _key: String = ""
var _clock: float = 0.0
var _slide: float = 0.0
var _tween: Tween
var _closing: bool = false


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
		bar.add_child(b)
		_tabs.append(b)
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
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = WIDTH
	v.add_child(_hint)
	_reveal = DitherReveal.new()
	_reveal.top_level = true
	add_child(_reveal)
	_tip = RelicTooltip.new()
	_tip.top_level = true
	add_child(_tip)


func bind(p_sim: Sim) -> void:
	sim = p_sim


## True while the window is on screen and not on its way out.
func is_open() -> bool:
	return visible and not _closing


func open_tab(t: int) -> void:
	if sim == null:
		return
	var was_open: bool = is_open()
	tab = clampi(t, 0, 1)
	_key = ""
	_refresh(true)
	_sync_tabs()
	if was_open:
		_focus_first_row()
		return
	_closing = false
	visible = true
	_layout()
	_animate(true)
	_focus_first_row()


func set_tab(t: int) -> void:
	if t == tab:
		_sync_tabs()
		return
	tab = t
	_key = ""
	_tip.hide_tip()
	_refresh(true)
	_sync_tabs()
	_play_icon()
	_focus_first_row()


func close_panel() -> void:
	if not visible or _closing:
		return
	_closing = true
	_tip.hide_tip()
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
	_tween = create_tween()
	var from: float = 0.0 if opening else 1.0
	var to: float = 1.0 if opening else 0.0
	_tween.tween_method(_set_t, from, to, OPEN_TIME if opening else CLOSE_TIME)
	if not opening:
		_tween.tween_callback(_finish_close)


## t 0 = hidden (inked, low), 1 = shown. Both effects step, so they read as pixel art.
func _set_t(t: float) -> void:
	var s: float = floorf(t * DitherReveal.STEPS) / DitherReveal.STEPS
	_slide = roundf((1.0 - s) * SLIDE)
	_reveal.set_cover(1.0 - s)


func _play_icon() -> void:
	var sheet_path: String = "res://assets/icons/%s_sheet.png" % SHEETS[tab]
	_icon_sheet = load(sheet_path) as Texture2D
	_set_frame(0)
	if FxConfig.reduce_flashing:
		return
	var t := create_tween()
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
	_hint.text = "Hover or focus a row for details. Shoulder buttons switch tab." if tab == Tab.STATS \
		else "Spend Prestige in Upgrades [%s]. This list is read only." % Keybinds.key_name(&"upgrades")


func _data() -> Array[Dictionary]:
	return StatIndex.stats(sim) if tab == Tab.STATS else StatIndex.attributes(sim)


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
			(_rows[r["id"]] as IndexRow).set_data(r)
		_refresh_tip()
	_sub.text = "Prestige to spend: %s" % sim.prestige_available().format() if tab == Tab.ATTRIBUTES else ""


func _rebuild(rows: Array[Dictionary], key: String) -> void:
	var keep: StringName = &""
	var owner_ctl: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_ctl is IndexRow:
		keep = (owner_ctl as IndexRow).data.get("id", &"")
	_key = key
	_rows.clear()
	_tip_row = null
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var group: String = ""
	for r: Dictionary in rows:
		if r["group"] != group:
			group = r["group"]
			var h := Label.new()
			h.text = group.to_upper()
			h.add_theme_color_override("font_color", RelicStyle.accent)
			_list.add_child(h)
		var row := IndexRow.new(WIDTH - 12.0)
		row.set_data(r)
		row.mouse_entered.connect(_on_row_tip.bind(row))
		row.focus_entered.connect(_on_row_tip.bind(row))
		row.mouse_exited.connect(_on_row_untip.bind(row))
		row.focus_exited.connect(_on_row_untip.bind(row))
		_list.add_child(row)
		_rows[r["id"]] = row
	var tail := Control.new()   # keeps the last row clear of the scroll edge
	tail.custom_minimum_size = Vector2(1, 6)
	_list.add_child(tail)
	if keep != &"" and _rows.has(keep) and is_open():
		(_rows[keep] as IndexRow).call_deferred("grab_focus")


func _focus_first_row() -> void:
	if _list.get_child_count() == 0:
		return
	for c in _list.get_children():
		if c is IndexRow:
			(c as IndexRow).call_deferred("grab_focus")
			return


func _on_row_tip(row: IndexRow) -> void:
	_tip_row = row
	_refresh_tip()


func _on_row_untip(row: IndexRow) -> void:
	if _tip_row == row:
		_tip_row = null
		_tip.hide_tip()


var _tip_text: String = ""

func _refresh_tip() -> void:
	if _tip_row == null or not is_instance_valid(_tip_row):
		return
	var d: Dictionary = _tip_row.data
	var body: String = String(d["tip"])
	if _tip_text == body and _tip.visible:
		return
	_tip_text = body
	_tip.show_text(String(d["name"]), body, Rect2(global_position.x, _tip_row.global_position.y, size.x, _tip_row.size.y))


# ---------------------------------------------------------------- frame

func _layout() -> void:
	var host: Control = get_parent_control()
	if host == null:
		return
	var avail: float = host.size.y - 150.0
	var h: float = clampf(avail, 64.0, SCROLL_H)
	if _scroll.custom_minimum_size.y != h:
		_scroll.custom_minimum_size.y = h
		reset_size()
	position = ((host.size - size) * 0.5).floor() + Vector2(0.0, _slide)
	_reveal.global_position = global_position
	_reveal.size = size


func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		_refresh()


func _input(event: InputEvent) -> void:
	if not is_open() or event.is_echo():
		return
	if event.is_action_pressed(&"plinky_tab_prev"):
		set_tab(maxi(tab - 1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_tab_next"):
		set_tab(mini(tab + 1, 1))
		get_viewport().set_input_as_handled()
