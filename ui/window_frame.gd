class_name WindowFrame
extends Control
## The game's own window chrome for windowed mode: a 12 px title bar (drag, double-click to maximise,
## minimise / maximise / close), resize handles on every edge and corner, and the dither wipe that plays
## when switching between windowed and fullscreen. Fullscreen, or the native-frame setting, shows none of it.
## Window behaviour goes through DisplayServer's interactive drag and resize, so it works on Windows and macOS.
## Colours come from RelicStyle, so the bar follows the zone palette.

const BAR_H: int = 12
const BTN_W: int = 14
const EDGE: int = 5      ## window pixels (not texels): the resize band on each side
const CORNER: int = 12   ## window pixels: the square at each corner that resizes both axes
const WIPE_STEPS: float = 8.0
const WIPE_OUT: float = 0.28
const WIPE_IN: float = 0.34

const WIPE_SHADER: String = """
shader_type canvas_item;
uniform float progress = 0.0;
uniform vec4 ink : source_color = vec4(0.08, 0.09, 0.11, 1.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	float b = (BAYER[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
	float sweep = (UV.x + UV.y) * 0.5;
	float cover = clamp(progress * 1.6 - sweep * 0.6, 0.0, 1.0);
	COLOR = vec4(ink.rgb, cover > b ? 1.0 : 0.0);
}
"""

var _win: Window
var _bar: TitleBar
var _wipe_layer: CanvasLayer
var _wipe: ColorRect
var _queue: SwitchQueue = SwitchQueue.new()
var _busy_since: int = 0
var _bar_key: String = ""
var _cursor_set: bool = false

signal inset_changed


func bind(win: Window) -> void:
	_win = win
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = TitleBar.new()
	_bar.win = win
	_bar.top_level = true  # sits at the very top of the view, above the HUD frame
	_bar.visible = false
	add_child(_bar)

	_wipe_layer = CanvasLayer.new()
	_wipe_layer.layer = 128
	add_child(_wipe_layer)
	_wipe = ColorRect.new()
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = WIPE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_wipe.material = mat
	_wipe.visible = false
	_wipe_layer.add_child(_wipe)

	DisplaySettings.animator = Callable(self, "_play_switch")
	_sync()


## Height of the title bar in texels while it is showing, else 0. Main shrinks the HUD frame by this.
func inset() -> float:
	return float(BAR_H) if DisplaySettings.custom_frame_active() else 0.0


func _sync() -> void:
	var want: bool = DisplaySettings.custom_frame_active()
	var vis: Vector2 = get_viewport_rect().size
	if _bar.visible != want:
		_bar.visible = want
		inset_changed.emit()
	if want:
		_bar.position = Vector2.ZERO
		var key: String = "%d|%d|%s" % [int(vis.x), _win.mode, RelicStyle.edge.to_html()]
		if key != _bar_key:  # redraw only when width, maximised state or palette change
			_bar_key = key
			_bar.size = Vector2(vis.x, BAR_H)
			_bar.queue_redraw()


var _clock_acc: float = 1.0


## Day count and in-game time in the middle of the bar, from the Calendar autoload; redrawn only when the text changes.
func _sync_clock(delta: float) -> void:
	_clock_acc += delta
	if _clock_acc < 0.25 or _bar == null or not _bar.visible:
		return
	_clock_acc = 0.0
	var cal: Node = get_tree().root.get_node_or_null("Calendar")
	if cal == null:
		return
	var n: Dictionary = cal.call("now")
	if n.is_empty():
		return
	_bar.set_clock("Day %d" % int(n["total_day"]), String(n["clock_text"]))


func _process(_delta: float) -> void:
	_sync()
	_sync_clock(_delta)
	# Watchdog: a switch that has not finished in 3 s (window manager hiccup) must never leave the screen covered.
	if _queue.busy and Time.get_ticks_msec() - _busy_since > 3000:
		_queue.reset()
		_wipe.visible = false
	_update_resize_cursor()


