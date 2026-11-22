class_name WalkMask
extends RefCounted
## Where the walker may stand in the meadow. Baked by tools/art/gen_meadow3d.py (walkable.png, same
## 840x480 frame as ground.png, so texel p in the 640x360 world frame is pixel p + OFFSET).
## Grass and path are walkable; water, cliffs, mountains, tree trunks, rocks and crystals are not.

const PATH: String = "res://assets/art/zone1/meadow3d/walkable.png"
const OFFSET: Vector2i = Vector2i(100, 60)

static var _img: Image = null
static var _tried: bool = false


static func image() -> Image:
	if not _tried:
		_tried = true
		var tex: Texture2D = load(PATH) as Texture2D   # imported resource: works in exports too
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
	var x: int = int(floorf(p.x)) + OFFSET.x
	var y: int = int(floorf(p.y)) + OFFSET.y
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
