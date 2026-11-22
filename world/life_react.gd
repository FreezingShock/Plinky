class_name LifeReact
extends Node2D
## Meadow life that answers the walker (MeadowScene child, z 10 like LifeAir). Four reactions:
##   bushes   rustle (a 1 texel shuffle of the bush sprite) while the walker is near, and settle after;
##   birds    perch on the grass and scatter up and away when the walker comes close, then glide back;
##   ripples  rings spread on a pond or the lake when the walker walks along its shore;
##   grass    bends away from the walker (LifeGround.pusher, handled there).
## Stepped at 12 fps, palette indices only, no alpha. Reduce motion (MeadowLife.reduce_motion) keeps bushes,
## birds and ripples still. Positions are texels in the 640x360 frame; the walker is found by group "walker".

const STEP: float = 1.0 / 12.0
const BUSH_RADIUS: float = 20.0
const BUSH_SETTLE: float = 0.5        # seconds the rustle lingers after the walker leaves
const BIRD_COUNT: int = 6
const BIRD_SCARE: float = 44.0        # walker distance that startles a perched bird
const BIRD_RETURN_AFTER: float = 9.0  # seconds a scattered bird stays away
const BIRD_FLIGHT: float = 1.6        # seconds spent leaving or returning
const SHORE_REACH: float = 26.0       # walker distance from the water edge that makes ripples
const SHORE_LINGER: float = 2.5       # seconds ripples keep coming after the walker stops at the shore
const RIPPLE_EVERY: float = 0.4
const RIPPLE_LIFE: float = 1.0
const IDX_INK: int = 0
const IDX_EARTH: int = 6
const IDX_PAPER: int = 7

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _walker: Node2D
var _bushes: Array[Dictionary] = []   # {sprite, base_x, foot, near (seconds left of rustle)}
var _birds: Array[Dictionary] = []    # {home, scared (seconds since scare, -1 = perched), dir, seed}
var _water: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []  # {pos, age}
var _ripple_clock: float = 0.0
var _shore_left: float = 0.0
var _shore_pos: Vector2 = Vector2.INF
var _t: float = 0.0
var _step: int = -1


## `bush_sprites` are the bush occluders from MeadowScene.spawn_occluders. `perches` are candidate ground texels.
func setup(life: Dictionary, perches: Array) -> void:
	_water.clear()
	for wb: Variant in life.get("water", []) as Array:
		_water.append(wb as Dictionary)
	_birds.clear()
	var pool: Array = perches.duplicate()
	for i: int in BIRD_COUNT:
		if pool.is_empty():
			break
		var pick: int = int(MeadowLife.hash01(i * 7 + 3) * float(pool.size())) % pool.size()
		var p: Array = pool[pick] as Array
		pool.remove_at(pick)
		_birds.append({"home": Vector2(float(p[0]), float(p[1])), "scared": -1.0,
			"dir": -1.0 if MeadowLife.hash01(i + 40) < 0.5 else 1.0, "seed": i})


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.button_pressed.connect(_on_pressed)


## A crit press startles every bird in the meadow.
func _on_pressed(_id: StringName, _pos: Vector3, _gain: BigNum, crit: bool) -> void:
	if crit and not MeadowLife.reduce_motion:
		scare_all()


func scare_all() -> void:
	for bird: Dictionary in _birds:
		if float(bird.scared) < 0.0:
			bird.scared = 0.0


func set_bushes(sprites: Array) -> void:
	_bushes.clear()
	for s: Variant in sprites:
		var sp: Sprite2D = s as Sprite2D
		_bushes.append({"sprite": sp, "base_x": sp.offset.x, "near": 0.0})


## Rustle shuffle for a bush: -1, 0, +1, 0 texels, from stepped time.
static func rustle_offset(step: int) -> float:
	return [-1.0, 0.0, 1.0, 0.0][posmod(step, 4)]


## How far along its leave/return trip a scattered bird is: 0 perched, 1 gone.
static func away_amount(since_scare: float) -> float:
	if since_scare < 0.0:
		return 0.0
	if since_scare < BIRD_FLIGHT:
		return since_scare / BIRD_FLIGHT
	if since_scare < BIRD_RETURN_AFTER:
		return 1.0
	if since_scare < BIRD_RETURN_AFTER + BIRD_FLIGHT:
		return 1.0 - (since_scare - BIRD_RETURN_AFTER) / BIRD_FLIGHT
	return 0.0


## Point on a water ellipse nearest the given spot, or Vector2.INF when the spot is farther than `reach`
## from the edge. Edge distance is approximated in the ellipse's own units, then scaled back.
static func shore_point(w: Dictionary, spot: Vector2, reach: float) -> Vector2:
	var c: Vector2 = Vector2(float(w.x), float(w.y))
	var r: Vector2 = Vector2(float(w.rx), float(w.ry))
	var d: Vector2 = spot - c
	var k: float = sqrt((d.x / r.x) * (d.x / r.x) + (d.y / r.y) * (d.y / r.y))
	if k < 0.0001:
		return Vector2.INF
	var edge: Vector2 = c + d / k * 0.9   # just inside the edge, so the ring sits on water
	if spot.distance_to(edge) > reach:
		return Vector2.INF
	return edge


