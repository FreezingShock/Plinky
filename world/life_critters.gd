class_name LifeCritters
extends RefCounted
## Ground and water critters of the zone 1 world life. LifeAir owns one and draws it in its own _draw (z 10), so the
## critters cost no nodes: LifeAir calls update() each frame with the walker's position and draw() from its redraw.
##   rabbits  graze on the grass tips near their burrow spot. A walker close by makes them sit up and watch; closer, they
##            flee in quick hops and watch again from the far side. They sit out most of the middle of the day, the rain
##            and the winter, and fade in and out by dither rather than popping.
##   ducks    swim the lake and the pond. A walker on the shore sends them paddling off, leaving rings of ripples.
##   frogs    sit on the shore. A walker close by sends them leaping into the water, where they stay a while. Rain brings
##            them out; winter keeps them under.
## Every critter is a few palette-index sprites, drawn in LifeAir's 12 fps steps (see GraphicsQuality), with no alpha. Under reduce motion nothing travels:
## a rabbit still stands up and watches, a duck floats still, a frog keeps its perch. Positions come from the anchor data
## (grass tips, pads, water), so critters never stand on a pad, never sit in water, and have no body to block the walker.

const RABBIT_NEAR: float = 26.0        # walker distance (texels, y doubled) that starts a flight from a rabbit
const RABBIT_WATCH: float = 42.0       # walker distance that makes a rabbit sit up and watch
const RABBIT_WATCH_TIME: float = 2.5   # seconds a rabbit keeps watching after the walker has gone
const RABBIT_WANDER: float = 30.0      # how far a grazing rabbit strays from its burrow spot
const RABBIT_FLEE_HOP: float = 11.0    # texels per flight hop
const RABBIT_FLEE_TIME: float = 0.18   # seconds per flight hop
const RABBIT_GRAZE_TIME: float = 0.5   # seconds per grazing hop
const RABBIT_FLEE_RANGE: Vector2 = Vector2(14.0, 80.0)   # how far a flight goes, texels
const RABBIT_FLEE_IDEAL: float = 40.0  # a flight prefers to land about this far off
const RABBIT_FLEE_RETRY: float = 0.5   # seconds before a rabbit that found no route looks again
const RABBIT_HOP_LIFT: float = 2.0    # texels a hop rises at its peak
const RABBIT_NIBBLE: float = 1.2       # seconds of each 4 spent nibbling with the head down
const DUCK_SHY: float = 36.0           # walker distance that sends a duck paddling off
const DUCK_SPEED: float = 9.0          # texels per second when paddling away
const DUCK_IDLE_SPEED: float = 2.5     # texels per second when drifting
const DUCK_WAIT: Vector2 = Vector2(2.0, 6.0)   # seconds a duck floats between drifts
const FROG_NEAR: float = 24.0          # walker distance that sends a frog into the water
const FROG_LEAP_TIME: float = 0.45     # seconds in the air
const FROG_AWAY: Vector2 = Vector2(6.0, 12.0)  # seconds a frog stays in the water
const FROG_PERCH: int = 3              # frog perches per water body at most
const SHORE_OUT: float = 1.3           # a grass tip this far out (normalised radius, 1 = the edge) is shore
const PAD_KEEP: float = 16.0           # texels a critter keeps from a pad centre
const WATER_KEEP: float = 1.1          # a critter on land keeps this far outside the water ellipse
const FADE_RATE: float = 0.8           # per second: how fast a critter dissolves in or out
const RIPPLE_LIFE: float = 1.0
const RIPPLE_EVERY: float = 0.45
const RABBIT_COUNT_MIN: int = 2
const RABBIT_COUNT_MAX: int = 8
const RABBIT_SPACING: float = 30.0   # texels between burrow spots
const RABBIT_GRAZE_REACH: float = 16.0  # the longest grazing hop, texels

