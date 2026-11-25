extends CanvasLayer
## Shared popup banner (autoload `Banner`). One call shows a centred, bottom-middle panel that types in from its
## centre, holds for a couple of seconds, then collapses back to the centre and gets out of the way:
##
##   Banner.announce({"title": "Heronmere", "lines": ["Spring - Day 2", "06:30 - Dawn"], "icon": "lake", "duration": 2.6})
##
## Keys: title (Pixelify), lines (Spleen), icon (AreaIcons id), color (Color, tints the border and title), fill (Color,
## the panel background; zone banners use their palette ink), duration (hold, seconds), key (same key = same banner,
## dropped as a duplicate), interrupt (replace what is showing).
## Banners queue (max 4 waiting), skip() ends the current one early, and reduced motion (FxConfig.still())
## shows each one whole with no typing. Logic lives in core/banner_queue.gd. main.gd calls attach(hud) so the panel
## sits inside the framed game view; until then it uses its own layer.

signal banner_started(key: String)
signal banner_finished(key: String)

## Loaded on first use, not preloaded: a preload in a script compiled during a fresh first import fails ("no resource loaders"),
## which then fails this autoload too.
static var _title_font: Font = null
static var _body_font: Font = null
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://fonts/PixelifySans.ttf") as Font
	return _title_font
static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://fonts/spleen-6x12.fnt") as Font
	return _body_font
const TITLE_SIZE: int = 16
const BODY_SIZE: int = 12
const BOTTOM_MARGIN: float = 34.0
const AVOID_GAP: float = 6.0

var queue := BannerQueue.new()
var view: PanelContainer
var _icon: Control
var _title: _Line
var _lines: Array[_Line] = []
var _box: VBoxContainer
var _t: float = 0.0
var _clock: float = 0.0
var _tl: Dictionary = BannerQueue.timeline(0, 0.0, true)   # always a full timeline, so no key can be missing
var _count: int = 0
var _active: bool = false
## A HUD control the banner lifts clear of when it would cover it (the Momentum meter at 640x360). Set by the HUD.
var avoid: Control = null
## True while a menu is open (Main sets it). Banners wait, and one already up is held back until the menu closes.
var hold: Callable = Callable()
var _source: Dictionary = {}   ## the normalised spec on screen, kept so a held-back banner can be shown again