# --- Resize edges -----------------------------------------------------------------------------------------

## Resize band thickness in window pixels: at least EDGE, and never thinner than one texel of the scaled
## view, so it stays grabbable on 4K and on HiDPI screens.
func _band() -> int:
	var vis_h: float = maxf(1.0, get_viewport_rect().size.y)
	var texel: float = float(_win.size.y) / vis_h
	var dpi: float = maxf(1.0, DisplayServer.screen_get_scale(_win.current_screen))
	return maxi(int(ceilf(EDGE * dpi)), int(roundf(texel)))


func _edge_at(p: Vector2i) -> int:
	if not _resizable():
		return -1
	var band: int = _band()
	return edge_at(p, _win.size, band, int(band * CORNER / EDGE))


## The edge or corner at window pixel `p` in a window of size `s`, as a DisplayServer.WindowResizeEdge, or -1.
static func edge_at(p: Vector2i, s: Vector2i, band: int, corner: int) -> int:
	if p.x < 0 or p.y < 0 or p.x >= s.x or p.y >= s.y:
		return -1
	var left: bool = p.x < band
	var right: bool = p.x >= s.x - band
	var top: bool = p.y < band
	var bottom: bool = p.y >= s.y - band
	var near_x_l: bool = p.x < corner
	var near_x_r: bool = p.x >= s.x - corner
	var near_y_t: bool = p.y < corner
	var near_y_b: bool = p.y >= s.y - corner
	if (left and near_y_t) or (top and near_x_l):
		return DisplayServer.WINDOW_EDGE_TOP_LEFT
	if (right and near_y_t) or (top and near_x_r):
		return DisplayServer.WINDOW_EDGE_TOP_RIGHT
	if (left and near_y_b) or (bottom and near_x_l):
		return DisplayServer.WINDOW_EDGE_BOTTOM_LEFT
	if (right and near_y_b) or (bottom and near_x_r):
		return DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT
	if left:
		return DisplayServer.WINDOW_EDGE_LEFT
	if right:
		return DisplayServer.WINDOW_EDGE_RIGHT
	if top:
		return DisplayServer.WINDOW_EDGE_TOP
	if bottom:
		return DisplayServer.WINDOW_EDGE_BOTTOM
	return -1


func _resizable() -> bool:
	return DisplaySettings.custom_frame_active() and _win.mode == Window.MODE_WINDOWED and not _queue.busy


## Mouse position in window pixels (not content texels). Taken from the content-space mouse and the window's
## stretch transform, so it is right under any DPI scale, letterbox, or monitor arrangement.
func _mouse_px() -> Vector2i:
	return Vector2i(_win.get_final_transform() * get_viewport().get_mouse_position())


func _cursor_for(edge: int) -> Input.CursorShape:
	match edge:
		DisplayServer.WINDOW_EDGE_LEFT, DisplayServer.WINDOW_EDGE_RIGHT:
			return Input.CURSOR_HSIZE
		DisplayServer.WINDOW_EDGE_TOP, DisplayServer.WINDOW_EDGE_BOTTOM:
			return Input.CURSOR_VSIZE
		DisplayServer.WINDOW_EDGE_TOP_LEFT, DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT:
			return Input.CURSOR_FDIAGSIZE
		DisplayServer.WINDOW_EDGE_TOP_RIGHT, DisplayServer.WINDOW_EDGE_BOTTOM_LEFT:
			return Input.CURSOR_BDIAGSIZE
	return Input.CURSOR_ARROW


func _update_resize_cursor() -> void:
	var edge: int = _edge_at(_mouse_px()) if _win.has_focus() else -1
	if edge >= 0:
		Input.set_default_cursor_shape(_cursor_for(edge))
		_cursor_set = true
	elif _cursor_set:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor_set = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var edge: int = _edge_at(_mouse_px())
		if edge >= 0:
			DisplayServer.window_start_resize(edge as DisplayServer.WindowResizeEdge, _win.get_window_id())
			get_viewport().set_input_as_handled()
			return
		# The black letterbox beside or above the bar drags the window too, so the title strip spans the window.
		if _bar.visible and not _queue.busy and _in_bar_strip():
			DisplayServer.window_start_drag(_win.get_window_id())
			get_viewport().set_input_as_handled()


