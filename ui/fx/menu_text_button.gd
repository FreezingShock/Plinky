class_name MenuTextButton
extends PixelButton
## Plain text button for the title screen and the pause menu (Resume, Quit to title, Quit game). Deliberately not
## a framed chip: no box, just Pixelify Sans text that, on hover or focus, turns to its accent colour, nudges
## right as a ">" marker slides in, and gets an underline that sweeps out. Everything is a per-frame ease on whole
## texels (no tweens), so sweeping across a stack of buttons never queues animations, and the button's size never
## changes. Reduce motion / flashing snaps instead of easing.

const FONT: FontFile = preload("res://fonts/PixelifySans.ttf")
## Gap in texels between the ">" marker and the first letter.
const ARROW_GAP: int = 4
const FONT_SIZE: int = 16
const SPEED: float = 9.0
const NUDGE: int = 4
const PAD_X: float = 14.0
const PAD_Y: float = 5.0
## Width of the icon column when `icon_id` is set: the 9 texel icon plus a gap.
const ICON_SLOT: float = 9.0 + 7.0

## The label, drawn by this button (the Button's own text stays empty).
var label: String = "":
	set(v):
		label = v
		_fit()
## Colour at rest, and colour while hovered, focused or pressed. Role colours from RelicStyle, set by the owner.
var rest_color: Color = RelicStyle.text
var accent_color: Color = RelicStyle.accent
## Vertical padding above and below the label; tighter stacks (the title menu) lower it.
var pad_y: float = PAD_Y:
	set(v):
		pad_y = v
		_fit()
## Optional MenuIcons id, drawn to the left of the label. An icon button skips the ">" marker (the icon itself
## brightens and the row nudges), and its width grows by ICON_SLOT.
var icon_id: String = "":
	set(v):
		icon_id = v
		_fit()
## 0 resting .. 1 fully hovered. Read by tests.
var t: float = 0.0


func _ready() -> void:
	CrispFont.apply(FONT)
	super._ready()
	text = ""
	flat = true
	for s: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_ALL
	_fit()


func _fit() -> void:
	var w: float = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	var h: float = ceilf(FONT.get_height(FONT_SIZE))
	var icon_w: float = ICON_SLOT if icon_id != "" else 0.0
	custom_minimum_size = Vector2(ceilf(w) + icon_w + PAD_X * 2.0 + float(NUDGE) * 2.0, h + pad_y * 2.0)
	queue_redraw()


## Pure: x offset in whole texels for a progress.
static func nudge_px(p: float) -> int:
	return roundi(clampf(p, 0.0, 1.0) * float(NUDGE))


## Pure: width of the underline for a progress, in whole texels.
static func underline_px(text_w: float, p: float) -> int:
	return floori(text_w * clampf(p, 0.0, 1.0))


func _process(delta: float) -> void:
	super._process(delta)
	var want: float = 1.0 if ((is_hovered() or has_focus()) and not disabled) else 0.0
	var n: float = want if (FxConfig.reduce_flashing or MeadowLife.reduce_motion) else move_toward(t, want, SPEED * delta)
	if n != t:
		t = n
		queue_redraw()


func _draw() -> void:
	super._draw()
	var fs: int = FONT_SIZE
	var tw: float = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var down: bool = get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var col: Color = RelicStyle.dim if disabled else rest_color.lerp(accent_color, 1.0 if t > 0.0 else 0.0)
	var x: float = PAD_X + float(NUDGE) + float(nudge_px(t))
	var base: float = floorf(pad_y + FONT.get_ascent(fs)) + (1.0 if down else 0.0)
	if icon_id != "":
		var iy: float = floorf(base - FONT.get_ascent(fs) + (ceilf(FONT.get_height(fs)) - float(MenuIcons.SIZE)) * 0.5) + 1.0
		MenuIcons.draw(self, icon_id, Vector2(x, iy), col)
		x += ICON_SLOT
	FONT.draw_string(get_canvas_item(), Vector2(x, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
	if t > 0.0 and icon_id != "":
		draw_rect(Rect2(x, base + 3.0, float(underline_px(tw, t)), 1.0), col)
	elif t > 0.0:
		# ">" marker slides in from the left; underline sweeps out beneath the text.
		# Right-aligned a fixed gap before the first letter, on whole texels, so the two never touch.
		var aw: float = ceilf(FONT.get_string_size(">", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x)
		var mx: float = x - aw - float(ARROW_GAP)
		FONT.draw_string(get_canvas_item(), Vector2(mx, base), ">", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(col, clampf(t * 2.0, 0.0, 1.0)))
		var uy: float = base + 3.0
		draw_rect(Rect2(x, uy, float(underline_px(tw, t)), 1.0), col)
