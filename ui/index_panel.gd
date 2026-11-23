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
var _rows: Dictionary = {}     # row id -> IndexRow
var _key: String = ""
var _clock: float = 0.0
var _slide: float = 0.0
var _tween: Tween
var _closing: bool = false
var _t: float = 0.0   ## current wipe progress 0..1, so a reversed animation starts where the last one stopped


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
	var x_gap := Control.new()   # room for the close X floating in the corner
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
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
	_reveal.z_index = 1   # above the panel; it is a sibling, added in _ready, so nothing in the panel can cover it


func _exit_tree() -> void:
	if _reveal != null and _reveal.get_parent() != null and not _reveal.is_queued_for_deletion():
		_reveal.queue_free()


## What Main's I and O keys and the HUD buttons call: open the tab, or close if it is already the one showing.
func toggle_tab(t: int) -> void:
	if is_open() and tab == t:
		close_panel()
	else:
		open_tab(t)


## Debug: F7 slows the open and close animation 5x so the wipe can be checked by eye.
static var slow_mo: bool = false


## True while the wipe overlay is on screen, sized to the panel, and drawn above it.
func wipe_showing() -> bool:
	return _reveal.visible and _reveal.size.x > 0.0 and _reveal.size.y > 0.0 and _reveal.z_index > z_index


func bind(p_sim: Sim) -> void:
	sim = p_sim
	var host: Node = get_parent()
	if host != null and _reveal.get_parent() == null:
		host.add_child(_reveal)


## True while the window is on screen and not on its way out.
func is_open() -> bool:
	return visible and not _closing


func open_tab(t: int) -> void:
	if sim == null:
		return
	var was_open: bool = is_open()
	if not visible:
		_t = 0.0   # a hidden window always opens from the start of the wipe
	tab = clampi(t, 0, 1)
	_key = ""
	_refresh(true)
	_sync_tabs()
	if was_open:
		_focus_first_row()
		return
	_closing = false
	visible = true
	reset_size()
	_layout()
	_animate(true)
	_focus_first_row()


func set_tab(t: int) -> void:
	if t == tab:
		_sync_tabs()
		return
	tab = t
	_key = ""
	Tip.hide_all()
	_refresh(true)
	_sync_tabs()
	_play_icon()
	_focus_first_row()


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
	_t = 0.0
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
	var from: float = _t
	_set_t(from)   # cover now, so the first drawn frame is already wiping, not opaque
	var to: float = 1.0 if opening else 0.0
	var full: float = OPEN_TIME if opening else CLOSE_TIME
	var dur: float = maxf(0.01, full * absf(to - from))   # only the distance left, so a reversal never replays the whole wipe
	_tween = create_tween()
	_tween.set_speed_scale(0.2 if slow_mo else 1.0)
	_tween.tween_method(_set_t, from, to, dur)
	if not opening:
		_tween.tween_callback(_finish_close)


## t 0 = hidden (inked, low), 1 = shown. Both effects step, so they read as pixel art.
func _set_t(t: float) -> void:
	_t = t
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
	_sub.text = "Prestige to spend: %s" % sim.prestige_available().format() if tab == Tab.ATTRIBUTES else ""


func _rebuild(rows: Array[Dictionary], key: String) -> void:
	var keep: StringName = &""
	var owner_ctl: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_ctl is IndexRow:
		keep = (owner_ctl as IndexRow).data.get("id", &"")
	_key = key
	_rows.clear()
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
		Tip.bind_all(row, func() -> Variant: return TipText.index_row(row.data))
		_list.add_child(row)
		_rows[r["id"]] = row
	var tail := Control.new()   # keeps the last row clear of the scroll edge
	tail.custom_minimum_size = Vector2(1, 6)
	_list.add_child(tail)
	if keep != &"" and _rows.has(keep) and is_open():
		_grab.call_deferred(_rows[keep] as IndexRow)


func _grab(row: IndexRow, quiet: bool = false) -> void:
	if is_instance_valid(row) and row.is_inside_tree() and is_open():
		if quiet:
			Tip.grab_quiet(row)
		else:
			row.grab_focus()


func _focus_first_row() -> void:
	if _list.get_child_count() == 0:
		return
	for c in _list.get_children():
		if c is IndexRow:
			_grab.call_deferred(c as IndexRow, true)
			return


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
	_reveal.size = size.max(get_combined_minimum_size())


func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7 and visible:
		slow_mo = not slow_mo
		get_viewport().set_input_as_handled()
		return
	if not is_open() or event.is_echo():
		return
	if event.is_action_pressed(&"plinky_tab_prev"):
		set_tab(maxi(tab - 1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_tab_next"):
		set_tab(mini(tab + 1, 1))
		get_viewport().set_input_as_handled()
