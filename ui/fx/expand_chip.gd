class_name ExpandChip
extends PixelButton
## Icon-only HUD chip with a floating label. The chip itself NEVER changes size or moves, so sweeping the mouse
## across a row of chips always hits the chip you aimed at. The label opens as a small framed bubble above the
## chip (it types in with a few scrambled trailing glyphs) and draws over its neighbours without touching layout.
##
## One shared state drives it: keyboard or pad focus opens it at once; the mouse opens it after a short hover
## intent (INTENT), so a quick sweep opens nothing, and it lingers a moment (GRACE) after the mouse leaves, so
## crossing the gap between two chips does not flicker. The hit area reaches past the frame into the gaps and
## the bar's margin, so there is no dead space between chips.
##
## label_mode (Settings > Access > Bottom bar labels): "hover" = bubble, "always" = the label sits in the chip
## (a fixed, wider chip; nothing animates), "never" = icon only (tooltips still name it).
## Reduce motion / flashing snaps the bubble open and closed with no scramble.

const MODE_HOVER: String = "hover"
const MODE_ALWAYS: String = "always"
const MODE_NEVER: String = "never"
static var label_mode: String = MODE_HOVER

const OPEN_SPEED: float = 5.0      ## progress per second while opening (~0.2 s)
const CLOSE_SPEED: float = 8.0
const INTENT: float = 0.13         ## mouse must rest this long before the label opens
const GRACE: float = 0.15          ## label lingers this long after the mouse leaves
const GLYPHS: String = "#%&*+=/\\<>01:;"
const SCRAMBLE_TAIL: int = 3       ## trailing letters shown as noise while typing
const SETTLE_TIME: float = 0.14    ## one letter still flickers briefly after the label finishes
const TICK_MS: int = 45            ## the noise re-rolls at about 22 Hz
const ICON_SIZE: float = 16.0
const MIN_HEIGHT: float = 24.0
const HIT_PAD_X: float = 2.0       ## half the gap between chips: neighbours' hit areas meet in the middle
const HIT_PAD_Y: float = 4.0       ## up into the Momentum margin and down to the screen edge
const BUBBLE_PAD: float = 6.0

## The label. Set it any time (Rebirth changes its text).
var full_text: String = "":
	set(v):
		if v == full_text:
			return
		full_text = v
		_dirty = true
## Bubble opens leftwards from the chip's right edge (for chips at the right edge of the screen).
var anchor_right: bool = false
## 0 closed .. 1 open. Read by tests.
var progress: float = 0.0

var _dirty: bool = true
var _collapsed_w: float = 32.0
var _open_w: float = 32.0
var _text_w: float = 0.0
var _settle: float = 0.0
var _hover_time: float = 0.0
var _grace: float = 0.0
var _bubble_box: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0)


func _ready() -> void:
	super._ready()
	clip_text = false
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text = ""
	custom_minimum_size.y = MIN_HEIGHT
	_apply()


## A generous, stable hit area: the frame plus the gaps and margin around it.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2(-HIT_PAD_X, -HIT_PAD_Y), size + Vector2(HIT_PAD_X * 2.0, HIT_PAD_Y * 2.0)).has_point(point)


## Pure: should the bubble be opening? Focus is immediate; the mouse needs intent; a recent mouse lingers.
static func wants_open(mode: String, has_text: bool, focused: bool, hovered: bool, hover_time: float, grace: float, was_open: bool) -> bool:
	if mode != MODE_HOVER or not has_text:
		return false
	if focused:
		return true
	if hovered:
		return hover_time >= INTENT
	return grace > 0.0 and was_open


