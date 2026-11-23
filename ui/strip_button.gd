class_name StripButton
extends Control
## A small square button for the HUD stat strip's edit mode: a framed pixel glyph (pencil, arrows, X, tick, reset) or a
## 16 px stat icon. It draws its own AsciiBox frame, keeps no state that can stick, and reports a click, Enter or pad A
## through `pressed`. Names live in instant tooltips (Tip.bind), so the glyphs stay tiny.

signal pressed

enum Glyph { EDIT, UP, DOWN, CLOSE, DONE, RESET, NONE }

const SIZE: float = 12.0        ## row controls and the pencil
const CHIP_SIZE: float = 22.0   ## stat icon chips (16 px icon plus a frame)

## Glyph pixels, '#' is lit. Each is centred in the button.
const GLYPHS: Dictionary = {
	Glyph.EDIT: [".....#.", "....###", "...###.", "..###..", ".###...", ".##....", "#......"],
	Glyph.UP: ["...#...", "..###..", ".#####.", "#######"],
	Glyph.DOWN: ["#######", ".#####.", "..###..", "...#..."],
	Glyph.CLOSE: ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	Glyph.DONE: ["....#", "...#.", "#.#..", ".#..."],
	Glyph.RESET: ["..###.#", ".#...##", "#.....#", "#......", "#.....#", ".#...#.", "..###.."],
}

var glyph: Glyph = Glyph.NONE:
	set(v):
		glyph = v
		queue_redraw()
var icon: Texture2D = null:
	set(v):
		icon = v
		queue_redraw()
var disabled: bool = false:
	set(v):
		if v == disabled:
			return
		disabled = v
		_down = false
		queue_redraw()
## Drawn in the hover look (edit mode's pencil while it is on).
var active: bool = false:
	set(v):
		active = v
		queue_redraw()

var _hover: bool = false
var _down: bool = false
var _box_normal: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0)
var _box_hover: AsciiBox = AsciiBox.make(AsciiBox.Kind.HOVER, 0.0, 0.0)
var _box_press: AsciiBox = AsciiBox.make(AsciiBox.Kind.PRESSED, 0.0, 0.0)
var _box_off: AsciiBox = AsciiBox.make(AsciiBox.Kind.DISABLED, 0.0, 0.0)


## A glyph button, SIZE square.
static func make(g: Glyph) -> StripButton:
	var b := StripButton.new()
	b.glyph = g
	b.custom_minimum_size = Vector2(SIZE, SIZE)
	return b


## A stat icon chip, CHIP_SIZE square.
static func chip(tex: Texture2D) -> StripButton:
	var b := StripButton.new()
	b.icon = tex
	b.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	return b


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false
		queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## The click, Enter and pad A all end up here; tests call it directly. Does nothing while disabled.
func press() -> void:
	if not disabled:
		pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if disabled:
			return
		if event.pressed:
			_down = true
			queue_redraw()
		else:
			var was_down: bool = _down
			_down = false
			queue_redraw()
			if was_down and Rect2(Vector2.ZERO, size).has_point((event as InputEventMouseButton).position):
				press()
	elif event.is_action_pressed(&"ui_accept") and has_focus():
		accept_event()
		press()


func _draw() -> void:
	var lit: bool = (_hover or has_focus() or active) and not disabled
	var box: AsciiBox = _box_off if disabled else (_box_press if _down else (_box_hover if lit else _box_normal))
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var press_dy: float = 1.0 if _down else 0.0
	if icon != null:
		var at: Vector2 = Vector2(floorf((size.x - 16.0) * 0.5), floorf((size.y - 16.0) * 0.5) + press_dy)
		draw_texture_rect(icon, Rect2(at, Vector2(16.0, 16.0)), false, Color(1, 1, 1, 0.4 if disabled else 1.0))
	elif GLYPHS.has(glyph):
		var rows: Array = GLYPHS[glyph]
		var gw: int = (rows[0] as String).length()
		var col: Color = RelicStyle.dim if disabled else (RelicStyle.ink if _down else (RelicStyle.accent if lit else RelicStyle.text))
		var ox: float = floorf((size.x - float(gw)) * 0.5)
		var oy: float = floorf((size.y - float(rows.size())) * 0.5) + press_dy
		for y: int in rows.size():
			var line: String = rows[y]
			for x: int in line.length():
				if line[x] == "#":
					draw_rect(Rect2(ox + float(x), oy + float(y), 1.0, 1.0), col)
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), RelicStyle.accent)
