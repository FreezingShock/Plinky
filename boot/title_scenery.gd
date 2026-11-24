class_name TitleScenery
extends Control
## Everything on the title backdrop that the shader does not draw: a pine line along the mid ridge, a windmill and a
## cottage with a smoke trail, two big trees with swaying canopies, fireflies over the meadow, birds crossing the sky
## and a few leaves in the wind. All of it is baked once into small textures (or drawn as whole-texel rects) in meadow
## palette indices, snapped to the 640x360 texel grid, and shifted by the same whole-texel parallax as the layer it
## sits in (matching title_background.gdshader's layer_shift). Reduce motion keeps it all still.

const W: int = 640
const H: int = 360
## How far the backdrop reaches past the 640x360 art on each side, in texels. Pre-game screens fill any window, so a
## wide view shows this much more art on each side. 480 covers a view up to 1600 texels wide.
const PAD: int = 480
const GRADE_SHADER: Shader = preload("res://boot/title_scenery.gdshader")
const MID_K: float = 0.38
const NEAR_K: float = 1.0
const TREES: Array[Dictionary] = [
	{"x": 590.0, "base": 306.0, "r": 21, "h": 58, "seed": 3},
	{"x": 536.0, "base": 288.0, "r": 14, "h": 40, "seed": 11},
]

var parallax: Vector2 = Vector2.ZERO

## Where the 640x360 art sits in this control, in texels: centred, whole texels. Zero when the view is 640x360.
var _origin: Vector2 = Vector2.ZERO
var _pal: PackedColorArray
var _t: float = 0.0
var _pines: ImageTexture
var _pines_y0: int = 160
var _canopies: Array[ImageTexture] = []
var _trunks: Array[ImageTexture] = []
var _flies: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
## Night and day amounts 0..1 from TitleMood: fireflies come out in the dark, birds fly in the light.
var _night: float = 0.0
var _day: float = 1.0


## Mirror of mid_ridge() in title_background.gdshader.
static func mid_ridge(x: float) -> float:
	return 200.0 - 7.0 * sin(x * 0.021 + 1.0) - 4.0 * sin(x * 0.067) - 3.0 * sin(x * 0.13 + 2.0)


## Mirror of near_hill() in title_background.gdshader.
static func near_hill(x: float) -> float:
	return 252.0 - 34.0 * exp(-pow(x / 140.0, 2.0)) - 7.0 * sin(x * 0.012 + 0.8) - 12.0 * smoothstep(430.0, 640.0, x)


## Whole-texel shift of a layer for a parallax, like the shader's layer_shift().
static func layer_shift(par: Vector2, k: float) -> Vector2:
	return (par * k + Vector2(0.5, 0.5)).floor()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var grade := ShaderMaterial.new()
	grade.shader = GRADE_SHADER
	material = grade
	_pal = Palettes.colors(Palettes.MEADOW)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	_pines = _bake_pines(rng)
	for tdef: Dictionary in TREES:
		_canopies.append(_bake_canopy(int(tdef["r"]), int(tdef["h"]), int(tdef["seed"])))
		_trunks.append(_bake_trunk(int(tdef["r"]), int(tdef["h"]), int(tdef["seed"])))
	for i in 10:
		_flies.append({"x": rng.randf_range(300.0, 630.0), "y": rng.randf_range(262.0, 336.0), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.4, 0.9)})
	for i in 3:
		_birds.append({"x": rng.randf_range(-float(PAD), float(W + PAD)), "y": rng.randf_range(92.0, 128.0), "sp": rng.randf_range(7.0, 11.0), "ph": rng.randf() * TAU})
	for i in 5:
		_leaves.append({"ph": rng.randf(), "sp": rng.randf_range(9.0, 15.0), "dx": rng.randf_range(-14.0, 6.0), "src": rng.randi_range(0, 1)})


func _process(delta: float) -> void:
	if not (FxConfig.reduce_flashing or MeadowLife.reduce_motion):
		_t += delta
	var origin: Vector2 = ((size - Vector2(W, H)) * 0.5).round()
	if origin != _origin:
		_origin = origin
	queue_redraw()


## Push the time of day in: the tint and night shade grade every scenery texel, and night and day decide which
## life is out (fireflies at night, birds by day).
func set_mood(tint: Color, shade: float, night: float, day: float) -> void:
	var grade: ShaderMaterial = material as ShaderMaterial
	if grade != null:
		grade.set_shader_parameter("tint", tint)
		grade.set_shader_parameter("shade", clampf(shade, 0.0, 1.0))
	_night = clampf(night, 0.0, 1.0)
	_day = clampf(day, 0.0, 1.0)


