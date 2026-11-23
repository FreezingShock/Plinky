class_name SkyRain
extends Node2D
## Light rain over the meadow. Each drop is a pure function of time and its index: no state, no alpha, palette
## indices only (7 paper for near streaks, 4 light for far ones). Redrawn at 12 fps. Drops hit the ground and
## leave a two-frame splash. Wind slants the fall. Intensity 0..1 decides how many of the drops are active.

const STEP: float = 1.0 / 12.0
const IDX_FAR: int = 4
const IDX_NEAR: int = 7

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var area: Rect2 = Rect2(-110.0, -70.0, 860.0, 500.0)
var drops: int = 150
var intensity: float = 0.0   # 0..1, set by SkyCycle
var wind: float = 0.0        # 0..1, set by SkyCycle
var _t: float = 0.0
var _step: int = -1


func _process(delta: float) -> void:
	if intensity <= 0.001:
		if _step != -2:
			_step = -2
			queue_redraw()  # clear once
		return
	_t += delta
	var s: int = int(_t / STEP)
	if s != _step:
		_step = s
		queue_redraw()


func _draw() -> void:
	if intensity <= 0.001:
		return
	var tb: float = float(maxi(_step, 0)) * STEP
	var active: int = int(ceilf(float(drops) * intensity))
	var slant: float = 0.15 + 0.5 * wind          # texels sideways per texel fallen
	# Only drops inside the visible part of the sky are drawn, so a zoomed-in camera costs less, not more.
	var view: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	view = view.grow(6.0)
	for i in mini(active, drops):
		var near: bool = (i % 2) == 0
		var speed: float = 190.0 if near else 130.0
		var fall_h: float = area.size.y
		var cycle: float = fall_h / speed
		var u: float = tb / cycle + MeadowLife.hash01(i * 7 + 3)
		var k: float = fposmod(u, 1.0)
		var x0: float = area.position.x + MeadowLife.hash01(i * 13 + 1) * area.size.x
		# Each drop lands on its own ground depth, so splashes spread over the field, not one line.
		var land: float = 0.18 + 0.82 * MeadowLife.hash01(i * 17 + int(u) * 5 + 9)
		var y_end: float = area.position.y + fall_h * land
		var y: float = area.position.y + (y_end - area.position.y) * (k / 0.92) if k < 0.92 else y_end
		var x: float = x0 + slant * (y - area.position.y)
		var px: int = int(floorf(x))
		var py: int = int(floorf(y))
		if not view.has_point(Vector2(px, py)):
			continue
		if k < 0.92:
			var streak: int = 3 if near else 2
			for j in streak:
				draw_rect(Rect2(px - int(floorf(float(j) * slant + 0.5)), py - j, 1, 1), palette[IDX_NEAR if near else IDX_FAR])
		elif k < 0.97:
			draw_rect(Rect2(px - 1, py, 3, 1), palette[IDX_NEAR if near else IDX_FAR])
		else:
			draw_rect(Rect2(px, py - 1, 1, 1), palette[IDX_NEAR if near else IDX_FAR])
