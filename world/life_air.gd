class_name LifeAir
extends Node2D
## Air and light layer of the zone 1 world life. MeadowScene adds it as its child at z_index 10, so it
## draws over the walker, pads and gate. Every element is a pure function of time, redrawn in 12 fps
## steps (8 on Low, see GraphicsQuality; lower levels also draw fewer fireflies and pollen) with no alpha: fireflies with a Bayer-dithered halo, lantern and shrine glow, drifting pollen and
## leaves, two butterflies, sparkles on the water cove, and a shimmer that runs round each ready pad.
## Colours are palette indices (art-bible section 3), so a zone palette swap re-tints the whole layer.
## Every position comes from world/meadow_life.json (anchor data), so the layer follows the art.
## Z order: world layers sit above the HUD's z order, so main.gd raises the HUD z_index above them.

const STEP: float = 1.0 / 12.0
const FIREFLIES: int = 12
const POLLEN: int = 20            # of which every 4th is a leaf; the day count scales it (see _pollen_count)
const POLLEN_DAY: int = 14
const FIREFLIES_DAY: int = 2      # a few stragglers at noon; the rest come out as the light goes
const BUTTERFLIES: int = 6        # the most that are ever out (summer noon); the season, light and rain thin them
const WATER_SPARKLES: int = 6
const PAD_PERIOD: float = 2.4
const PAD_HALF: Vector2 = Vector2(14.0, 7.0)  # must match TexelPad.HALF (kept local so this script compiles without autoloads)
const DEFAULT_DRIFT: Array = [34.0, 104.0, 572.0, 226.0]  # fallback if the data has no drift box

## Palette roles used here (art-bible section 3).
const IDX_INK: int = 0
const IDX_DARK: int = 1
const IDX_LIGHT: int = 4
const IDX_ACCENT: int = 5
const IDX_EARTH: int = 6
const IDX_PAPER: int = 7

## Butterfly frames, 7 x 4 texels, centred on column 3. a = accent wing, e = earth wing, k = ink body.
const BUTTERFLY_OPEN: Array = ["aa.k.aa", "aaakaaa", "ee.k.ee", ".e.k.e."]
const BUTTERFLY_CLOSED: Array = ["..k.k..", "...k...", "..aka..", "..eke.."]

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _drift: Rect2 = Rect2()
var _lights: Array = []
var _water: Array[Dictionary] = []   # water ellipses from the data (bounding ellipses)
var _img: Image                       # backdrop pixels, to keep sparkles on water texels
var _origin: Vector2i = Vector2i.ZERO  # where the backdrop's texel (0, 0) sits in the frame
var _pads: Array[Vector2] = []
var _t: float = 0.0
var _pt: float = 0.0               # pollen clock: runs faster in a breeze, so a gust carries it without a jump
var _step: int = -1
var _view: Rect2 = Rect2()             # on-screen part of this layer this redraw; empty = draw everything


func setup(data: Dictionary, backdrop_sprite: Sprite2D) -> void:
	var dr: Array = data.get("drift", DEFAULT_DRIFT) as Array
	_drift = Rect2(float(dr[0]), float(dr[1]), float(dr[2]), float(dr[3]))
	_lights = data.get("lights", []) as Array
	_water.clear()
	for wb: Variant in data.get("water", []) as Array:
		_water.append(wb as Dictionary)
	_img = backdrop_sprite.texture.get_image() if backdrop_sprite.texture != null else null
	_origin = Vector2i(roundi(backdrop_sprite.position.x), roundi(backdrop_sprite.position.y))
	_pads.clear()
	for p: Variant in data.get("pads", []) as Array:
		var a: Array = p as Array
		_pads.append(Vector2(float(a[0]), float(a[1])))
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not MeadowLife.reduce_motion:
		_pt += delta * (0.55 + 0.9 * MeadowLife.wind)
	var s: int = int(_t / GraphicsQuality.life_step())
	if s != _step:
		_step = s
		queue_redraw()