func _process(delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		_walker = get_tree().get_first_node_in_group(&"walker") as Node2D
	if _walker == null:
		return
	var calm: bool = MeadowLife.reduce_motion
	_t += delta
	var wp: Vector2 = _walker.position
	for b: Dictionary in _bushes:
		var sp: Sprite2D = b.sprite as Sprite2D
		var foot: Vector2 = sp.position
		if not calm and wp.distance_to(foot) <= BUSH_RADIUS:
			b.near = BUSH_SETTLE
		else:
			b.near = maxf(float(b.near) - delta, 0.0)
	for bird: Dictionary in _birds:
		var since: float = float(bird.scared)
		if since >= 0.0:
			since += delta
			bird.scared = -1.0 if since >= BIRD_RETURN_AFTER + BIRD_FLIGHT else since
		elif not calm and wp.distance_to(bird.home as Vector2) <= BIRD_SCARE:
			bird.scared = 0.0
	if not calm:
		for w: Dictionary in _water:
			var p: Vector2 = shore_point(w, wp, SHORE_REACH)
			if p != Vector2.INF:
				_shore_pos = p
				_shore_left = SHORE_LINGER if bool(_walker.get("moving")) else _shore_left
		_shore_left = maxf(_shore_left - delta, 0.0)
		_ripple_clock -= delta
		if _shore_left > 0.0 and _shore_pos != Vector2.INF and _ripple_clock <= 0.0:
			_ripples.append({"pos": _shore_pos, "age": 0.0})
			_ripple_clock = RIPPLE_EVERY
	for r: Dictionary in _ripples:
		r.age = float(r.age) + delta
	var alive: Array[Dictionary] = []
	for r2: Dictionary in _ripples:
		if float(r2.age) < RIPPLE_LIFE:
			alive.append(r2)
	_ripples = alive
	var s: int = int(_t / STEP)
	if s != _step:
		_step = s
		for b: Dictionary in _bushes:
			var sp2: Sprite2D = b.sprite as Sprite2D
			var shake: float = rustle_offset(s) if float(b.near) > 0.0 else 0.0
			sp2.offset.x = float(b.base_x) + shake
		queue_redraw()


func _draw() -> void:
	for bird: Dictionary in _birds:
		_draw_bird(bird)
	for r: Dictionary in _ripples:
		_draw_ripple(r)


func _draw_bird(bird: Dictionary) -> void:
	var home: Vector2 = bird.home as Vector2
	var away: float = away_amount(float(bird.scared))
	if away >= 1.0:
		return
	var sx: float = float(bird.dir)
	var at: Vector2 = home + Vector2(sx * 90.0 * away, -60.0 * away)
	var x: int = roundi(at.x)
	var y: int = roundi(at.y)
	if away <= 0.0:
		# Perched, 6 x 5 texels: paper breast and ink back so it reads on grass and sand. Pecks now and then.
		var peck: bool = int(_t * 2.0 + float(bird.seed) * 1.7) % 5 == 0
		_rect(x - 1, y - 3, 5, 3, IDX_INK)
		_rect(x, y - 2, 3, 2, IDX_PAPER)
		_rect(x + 4, y - 4 + (2 if peck else 0), 2, 2, IDX_INK)
		_rect(x - 3, y - 3, 2, 1, IDX_EARTH)
		_rect(x, y, 1, 1, IDX_INK)
		_rect(x + 2, y, 1, 1, IDX_INK)
		return
	# In flight: ink body with paper-edged wings, up then flat at 6 flaps a second.
	var up: bool = (_step / 2) % 2 == 0
	var wy: int = -3 if up else 1
	_rect(x - 1, y - 1, 4, 3, IDX_INK)
	_rect(x + 1, y, 2, 1, IDX_PAPER)
	_rect(x - 4, y + wy, 3, 2, IDX_INK)
	_rect(x + 3, y + wy, 3, 2, IDX_INK)
	_rect(x - 4, y + wy + (0 if up else 2), 1, 1, IDX_PAPER)
	_rect(x + 5, y + wy + (0 if up else 2), 1, 1, IDX_PAPER)


func _draw_ripple(r: Dictionary) -> void:
	var f: float = float(r.age) / RIPPLE_LIFE
	var rx: float = 2.0 + f * 9.0
	var ry: float = rx * 0.5
	var c: Vector2 = r.pos as Vector2
	var n: int = 28
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var x: int = roundi(c.x + cos(a) * rx)
		var y: int = roundi(c.y + sin(a) * ry)
		# Bayer thins the ring as it fades, so it dissolves instead of blinking out.
		if MeadowLife.bayer(x, y) < 1.0 - f:
			_px(x, y, IDX_PAPER)


func _rect(x: int, y: int, w: int, h: int, idx: int) -> void:
	draw_rect(Rect2(x, y, w, h), palette[idx])


func _px(x: int, y: int, idx: int) -> void:
	draw_rect(Rect2(x, y, 1, 1), palette[idx])
