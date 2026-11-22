class_name PadPointer
extends Node2D
## A bobbing pixel arrow over the first pad. Shows only for a brand new player (no presses yet, tips on),
## so the first step is unmissable. Palette roles only: accent fill, ink outline.

const BOB_PX: float = 3.0
const BOB_HZ: float = 2.0
const HEIGHT: float = 26.0  # texels above the pad anchor

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


func _draw() -> void:
	var bob: float = roundf(sin(_t * TAU * BOB_HZ) * BOB_PX * 0.5 + BOB_PX * 0.5)
	var ink: Color = palette[0] if palette.size() > 0 else Color.BLACK
	var fill: Color = palette[5] if palette.size() > 5 else Color.WHITE
	var y: float = -HEIGHT - bob
	# Down-pointing arrow, 9 wide, drawn row by row with a 1 texel outline.
	for row in 5:
		var half: int = 4 - row
		draw_rect(Rect2(-half - 1, y + row, half * 2 + 3, 1), ink)
	for row in 4:
		var half: int = 3 - row
		draw_rect(Rect2(-half, y + row, half * 2 + 1, 1), fill)
	draw_rect(Rect2(-1, y - 3, 3, 3), ink)
	draw_rect(Rect2(0, y - 2, 1, 2), fill)