func _draw() -> void:
	var tb: float = float(maxi(_step, 0)) * GraphicsQuality.life_step()  # stepped time: blinks, glow, sparkles
	_view = GraphicsQuality.visible_local_rect(self)
	var tm: float = 0.0 if MeadowLife.reduce_motion else tb  # moving things freeze under reduce-motion
	_draw_lights(tb)
	_draw_water(tb)
	_draw_pads(tm)
	if not MeadowLife.reduce_motion:
		_draw_pollen(tm, tb)
		_draw_butterflies(tm, tb)
	_draw_fireflies(tm, tb)


func _dot(p: Vector2i, idx: int) -> void:
	draw_rect(Rect2(p.x, p.y, 1, 1), palette[idx])


## Fireflies come out with the dark: a couple by day, most of them by dusk, all of them at night, none in the rain.
func _firefly_count() -> int:
	var dark: float = clampf(MeadowLife.night * 1.3 + MeadowLife.low_sun * 0.55, 0.0, 1.0)
	var n: float = lerpf(float(FIREFLIES_DAY), float(FIREFLIES), dark) * (1.0 - MeadowLife.rain)
	return roundi(n * MeadowLife.firefly_season_share())


## Pollen is a daytime thing: full by day, thin at night, and a handful more motes at low sun where the light hits them.
func _pollen_count() -> int:
	var day: float = float(POLLEN_DAY) * (1.0 - MeadowLife.night * 0.85) + float(POLLEN - POLLEN_DAY) * MeadowLife.low_sun
	return roundi(day * (1.0 - 0.8 * MeadowLife.rain))


## Fireflies hover on a slow Lissajous path and blink: a 1.2 s lit phase in a 4 to 7 s cycle.
func _draw_fireflies(tm: float, tb: float) -> void:
	for i: int in GraphicsQuality.life_scaled(_firefly_count()):
		var s: float = float(i)
		var home: Vector2 = Vector2(
			lerpf(_drift.position.x, _drift.end.x, MeadowLife.hash01(i * 3 + 1)),
			lerpf(_drift.position.y, _drift.end.y, MeadowLife.hash01(i * 3 + 2)))
		var p: Vector2 = home + Vector2(
			sin(tm * 0.37 + s * 1.9) * 14.0 + sin(tm * 0.13 + s) * 6.0,
			cos(tm * 0.29 + s * 2.3) * 5.0 - 8.0 + sin(tm * 0.9 + s) * 1.5)
		var pos: Vector2i = Vector2i(roundi(p.x), roundi(p.y))
		if _view.has_area() and not _view.has_point(Vector2(pos)):
			continue
		var cycle: float = 4.0 + MeadowLife.hash01(i * 5 + 2) * 3.0
		var phase: float = fposmod(tb + MeadowLife.hash01(i * 7 + 3) * cycle, cycle)
		if phase >= 1.2:
			_dot(pos, IDX_DARK)  # unlit body, a dark speck
			continue
		var level: int = int(clampf(1.0 - absf(phase - 0.6) / 0.6, 0.0, 1.0) * 3.99)  # 0..3
		_dot(pos, IDX_PAPER if level == 3 else IDX_ACCENT)
		for dy: int in range(-level, level + 1):
			for dx: int in range(-level, level + 1):
				var d: int = absi(dx) + absi(dy)
				if d == 0 or d > level:
					continue
				# Halo fades by ordered dither: the nearer texels are always lit, the far ones sometimes.
				if MeadowLife.bayer(pos.x + dx, pos.y + dy) < 1.0 - float(d) / float(level + 1):
					_dot(pos + Vector2i(dx, dy), IDX_ACCENT)


