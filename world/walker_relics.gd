class_name WalkerRelics
extends Node2D
## Equipped relics on the walker. One mote per equipped relic circles the head in that relic's rarity colour, with a
## faint pool of the highest equipped rarity under the feet. Epic and up also sparkle. Presentation only: reads
## RelicInventory, changes no game state. Drawn in texels (1 texel = 1 rect) so it keeps the pixel look.
## Added as a child of TexelWalker; the node sits at the walker's lift so it rises with a jump.

const ORBIT_CENTER: Vector2 = Vector2(0.0, -24.0)   # head height, in texels above the feet
const ORBIT_RX: float = 13.0
const ORBIT_RY: float = 6.0                          # 2:1, like the isometric ground
const SPEED: float = 1.3                             # radians per second
const TRAIL: int = 3                                 # trail points behind each mote
const POOL_RX: float = 10.0
const POOL_RY: float = 3.5
const SPARK_RANK: int = 3                            # Epic and up sparkle
const SPARK_LIFE: float = 0.6
const SPARK_EVERY: float = 0.45

var _phase: float = 0.0
var _ids: Array[StringName] = []
var _colors: Array[Color] = []
var _trails: Array[PackedVector2Array] = []
var _top_rank: int = -1
var _pool_color: Color = Color.TRANSPARENT
var _sparks: Array[Dictionary] = []                  # {p: Vector2, t: float, c: Color}
var _spark_clock: float = 0.0
var _walker: TexelWalker


func _ready() -> void:
	z_index = 1
	_walker = get_parent() as TexelWalker
	_rebuild()


func _rebuild() -> void:
	var inv: RelicInventory = GameState.relics
	_ids = []
	if inv != null:
		_ids = inv.equipped.duplicate()
	_colors.clear()
	_trails.clear()
	_top_rank = -1
	_pool_color = Color.TRANSPARENT
	for id: StringName in _ids:
		var d: RelicDef = inv.defs[id] as RelicDef
		var c: Color = d.rarity.tint()
		_colors.append(c)
		_trails.append(PackedVector2Array())
		if d.rarity.rank > _top_rank:
			_top_rank = d.rarity.rank
			_pool_color = c
	if _top_rank < SPARK_RANK:
		_sparks.clear()


func _process(delta: float) -> void:
	if _walker == null:
		return
	position = Vector2(0.0, -_walker.lift)
	var inv: RelicInventory = GameState.relics
	if inv != null and inv.equipped != _ids:
		_rebuild()
	if _ids.is_empty():
		if visible:
			visible = false
		return
	visible = true
	_phase = fmod(_phase + delta * SPEED, TAU)
	var n: int = _ids.size()
	for i in n:
		var a: float = _phase + TAU * float(i) / float(n)
		var p := ORBIT_CENTER + Vector2(cos(a) * ORBIT_RX, sin(a) * ORBIT_RY)
		var trail: PackedVector2Array = _trails[i]
		trail.append(p)
		while trail.size() > TRAIL:
			trail.remove_at(0)
		_trails[i] = trail
	if _top_rank >= SPARK_RANK:
		_spark_clock -= delta
		if _spark_clock <= 0.0:
			_spark_clock = SPARK_EVERY
			var a: float = randf() * TAU
			var c: Color = _colors[randi() % n]
			_sparks.append({"p": ORBIT_CENTER + Vector2(cos(a) * (ORBIT_RX + 2.0), sin(a) * (ORBIT_RY + 1.0)), "t": 0.0, "c": c})
	var live: Array[Dictionary] = []
	for s: Dictionary in _sparks:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) < SPARK_LIFE:
			live.append(s)
	_sparks = live
	queue_redraw()


func _draw() -> void:
	if _ids.is_empty():
		return
	# Pool of the highest rarity under the feet.
	if _pool_color.a > 0.0:
		var pts := PackedVector2Array()
		for k in 16:
			var a: float = TAU * float(k) / 16.0
			pts.append(Vector2(cos(a) * POOL_RX, sin(a) * POOL_RY))
		draw_colored_polygon(pts, Color(_pool_color, 0.22))
	# Motes with fading trails.
	for i in _ids.size():
		var c: Color = _colors[i]
		var trail: PackedVector2Array = _trails[i]
		for k in trail.size():
			var fade: float = float(k + 1) / float(TRAIL + 1)
			_texel(trail[k], Color(c, 0.25 + 0.4 * fade))
		if not trail.is_empty():
			var head: Vector2 = trail[trail.size() - 1].floor()
			draw_rect(Rect2(head - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c)
			draw_rect(Rect2(head, Vector2(1.0, 1.0)), c.lightened(0.5))
	for s: Dictionary in _sparks:
		var life: float = 1.0 - float(s["t"]) / SPARK_LIFE
		_texel(s["p"] as Vector2, Color((s["c"] as Color).lightened(0.4), life))


func _texel(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2(1.0, 1.0)), c)
