class_name AsciiBox
extends StyleBox
## Notched, dithered frame drawn texel by texel (Spleen has no box-drawing glyphs).
## Kinds: PANEL, BUTTON, HOVER, PRESSED, DISABLED. Colours come from RelicStyle (zone palette).

enum Kind { PANEL, BUTTON, HOVER, PRESSED, DISABLED }

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var kind: Kind = Kind.PANEL
## Hover ripple phase, advanced by PixelButton while hovered (texels the wash drifts).
static var phase: int = 0


static func make(p_kind: Kind, pad_x: float = 8.0, pad_y: float = 6.0) -> AsciiBox:
	var b := AsciiBox.new()
	b.kind = p_kind
	b.content_margin_left = pad_x
	b.content_margin_right = pad_x
	b.content_margin_top = pad_y
	b.content_margin_bottom = pad_y
	return b


func _px(ci: RID, x: float, y: float, w: float, h: float, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, y, w, h), c)


func _dither(ci: RID, r: Rect2, c: Color, level: int, shift: int = 0) -> void:
	for j in int(r.size.y):
		for i in int(r.size.x):
			var gx: int = int(r.position.x) + i
			var gy: int = int(r.position.y) + j
			if BAYER[(gy % 4) * 4 + posmod(gx + gy + shift, 4)] < level:
				_px(ci, gx, gy, 1, 1, c)


func _draw(ci: RID, rect: Rect2) -> void:
	var x: float = floorf(rect.position.x)
	var y: float = floorf(rect.position.y)
	var w: float = floorf(rect.size.x)
	var h: float = floorf(rect.size.y)
	var edge: Color = RelicStyle.edge
	var fill: Color = RelicStyle.ink
	match kind:
		Kind.HOVER:
			edge = RelicStyle.accent
		Kind.PRESSED:
			edge = RelicStyle.accent
			fill = RelicStyle.accent
		Kind.DISABLED:
			edge = RelicStyle.ink.lerp(RelicStyle.edge, 0.3)
	_px(ci, x, y, w, h, fill)
	# 1 texel border with the corners notched.
	_px(ci, x + 2, y, w - 4, 1, edge)
	_px(ci, x + 2, y + h - 1, w - 4, 1, edge)
	_px(ci, x, y + 2, 1, h - 4, edge)
	_px(ci, x + w - 1, y + 2, 1, h - 4, edge)
	_px(ci, x + 1, y + 1, 1, 1, edge)
	_px(ci, x + w - 2, y + 1, 1, 1, edge)
	_px(ci, x + 1, y + h - 2, 1, 1, edge)
	_px(ci, x + w - 2, y + h - 2, 1, 1, edge)
	if kind == Kind.PANEL:
		var stud: Color = RelicStyle.edge
		for p: Vector2 in [Vector2(x + 3, y + 3), Vector2(x + w - 5, y + 3), Vector2(x + 3, y + h - 5), Vector2(x + w - 5, y + h - 5)]:
			_px(ci, p.x, p.y, 2, 2, stud)
		_dither(ci, Rect2(x + 3, y + h - 3, w - 6, 1), edge, 6)
		_dither(ci, Rect2(x + w - 3, y + 3, 1, h - 6), edge, 6)
	elif kind == Kind.HOVER:
		_dither(ci, Rect2(x + 2, y + 2, w - 4, h - 5), edge, 3, phase)
		_px(ci, x + 2, y + h - 2, w - 4, 1, edge)
	elif kind == Kind.DISABLED:
		_dither(ci, Rect2(x + 2, y + 2, w - 4, h - 4), edge, 3)
	elif kind == Kind.BUTTON:
		_px(ci, x + 2, y + h - 2, w - 4, 1, edge)
