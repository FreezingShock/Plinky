class_name GalleryTile
extends PixelButton
## One big tile in the gallery menu: a 32 texel icon over a label. Hover or focus lifts the icon two or three
## texels in steps with a small shadow under it; press sinks like every other button. The tile is icon-only at
## rest: its label types in beneath the icon on hover or focus, the same reveal as the bottom bar chips (ExpandChip),
## and the tile never changes size. The lift and the label ease per frame (no tweens), so sweeping the mouse across
## the grid never stacks animations.

const W: float = 74.0
const H: float = 62.0
const ICON: float = 32.0
const LIFT: int = 3
const LIFT_SPEED: float = 12.0

var kind: StringName = &""
var label: String = ""
var big_icon: Texture2D
var lift_t: float = 0.0
## 0 label hidden .. 1 fully typed in. Read by tests.
var label_t: float = 0.0
var _settle: float = 0.0
var _select: AsciiBox = AsciiBox.make(AsciiBox.Kind.SELECT, 0.0, 0.0)


func _ready() -> void:
	super._ready()
	text = ""
	custom_minimum_size = Vector2(W, H)
	clip_text = true
	# Hover is a solid lifted panel (no dither wash behind the icon and label); focus draws the same panel.
	add_theme_stylebox_override("hover", _select)


static func lift_px(t: float) -> int:
	return roundi(clampf(t, 0.0, 1.0) * float(LIFT))


func _process(delta: float) -> void:
	super._process(delta)
	var want: float = 1.0 if ((is_hovered() or has_focus()) and not disabled) else 0.0
	var calm: bool = FxConfig.reduce_flashing or MeadowLife.reduce_motion
	var n: float = want if calm else move_toward(lift_t, want, LIFT_SPEED * delta)
	# The label also shows on a locked tile, so a greyed icon can say "Locked".
	var want_label: float = 1.0 if (is_hovered() or has_focus()) else 0.0
	var before: float = label_t
	var ln: float = want_label if calm else ExpandChip.step_progress(label_t, want_label, delta)
	_settle = _settle + delta if (ln >= 1.0 and before >= 1.0) else 0.0
	if n != lift_t or ln != label_t or ln > 0.0 and ln < 1.0:
		lift_t = n
		label_t = ln
		queue_redraw()


func _draw() -> void:
	var mode: int = get_draw_mode()
	if has_focus() and not disabled and mode != DRAW_HOVER and mode != DRAW_PRESSED and mode != DRAW_HOVER_PRESSED:
		_select.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	super._draw()
	var lift: int = lift_px(lift_t)
	var ix: float = floorf((size.x - ICON) * 0.5)
	var iy: float = 6.0 - float(lift)
	if lift > 0:   # small shadow so the lift reads
		draw_rect(Rect2(ix + 6.0, 6.0 + ICON, ICON - 12.0, 1.0), RelicStyle.edge)
	if big_icon != null:
		draw_texture(big_icon, Vector2(ix, iy), Color(1, 1, 1, 0.45) if disabled else Color.WHITE)
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	var col: Color = RelicStyle.dim if disabled else (RelicStyle.ink if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED else (RelicStyle.accent if lift > 0 else RelicStyle.text))
	var shown: String = ExpandChip.reveal(label if not disabled else "Locked", label_t, int(Time.get_ticks_msec() / ExpandChip.TICK_MS), _settle, FxConfig.reduce_flashing or MeadowLife.reduce_motion)
	if shown == "":
		return
	var tw: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	font.draw_string(get_canvas_item(), Vector2(floorf((size.x - tw) * 0.5), H - 8.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
