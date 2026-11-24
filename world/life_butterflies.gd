class_name LifeButterflies
extends RefCounted
## Butterflies of the zone 1 world life. LifeCritters owns one; LifeAir draws it at z 10 (no nodes of its own). They rest on
## flower spots (the blossom beds in the backdrop, "flowers" in the life data), flap in place, and flit to another bed
## now and then. A walker that comes close sends them off to a far bed. They are out by day in spring and summer, a few
## in autumn, and none at night, in winter or in rain (MeadowLife.butterfly_share). Under reduce motion they stay on
## their bed and flap in place. Palette indices, no alpha, drawn in LifeAir's 12 fps steps.

const BUTTERFLIES: int = 6        # the most that are ever out (summer noon)
const HOVER_MIN: float = 2.5      # seconds on a bed before the next flit
const HOVER_MAX: float = 6.0
const FLIT_MIN: float = 18.0      # texels: the nearest bed a flit may go to
const FLIT_MAX: float = 110.0     # texels: the farthest
const FLIT_SPEED: float = 24.0    # texels per second
const SCATTER_SPEED: float = 55.0
const SCARE: float = 30.0         # walker distance that sends a butterfly off
const ORBIT_RX: float = 4.0       # wobble on the bed, texels
const ORBIT_RY: float = 1.5
const ORBIT_SPEED: float = 1.7    # radians per second
const FADE_RATE: float = 0.8      # per second: how fast a butterfly dissolves in or out
const DEFAULT_DRIFT: Array = [34.0, 104.0, 572.0, 226.0]  # fallback beds when the data has no flowers

## Butterfly frames, 7 x 4 texels, centred on column 3. a = accent wing, e = earth wing, k = ink body.
const BUTTERFLY_OPEN: Array = ["aa.k.aa", "aaakaaa", "ee.k.ee", ".e.k.e."]
const BUTTERFLY_CLOSED: Array = ["..k.k..", "...k...", "..aka..", "..eke.."]

## Wing colour pairs (big wing, small wing) as palette indices: accent over earth, paper over accent, light over earth.
const WINGS: Array = [[5, 6], [7, 5], [4, 6]]
const IDX_INK: int = 0
const IDX_EARTH: int = 6

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _beds: Array[Vector2] = []
var _flies: Array[Dictionary] = []   # {bed, pos, from, to, t, dur, hover, angle, fade, seed}
var _ci: CanvasItem
var _view: Rect2 = Rect2()
var _t: float = 0.0


## `life` is the parsed life data (MeadowLife.load_data). Beds are the flower spots, or a spread of points in the drift box.
func setup(life: Dictionary) -> void:
	_beds.clear()
	for p: Variant in life.get("flowers", []) as Array:
		var a: Array = p as Array
		_beds.append(Vector2(float(a[0]), float(a[1])))
	if _beds.is_empty():
		var dr: Array = life.get("drift", DEFAULT_DRIFT) as Array
		var box := Rect2(float(dr[0]), float(dr[1]), float(dr[2]), float(dr[3]))
		for i: int in 16:
			_beds.append(box.position + box.size * Vector2(MeadowLife.hash01(i * 2 + 1), MeadowLife.hash01(i * 2 + 2)))
	_flies.clear()
	for i: int in BUTTERFLIES:
		var bed: int = int(MeadowLife.hash01(i * 13 + 4) * float(_beds.size())) % _beds.size()
		var p: Vector2 = _beds[bed]
		_flies.append({"bed": bed, "pos": p, "from": p, "to": p, "t": 0.0, "dur": 0.0,
			"hover": HOVER_MIN + MeadowLife.hash01(i * 5 + 9) * (HOVER_MAX - HOVER_MIN),
			"angle": MeadowLife.hash01(i * 3 + 7) * TAU, "fade": 0.0, "seed": i})


## Moves the butterflies by delta. `wp` is the walker's position in the frame.
func update(delta: float, wp: Vector2) -> void:
	_t += delta
	var share: float = MeadowLife.butterfly_share()
	var budget: int = GraphicsQuality.life_scaled(BUTTERFLIES)
	for i: int in _flies.size():
		var f: Dictionary = _flies[i]
		var out: bool = i < budget and MeadowLife.hash01(int(f.seed) * 19 + 5) < share
		f.fade = move_toward(float(f.fade), 1.0 if out else 0.0, FADE_RATE * delta)
		if float(f.fade) <= 0.0:
			f.dur = 0.0
			f.pos = _beds[int(f.bed)]
			continue
		_update(f, delta, wp)