## Pure: the text to show for a given progress. `tick` re-rolls the noise; `settle` is seconds since finishing.
static func reveal(full: String, p: float, tick: int, settle: float, calm: bool) -> String:
	var n: int = full.length()
	if n == 0 or p <= 0.0:
		return ""
	if calm or (p >= 1.0 and settle >= SETTLE_TIME):
		return full if p >= 1.0 else full.substr(0, ceili(p * float(n)))
	var shown: int = n if p >= 1.0 else clampi(ceili(p * float(n)), 0, n)
	var out: String = full.substr(0, shown)
	if p >= 1.0:
		var one: Array[int] = [posmod(tick * 7, n)]
		return _noisy(out, one, tick)
	var idx: Array[int] = []
	for i in range(maxi(0, shown - SCRAMBLE_TAIL), shown):
		idx.append(i)
	return _noisy(out, idx, tick)


static func _noisy(s: String, idx: Array[int], tick: int) -> String:
	var chars: PackedStringArray = PackedStringArray()
	for i in s.length():
		chars.append(s[i])
	for i: int in idx:
		if i < chars.size() and chars[i] != " ":
			chars[i] = GLYPHS[posmod(tick * 31 + i * 17 + tick * i, GLYPHS.length())]
	return "".join(chars)


## Pure: width in whole texels at a progress, easing out so it opens fast and settles.
static func width_at(collapsed: float, open: float, p: float) -> float:
	var q: float = clampf(p, 0.0, 1.0)
	var e: float = 1.0 - (1.0 - q) * (1.0 - q)
	return floorf(lerpf(collapsed, open, e))


## Pure: new progress after `delta` seconds heading to `target` (0 or 1).
static func step_progress(p: float, target: float, delta: float) -> float:
	if target > p:
		return minf(target, p + OPEN_SPEED * delta)
	return maxf(target, p - CLOSE_SPEED * delta)


func _measure() -> void:
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	_text_w = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x if font != null else 0.0
	var pad: float = AsciiBox.BUTTON_PAD.x * 2.0
	var iw: float = ICON_SIZE if icon != null else 0.0
	_collapsed_w = ceilf(pad + iw)
	_open_w = ceilf(pad + iw + (float(get_theme_constant(&"h_separation")) if icon != null else 0.0) + _text_w)
	_dirty = false


func bubble_text() -> String:
	return reveal(full_text, progress, int(Time.get_ticks_msec() / TICK_MS), _settle, _calm())


func _calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_flashing


func _process(delta: float) -> void:
	super._process(delta)
	if _dirty and is_inside_tree():
		_measure()
	var hovered: bool = is_hovered()
	if hovered:
		_hover_time += delta
		_grace = GRACE
	else:
		_hover_time = 0.0
		_grace = maxf(0.0, _grace - delta)
	var want: bool = wants_open(label_mode, full_text != "", has_focus(), hovered, _hover_time, _grace, progress > 0.0)
	var target: float = 1.0 if want else 0.0
	var before: float = progress
	progress = target if _calm() else step_progress(progress, target, delta)
	if progress >= 1.0:
		_settle = _settle + delta if before >= 1.0 else 0.0
	else:
		_settle = 0.0
	_apply()


func _apply() -> void:
	# The chip's own size depends only on the label mode, never on hover or focus.
	var w: float = _open_w if label_mode == MODE_ALWAYS else _collapsed_w
	if custom_minimum_size.x != w:
		custom_minimum_size.x = w
	var t: String = full_text if label_mode == MODE_ALWAYS else ""
	if text != t:
		text = t
	var z: int = 4 if progress > 0.0 else 0   # an open bubble draws over its neighbours and the meter above
	if z_index != z:
		z_index = z
	queue_redraw()


func _draw() -> void:
	super._draw()
	if label_mode != MODE_HOVER or progress <= 0.0 or full_text == "":
		return
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	var bh: float = ceilf(font.get_height(fs)) + 6.0
	var bw: float = maxf(14.0, width_at(0.0, _text_w + BUBBLE_PAD * 2.0, progress))
	var x: float = size.x - bw if anchor_right else 0.0
	var y: float = -bh - 3.0
	draw_style_box(_bubble_box, Rect2(x, y, bw, bh))
	draw_string(font, Vector2(x + BUBBLE_PAD, y + 3.0 + font.get_ascent(fs)), bubble_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, RelicStyle.text)