## Palette roles used by the sprites below (art-bible section 3): k ink, d shadow, g deep, b base, l light, y accent,
## f earth, w paper. The sprite art is kept as text so it can be read and edited by eye.
const CODE: Dictionary = {"k": 0, "d": 1, "g": 2, "b": 3, "l": 4, "y": 5, "f": 6, "w": 7}
const RABBIT_SIT: Array = [
	".....kffk..", "....kffwfk.", "....kffwfk.", "....kffwfk.", "..kkffffkk.", ".kffffffwwk",
	"kfffffffkk.", "kfffwfffk..", "wffwwwffk..", "wffwwwfk...", "kkwwwfwwk..",
]
const RABBIT_ALERT: Array = [
	"....kwfwk..", "....kwfwk..", "....kfffk..", "....kffkk..", "...kfffwwk.", "..kffffwwk.",
	".kfffffkk..", ".kfffffk...", ".kfwwwfk...", "kkfwwwfk...", "wkfwwwfk...", "kkwwfkwwk..",
]
const RABBIT_NIBBLE_ART: Array = [
	"......kk...", ".....kffk..", "...kkfffk..", "..kfffffkk.", ".kffffffffk", "kffffffffk.",
	"kffwwffffwk", "kffwwwfffk.", ".kwwwfwwk..",
]
const RABBIT_HOP_ART: Array = [
	"......kffk...", "....kkkffkk..", "..kkfffffffk.", ".kffffffffkk.", "kkffwwwwffwwk",
	"wkfwwwwwfkkk.", "wwwkfffkkwwk.", "kkk.kkk..kk..",
]
const DUCK_ART: Array = [
	"........kkk..", "k..kkkkkdddkk", "fkkfffwdddkyy", "kfffffffdddkk", "kfffffffwwk..", "kwwwwwwwwwk..",
	"llkwwwwwkllk.", "kk.kkkkk.kk..",
]
const DUCK_SLEEP_ART: Array = [
	".............", "...kkkk.kk...", ".kkfffwkddk..", "kffffffddddk.", "kffffffddddk.", "kwwwwwwwwwk..",
	"llkwwwwwkllk.", "kk.kkkkk.kk..",
]
const FROG_ART: Array = [".kwkwk.", "kwkbwk.", "kblllbk", "kbbbbbk", "ddbbbdd"]
const FROG_TUCK_ART: Array = [".kkwk", "klllk", "bbbbb", "kbbbk"]

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _sprites: Dictionary = {}             # name -> {runs: Array[PackedInt32Array], w, h}
var _pads: Array[Vector2] = []            # every pad centre, ready or not
var _water: Array[Dictionary] = []        # water ellipses from the data
var _graze: Array[Vector2] = []           # grass tips off the pads and out of the water
var _shore: Array[Vector2] = []           # grass tips just outside a water edge
var _rabbits: Array[Dictionary] = []
var _ducks: Array[Dictionary] = []
var _frogs: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []      # {pos, age}
var _ripple_clock: float = 0.0
var _ci: CanvasItem                       # the node being drawn into this redraw (set by draw)
var _view: Rect2 = Rect2()
var _t: float = 0.0
var _fly: LifeButterflies = LifeButterflies.new()


## `life` is the parsed life data (MeadowLife.load_data); `sway` is its grass tip list, where the critters graze.
func setup(life: Dictionary) -> void:
	_build_sprites()
	var sway: Array = life.get("sway", []) as Array
	_pads.clear()
	for p: Variant in life.get("pad_sites", life.get("pads", [])) as Array:
		var a: Array = p as Array
		_pads.append(Vector2(float(a[0]), float(a[1])))
	_water.clear()
	for wb: Variant in life.get("water", []) as Array:
		_water.append(wb as Dictionary)
	_graze.clear()
	_shore.clear()
	for p: Variant in sway:
		var a: Array = p as Array
		var at := Vector2(float(a[0]), float(a[1]))
		if MeadowLife.near_any(at, _pads, PAD_KEEP) or MeadowLife.in_water(at, _water, WATER_KEEP):
			continue
		_graze.append(at)
		for w: Dictionary in _water:
			var k: float = MeadowLife.water_k(at, w)
			if k >= WATER_KEEP and k <= SHORE_OUT:
				_shore.append(at)
				break
	_spawn_rabbits()
	_spawn_water_critters()
	_fly.setup(life)