## True when the mouse is on the window row that holds the title bar but outside the bar itself (letterbox).
func _in_bar_strip() -> bool:
	var m: Vector2 = get_viewport().get_mouse_position()
	var vis: Vector2 = get_viewport_rect().size
	if Rect2(Vector2.ZERO, Vector2(vis.x, BAR_H)).has_point(m):
		return false  # the bar handles its own clicks
	var bottom_px: float = (_win.get_final_transform() * Vector2(0.0, float(BAR_H))).y
	return float(_mouse_px().y) < bottom_px


# --- Fullscreen / windowed wipe ---------------------------------------------------------------------------

## Registered as DisplaySettings.animator. Covers the screen with a dither sweep, switches mode while it is
## covered, then uncovers. Reduce-flashing players get an instant switch.
func _play_switch(win: Window, on: bool) -> void:
	if FxConfig.reduce_flashing or not is_inside_tree():
		DisplaySettings.commit_fullscreen(win, on)
		return
	if not _queue.request(on):
		return  # a switch is playing; the latest request is queued and runs after it
	var target: int = 1 if on else 0
	while target != SwitchQueue.NONE:
		_busy_since = Time.get_ticks_msec()
		await _one_switch(win, target == 1)
		target = _queue.finish(DisplaySettings.fullscreen)


func _one_switch(win: Window, on: bool) -> void:
	var mat: ShaderMaterial = _wipe.material as ShaderMaterial
	mat.set_shader_parameter("ink", RelicStyle.ink)
	_set_progress(0.0)
	_wipe.visible = true
	await _run_wipe(0.0, 1.0, WIPE_OUT)
	DisplaySettings.commit_fullscreen(win, on)
	# Let the OS finish the mode change and the viewport resize before uncovering.
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	_set_progress(1.0)
	await _run_wipe(1.0, 0.0, WIPE_IN)
	_wipe.visible = false


func _run_wipe(from: float, to: float, time: float) -> void:
	var t: Tween = create_tween()
	t.tween_method(_set_progress, from, to, time)
	await t.finished


## Stepped, so the wipe reads as a few dither frames rather than a smooth fade.
func _set_progress(v: float) -> void:
	var stepped: float = roundf(v * WIPE_STEPS) / WIPE_STEPS
	(_wipe.material as ShaderMaterial).set_shader_parameter("progress", stepped)


# --- Title bar --------------------------------------------------------------------------------------------

