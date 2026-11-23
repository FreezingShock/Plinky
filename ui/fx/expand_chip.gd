class_name ExpandChip
extends PixelButton
## Icon-only HUD chip that opens into icon + label on hover or focus.
## The width follows one progress value (0 collapsed, 1 open) that eases toward its target every frame, so
## spamming hover in and out just reverses it mid-way: no tweens to stack. The label types in left to right
## with a few trailing glyphs scrambled (dither / ASCII look). The frame is the button's own AsciiBox, so the
## outline grows with it, and the HBox around it slides the neighbours aside as the width changes.
## Reduce motion (MeadowLife.reduce_motion) snaps open and closed with no scramble.

const OPEN_SPEED: float = 4.5      ## progress per second while opening (~0.22 s)
const CLOSE_SPEED: float = 6.5     ## closing is quicker so the bar settles fast
const GLYPHS: String = "#%&*+=/\\<>01:;"
const SCRAMBLE_TAIL: int = 3       ## trailing letters shown as noise while typing
const SETTLE_TIME: float = 0.14    ## one letter still flickers briefly after the label finishes
const TICK_MS: int = 45            ## the noise re-rolls at about 22 Hz
const ICON_SIZE: float = 16.0
const MIN_HEIGHT: float = 24.0

## The label shown when open. Set it any time (Rebirth changes its text); the open width follows.
var full_text: String = "":
	set(v):
		if v == full_text:
			return
		full_text = v
		_dirty = true
## 0 collapsed .. 1 open. Read by tests.
var progress: float = 0.0

var _dirty: bool = true
var _collapsed_w: float = 32.0
var _open_w: float = 32.0
var _settle: float = 0.0


func _ready() -> void:
	super._ready()
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text = ""
	custom_minimum_size.y = MIN_HEIGHT
	_apply()


func is_open_wanted() -> bool:
	return is_hovered() or has_focus()


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
		# Settling: a single letter flickers.
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


## Pure: width in texels (whole numbers) at a progress, easing out so it opens fast and settles.
static func width_at(collapsed: float, open: float, p: float) -> float:
	var e: float = 1.0 - (1.0 - clampf(p, 0.0, 1.0)) * (1.0 - clampf(p, 0.0, 1.0))
	return floorf(lerpf(collapsed, open, e))


## Pure: new progress after `delta` seconds heading to `target` (0 or 1).
static func step_progress(p: float, target: float, delta: float) -> float:
	if target > p:
		return minf(target, p + OPEN_SPEED * delta)
	return maxf(target, p - CLOSE_SPEED * delta)


func _measure() -> void:
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	var tw: float = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x if font != null else 0.0
	var pad: float = AsciiBox.BUTTON_PAD.x * 2.0
	var iw: float = ICON_SIZE if icon != null else 0.0
	_collapsed_w = ceilf(pad + iw)
	_open_w = ceilf(pad + iw + (float(get_theme_constant(&"h_separation")) if icon != null else 0.0) + tw)
	_dirty = false


func _process(delta: float) -> void:
	super._process(delta)
	if _dirty and is_inside_tree():
		_measure()
	var target: float = 1.0 if (is_open_wanted() and full_text != "") else 0.0
	var calm: bool = MeadowLife.reduce_motion
	var before: float = progress
	progress = target if calm else step_progress(progress, target, delta)
	if progress >= 1.0:
		_settle = _settle + delta if before >= 1.0 else 0.0
	else:
		_settle = 0.0
	_apply()


func _apply() -> void:
	var w: float = width_at(_collapsed_w, _open_w, progress)
	if custom_minimum_size.x != w:
		custom_minimum_size.x = w
	var tick: int = int(Time.get_ticks_msec() / TICK_MS)
	var t: String = reveal(full_text, progress, tick, _settle, MeadowLife.reduce_motion)
	if text != t:
		text = t