## Lanterns and the shrine: a dithered glow that flickers one texel in size on a 6 fps beat.
func _draw_lights(tb: float) -> void:
	var beat: int = int(tb * 6.0)
	for k: int in _lights.size():
		var L: Dictionary = _lights[k] as Dictionary
		var c: Vector2i = Vector2i(roundi(float(L.x)), roundi(float(L.y)))
		if _view.has_area() and not _view.grow(12.0).has_point(Vector2(c)):
			continue  # glow is at most 12 texels wide, so a light just off screen can still reach in
		var flick: int = int(MeadowLife.hash01(beat * 7 + k * 101) * 3.0) - 1  # -1, 0 or +1
		var r: int = clampi(int(L.r) + flick, 3, 12)
		_dot(c, IDX_PAPER)
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				# Iso ground is 2:1, so squash the vertical distance to make a round-looking pool of light.
				var dist: float = sqrt(float(dx * dx) + float(dy * dy) * 4.0) / float(r)
				if dist >= 1.0 or (dx == 0 and dy == 0):
					continue
				if 1.0 - dist > MeadowLife.bayer(c.x + dx, c.y + dy):
					_dot(c + Vector2i(dx, dy), IDX_ACCENT)


## Sparkles on the water: each slot lives 0.5 s, then reappears on another water texel.
func _draw_water(tb: float) -> void:
	if _water.is_empty() or _img == null:
		return
	for k: int in WATER_SPARKLES:
		var cycle: float = 1.6 + MeadowLife.hash01(k * 17) * 1.2
		var t_k: float = tb + MeadowLife.hash01(k * 31) * cycle
		var n: int = int(floor(t_k / cycle))
		var age: float = fposmod(t_k, cycle)
		if age > 0.5:
			continue
		var p: Vector2i = _sparkle_spot(k, n)
		if p.x < 0:
			continue
		_dot(p, IDX_PAPER)
		if age < 0.3:
			_dot(p + Vector2i(1, 0), IDX_ACCENT)
			_dot(p + Vector2i(-1, 0), IDX_ACCENT)
			_dot(p + Vector2i(0, -1), IDX_ACCENT)


## A water texel for sparkle slot k in cycle n, or (-1, -1). Picks a water body by seed, then tries a few
## spots inside its ellipse (shrunk to 85% so sparkles stay off the shore). A spot counts only if the
## backdrop shows water there, so bounding-ellipse corners that are grass or sand get no sparkle.
func _sparkle_spot(k: int, n: int) -> Vector2i:
	var body: Dictionary = _water[int(MeadowLife.hash01(k * 53 + n * 7) * _water.size()) % _water.size()]
	var cx: float = float(body.x)
	var cy: float = float(body.y)
	var rx: float = float(body.rx) * 0.85
	var ry: float = float(body.ry) * 0.85
	for tries: int in 4:
		var seed_n: int = k * 97 + n * 13 + tries * 1009
		var ang: float = MeadowLife.hash01(seed_n) * TAU
		var rad: float = sqrt(MeadowLife.hash01(seed_n + 1))
		var q: Vector2 = Vector2(cx + cos(ang) * rx * rad, cy + sin(ang) * ry * rad)
		var p: Vector2i = Vector2i(roundi(q.x), roundi(q.y))
		if _is_water(p):
			return p
	return Vector2i(-1, -1)


## True if the backdrop texel under frame point p is one of the two deep water colours (palette 1 or 2).
func _is_water(p: Vector2i) -> bool:
	var t: Vector2i = p - _origin
	if t.x < 0 or t.y < 0 or t.x >= _img.get_width() or t.y >= _img.get_height():
		return false
	var c: Color = _img.get_pixel(t.x, t.y)
	return c.is_equal_approx(palette[1]) or c.is_equal_approx(palette[2])


## A paper dot runs round the diamond of each ready pad, one lap every 2.4 s, staggered per pad.
## The diamond is PAD_HALF, so the shimmer stays on the pad outline.
func _draw_pads(tm: float) -> void:
	var hx: float = PAD_HALF.x
	var hy: float = PAD_HALF.y
	var corners: Array[Vector2] = [Vector2(0, -hy), Vector2(hx, 0), Vector2(0, hy), Vector2(-hx, 0)]
	for i: int in _pads.size():
		var u: float = fposmod(tm + float(i) * 0.37, PAD_PERIOD) / PAD_PERIOD * 4.0
		var edge: int = int(floor(u)) % 4
		var f: float = u - floor(u)
		var local: Vector2 = corners[edge].lerp(corners[(edge + 1) % 4], f)
		var p: Vector2i = Vector2i(roundi(_pads[i].x + local.x), roundi(_pads[i].y + local.y))
		_dot(p, IDX_PAPER)