func _spawn_rabbits() -> void:
	_rabbits.clear()
	if _graze.is_empty():
		return
	var n: int = clampi(roundi(sqrt(float(_graze.size())) * 0.3), RABBIT_COUNT_MIN, RABBIT_COUNT_MAX)
	for i: int in n:
		var home: Vector2 = _graze[0]
		for tries: int in 12:
			home = _hash_pick(_graze, i * 17 + tries * 5 + 5)
			var spaced: bool = true
			for r: Dictionary in _rabbits:
				if (r.home as Vector2).distance_to(home) < RABBIT_SPACING:
					spaced = false
					break
			if spaced:
				break
		_rabbits.append({"home": home, "pos": home, "from": home, "to": home, "lift": 0.0,
			"hop_t": 0.0, "hop_dur": 0.0, "fleeing": false, "route": home,
			"timer": 1.0 + MeadowLife.hash01(i * 3 + 2) * 4.0, "watch": 0.0, "fade": 0.0, "cool": 0.0,
			"face": 1.0, "seed": i * 31 + 3})


func _spawn_water_critters() -> void:
	_ducks.clear()
	_frogs.clear()
	for b: int in _water.size():
		var w: Dictionary = _water[b]
		var n_ducks: int = clampi(roundi(float(w.rx) * float(w.ry) / 20000.0), 1, 3)
		for i: int in n_ducks:
			var at: Vector2 = _water_point(b, 0.6, 17 * b + i * 11 + 1)
			_ducks.append({"body": b, "pos": at, "to": at, "wait": DUCK_WAIT.x + MeadowLife.hash01(i * 5 + b) * 4.0,
				"scared": 0.0, "dir": 1.0, "seed": 40 + b * 9 + i})
		var shore: Array[Vector2] = []
		for s: Vector2 in _shore:
			var k: float = MeadowLife.water_k(s, w)
			if k >= WATER_KEEP and k <= SHORE_OUT:
				shore.append(s)
		if shore.is_empty():
			continue
		for i: int in mini(FROG_PERCH, shore.size()):
			var home: Vector2 = _hash_pick(shore, 60 + b * 13 + i * 7)
			_frogs.append({"body": b, "home": home, "pos": home, "to": home, "state": 0, "t": 0.0,
				"away": 0.0, "lift": 0.0, "fade": 0.0, "seed": 70 + b * 9 + i})


## A spot from `pool`, chosen by hash: the same seed always gives the same spot.
func _hash_pick(pool: Array[Vector2], seed_n: int) -> Vector2:
	return pool[int(MeadowLife.hash01(seed_n) * float(pool.size())) % pool.size()]


## A point in water body b, `grow` of the way to its edge (0.6 = well inside), picked by hash.
func _water_point(b: int, grow: float, seed_n: int) -> Vector2:
	var w: Dictionary = _water[b]
	var ang: float = MeadowLife.hash01(seed_n) * TAU
	var rad: float = sqrt(MeadowLife.hash01(seed_n + 1)) * grow
	return Vector2(float(w.x) + cos(ang) * float(w.rx) * rad, float(w.y) + sin(ang) * float(w.ry) * rad)


## Rabbits are out by day in spring and summer, fewer in autumn and winter, and sit out the rain.
static func rabbit_share() -> float:
	var by_season: float = MeadowLife.season_mix([1.0, 0.85, 0.7, 0.35])
	var by_light: float = clampf(0.2 + 0.8 * maxf(MeadowLife.low_sun, MeadowLife.night), 0.0, 1.0)
	return by_season * by_light * (1.0 - MeadowLife.rain)


