class_name SkyRain
extends Node2D
## Light rain over the outdoor scenes. The drops fall through the part of the field that is on screen (a window that
## follows the camera). The window is always the whole frame, so `drops` is the count per frame at every zoom (a zoomed-in
## camera has a smaller window in texels, and each drop is bigger on screen), and the cost does not grow with the map.
## Each drop is a pure function of time and its index: no state, no alpha, palette indices only (7 paper for near
## streaks, 4 light for far ones). Redrawn at 12 fps. Drops hit the ground and leave a two-frame splash. Wind slants
## the fall. Intensity 0..1 decides how many of the drops are active.

const STEP: float = 1.0 / 12.0
const IDX_FAR: int = 4
const IDX_NEAR: int = 7
const NEAR_FALL: float = 0.9                 # seconds for a near drop to fall the window
const FAR_FALL: float = 1.3

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
## The field, used only until the layer is on screen (then the camera's view is the window).
var area: Rect2 = Rect2(-110.0, -70.0, 860.0, 500.0)
var drops: int = 900
var intensity: float = 0.0   # 0..1, set by SkyCycle
var wind: float = 0.0        # 0..1, set by SkyCycle
var _t: float = 0.0
var _step: int = -1
var _x0: PackedFloat32Array = PackedFloat32Array()    # per-drop constants, so a redraw does not re-hash every drop
var _phase: PackedFloat32Array = PackedFloat32Array()
var _cached_drops: int = -1


## The hash is a sin() each, and three of them per drop per redraw were the rain's spike frames. Two are constant.
func _cache() -> void:
	_cached_drops = drops
	var cap: int = drops
	_x0.resize(cap)
	_phase.resize(cap)
	for i: int in cap:
		_x0[i] = MeadowLife.hash01(i * 13 + 1)
		_phase[i] = MeadowLife.hash01(i * 7 + 3)


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
	if _cached_drops != drops:
		_cache()
	# The window is the visible part of the field, grown by a margin so the edges never pop. Low draws 40% of the
	# drops, Medium 70% (GraphicsQuality). The look is the same, just lighter rain.
	var view: Rect2 = GraphicsQuality.visible_local_rect(self)
	if not view.has_area():
		view = area
	var wanted: int = int(ceilf(float(drops) * intensity))
	var active: int = mini(GraphicsQuality.life_scaled(wanted), _x0.size())
	var slant: float = 0.15 + 0.5 * wind          # texels sideways per texel fallen
	var top: float = view.position.y - 4.0
	for i in active:
		var near: bool = (i % 2) == 0
		var fall: float = NEAR_FALL if near else FAR_FALL
		var u: float = tb / fall + _phase[i]
		var k: float = fposmod(u, 1.0)
		# Each drop lands at its own depth in the window, so splashes spread over the view, not one line.
		var land: float = 0.18 + 0.82 * MeadowLife.hash01(i * 17 + int(u) * 5 + 9)
		var y_end: float = view.position.y + view.size.y * land
		var y: float = top + (y_end - top) * (k / 0.92) if k < 0.92 else y_end
		var x: float = view.position.x + fposmod(_x0[i] * view.size.x + slant * (y - top), view.size.x)
		var px: int = int(floorf(x))
		var py: int = int(floorf(y))
		if k < 0.92:
			var streak: int = 3 if near else 2
			for j in streak:
				draw_rect(Rect2(px - int(floorf(float(j) * slant + 0.5)), py - j, 1, 1), palette[IDX_NEAR if near else IDX_FAR])
		elif k < 0.97:
			draw_rect(Rect2(px - 1, py, 3, 1), palette[IDX_NEAR if near else IDX_FAR])
		else:
			draw_rect(Rect2(px, py - 1, 1, 1), palette[IDX_NEAR if near else IDX_FAR])