func _update(f: Dictionary, delta: float, wp: Vector2) -> void:
	if MeadowLife.reduce_motion:
		f.pos = _beds[int(f.bed)]   # in place: wings flap, nothing travels
		return
	if float(f.dur) > 0.0:
		f.t = float(f.t) + delta
		var k: float = clampf(float(f.t) / float(f.dur), 0.0, 1.0)
		var a: Vector2 = f["from"] as Vector2
		var b: Vector2 = f["to"] as Vector2
		var mid: Vector2 = a.lerp(b, 0.5) + Vector2(0.0, -10.0)   # the flit arcs up over the grass
		f.pos = a.lerp(mid, k).lerp(mid.lerp(b, k), k)
		if k >= 1.0:
			f.dur = 0.0
			f.bed = int(f.target_bed)
			f.hover = HOVER_MIN + MeadowLife.hash01(int(f.seed) * 7 + int(_t * 3.0)) * (HOVER_MAX - HOVER_MIN)
		return
	var bed: Vector2 = _beds[int(f.bed)]
	f.angle = float(f.angle) + delta * ORBIT_SPEED
	f.pos = bed + Vector2(cos(float(f.angle)) * ORBIT_RX, sin(float(f.angle)) * ORBIT_RY)
	if MeadowLife.iso_distance(f.pos as Vector2, wp) < SCARE:
		_flit(f, wp, true)
		return
	f.hover = float(f.hover) - delta
	if float(f.hover) <= 0.0:
		_flit(f, wp, false)


## Starts a flight to another bed. A scatter (walker close) goes to a far bed the walker is not near; a normal flit
## goes to a bed within FLIT_MIN..FLIT_MAX. The search starts at a seed-and-time offset, so beds are not always the same.
func _flit(f: Dictionary, wp: Vector2, scatter: bool) -> void:
	var here: Vector2 = f.pos as Vector2
	var pick: int = int(MeadowLife.hash01(int(f.seed) * 31 + int(_t * 7.0)) * float(_beds.size()))
	var best: int = -1
	for j: int in _beds.size():
		var k: int = (j + pick) % _beds.size()
		if k == int(f.bed):
			continue
		var d: float = MeadowLife.iso_distance(_beds[k], here)
		var ok: bool = d >= 90.0 and MeadowLife.iso_distance(_beds[k], wp) >= SCARE if scatter \
			else (d >= FLIT_MIN and d <= FLIT_MAX)
		if ok:
			best = k
			break
	if best < 0:
		return   # nothing suitable: keep hovering
	f.from = here
	f.to = _beds[best]
	f.target_bed = best
	f.t = 0.0
	f.dur = MeadowLife.iso_distance(here, _beds[best]) / (SCATTER_SPEED if scatter else FLIT_SPEED)


## Draws the butterflies into `ci`. `tb` is LifeAir's stepped time.
func draw(ci: CanvasItem, tb: float) -> void:
	_ci = ci
	_view = GraphicsQuality.visible_local_rect(ci)
	for i: int in _flies.size():
		var f: Dictionary = _flies[i]
		var fade: float = float(f.fade)
		if fade <= 0.0:
			continue
		var p: Vector2 = f.pos as Vector2
		var origin: Vector2i = Vector2i(roundi(p.x), roundi(p.y))
		if _view.has_area() and not _view.grow(10.0).has_point(p):
			continue
		var open: bool = int(tb * 6.0 + float(f.seed)) % 2 == 0
		var rows: Array = BUTTERFLY_OPEN if open else BUTTERFLY_CLOSED
		var flip: bool = (float(f.dur) > 0.0 and (f.to as Vector2).x < (f.from as Vector2).x) \
			or (float(f.dur) <= 0.0 and int(f.seed) % 2 == 1)
		var wing: Array = WINGS[int(f.seed) % WINGS.size()] as Array
		var top: int = rows.size() / 2
		for ry: int in rows.size():
			var row: String = rows[ry]
			for rx: int in row.length():
				var ch: String = row[rx]
				if ch == ".":
					continue
				var col: int = rx - 3 if not flip else 3 - rx
				var idx: int = IDX_INK if ch == "k" else (int(wing[0]) if ch == "a" else int(wing[1]))
				var x: int = origin.x + col
				var y: int = origin.y + ry - top
				if MeadowLife.dissolved(fade, x, y):
					_ci.draw_rect(Rect2(x, y, 1, 1), palette[idx])