# ---- Baking ----------------------------------------------------------------------------------------------------------

func _put(img: Image, x: int, y: int, i: int) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, _pal[i])


static func _bayer(x: int, y: int) -> float:
	const B: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (float(B[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0


## Pines along the mid ridge: ink-dark spruce with a lit right flank. Image row 0 is world y `_pines_y0`.
func _bake_pines(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(W + 2 * PAD + 64, 64, false, Image.FORMAT_RGBA8)
	var x: int = 0
	while x < W + 2 * PAD + 64:
		var wx: float = float(x - 32 - PAD)
		var base: int = int(mid_ridge(wx)) + 2 - _pines_y0
		var h: int = rng.randi_range(8, 15)
		var gap: int = rng.randi_range(5, 8)
		for r in h:
			var half: int = 1 + int(float(r) * 0.42)
			var y: int = base - h + r
			for dx in range(-half, half + 1):
				var col: int = 0 if (r == h - 1 or absi(dx) == half and r > 1) else 1
				if dx > 0 and col == 1 and (dx * 2 > half or r % 3 == 0):
					col = 2
				_put(img, x + dx, y, col)
		_put(img, x, base, 0)
		x += gap
	return ImageTexture.create_from_image(img)


## A round canopy (union of blobs) lit from the upper right: dithered light, base, shade and deep, one ink outline.
func _bake_canopy(r: int, h: int, seed_v: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w: int = r * 2 + 12
	var ht: int = int(float(r) * 2.3) + 8
	var img := Image.create(w, ht, false, Image.FORMAT_RGBA8)
	var blobs: Array[Vector3] = []
	blobs.append(Vector3(float(w) * 0.5, float(r) + 4.0, float(r)))
	for i in 4:
		var a: float = rng.randf() * TAU
		blobs.append(Vector3(float(w) * 0.5 + cos(a) * float(r) * 0.62, float(r) + 4.0 + sin(a) * float(r) * 0.55 + float(r) * 0.35, float(r) * rng.randf_range(0.5, 0.72)))
	var inside := PackedByteArray()
	inside.resize(w * ht)
	for y in ht:
		for x in w:
			for b: Vector3 in blobs:
				if Vector2(float(x) - b.x, float(y) - b.y).length() <= b.z:
					inside[y * w + x] = 1
					break
	for y in ht:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			var edge: bool = false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= ht or inside[ny * w + nx] == 0:
					edge = true
			if edge:
				_put(img, x, y, 0)
				continue
			# Light from the upper right: a value 0 (lit) to 1 (shade) from position, blended with leaf-clump noise.
			var lx: float = (float(x) - float(w) * 0.5) / float(r)
			var ly: float = (float(y) - float(r) - 4.0) / float(r)
			var v: float = 0.5 + (-lx * 0.30 + ly * 0.34) + (rng.randf() - 0.5) * 0.12
			var th: float = _bayer(x, y)
			var idx: int = 3
			if v < 0.22 or (v < 0.34 and th < 0.5):
				idx = 4
			elif v > 0.82 or (v > 0.68 and th < 0.5):
				idx = 1
			elif v > 0.52 and th < 0.55:
				idx = 2
			_put(img, x, y, idx)
	return ImageTexture.create_from_image(img)


## Trunk with a ground shadow, one ink outline, earth colour lit on the right.
func _bake_trunk(r: int, h: int, _seed_v: int) -> ImageTexture:
	var tw: int = maxi(4, floori(float(r) / 4.0) + 2)
	var w: int = r * 2 + 12
	var th: int = h + 10
	var img := Image.create(w, th, false, Image.FORMAT_RGBA8)
	# Ground shadow: a dithered ellipse on the meadow.
	var sy: int = th - 4
	for y in range(sy - 4, sy + 5):
		for x in w:
			var ex: float = (float(x) - float(w) * 0.5) / (float(r) * 0.95)
			var ey: float = float(y - sy) / 4.0
			if ex * ex + ey * ey < 1.0 and _bayer(x, y) < 0.62:
				_put(img, x, y, 2)
	var cx: int = floori(float(w) / 2.0)
	for y in range(th - h - 2, th - 3):
		for x in range(cx - floori(float(tw) / 2.0) - 1, cx + floori(float(tw) / 2.0) + 2):
			var xo: int = x - (cx - floori(float(tw) / 2.0))
			var col: int = 0 if (xo < 0 or xo >= tw) else (6 if xo >= floori(float(tw) / 2.0) else 1)
			_put(img, x, y, col)
	return ImageTexture.create_from_image(img)


# ---- Drawing ---------------------------------------------------------------------------------------------------------

func _draw() -> void:
	# Everything below is drawn in art texels (640x360); the transform centres the art in the control.
	draw_set_transform(_origin, 0.0, Vector2.ONE)
	var mid: Vector2 = layer_shift(parallax, MID_K)
	var near: Vector2 = layer_shift(parallax, NEAR_K)
	draw_texture(_pines, Vector2(float(-32 - PAD), float(_pines_y0)) + mid)
	_draw_windmill(Vector2(300.0, mid_ridge(300.0) + 2.0) + mid)
	_draw_cottage(Vector2(356.0, mid_ridge(356.0) + 2.0) + mid)
	_draw_birds()
	_draw_trees(near)
	_draw_flies(near)
	_draw_leaves(near)
	_draw_foreground(layer_shift(parallax, 1.8))


func _r(x: float, y: float, w: float, h: float, i: int) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), _pal[i])


## Four-bladed mill on a tapered tower. The blades turn in quarter steps, three times a second.
func _draw_windmill(base: Vector2) -> void:
	var bx: float = floorf(base.x)
	var by: float = floorf(base.y)
	for r in 15:
		var half: float = 3.0 - float(r) * 0.12
		_r(bx - half - 1.0, by - float(r), half * 2.0 + 3.0, 1.0, 0)
		_r(bx - half, by - float(r), half * 2.0 + 1.0, 1.0, 7 if r % 5 != 4 else 6)
		_r(bx + 1.0, by - float(r), maxf(half, 1.0), 1.0, 6)
	_r(bx - 1.0, by - 3.0, 3.0, 3.0, 0)
	_r(bx, by - 2.0, 1.0, 2.0, 5)
	_r(bx - 4.0, by - 16.0, 9.0, 1.0, 0)
	_r(bx - 3.0, by - 17.0, 7.0, 1.0, 6)
	var hub := Vector2(bx, by - 14.0)
	var step: int = int(_t * 3.0) % 4
	var tips: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for k in 4:
		var d: Vector2 = tips[(k + step) % 4]
		for n in range(1, 10):
			var p: Vector2 = hub + d * float(n)
			_r(p.x, p.y, 1.0, 1.0, 0 if n % 3 == 0 else 7)
			if n > 4:
				var side := Vector2(-d.y, d.x)
				var q: Vector2 = p + side
				_r(q.x, q.y, 1.0, 1.0, 7)
	_r(hub.x - 1.0, hub.y - 1.0, 3.0, 3.0, 0)
	_r(hub.x, hub.y, 1.0, 1.0, 5)


## A cottage with a lit window, a chimney and a smoke trail that rises, thins and wanders.
func _draw_cottage(base: Vector2) -> void:
	var bx: float = floorf(base.x)
	var by: float = floorf(base.y)
	_r(bx - 8.0, by - 9.0, 17.0, 9.0, 0)
	_r(bx - 7.0, by - 8.0, 15.0, 8.0, 7)
	_r(bx + 2.0, by - 8.0, 6.0, 8.0, 6)
	for k in 6:
		_r(bx - 9.0 + float(k), by - 15.0 + float(k), 19.0 - float(k) * 2.0, 1.0, 0)
		_r(bx - 8.0 + float(k), by - 14.0 + float(k), 17.0 - float(k) * 2.0, 1.0, 6 if k < 5 else 5)
	_r(bx + 3.0, by - 17.0, 3.0, 5.0, 0)
	_r(bx + 4.0, by - 16.0, 1.0, 4.0, 6)
	_r(bx - 5.0, by - 6.0, 3.0, 3.0, 0)
	_r(bx - 4.0, by - 5.0, 1.0, 1.0, 5)
	_r(bx + 0.0, by - 5.0, 2.0, 5.0, 0)
	for n in 7:
		var life: float = fposmod(_t * 0.35 + float(n) / 7.0, 1.0)
		var sx: float = bx + 5.0 + sin(life * 6.0 + float(n)) * (1.0 + life * 3.0)
		var sy: float = by - 19.0 - life * 22.0
		var sz: float = 1.0 + floorf(life * 2.5)
		if life < 0.85:
			_r(sx, sy, sz, sz, 4 if life < 0.4 else 3)


## Birds crossing the sky: a two-frame flap, drifting right and wrapping.
func _draw_birds() -> void:
	if _day < 0.15:
		return
	for b: Dictionary in _birds:
		var x: float = fposmod(float(b["x"]) + _t * float(b["sp"]) + float(PAD + 20), float(W + 2 * PAD + 40)) - float(PAD + 20)
		var y: float = floorf(float(b["y"]) + sin(_t * 0.7 + float(b["ph"])) * 3.0)
		var up: bool = int(_t * 4.0 + float(b["ph"])) % 2 == 0
		x = floorf(x)
		if up:
			_r(x - 2.0, y, 2.0, 1.0, 0)
			_r(x + 1.0, y, 2.0, 1.0, 0)
			_r(x - 3.0, y - 1.0, 1.0, 1.0, 0)
			_r(x + 3.0, y - 1.0, 1.0, 1.0, 0)
			_r(x, y + 1.0, 1.0, 1.0, 0)
		else:
			_r(x - 3.0, y + 1.0, 2.0, 1.0, 0)
			_r(x + 2.0, y + 1.0, 2.0, 1.0, 0)
			_r(x - 1.0, y, 3.0, 1.0, 0)


func _draw_trees(near: Vector2) -> void:
	for i in TREES.size():
		var tdef: Dictionary = TREES[i]
		var trunk: ImageTexture = _trunks[i]
		var canopy: ImageTexture = _canopies[i]
		var origin := Vector2(floorf(float(tdef["x"])) - float(trunk.get_width()) * 0.5, floorf(float(tdef["base"])) - float(trunk.get_height())) + near
		draw_texture(trunk, origin)
		var sway: float = roundf(sin(_t * 0.8 + float(tdef["seed"])) * 1.0)
		var cpos := Vector2(floorf(float(tdef["x"])) - float(canopy.get_width()) * 0.5 + sway, origin.y - float(canopy.get_height()) + float(tdef["r"]) * 0.9 + 6.0)
		draw_texture(canopy, cpos + near)


## Fireflies: slow Lissajous wander, blink on a stepped timer, a plus-shaped glow at the peak.
func _draw_flies(near: Vector2) -> void:
	if _night < 0.15:
		return
	for f: Dictionary in _flies:
		var ph: float = float(f["ph"])
		var x: float = float(f["x"]) + sin(_t * float(f["sp"]) + ph) * 12.0
		var y: float = float(f["y"]) + cos(_t * float(f["sp"]) * 0.7 + ph) * 6.0
		var glow: float = sin(_t * 1.6 + ph * 3.0)
		if glow > 0.2:
			_r(x + near.x, y + near.y, 1.0, 1.0, 5)
			if glow > 0.8:
				_r(x + near.x - 1.0, y + near.y, 3.0, 1.0, 4)
				_r(x + near.x, y + near.y - 1.0, 1.0, 3.0, 4)


## Leaves shaken loose from the big tree, tumbling down and to the left on a sine wobble.
func _draw_leaves(near: Vector2) -> void:
	var tdef: Dictionary = TREES[0]
	for l: Dictionary in _leaves:
		var life: float = fposmod(_t / 11.0 * (float(l["sp"]) / 12.0) + float(l["ph"]), 1.0)
		var x: float = float(tdef["x"]) + float(l["dx"]) - life * 70.0 + sin(life * 14.0) * 3.0
		var y: float = float(tdef["base"]) - float(tdef["h"]) - 4.0 + life * 62.0
		_r(x + near.x, y + near.y, 2.0, 1.0, 5 if int(l["src"]) == 0 else 3)


## Tall grass and a few big flowers along the bottom edge, nearest to the camera: dark blades that lean on the wind
## in whole-texel steps, with a lit tip, and flower clusters (stem, petals, centre) between them.
func _draw_foreground(shift: Vector2) -> void:
	var step: int = 6
	for i in range(-PAD / step - 4, (W + PAD) / step + 6):
		var h: float = _hash(float(i) * 1.7)
		var x: float = float(i * step) + h * 4.0 + shift.x
		var ht: float = 14.0 + _hash(float(i) * 5.3) * 18.0
		var lean: float = roundf(sin(_t * 1.3 + float(i) * 0.5) * 1.5)
		var base: float = 360.0 + shift.y * 0.5
		for r in int(ht):
			var k: float = float(r) / ht
			var bx: float = x + lean * k * k * 2.0
			var col: int = 0 if r < 3 else (1 if k < 0.85 else 2)
			_r(bx, base - float(r), 2.0 if r < int(ht) - 4 else 1.0, 1.0, col)
		if h > 0.8:
			var fx: float = x + 3.0 + lean
			var fy: float = base - ht - 2.0
			_r(fx, fy, 1.0, 3.0, 2)
			_r(fx - 1.0, fy - 2.0, 3.0, 3.0, 5 if h > 0.9 else 7)
			_r(fx, fy - 1.0, 1.0, 1.0, 6)


static func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)