## Frogs come out in spring and summer, and most after rain or in the dark. Winter keeps them under.
static func frog_share() -> float:
	var by_season: float = MeadowLife.season_mix([1.0, 0.8, 0.4, 0.0])
	var wet: float = clampf(0.35 + 0.65 * MeadowLife.rain + 0.2 * MeadowLife.night, 0.0, 1.0)
	return by_season * wet


## Moves every critter by delta. `wp` is the walker's position in the frame (far away when there is no walker).
func update(delta: float, wp: Vector2) -> void:
	_t += delta
	_fly.update(delta, wp)
	var calm: bool = MeadowLife.reduce_motion
	var budget: int = GraphicsQuality.life_scaled(_rabbits.size())
	var rshare: float = rabbit_share()
	for i: int in _rabbits.size():
		_update_rabbit(_rabbits[i], delta, wp, calm, i < budget and _out(int(_rabbits[i].seed) * 7 + 1, rshare))
	_update_ducks(delta, wp, calm)
	var fshare: float = frog_share()
	for f: Dictionary in _frogs:
		_update_frog(f, delta, wp, calm, _out(int(f.seed) * 11 + 3, fshare))
	for r: Dictionary in _ripples:
		r.age = float(r.age) + delta
	var alive: Array[Dictionary] = []
	for r2: Dictionary in _ripples:
		if float(r2.age) < RIPPLE_LIFE:
			alive.append(r2)
	_ripples = alive


## Whether a critter with this seed is out for a given share: a fixed hash, so the same critters go first and come back last.
static func _out(seed_n: int, share: float) -> bool:
	return MeadowLife.hash01(seed_n) < share


## Moves a critter's fade toward 1 (out) or 0 (in), in seconds at FADE_RATE.
func _fade(c: Dictionary, out: bool, delta: float) -> void:
	c.fade = move_toward(float(c.fade), 1.0 if out else 0.0, FADE_RATE * delta)


func _update_rabbit(r: Dictionary, delta: float, wp: Vector2, calm: bool, out: bool) -> void:
	_fade(r, out, delta)
	if float(r.fade) <= 0.0:
		r.hop_dur = 0.0
		r.fleeing = false
		r.pos = r.home
		r.lift = 0.0
		return
	if float(r.hop_dur) > 0.0:
		_advance_hop(r, delta)
	else:
		var d: float = MeadowLife.iso_distance(r.pos as Vector2, wp)
		if d < RABBIT_WATCH:
			r.watch = RABBIT_WATCH_TIME
			r.face = signf(wp.x - (r.pos as Vector2).x) if absf(wp.x - (r.pos as Vector2).x) > 0.5 else float(r.face)
		else:
			r.watch = maxf(float(r.watch) - delta, 0.0)
		if bool(r.fleeing):
			_next_flee_hop(r)
		elif d < RABBIT_NEAR and not calm:
			r.cool = maxf(float(r.cool) - delta, 0.0)
			if float(r.cool) <= 0.0:
				_plan_flight(r, wp)
		elif not calm and float(r.watch) <= 0.0:
			r.timer = float(r.timer) - delta
			if float(r.timer) <= 0.0:
				_plan_graze(r)


func _advance_hop(c: Dictionary, delta: float) -> void:
	c.hop_t = float(c.hop_t) + delta
	var k: float = clampf(float(c.hop_t) / float(c.hop_dur), 0.0, 1.0)
	c.pos = (c.from as Vector2).lerp(c.to as Vector2, k)
	c.lift = sin(k * PI) * RABBIT_HOP_LIFT
	if k >= 1.0:
		c.pos = c.to
		c.hop_dur = 0.0
		c.lift = 0.0
		if not bool(c.fleeing):
			c.timer = 2.0 + MeadowLife.hash01(int(c.seed) + int(_t * 2.0)) * 4.0