class TitleBar extends Control:
	enum Hit { NONE, TITLE, MIN, MAX, CLOSE }

	var win: Window
	var _hover: int = Hit.NONE
	var _day_text: String = ""
	var _time_text: String = ""

	func set_clock(day_text: String, time_text: String) -> void:
		if day_text != _day_text or time_text != _time_text:
			_day_text = day_text
			_time_text = time_text
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 200

	func _hit_at(p: Vector2) -> int:
		if p.y < 0.0 or p.y >= float(WindowFrame.BAR_H) or p.x < 0.0 or p.x >= size.x:
			return Hit.NONE
		var from_right: float = size.x - p.x
		if from_right <= float(WindowFrame.BTN_W):
			return Hit.CLOSE
		if from_right <= float(WindowFrame.BTN_W * 2):
			return Hit.MAX
		if from_right <= float(WindowFrame.BTN_W * 3):
			return Hit.MIN
		return Hit.TITLE

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var h: int = _hit_at((event as InputEventMouseMotion).position)
			if h != _hover:
				_hover = h
				queue_redraw()
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
				return
			match _hit_at(mb.position):
				Hit.MIN:
					win.mode = Window.MODE_MINIMIZED
				Hit.MAX:
					_toggle_max()
				Hit.CLOSE:
					var saver: Node = get_tree().root.get_node_or_null("Save")
					if saver != null:
						saver.call("save_game")
					get_tree().quit()
				Hit.TITLE:
					if mb.double_click:
						_toggle_max()
					else:
						DisplayServer.window_start_drag(win.get_window_id())
			accept_event()

	func _toggle_max() -> void:
		win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_MAXIMIZED else Window.MODE_MAXIMIZED

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _hover != Hit.NONE:
			_hover = Hit.NONE
			queue_redraw()

	func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func _draw() -> void:
		var w: float = size.x
		var ink: Color = RelicStyle.ink
		var edge: Color = RelicStyle.edge
		var accent: Color = RelicStyle.accent
		var txt: Color = RelicStyle.text
		_px(0, 0, w, WindowFrame.BAR_H, ink)
		# Bottom rule, with a 4x4 Bayer dither row above it fading toward the buttons.
		_px(0, WindowFrame.BAR_H - 1, w, 1, edge)
		for x in int(w):
			var level: int = int(8.0 * (1.0 - float(x) / maxf(w, 1.0)))
			if AsciiBox.BAYER[((WindowFrame.BAR_H - 2) % 4) * 4 + (x % 4)] < level:
				_px(x, WindowFrame.BAR_H - 2, 1, 1, edge)
		# Mark: a tiny pad.
		_px(3, 3, 6, 1, accent)
		_px(2, 4, 8, 3, accent)
		_px(3, 7, 6, 1, edge)
		var font: Font = get_theme_default_font()
		var fs: int = get_theme_default_font_size()
		draw_string(font, Vector2(14, 9), "PLINKY", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt)
		# Day count and in-game time, centred; whole texels so it stays crisp. Skipped when the bar is too narrow.
		if not _day_text.is_empty() and w >= 220.0:
			var gap: float = 6.0
			var dw: float = font.get_string_size(_day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tw: float = font.get_string_size(_time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x0: float = floorf((w - (dw + gap + tw)) * 0.5)
			draw_string(font, Vector2(x0, 9), _day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RelicStyle.dim)
			draw_string(font, Vector2(x0 + dw + gap, 9), _time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent)
		# Buttons, right to left: close, maximise, minimise.
		_button(Hit.CLOSE, w - WindowFrame.BTN_W, accent, ink)
		_button(Hit.MAX, w - WindowFrame.BTN_W * 2, edge, ink)
		_button(Hit.MIN, w - WindowFrame.BTN_W * 3, edge, ink)

	func _button(which: int, x: float, hover_fill: Color, ink: Color) -> void:
		var on: bool = _hover == which
		var fg: Color = ink if on else RelicStyle.text
		if on:
			_px(x, 0, WindowFrame.BTN_W, WindowFrame.BAR_H - 1, hover_fill)
		var cx: float = x + float(WindowFrame.BTN_W) * 0.5
		match which:
			Hit.MIN:
				_px(cx - 3, 7, 6, 1, fg)
			Hit.MAX:
				if win != null and win.mode == Window.MODE_MAXIMIZED:
					_px(cx - 3, 4, 5, 1, fg)
					_px(cx - 3, 4, 1, 4, fg)
					_px(cx - 3, 7, 5, 1, fg)
					_px(cx + 1, 4, 1, 4, fg)
					_px(cx - 1, 3, 5, 1, fg)
					_px(cx + 3, 3, 1, 4, fg)
				else:
					_px(cx - 3, 3, 6, 1, fg)
					_px(cx - 3, 8, 6, 1, fg)
					_px(cx - 3, 3, 1, 6, fg)
					_px(cx + 2, 3, 1, 6, fg)
			Hit.CLOSE:
				for i in 5:
					_px(cx - 3 + i, 3 + i, 1, 1, fg)
					_px(cx + 1 - i, 3 + i, 1, 1, fg)
