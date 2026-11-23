class_name LavaFlow
extends Node2D
## The quarry's moving lava. tools/art/gen_quarry.py bakes frame 0 into ground.png and ships every lava tile as a
## strip of 6 frames (placements3d.json "lava": file, x, y, w, h, frames). One sprite per tile shows a slice of its strip,
## stepped about 5 times a second and only while it is on screen. Frozen on frame 0 under Reduce motion, slower on Low.

const STEP: float = 0.2

var _tiles: Array[Dictionary] = []   # {sprite: Sprite2D, w: int, frames: int}
var _clock: float = 0.0
var _frame: int = -1


func setup(dir: String, tiles: Array) -> void:
	for t: Variant in tiles:
		var d: Dictionary = t as Dictionary
		var tex: Texture2D = load(dir + String(d.get("file", ""))) as Texture2D
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.region_enabled = true
		var w: int = int(d.get("w", 1))
		var h: int = int(d.get("h", 1))
		sp.region_rect = Rect2(0.0, 0.0, float(w), float(h))
		sp.position = Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		add_child(sp)
		_tiles.append({"sprite": sp, "w": w, "frames": int(d.get("frames", 1))})


## Frame shown at time t for a strip of n frames.
static func frame_at(t: float, n: int, step: float) -> int:
	return int(floorf(t / maxf(step, 0.01))) % maxi(n, 1)


func _process(delta: float) -> void:
	if MeadowLife.reduce_motion or _tiles.is_empty():
		return
	_clock += delta
	var step: float = maxf(STEP, GraphicsQuality.life_step() * 2.0)
	var f: int = frame_at(_clock, 6, step)
	if f == _frame:
		return
	_frame = f
	var view: Rect2 = GraphicsQuality.visible_local_rect(self)
	for t: Dictionary in _tiles:
		var sp: Sprite2D = t["sprite"] as Sprite2D
		var w: int = t["w"] as int
		if view.has_area() and not view.intersects(Rect2(sp.position, Vector2(float(w), sp.region_rect.size.y))):
			continue
		sp.region_rect = Rect2(float((f % (t["frames"] as int)) * w), 0.0, float(w), sp.region_rect.size.y)