func _start_hop(r: Dictionary, to: Vector2, dur: float) -> void:
	var from: Vector2 = r.pos as Vector2
	r.from = from
	r.to = to
	r.hop_t = 0.0
	r.hop_dur = dur
	if absf(to.x - from.x) > 0.1:
		r.face = signf(to.x - from.x)


## A walker close by: run to the grass tip that lies away from the walker, about RABBIT_FLEE_IDEAL off, with no pad
## or water on the way. A rabbit with no such tip waits RABBIT_FLEE_RETRY seconds before it looks again.
func _plan_flight(r: Dictionary, wp: Vector2) -> void:
	if _graze.is_empty():
		return
	var here: Vector2 = r.pos as Vector2
	var away: Vector2 = here - wp
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	away = away.normalized()
	var best: Vector2 = here
	var best_score: float = -INF
	for c: Vector2 in _graze:
		var off: Vector2 = c - here
		var dist: float = off.length()
		if dist < RABBIT_FLEE_RANGE.x or dist > RABBIT_FLEE_RANGE.y:
			continue
		var facing: float = off.normalized().dot(away)
		if facing < 0.4:
			continue
		var score: float = facing - absf(dist - RABBIT_FLEE_IDEAL) * 0.01
		if score <= best_score or not _path_clear(here, c):
			continue
		best = c
		best_score = score
	if best_score == -INF:
		r.cool = RABBIT_FLEE_RETRY
		return
	r.route = best
	r.fleeing = true
	_next_flee_hop(r)


func _next_flee_hop(r: Dictionary) -> void:
	var here: Vector2 = r.pos as Vector2
	var left: Vector2 = (r.route as Vector2) - here
	if left.length() < 1.0 or not _path_clear(here, here + left.normalized() * RABBIT_FLEE_HOP):
		r.fleeing = false   # arrived, or the way is blocked: this is the new burrow spot
		r.home = here
		r.watch = RABBIT_WATCH_TIME
		return
	var step: Vector2 = here + left.normalized() * minf(RABBIT_FLEE_HOP, left.length())
	_start_hop(r, step, RABBIT_FLEE_TIME)


func _plan_graze(r: Dictionary) -> void:
	r.timer = 3.0
	if _graze.is_empty():
		return
	var here: Vector2 = r.pos as Vector2
	var home: Vector2 = r.home as Vector2
	for tries: int in 10:
		var c: Vector2 = _hash_pick(_graze, int(r.seed) * 19 + tries * 3 + int(_t * 3.0))
		var reach: float = MeadowLife.iso_distance(c, here)
		if reach < 4.0 or reach > RABBIT_GRAZE_REACH or MeadowLife.iso_distance(c, home) > RABBIT_WANDER:
			continue
		if not _path_clear(here, c):
			continue
		_start_hop(r, c, RABBIT_GRAZE_TIME)
		return


## True when a straight hop from a to b misses every pad and stays out of the water.
func _path_clear(a: Vector2, b: Vector2) -> bool:
	for k: int in 5:
		var p: Vector2 = a.lerp(b, float(k) / 4.0)
		if MeadowLife.near_any(p, _pads, PAD_KEEP * 0.8):
			return false
		if MeadowLife.in_water(p, _water, 1.0):
			return false
	return true


func _update_ducks(delta: float, wp: Vector2, calm: bool) -> void:
	for d: Dictionary in _ducks:
		var pos: Vector2 = d.pos as Vector2
		if not calm and MeadowLife.iso_distance(pos, wp) < DUCK_SHY and float(d.scared) <= 0.0:
			_duck_away(d, wp)
		if float(d.scared) > 0.0:
			d.scared = float(d.scared) - delta
		var speed: float = DUCK_SPEED if float(d.scared) > 0.0 else DUCK_IDLE_SPEED
		if calm:
			continue
		var to: Vector2 = d.to as Vector2
		var step: Vector2 = to - pos
		if step.length() > 0.2:
			pos += step.normalized() * minf(speed * delta, step.length())
			d.pos = pos
			if fmod(_t + float(d.seed) * 0.1, RIPPLE_EVERY) < delta:
				_ripples.append({"pos": pos - step.normalized() * 2.0, "age": 0.0})
		else:
			d.wait = float(d.wait) - delta
			if float(d.wait) <= 0.0:
				d.to = _water_point(int(d.body), 0.62, int(d.seed) * 23 + int(_t * 5.0))
				d.wait = DUCK_WAIT.x + MeadowLife.hash01(int(d.seed) + int(_t)) * (DUCK_WAIT.y - DUCK_WAIT.x)
				d.dir = signf((d.to as Vector2).x - pos.x) if absf((d.to as Vector2).x - pos.x) > 0.5 else float(d.dir)