## One centred line of text. Draws the visible centred slice at the position it would have in the full string, so
## typing grows outward and nothing shifts as it does.
class _Line extends Control:
	var text: String = ""
	var font: Font
	var font_size: int = 12
	var color: Color = Color.WHITE
	var progress: float = 0.0:
		set(v):
			if BannerQueue.visible_count(text.length(), v) != BannerQueue.visible_count(text.length(), progress):
				queue_redraw()
			progress = v
	var _w: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_text(t: String, f: Font, sz: int, c: Color) -> void:
		text = t
		font = f
		font_size = sz
		color = c
		_w = ceilf(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		custom_minimum_size = Vector2(_w, ceilf(f.get_height(sz)))
		queue_redraw()

	func _draw() -> void:
		var n: int = text.length()
		var k: int = BannerQueue.visible_count(n, progress)
		if k == 0:
			return
		var start: int = BannerQueue.window_start(n, k)
		var x0: float = floorf((size.x - _w) * 0.5)
		var pre: float = font.get_string_size(text.substr(0, start), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x0 + floorf(pre), font.get_ascent(font_size)), text.substr(start, k),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_view()


## Builds the panel. Quit to Title frees the HUD that the panel was attached to, which frees the panel with it, so
## _ensure_view() rebuilds it before anything touches a freed node.
func _build_view() -> void:
	view = PanelContainer.new()
	view.visible = false
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	view.grow_horizontal = Control.GROW_DIRECTION_BOTH
	view.grow_vertical = Control.GROW_DIRECTION_BEGIN
	view.offset_bottom = -BOTTOM_MARGIN
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	view.add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(AreaIcons.SIZE, AreaIcons.SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 2)
	row.add_child(_box)
	add_child(view)


## Rebuilds the panel if its node was freed, dropping the banner that was on screen.
func _ensure_view() -> void:
	if is_instance_valid(view):
		return
	_active = false
	_title = null
	_lines.clear()
	queue.current = {}
	_build_view()


## Moves the panel into `host` (the HUD) so it follows the framed game view. Safe to call again.
func attach(host: Control) -> void:
	_ensure_view()
	if view.get_parent() == host:
		return
	view.get_parent().remove_child(view)
	host.add_child(view)


## Queues a banner. Returns false when it was dropped as empty or a duplicate.
func announce(spec: Dictionary) -> bool:
	var ok: bool = queue.push(spec, _clock)
	if ok and queue.wants_interrupt():
		_end_current()
	return ok


## Ends the banner on screen now (it collapses unless motion is reduced) and moves on to the next.
func skip() -> void:
	if _active:
		_t = maxf(_t, BannerQueue.out_start(_count, _tl))


## Drops everything, shown or waiting.
func clear() -> void:
	queue.clear()
	_end_current()


func is_showing() -> bool:
	return _active


func _process(delta: float) -> void:
	_clock += delta
	_ensure_view()
	if _active and _held():
		_hold_back()
		return
	if not _active:
		if queue.pending.is_empty() or _held() or FxConfig.bloom_running:   # held while a menu is open or a reset animation plays
			return
		_source = queue.next()
		var resolved: Dictionary = _resolve(_source)
		if resolved.is_empty():
			queue.current = {}   # stale by the time it could show: dropped, the next one starts next frame
			return
		queue.current = resolved   # the repeat check and the finish record use the resolved key
		_begin(resolved)
	_t += delta
	if _t >= BannerQueue.total_time(_count, _tl):
		_end_current()
		return
	_title.progress = BannerQueue.line_progress(_t, 0, _count, _tl)
	for i in _lines.size():
		_lines[i].progress = BannerQueue.line_progress(_t, i + 1, _count, _tl)


## True while Main's hold (a menu is open) says banners must wait.
func _held() -> bool:
	return hold.is_valid() and bool(hold.call())


## Cuts the banner on screen short and puts it back at the front of the queue, to show again once the menu closes. It
## is not recorded as finished, so it is not dropped as a repeat.
func _hold_back() -> void:
	_active = false
	if is_instance_valid(view):
		view.visible = false
	queue.current = {}
	queue.pending.push_front(_source)


func _begin(spec: Dictionary) -> void:
	_ensure_view()
	var title: String = spec["title"]
	var body: Array = spec["lines"]
	var tint: Variant = spec["color"]
	var edge: Color = tint as Color if tint is Color else RelicStyle.edge
	var title_col: Color = tint as Color if tint is Color else RelicStyle.accent
	var box: AsciiBox = AsciiBox.panel(edge)
	if spec["fill"] is Color:
		box.fill_override = spec["fill"] as Color
	view.add_theme_stylebox_override("panel", box)
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_lines.clear()
	var longest: int = title.length()
	_count = body.size() + 1
	_title = _Line.new()
	_title.set_text(title, title_font(), TITLE_SIZE, title_col)
	_box.add_child(_title)
	for l: Variant in body:
		var ln := _Line.new()
		ln.set_text(str(l), body_font(), BODY_SIZE, RelicStyle.text)
		_box.add_child(ln)
		_lines.append(ln)
		longest = maxi(longest, str(l).length())
	_icon.visible = AreaIcons.has(spec["icon"])
	_icon.set_meta("id", spec["icon"])
	_icon.set_meta("color", title_col)
	_icon.queue_redraw()
	_tl = BannerQueue.timeline(longest, spec["duration"], FxConfig.still())
	_t = 0.0
	_title.progress = 0.0 if _tl["in"] > 0.0 else 1.0
	view.visible = true
	view.reset_size()
	view.offset_bottom = -_clear_bottom()
	_active = true
	banner_started.emit(spec["key"])


## A spec with a `resolve` Callable is built now, when it is about to show, so a banner that waited in the queue never
## shows what was true when it was queued. The Callable returns {} to drop the banner, and a repeat of one just shown
## is dropped too.
func _resolve(spec: Dictionary) -> Dictionary:
	var fn: Callable = spec.get("resolve", Callable()) as Callable
	if not fn.is_valid():
		return spec
	var fresh: Dictionary = fn.call() as Dictionary
	if fresh.is_empty():
		return {}
	var out: Dictionary = BannerQueue.normalize(fresh)
	if out["title"] == "" and (out["lines"] as Array).is_empty():
		return {}
	if queue.is_repeat(out["key"], _clock):
		return {}
	return out


## Bottom offset for this banner: the usual margin, or lifted above `avoid` when the two would overlap.
func _clear_bottom() -> float:
	var host: Control = view.get_parent() as Control
	if host == null or avoid == null or not is_instance_valid(avoid) or not avoid.is_visible_in_tree() or avoid.get_parent() != host:
		return BOTTOM_MARGIN
	return BannerQueue.bottom_clearance(host.size, view.size, Rect2(avoid.position, avoid.size), BOTTOM_MARGIN, AVOID_GAP)


func _end_current() -> void:
	if not _active:
		return
	_active = false
	if is_instance_valid(view):
		view.visible = false
	var key: String = queue.current.get("key", "")
	queue.finish(_clock)
	banner_finished.emit(key)


func _draw_icon() -> void:
	var id: String = str(_icon.get_meta("id", ""))
	if AreaIcons.has(id):
		AreaIcons.draw(_icon, id, Vector2.ZERO, _icon.get_meta("color") as Color)
