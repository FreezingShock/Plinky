class_name BootMotes
extends Control
## Drifting pollen motes for the boot screen: 1 to 2 texel squares in palette accent and light,
## snapped to the texel grid. Layout is seeded so every boot looks the same.

const COUNT: int = 28

var _motes: Array[Dictionary] = []
var _time: float = 0.0
var _pal: PackedColorArray


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pal = Palettes.colors(Palettes.MEADOW)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in COUNT:
		_motes.append({
			"x": rng.randf() * 640.0,
			"y": rng.randf() * 360.0,
			"speed": rng.randf_range(6.0, 16.0),
			"phase": rng.randf() * TAU,
			"size": rng.randi_range(1, 2),
			"col": 5 if rng.randf() < 0.6 else 4,
		})


## Under Reduce Motion the motes hang where they are: the clock stops, so they neither drift nor sway.
func _process(delta: float) -> void:
	if not FxConfig.still():
		_time += delta
	queue_redraw()


func _draw() -> void:
	var h: float = size.y
	for m: Dictionary in _motes:
		var y: float = fposmod(float(m["y"]) - _time * float(m["speed"]), h)
		var x: float = float(m["x"]) + sin(_time * 0.9 + float(m["phase"])) * 6.0
		var s: float = float(m["size"])
		draw_rect(Rect2(floorf(x), floorf(y), s, s), _pal[int(m["col"])])