## Pollen drifts on the breeze, left to right, and wraps at the edge. Leaves tumble in a 2x1 / 1x2 flutter.
func _draw_pollen(tm: float, tb: float) -> void:
	var glint: bool = MeadowLife.low_sun > 0.35   # motes catch the low sun
	for i: int in GraphicsQuality.life_scaled(_pollen_count()):
		var s: float = float(i)
		var speed: float = 8.0 + MeadowLife.hash01(i * 11) * 8.0
		var x: float = _drift.position.x + fposmod(MeadowLife.hash01(i * 11 + 1) * _drift.size.x + _pt * speed, _drift.size.x)
		var y: float = _drift.position.y + fposmod(MeadowLife.hash01(i * 11 + 2) * _drift.size.y, _drift.size.y) \
			+ sin(tm * 0.5 + s) * 6.0
		var p: Vector2i = Vector2i(roundi(x), roundi(y))
		if i % 4 == 3:
			var flip: bool = int(tm * 4.0 + s) % 2 == 0
			var w: int = 2 if flip else 1
			var h: int = 1 if flip else 2
			draw_rect(Rect2(p.x, p.y, w, h), palette[IDX_EARTH])
		else:
			# Pollen twinkles in place (not motion), so it stays visible under reduce-motion.
			if int(tb * 3.0 + s) % 3 != 0:
				_dot(p, IDX_PAPER if glint and i % 2 == 0 else IDX_ACCENT)


## Butterflies are out by day in spring and summer, a few in autumn, none in winter, at night or in the rain.
## Each has its own wing colours.
func _butterfly_count() -> int:
	return GraphicsQuality.life_scaled(roundi(float(BUTTERFLIES) * MeadowLife.butterfly_share()))


## Wing colour pairs (big wing, small wing) as palette indices: accent over earth, paper over accent, light over earth.
const WINGS: Array = [[IDX_ACCENT, IDX_EARTH], [IDX_PAPER, IDX_ACCENT], [IDX_LIGHT, IDX_EARTH]]


## Butterflies wander on Lissajous loops and flap open and shut at 6 fps.
func _draw_butterflies(tm: float, tb: float) -> void:
	for i: int in _butterfly_count():
		var s: float = float(i)
		var c: Vector2 = Vector2(
			lerpf(_drift.position.x + 40.0, _drift.end.x - 40.0, MeadowLife.hash01(i * 2 + 40)),
			lerpf(_drift.position.y + 20.0, _drift.end.y - 40.0, MeadowLife.hash01(i * 2 + 41)))
		var vx: float = cos(tm * 0.31 + s * 2.1)
		var p: Vector2 = c + Vector2(sin(tm * 0.31 + s * 2.1) * 46.0, cos(tm * 0.23 + s) * 16.0 + sin(tm * 0.7 + s) * 3.0)
		var origin: Vector2i = Vector2i(roundi(p.x), roundi(p.y))
		var open: bool = int(tb * 6.0 + s) % 2 == 0
		var rows: Array = BUTTERFLY_OPEN if open else BUTTERFLY_CLOSED
		var flip: bool = vx < 0.0
		var top: int = rows.size() / 2
		for ry: int in rows.size():
			var row: String = rows[ry]
			for rx: int in row.length():
				var ch: String = row[rx]
				if ch == ".":
					continue
				var col: int = rx - 3 if not flip else 3 - rx
				var wing: Array = WINGS[i % WINGS.size()] as Array
				var idx: int = IDX_INK if ch == "k" else (int(wing[0]) if ch == "a" else int(wing[1]))
				_dot(origin + Vector2i(col, ry - top), idx)