## Paddles away from the walker to a spot in the same water, at least 60 texels from it.
func _duck_away(d: Dictionary, wp: Vector2) -> void:
	var b: int = int(d.body)
	for tries: int in 8:
		var p: Vector2 = _water_point(b, 0.6, int(d.seed) * 29 + tries * 7 + int(_t * 9.0))
		if MeadowLife.iso_distance(p, wp) >= 60.0:
			d.to = p
			d.scared = 3.0
			return


func _update_frog(f: Dictionary, delta: float, wp: Vector2, calm: bool, out: bool) -> void:
	_fade(f, out, delta)
	var state: int = int(f.state)   # 0 perched, 1 leaping, 2 in the water
	if state == 0:
		if float(f.fade) <= 0.0:
			return
		if not calm and MeadowLife.iso_distance(f.home as Vector2, wp) < FROG_NEAR:
			f.to = _water_point(int(f.body), 0.7, int(f.seed) * 37 + int(_t * 6.0))
			f.state = 1
			f.t = 0.0
			f.pos = f.home
	elif state == 1:
		f.t = float(f.t) + delta
		var k: float = clampf(float(f.t) / FROG_LEAP_TIME, 0.0, 1.0)
		f.pos = (f.home as Vector2).lerp(f.to as Vector2, k)
		f.lift = sin(k * PI) * 7.0
		if k >= 1.0:
			_ripples.append({"pos": f.to, "age": 0.0})
			f.state = 2
			f.away = FROG_AWAY.x + MeadowLife.hash01(int(f.seed) + int(_t)) * (FROG_AWAY.y - FROG_AWAY.x)
	elif state == 2:
		f.away = float(f.away) - delta
		if float(f.away) <= 0.0:
			f.state = 0
			f.pos = f.home
			f.lift = 0.0


## Draws every critter into `ci` (the LifeAir node, inside its _draw). `tb` is LifeAir's stepped time.
func draw(ci: CanvasItem, tb: float) -> void:
	_ci = ci
	_view = GraphicsQuality.visible_local_rect(ci)
	_fly.draw(ci, tb)
	for r: Dictionary in _ripples:
		_draw_ripple(r)
	for f: Dictionary in _frogs:
		_draw_frog(f)
	for d: Dictionary in _ducks:
		_draw_duck(d, tb)
	for r2: Dictionary in _rabbits:
		_draw_rabbit(r2, tb)


func _seen(p: Vector2) -> bool:
	return not _view.has_area() or _view.grow(12.0).has_point(p)


func _draw_rabbit(r: Dictionary, tb: float) -> void:
	if float(r.fade) <= 0.0:
		return
	var at: Vector2 = (r.pos as Vector2)
	if not _seen(at):
		return
	var name: String = "rabbit_sit"
	if float(r.hop_dur) > 0.0:
		name = "rabbit_hop"
	elif float(r.watch) > 0.0 or bool(r.fleeing):
		name = "rabbit_alert"
	elif fposmod(tb + float(r.seed) * 1.3, 4.0) < RABBIT_NIBBLE:
		name = "rabbit_nibble"
	var spr: Dictionary = _sprites[name] as Dictionary
	var w: int = int(spr.w)
	var h: int = int(spr.h)
	var origin: Vector2i = Vector2i(roundi(at.x) - w / 2, roundi(at.y - float(r.lift)) - h + 1)
	_blit(spr, origin, float(r.face) < 0.0, float(r.fade))


