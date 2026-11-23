class_name DitherReveal
extends Control
## Ink overlay that wipes a panel in or out as a 4x4 Bayer dither, stepped (no smooth fades).
## cover 1 = fully inked, 0 = clear. Sits on top of a panel, ignores the mouse.
## Drawn by tiling a tiny 4x4 texture per step (no shader), so it behaves the same in every renderer path.

const STEPS: int = 8
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _tiles: Dictionary = {}   # "step|ink" -> ImageTexture

var _step: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


## Set the cover, snapped to STEPS levels. Hidden when clear.
func set_cover(v: float) -> void:
	_step = clampi(int(floorf(clampf(v, 0.0, 1.0) * STEPS)), 0, STEPS)
	visible = _step > 0
	queue_redraw()


func _draw() -> void:
	if _step <= 0:
		return
	if _step >= STEPS:
		draw_rect(Rect2(Vector2.ZERO, size), RelicStyle.ink)
		return
	draw_texture_rect(_tile(_step), Rect2(Vector2.ZERO, size), true)


## 4x4 texture where `step` of STEPS levels of the Bayer cells are inked.
static func _tile(step: int) -> Texture2D:
	var key: String = "%d|%s" % [step, RelicStyle.ink.to_html()]
	if _tiles.has(key):
		return _tiles[key]
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var limit: int = int(ceil(float(step) * 16.0 / float(STEPS)))
	for y in 4:
		for x in 4:
			img.set_pixel(x, y, RelicStyle.ink if BAYER[y * 4 + x] < limit else Color(0, 0, 0, 0))
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_tiles[key] = tex
	return tex
