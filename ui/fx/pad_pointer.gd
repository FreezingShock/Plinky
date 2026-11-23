class_name PadPointer
extends Node2D
## A bobbing pixel arrow over the first pad. Shows only for a brand new player (no presses yet, tips on),
## so the first step is unmissable. Palette roles only: accent fill, ink outline.

const BOB_PX: float = 3.0
const BOB_HZ: float = 2.0
const ARROW_H: float = 7.0   # rows of the arrow, tip at the bottom
const TIP_GAP: float = 9.0   # texels from the pad centre up to the arrow tip at rest (the pad is 14 wide, 7 tall each way)

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _t: float = 0.0


func _init() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	var sim: Sim = GameState.sim
	var want: bool = GameState.onboarding.tips_enabled and sim.press_count == 0 and sim.rebirth_count == 0
	if want != visible:
		visible = want
	if not want:
		return
	_t += delta
	queue_redraw()


## Y of the arrow tip relative to the pad centre, for a bob of 0 to BOB_PX texels (up is negative).
static func tip_y(bob: float) -> float:
	return -TIP_GAP - bob


func _draw() -> void:
	var bob: float = roundf(sin(_t * TAU * BOB_HZ) * BOB_PX * 0.5 + BOB_PX * 0.5)
	var ink: Color = palette[0] if palette.size() > 0 else Color.BLACK
	var fill: Color = palette[5] if palette.size() > 5 else Color.WHITE
	var y: float = tip_y(bob) - ARROW_H
	# Down-pointing arrow, 9 wide, drawn row by row with a 1 texel outline.
	for row in 7:
		var half: int = 6 - row
		draw_rect(Rect2(-half - 1, y + row, half * 2 + 3, 1), ink)
	for row in 6:
		var half: int = 5 - row
		draw_rect(Rect2(-half, y + row, half * 2 + 1, 1), fill)
	draw_rect(Rect2(-2, y - 4, 5, 4), ink)
	draw_rect(Rect2(-1, y - 3, 3, 3), fill)
