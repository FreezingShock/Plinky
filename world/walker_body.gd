class_name WalkerBody
extends Node2D
## Draws the walker from the atlas one texel row at a time, so a pose can be squashed, stretched and leaned
## while every texel stays on the grid (no rotation, no blur, no sub-texel positions). TexelWalker sets the pose
## fields each frame; this node only draws. Also owns the little dust puffs kicked up by sprints, slides and landings.

const ATLAS: Texture2D = preload("res://assets/art/walker/walker_atlas.png")
const CELL: int = 64
## The feet sit on row FEET.y - 1 of the cell, centred on column FEET.x. The node origin is that ground point.
const FEET: Vector2i = Vector2i(32, 47)
const COLS: int = 16                  ## half the drawn width: columns FEET.x - COLS .. FEET.x + COLS
const SPRITE_H: int = 44              ## rows scanned above the feet
const DUST_LIFE: float = 0.45

var cell: Vector2i = Vector2i.ZERO    ## (col, row) in the atlas
var flip: bool = false
var sy: float = 1.0                   ## height scale (squash < 1, stretch > 1), the feet stay planted
var sx: float = 1.0                   ## width scale
var lean: float = 0.0                 ## texels the top moves toward screen right (negative = left)
var lift: float = 0.0                 ## height above the ground, texels
var colors: PackedColorArray = PackedColorArray()   ## zone palette, for the dust
var _puffs: Array[Dictionary] = []    ## {p: Vector2 world offset from the walker's spawn frame, v: Vector2, t: float, n: int}


## Source height (rows above the feet) that destination row d shows at height scale `scale`.
static func src_height(d: int, scale: float) -> int:
	return clampi(floori(float(d) / maxf(scale, 0.05)), 0, SPRITE_H - 1)


## Horizontal shift of a row at height h out of a sprite `top` rows tall: zero at the feet, `lean` at the top.
static func lean_shift(h: int, top: int, amount: float) -> int:
	var u: float = clampf(float(h) / float(maxi(top, 1)), 0.0, 1.0)
	return roundi(amount * u * u)


## Even width, so the mirrored draw stays symmetrical.
static func row_width(scale_x: float) -> int:
	return maxi(2, roundi(float(COLS) * maxf(scale_x, 0.2)) * 2)


func puff(world_pos: Vector2, vel: Vector2) -> void:
	if _puffs.size() >= 24:
		_puffs.remove_at(0)
	_puffs.append({"p": world_pos, "v": vel, "t": 0.0})


func _process(delta: float) -> void:
	for i: int in range(_puffs.size() - 1, -1, -1):
		var d: Dictionary = _puffs[i]
		d["t"] = float(d["t"]) + delta
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		d["v"] = (d["v"] as Vector2) * (1.0 - minf(delta * 5.0, 1.0))
		if float(d["t"]) >= DUST_LIFE:
			_puffs.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var base_x: float = float(cell.x * CELL + FEET.x - COLS)
	var base_y: float = float(cell.y * CELL + FEET.y - 1)
	var w: int = row_width(sx)
	var rows: int = ceili(float(SPRITE_H) * sy)
	var up: float = -roundf(lift)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0) if flip else Vector2.ONE)
	var dir: float = -1.0 if flip else 1.0   # mirrored space: a screen-right lean is a local-left offset
	for d: int in rows:
		var h: int = src_height(d, sy)
		var off: int = int(dir * float(lean_shift(d, rows, lean)))
		var src := Rect2(base_x, base_y - float(h), float(COLS * 2), 1.0)
		var dst := Rect2(float(-w / 2 + off), up - 1.0 - float(d), float(w), 1.0)
		draw_texture_rect_region(ATLAS, dst, src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var parent: Node2D = get_parent() as Node2D
	if parent == null or colors.size() < 8:
		return
	for pf: Dictionary in _puffs:
		var life: float = float(pf["t"]) / DUST_LIFE
		var at: Vector2 = ((pf["p"] as Vector2) - parent.position).round()
		var size: float = 2.0 if life < 0.5 else 1.0
		var col: Color = colors[7] if life < 0.3 else colors[5]
		if life > 0.75 and (int(at.x) + int(at.y)) % 2 == 0:
			continue   # thins out as a 2x2 dither, never an alpha fade
		draw_rect(Rect2(at, Vector2(size, size)), col)