func _draw_duck(d: Dictionary, tb: float) -> void:
	var at: Vector2 = d.pos as Vector2
	if not _seen(at):
		return
	var asleep: bool = MeadowLife.night > 0.6 and float(d.scared) <= 0.0
	var spr: Dictionary = _sprites["duck_sleep" if asleep else "duck"] as Dictionary
	var bob: float = 0.0 if MeadowLife.reduce_motion else sin(tb * 1.6 + float(d.seed)) * 0.6
	var origin: Vector2i = Vector2i(roundi(at.x) - int(spr.w) / 2, roundi(at.y + bob) - int(spr.h) + 2)
	_blit(spr, origin, float(d.dir) < 0.0, 1.0)


func _draw_frog(f: Dictionary) -> void:
	if float(f.fade) <= 0.0 or int(f.state) == 2:
		return
	var at: Vector2 = f.pos as Vector2
	if not _seen(at):
		return
	var leaping: bool = int(f.state) == 1
	var spr: Dictionary = _sprites["frog_tuck" if leaping else "frog"] as Dictionary
	var origin: Vector2i = Vector2i(roundi(at.x) - int(spr.w) / 2, roundi(at.y - float(f.lift)) - int(spr.h) + 1)
	_blit(spr, origin, false, float(f.fade))


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
			_ci.draw_rect(Rect2(x, y, 1, 1), palette[7])


## Draws a sprite from its runs of one palette index. `fade` below 1 draws only the texels the dither lets through.
func _blit(spr: Dictionary, origin: Vector2i, flip: bool, fade: float) -> void:
	var w: int = int(spr.w)
	for run: Variant in spr.runs as Array:
		var rr: PackedInt32Array = run as PackedInt32Array
		var n: int = rr[2]
		var x0: int = rr[0] if not flip else w - rr[0] - n
		var y: int = rr[1]
		var idx: int = rr[3]
		if fade >= 1.0:
			_ci.draw_rect(Rect2(origin.x + x0, origin.y + y, n, 1), palette[idx])
			continue
		for k: int in n:
			var x: int = origin.x + x0 + k
			if MeadowLife.dissolved(fade, x, origin.y + y):
				_ci.draw_rect(Rect2(x, origin.y + y, 1, 1), palette[idx])


func _build_sprites() -> void:
	if not _sprites.is_empty():
		return
	_sprites["rabbit_sit"] = _make_sprite(RABBIT_SIT)
	_sprites["rabbit_alert"] = _make_sprite(RABBIT_ALERT)
	_sprites["rabbit_nibble"] = _make_sprite(RABBIT_NIBBLE_ART)
	_sprites["rabbit_hop"] = _make_sprite(RABBIT_HOP_ART)
	_sprites["duck"] = _make_sprite(DUCK_ART)
	_sprites["duck_sleep"] = _make_sprite(DUCK_SLEEP_ART)
	_sprites["frog"] = _make_sprite(FROG_ART)
	_sprites["frog_tuck"] = _make_sprite(FROG_TUCK_ART)


## Turns sprite text rows into runs of one colour: [x, y, length, palette index]. '.' is empty.
static func _make_sprite(rows: Array) -> Dictionary:
	var runs: Array = []
	var w: int = 0
	for r: Variant in rows:
		w = maxi(w, (r as String).length())
	for y: int in rows.size():
		var row: String = rows[y]
		var x: int = 0
		while x < row.length():
			var code: String = row[x]
			if code == ".":
				x += 1
				continue
			var n: int = 1
			while x + n < row.length() and row[x + n] == code:
				n += 1
			runs.append(PackedInt32Array([x, y, n, int(CODE[code])]))
			x += n
	return {"runs": runs, "w": w, "h": rows.size()}
