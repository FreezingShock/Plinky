class_name WalkMask
extends RefCounted
## Where the walker may stand in the meadow. Baked by tools/art/gen_meadow3d.py (walkable.png, same
## 840x480 frame as ground.png, so texel p in the 640x360 world frame is pixel p + OFFSET).
## Grass and path are walkable; water, cliffs, mountains, tree trunks, rocks and crystals are not.

const PATH: String = "res://assets/art/zone1/meadow3d/walkable.png"   # the meadow, used when a zone names no mask
const OFFSET: Vector2i = Vector2i(100, 60)   # the meadow's; other zones pass their own to use()

static var path: String = PATH
static var offset: Vector2i = OFFSET
static var _img: Image = null
static var _tried: bool = false


## Switches to another zone's mask (an empty path means the meadow). The mask loads on first use.
static func use(mask_path: String, mask_offset: Vector2i = OFFSET) -> void:
	var p: String = PATH if mask_path == "" else mask_path
	offset = mask_offset
	if p == path:
		return
	path = p
	_img = null
	_tried = false


static func image() -> Image:
	if not _tried:
		_tried = true
		var tex: Texture2D = load(path) as Texture2D   # imported resource: works in exports too
		if tex != null:
			_img = tex.get_image()
	return _img


static func available() -> bool:
	return image() != null


## True when the texel is walkable. With no mask loaded everything is walkable (never traps the walker).
static func walkable(p: Vector2) -> bool:
	var im: Image = image()
	if im == null:
		return true
	var x: int = int(floorf(p.x)) + offset.x
	var y: int = int(floorf(p.y)) + offset.y
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return false
	return im.get_pixel(x, y).r > 0.5


## Closest walkable texel to p (ring search, vertical distance doubled to match the 2:1 view).
## Returns p unchanged when it is already walkable or nothing walkable is within max_r.
static func nearest(p: Vector2, max_r: int = 80) -> Vector2:
	if walkable(p):
		return p
	var best: Vector2 = p
	var best_d: float = INF
	for r in range(1, max_r + 1):
		if best_d <= float(r - 1) * float(r - 1):
			break
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q: Vector2 = p + Vector2(dx, dy)
				var d: float = float(dx * dx) + float(dy * dy) * 4.0
				if d < best_d and walkable(q):
					best_d = d
					best = q
	return best


## Like nearest(), but the result also has `inset` walkable texels straight south of it, so a click near a ledge
## lands a little back from the lip instead of on the edge (the ring and the walker's stop stay on solid ground).
## A click that is already well inside the walkable area is left exactly where it is.
static func nearest_inset(p: Vector2, inset: int = 6, max_r: int = 80) -> Vector2:
	if walkable(p) and walkable(p + Vector2(0.0, float(inset))):
		return p
	var best: Vector2 = nearest(p, max_r)
	var best_d: float = INF
	var found: bool = false
	for r in range(0, max_r + 1):
		if found and best_d <= float(r - 1) * float(r - 1):
			break
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q: Vector2 = p + Vector2(dx, dy)
				var d: float = float(dx * dx) + float(dy * dy) * 4.0
				if d < best_d and walkable(q) and walkable(q + Vector2(0.0, float(inset))):
					best_d = d
					best = q
					found = true
	return best


## ---- routes ----
## Tap-to-move walks a straight line, which stops at the first lake or tree. route() plans around them: an A* search over a
## coarse grid of the mask (a cell is open only when every sample in it is walkable, so a route keeps a little clear of edges),
## then pulled tight so the walker cuts every corner the exact mask allows. Built once per mask, on the first blocked tap.
const CELL: int = 4

static var _grid: AStarGrid2D = null
static var _grid_path: String = ""


## True when a straight walk from a to b stays on walkable texels (sampled every texel).
static func line_clear(a: Vector2, b: Vector2) -> bool:
	var d: Vector2 = b - a
	var n: int = maxi(1, ceili(d.length()))
	for i in range(1, n + 1):
		if not walkable(a + d * (float(i) / float(n))):
			return false
	return true


static func _build_grid() -> void:
	var im: Image = image()
	if im == null:
		return
	if im.is_compressed():
		im = im.duplicate() as Image
		im.decompress()
	_grid_path = path
	var cols: int = ceili(float(im.get_width()) / float(CELL))
	var rows: int = ceili(float(im.get_height()) / float(CELL))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var w: int = im.get_width()
	var h: int = im.get_height()
	var data: PackedByteArray = im.get_data()
	var bpp: int = data.size() / maxi(w * h, 1)   # bytes per pixel; the first byte is red for every format the mask loads as
	var solid: Array[Vector2i] = []
	for cy in rows:
		for cx in cols:
			var open: bool = true
			for oy: int in [0, CELL - 1]:
				for ox: int in [0, CELL - 1]:
					var px: int = mini(cx * CELL + ox, w - 1)
					var py: int = mini(cy * CELL + oy, h - 1)
					if data[(py * w + px) * bpp] <= 127:
						open = false
			if open:
				var mx: int = mini(cx * CELL + CELL / 2, w - 1)
				var my: int = mini(cy * CELL + CELL / 2, h - 1)
				open = data[(my * w + mx) * bpp] > 127
			if not open:
				solid.append(Vector2i(cx, cy))
	for c: Vector2i in solid:
		grid.set_point_solid(c, true)
	_grid = grid


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + float(offset.x)) / float(CELL)), floori((p.y + float(offset.y)) / float(CELL)))


static func _open_cell_near(c: Vector2i, max_r: int = 10) -> Vector2i:
	if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
		return c
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for dy in range(-max_r, max_r + 1):
		for dx in range(-max_r, max_r + 1):
			var q := Vector2i(c.x + dx, c.y + dy)
			if _grid.is_in_boundsv(q) and not _grid.is_point_solid(q):
				var d: int = dx * dx + dy * dy * 4
				if d < best_d:
					best_d = d
					best = q
	return best


## Waypoints for the walker from `from` to `to`, the last being `to`. A clear straight walk is just [to]. Empty when no route exists
## (a click on an island the walker cannot reach), and the caller then walks straight and stops at the edge, as it always did.
static func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line_clear(from, to):
		out.append(to)
		return out
	if _grid == null or _grid_path != path:
		_build_grid()
	if _grid == null:
		return out
	var a: Vector2i = _open_cell_near(_cell_of(from))
	var b: Vector2i = _open_cell_near(_cell_of(to))
	if a.x < 0 or b.x < 0:
		return out
	var ids: Array[Vector2i] = _grid.get_id_path(a, b)
	if ids.is_empty():
		return out
	var pts: Array[Vector2] = [from]
	for id: Vector2i in ids:
		pts.append(Vector2(float(id.x * CELL + CELL / 2 - offset.x), float(id.y * CELL + CELL / 2 - offset.y)))
	pts.append(to)
	# pull it tight: from each kept point jump to the furthest later point that is a clear straight walk
	var i: int = 0
	while i < pts.size() - 1:
		var j: int = i + 1
		while j + 1 < pts.size() and line_clear(pts[i], pts[j + 1]):
			j += 1
		out.append(pts[j])
		i = j
	return out

