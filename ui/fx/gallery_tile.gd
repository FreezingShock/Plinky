class_name GalleryTile
extends PixelButton
## One big tile in the gallery menu: a 32 texel icon over a label. Hover or focus lifts the icon two or three
## texels in steps with a small shadow under it, bobs the icon one texel, and a band of light 4x4 Bayer dither in the
## section colour sweeps across the tile once; press sinks like every other button. The name is always shown under the
## icon (a locked tile says "Locked" while hovered), and the tile never changes size. Everything eases per frame (no
## tweens), so sweeping the mouse across the grid never stacks animations. Reduced motion / flashing: no lift, bob or sweep.

const W: float = 96.0
const H: float = 62.0
const ICON: float = 32.0
const LIFT: int = 3
const LIFT_SPEED: float = 12.0
## Sweep: seconds for the dither band to cross the tile, its width in 2 px cells, and the icon bob period.
const SWEEP_TIME: float = 0.4
const SWEEP_BAND: int = 6
const CELL: float = 2.0
const BOB_PERIOD: float = 0.5
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var kind: StringName = &""
var label: String = ""
var big_icon: Texture2D
var lift_t: float = 0.0
## Locked by the tutorial: still focusable (so arrows and pad can land on it and read Locked) but it does nothing.
var locked: bool = false
## 0..1 progress of the dither sweep; 1 = finished or idle. Restarts each time hover/focus begins.
var sweep_t: float = 1.0
var _bob_clock: float = 0.0
var _was_active: bool = false
var _was_hover: bool = false
## Section colour. Set before the tile enters the tree; Color(0,0,0,0) keeps the palette look.
var accent: Color = Color(0, 0, 0, 0)
var _select: AsciiBox = AsciiBox.make(AsciiBox.Kind.SELECT, 0.0, 0.0)


func _ready() -> void:
	super._ready()
	text = ""
	custom_minimum_size = Vector2(W, H)
	clip_text = true
	# Hover is a solid lifted panel (no dither wash behind the icon and label); focus draws the same panel.
	add_theme_stylebox_override("hover", _select)
	if accent.a > 0.0:
		var rest: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0)
		rest.edge_override = accent.darkened(0.35)
		add_theme_stylebox_override("normal", rest)
		_select.edge_override = accent.lightened(0.2)
		var down: AsciiBox = AsciiBox.make(AsciiBox.Kind.PRESSED, 0.0, 0.0)
		down.edge_override = accent
		add_theme_stylebox_override("pressed", down)
		add_theme_stylebox_override("hover_pressed", down)


static func lift_px(t: float) -> int:
	return roundi(clampf(t, 0.0, 1.0) * float(LIFT))


func _process(delta: float) -> void:
	super._process(delta)
	var active: bool = is_hovered() or has_focus()
	var want: float = 1.0 if (active and not locked) else 0.0
	var calm: bool = FxConfig.reduce_flashing or FxConfig.still()
	var n: float = want if calm else move_toward(lift_t, want, LIFT_SPEED * delta)
	var animating: bool = false
	if active and not locked and not calm:
		if not _was_active:
			sweep_t = 0.0
			_bob_clock = 0.0
		_bob_clock += delta
		animating = true
	if sweep_t < 1.0:
		sweep_t = minf(1.0, sweep_t + delta / SWEEP_TIME)
		animating = true
	_was_active = active and not locked
	if animating or n != lift_t:
		lift_t = n
		queue_redraw()
	elif active != _was_hover:
		queue_redraw()
	_was_hover = active


## Icon bob: one texel up on the second half of each period while hovered, and never when calm or locked.
func bob_px() -> int:
	if locked or lift_t < 1.0 or FxConfig.reduce_flashing or FxConfig.still():
		return 0
	return 1 if fmod(_bob_clock, BOB_PERIOD) >= BOB_PERIOD * 0.5 else 0


## True when Bayer cell (cx, cy) is lit at `density` 0..1 (4x4 ordered dither).
static func dither_lit(cx: int, cy: int, density: float) -> bool:
	return float(BAYER[(cy & 3) * 4 + (cx & 3)]) < clampf(density, 0.0, 1.0) * 16.0


## Light-dither band moving left to right in the section colour, behind the icon.
func _draw_sweep() -> void:
	if sweep_t >= 1.0 or locked:
		return
	var cols: int = int(size.x / CELL)   # the full width, so a stretched tile sweeps across all of it
	var rows: int = int(H / CELL)
	var half: float = float(SWEEP_BAND) * 0.5
	var centre: float = lerpf(-half, float(cols + rows / 3) + half, sweep_t)
	var tint: Color = accent.lightened(0.2) if accent.a > 0.0 else RelicStyle.accent
	tint.a = 0.55
	for cy: int in rows:
		for cx: int in cols:
			var slanted: int = cx + cy / 3   # the band leans, so it reads as a sweep and not a wipe
			var d: float = absf(float(slanted) - centre)
			if d < half and dither_lit(cx, cy, 1.0 - d / half):
				draw_rect(Rect2(float(cx) * CELL, float(cy) * CELL, CELL, CELL), tint)


func _draw() -> void:
	var mode: int = get_draw_mode()
	if has_focus() and not locked and mode != DRAW_HOVER and mode != DRAW_PRESSED and mode != DRAW_HOVER_PRESSED:
		_select.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	super._draw()
	_draw_sweep()
	var lift: int = lift_px(lift_t)
	var ix: float = floorf((size.x - ICON) * 0.5)
	var iy: float = 6.0 - float(lift) - float(bob_px())
	if lift > 0:   # small shadow so the lift reads
		draw_rect(Rect2(ix + 6.0, 6.0 + ICON, ICON - 12.0, 1.0), RelicStyle.edge)
	if big_icon != null:
		draw_texture(big_icon, Vector2(ix, iy), Color(1, 1, 1, 0.45) if locked else Color.WHITE)
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	var col: Color = RelicStyle.dim if locked else (RelicStyle.ink if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED else ((accent.lightened(0.2) if accent.a > 0.0 else RelicStyle.accent) if lift > 0 else RelicStyle.text))
	# The name is always shown; a locked tile says "Locked" while hovered so a greyed icon explains itself.
	var shown: String = "Locked" if (locked and (is_hovered() or has_focus())) else label
	var tw: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	font.draw_string(get_canvas_item(), Vector2(floorf((size.x - tw) * 0.5), H - 8.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
