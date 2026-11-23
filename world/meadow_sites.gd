class_name MeadowSites
extends RefCounted
## Where things are in the meadow, for sound: which surface a foot lands on, how close the lake or
## pond is, how close the trees are. Pure lookups in texel space (640x360 frame), no nodes.
## Sources: placements3d.json (pads, gate, water, trees) and ground.png (the sand path is dithered
## in two cream colours, so sand is "enough cream texels around the foot").

const MEADOW_PLACEMENTS: String = "res://assets/art/zone1/meadow3d/placements3d.json"
const MEADOW_GROUND: String = "res://assets/art/zone1/meadow3d/ground.png"
const MEADOW_OFFSET: Vector2i = Vector2i(100, 60)   # same bleed as WalkMask.OFFSET

const SAND_A: Color = Color8(242, 230, 160)
const SAND_B: Color = Color8(246, 239, 217)
const SAND_RADIUS: int = 2          # 5x5 window around the foot
const SAND_MIN_FRACTION: float = 0.3
const WOOD_RX: float = 14.0         # pad plates are wood: same half extents as TexelPad.HALF
const WOOD_RY: float = 7.0
const WATER_RANGE: float = 90.0     # texels from the shore where lapping fades to nothing
const TREE_RANGE: float = 70.0      # texels from a trunk where birdsong fades to nothing
const TREE_KINDS: Array[String] = ["oak", "pine"]

const GRASS: StringName = &"grass"
const SAND: StringName = &"sand"
const WOOD: StringName = &"wood"

static var _placements: String = MEADOW_PLACEMENTS
static var _ground_path: String = MEADOW_GROUND
static var _offset: Vector2i = MEADOW_OFFSET
static var _loaded: bool = false
static var _wood: Array[Vector2] = []
static var _water: Array[Dictionary] = []     # {c: Vector2, r: Vector2, w: float}
static var _trees: Array[Vector2] = []
static var _ground: Image = null


## Points the lookups at another zone's placements and ground (an empty placements path means the meadow).
static func use(placements: String, ground: String, offset: Vector2i) -> void:
	var p: String = MEADOW_PLACEMENTS if placements == "" else placements
	var g: String = MEADOW_GROUND if ground == "" else ground
	if p == _placements and g == _ground_path and offset == _offset:
		return
	_placements = p
	_ground_path = g
	_offset = offset
	_loaded = false
	_wood.clear()
	_water.clear()
	_trees.clear()
	_ground = null


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_placements))
	if data is Dictionary:
		for a: Variant in (data as Dictionary).get("anchors", []):
			var d: Dictionary = a as Dictionary
			var kind: String = str(d.get("kind", ""))
			var c := Vector2(float(d.get("sx", 0.0)), float(d.get("sy", 0.0)))
			if kind == "pad" or kind == "gate" or kind == "arch":
				_wood.append(c)
			elif kind == "water":
				var r := Vector2(maxf(float(d.get("rx", 1.0)), 1.0), maxf(float(d.get("ry", 1.0)), 1.0))
				_water.append({"c": c, "r": r, "w": 1.0 if r.x > 40.0 else 0.6})   # the pond laps softer than the lake
		for s: Variant in (data as Dictionary).get("sprites", []):
			var d: Dictionary = s as Dictionary
			if TREE_KINDS.has(str(d.get("kind", ""))):
				var foot: Array = d.get("foot", []) as Array
				if foot.size() == 2:
					_trees.append(Vector2(float(foot[0]), float(foot[1])))
	if ResourceLoader.exists(_ground_path):
		var tex: Texture2D = load(_ground_path) as Texture2D
		if tex != null:
			_ground = tex.get_image()


static func _is_sand(c: Color) -> bool:
	return c.is_equal_approx(SAND_A) or c.is_equal_approx(SAND_B)


## Surface under a foot at texel p: &"wood", &"sand" or &"grass".
static func surface_at(p: Vector2) -> StringName:
	_load()
	for w: Vector2 in _wood:
		var d: Vector2 = p - w
		if (d.x * d.x) / (WOOD_RX * WOOD_RX) + (d.y * d.y) / (WOOD_RY * WOOD_RY) <= 1.0:
			return WOOD
	if _ground == null:
		return GRASS
	var cx: int = int(floorf(p.x)) + _offset.x
	var cy: int = int(floorf(p.y)) + _offset.y
	var hits: int = 0
	var total: int = 0
	for dy in range(-SAND_RADIUS, SAND_RADIUS + 1):
		for dx in range(-SAND_RADIUS, SAND_RADIUS + 1):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= _ground.get_width() or y >= _ground.get_height():
				continue
			total += 1
			if _is_sand(_ground.get_pixel(x, y)):
				hits += 1
	if total > 0 and float(hits) / float(total) >= SAND_MIN_FRACTION:
		return SAND
	return GRASS


## 0..1: how loud the shore should be at p. 1 at the water's edge, 0 at WATER_RANGE texels away.
static func water_proximity(p: Vector2) -> float:
	_load()
	var best: float = 0.0
	for w: Dictionary in _water:
		var c: Vector2 = w["c"] as Vector2
		var r: Vector2 = w["r"] as Vector2
		var q := Vector2((p.x - c.x) / r.x, (p.y - c.y) / r.y)
		var edge: float = maxf(q.length() - 1.0, 0.0) * sqrt(r.x * r.y)   # texels outside the shore
		var k: float = clampf(1.0 - edge / WATER_RANGE, 0.0, 1.0)
		best = maxf(best, k * k * (w["w"] as float))
	return best


## 0..1: how much birdsong at p. Several nearby trees add up; one is enough for about half.
static func tree_proximity(p: Vector2) -> float:
	_load()
	var sum: float = 0.0
	for t: Vector2 in _trees:
		var d: float = Vector2(p.x - t.x, (p.y - t.y) * 2.0).length()   # y doubled: the view is 2:1
		var k: float = clampf(1.0 - d / TREE_RANGE, 0.0, 1.0)
		sum += k * k
	return clampf(sum * 0.6, 0.0, 1.0)


## For tests.
static func counts() -> Dictionary:
	_load()
	return {"wood": _wood.size(), "water": _water.size(), "trees": _trees.size(), "ground": _ground != null}
