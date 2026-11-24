class_name LifeWild
extends RefCounted
## Wildlife for Larkmoor beyond the ground critters: dragonflies over the water, fish that leap in the mere, deer that graze
## the forest edge at dawn and dusk, and owls in the pine crowns at night. LifeCritters owns one and draws it from LifeAir's
## _draw, so it adds no nodes. The light, the season and the rain decide how many of each are out (the *_share helpers,
## read once a frame): the first ceil(share * count) of them are out, so the crowd follows the light instead of a roll.
## They only come out within REACH of the walker, and a creature that has been left far behind dissolves and re-forms inside
## REACH, so the player sees them where they walk. A walker close by sends a dragonfly darting, a deer into the trees, and
## an owl to another perch. Under reduce motion nothing travels or
## jumps: dragonflies hover where they are, and fish, deer and owls stay put. Palette indices, drawn with MeadowLife.blit.

const DRAGON_MAX: int = 6
const DRAGON_SPEED: float = 14.0            # texels per second over the water
const DRAGON_HOVER: Vector2 = Vector2(1.0, 3.0)   # seconds over a spot before the next dart
const DRAGON_SHY: float = 30.0              # walker distance that sends a dragonfly off
const DRAGON_FLEE: float = 1.5              # seconds a scared dragonfly keeps darting
const WATER_INNER: float = 0.8              # wildlife keeps inside this normalised radius of the water
const REACH: float = 200.0                  # wildlife comes out only this close (iso texels) to the walker, so it is on screen
const GONE: float = 300.0                   # past this a creature dissolves and re-forms inside REACH
const FISH_EVERY: Vector2 = Vector2(2.5, 6.0)     # seconds between one body's leaps
const FISH_TIME: float = 0.7                # seconds in the air
const FISH_HEIGHT: float = 10.0             # texels a leap rises at its peak
const RING_LIFE: float = 0.9
const DEER_MAX: int = 3
const DEER_SHY: float = 36.0                # walker distance that sends a deer into the trees
const DEER_FLEE_TIME: float = 5.0
const DEER_SPEED: float = 5.0               # texels per second when grazing along the edge
const DEER_RUN: float = 14.0
const DEER_WAIT: Vector2 = Vector2(5.0, 10.0)     # seconds a deer grazes between moves
const DEER_PAD_KEEP: float = 16.0           # a deer does not walk over a pad
const OWL_MAX: int = 3
const OWL_SHY: float = 28.0                 # walker distance that sends an owl off its perch
const OWL_FLY_TIME: float = 6.0
const OWL_BLINK_EVERY: Vector2 = Vector2(3.5, 7.0)
const OWL_BLINK_TIME: float = 0.15
const FADE_RATE: float = 0.6                # per second: how fast a creature dissolves in or out

## Sprites, text rows as in LifeCritters. Colours are chosen to read on the dark water and the grass: the dragonfly has
## paper wings and a gold head, the fish is gold with a paper eye, the deer is earth brown with a paper belly, the owl is brown
## with paper eyes. Dragonfly 9 x 3 with wings up and down, fish 8 x 3, deer 10 x 8 facing right, owl 5 x 5. The deer is
## earth brown (f) with a paper belly, so it reads against the grass.
const DRAGON_UP: Array = ["ww..k.k..ww", ".wwkkkkkww.", "...kyyyk..."]
const DRAGON_DOWN: Array = ["...kyyyk...", ".wwkkkkkww.", "ww..k.k..ww"]
const FISH_ART: Array = ["...kk...", "kyyyywyk", "...kk..."]
const DEER_ART: Array = [".....k.k..", "....kffk..", "...ffffff.", "wffffffff.", "wffwwwwff.", ".dffffffd.", "..d.d.d.d.", "..k.k.k.k."]
const OWL_OPEN: Array = ["k...k", "kbbbk", "bwkwb", "bbbbb", ".bbb."]
const OWL_SHUT: Array = ["k...k", "kbbbk", "bkkkb", "bbbbb", ".bbb."]

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _sprites: Dictionary = {}
var _water: Array[Dictionary] = []          # the water ellipses (LifeCritters' list)
var _pads: Array[Vector2] = []
var _edge: Array[Vector2] = []              # forest-edge grass tips, where the deer grazes
var _perches: Array[Vector2] = []           # owl perches in the pine crowns
var _dragons: Array[Dictionary] = []        # {pos, to, hover, flee, fade, seed, rank}
var _fish: Array[Dictionary] = []           # {body, timer, jump, pos, t, flip}
var _rings: Array[Dictionary] = []          # {pos, age}: where a fish came down
var _deers: Array[Dictionary] = []          # {pos, to, wait, flee, fade, seed, dir, rank}
var _owls: Array[Dictionary] = []           # {perch, next, fade, fly, seed, blink, shut, rank}
var _ci: CanvasItem
var _view: Rect2 = Rect2()
var _t: float = 0.0


## `water` is LifeCritters' water list. `life` is the parsed Larkmoor data: pad_sites, forest_edge and perches.
func setup(life: Dictionary, water: Array[Dictionary]) -> void:
	_t = 0.0
	_water = water
	_pads = _points(life.get("pad_sites", []) as Array)
	_edge = _points(life.get("forest_edge", []) as Array)
	_perches = _points(life.get("perches", []) as Array)
	_build_sprites()
	_dragons.clear()
	if not _water.is_empty():
		for i: int in DRAGON_MAX:
			var start: Vector2 = _water_point(i % _water.size(), i * 37 + 5)
			_dragons.append({"pos": start, "to": start, "hover": 0.0, "flee": 0.0, "fade": 0.0, "seed": i, "rank": i})
	_fish.clear()
	for b: int in _water.size():
		_fish.append({"body": b, "timer": _range(FISH_EVERY, b * 11 + 3), "jump": false,
			"pos": Vector2.ZERO, "t": 0.0, "flip": false})
	_deers.clear()
	for i: int in DEER_MAX:
		var spot: Vector2 = _edge[(i * 4) % _edge.size()] if not _edge.is_empty() else Vector2.ZERO
		_deers.append({"pos": spot, "to": spot, "wait": 0.0, "flee": 0.0, "fade": 0.0,
			"seed": 3 + i * 7, "dir": 1.0, "rank": i})
	_owls.clear()
	for i: int in mini(OWL_MAX, _perches.size()):
		var perch: int = (i * 2) % _perches.size()
		_owls.append({"perch": perch, "next": perch, "fade": 0.0, "fly": 0.0, "seed": i * 5 + 2,
			"blink": _range(OWL_BLINK_EVERY, i * 9 + 1), "shut": 0.0, "rank": i})
	_rings.clear()


## Moves the wildlife by delta. `wp` is the walker's position in the frame.
func update(delta: float, wp: Vector2) -> void:
	_t += delta
	var calm: bool = MeadowLife.reduce_motion
	_update_dragons(delta, wp, calm)
	_update_fish(delta, wp, calm)
	_update_deers(delta, wp, calm)
	_update_owls(delta, wp, calm)
	var alive: Array[Dictionary] = []
	for r: Dictionary in _rings:
		r.age = float(r.age) + delta
		if float(r.age) < RING_LIFE:
			alive.append(r)
	_rings = alive


## Draws the wildlife into `ci`. `tb` is LifeAir's stepped time.
func draw(ci: CanvasItem, tb: float) -> void:
	_ci = ci
	_view = GraphicsQuality.visible_local_rect(ci)
	for r: Dictionary in _rings:
		_draw_ring(r)
	for f: Dictionary in _fish:
		_draw_fish(f)
	for d: Dictionary in _dragons:
		_draw_dragon(d, tb)
	for e: Dictionary in _deers:
		_draw_deer(e)
	for o: Dictionary in _owls:
		_draw_owl(o)


## Shares: how many of each kind are out, as a fraction. The first ceil(share * count) are out (see _rank_out).
static func dragonfly_share() -> float:
	return clampf((1.0 - MeadowLife.night) * (1.0 - MeadowLife.rain) * MeadowLife.season_mix([0.6, 1.0, 0.3, 0.0]), 0.0, 1.0)


static func fish_share() -> float:
	return clampf((1.0 - MeadowLife.night * 0.8) * (1.0 - MeadowLife.rain * 0.4) * MeadowLife.season_mix([0.8, 1.0, 0.7, 0.2]), 0.0, 1.0)


static func deer_share() -> float:
	return clampf(maxf(MeadowLife.low_sun * 1.5, sin(PI * clampf(MeadowLife.night, 0.0, 1.0)) * 0.9), 0.0, 1.0) * (1.0 - MeadowLife.rain) * MeadowLife.season_mix([0.9, 0.9, 1.0, 0.5])


static func owl_share() -> float:
	return clampf(MeadowLife.night * (1.0 - MeadowLife.rain * 0.5) * (0.8 + 0.2 * MeadowLife.season_mix([0.7, 0.8, 0.8, 1.0])), 0.0, 1.0)


## True when creature `rank` of `count` is out at this share: the lowest ranks come out first, so the count follows the share.
static func _rank_out(rank: int, count: int, share: float) -> bool:
	return (float(rank) + 0.5) / float(count) < share


func _update_dragons(delta: float, wp: Vector2, calm: bool) -> void:
	var share: float = dragonfly_share()
	for d: Dictionary in _dragons:
		var shown: bool = _rank_out(int(d.rank), DRAGON_MAX, share)
		if shown and float(d.fade) <= 0.0 and MeadowLife.iso_distance(d.pos as Vector2, wp) > GONE:
			_relocate_dragon(d, wp)
		var near: bool = MeadowLife.iso_distance(d.pos as Vector2, wp) <= GONE
		d.fade = move_toward(float(d.fade), 1.0 if shown and near else 0.0, FADE_RATE * delta)
		if float(d.fade) <= 0.0 or calm:
			continue
		var pos: Vector2 = d.pos as Vector2
		var scared: bool = MeadowLife.iso_distance(pos, wp) < DRAGON_SHY
		if scared and float(d.flee) <= 0.0:
			_dart(d, wp, true)
			d.flee = DRAGON_FLEE
		d.flee = maxf(float(d.flee) - delta, 0.0)
		var to: Vector2 = d.to as Vector2
		if pos.distance_to(to) > 0.5:
			var step: Vector2 = to - pos
			var speed: float = DRAGON_SPEED * (2.0 if scared else 1.0)
			d.pos = pos + step.normalized() * minf(speed * delta, step.length())
		else:
			d.hover = float(d.hover) - delta
			if float(d.hover) <= 0.0:
				_dart(d, wp, false)


## A dissolved dragonfly that the walker has left far behind re-forms over water inside REACH. None in reach: it stays hidden.
func _relocate_dragon(d: Dictionary, wp: Vector2) -> void:
	var spot: Vector2 = _water_within(wp, int(d.seed) * 31 + int(_t * 4.0), DRAGON_SHY * 2.0, REACH)
	if spot.is_finite():
		d.pos = spot
		d.to = spot
		d.hover = _range(DRAGON_HOVER, int(d.seed) + 5)


## Picks a dragonfly's next spot over the water. Away means a spot the walker is well clear of (but still in reach);
## otherwise a spot near the walker. No such water: it hovers where it is.
func _dart(d: Dictionary, wp: Vector2, away: bool) -> void:
	var seed_n: int = int(d.seed) * 29 + int(_t * 4.0)
	var to: Vector2 = d.pos as Vector2
	var spot: Vector2 = _water_within(wp, seed_n, DRAGON_SHY * 2.0 if away else 0.0, REACH)
	if spot.is_finite():
		to = spot
	d.to = to
	d.hover = _range(DRAGON_HOVER, seed_n + 5)


func _update_fish(delta: float, wp: Vector2, calm: bool) -> void:
	var share: float = fish_share()
	for f: Dictionary in _fish:
		if bool(f.jump):
			f.t = float(f.t) + delta
			if float(f.t) >= FISH_TIME:
				f.jump = false
				_rings.append({"pos": f.pos, "age": 0.0})
			continue
		if calm or _water.is_empty():
			continue
		f.timer = float(f.timer) - delta
		if float(f.timer) > 0.0:
			continue
		f.timer = _range(FISH_EVERY, int(f.body) * 11 + int(_t * 2.0) + 3)
		if MeadowLife.hash01(int(f.body) * 17 + int(_t * 5.0)) < share:
			var spot: Vector2 = _water_within(wp, int(f.body) * 13 + int(_t * 9.0), 0.0, REACH)
			if not spot.is_finite():
				continue   # no water near the walker: no leap this time
			f.pos = spot
			f.flip = MeadowLife.hash01(int(_t * 6.0) + int(f.body)) < 0.5
			f.t = 0.0
			f.jump = true


func _update_deers(delta: float, wp: Vector2, calm: bool) -> void:
	if _edge.is_empty():
		return
	var share: float = deer_share()
	for d: Dictionary in _deers:
		var shown: bool = _rank_out(int(d.rank), DEER_MAX, share)
		if shown and float(d.fade) <= 0.0 and MeadowLife.iso_distance(d.pos as Vector2, wp) > GONE:
			var spot: Vector2 = _edge_within(wp, int(d.seed) * 23 + int(_t * 3.0), 0.0, REACH)
			if spot.is_finite():
				d.pos = spot
				d.to = spot
				d.wait = 0.0
		var near: bool = MeadowLife.iso_distance(d.pos as Vector2, wp) <= GONE
		d.fade = move_toward(float(d.fade), 1.0 if shown and near else 0.0, FADE_RATE * delta)
		if float(d.fade) <= 0.0 or calm:
			continue
		var pos: Vector2 = d.pos as Vector2
		d.flee = maxf(float(d.flee) - delta, 0.0)
		if float(d.flee) <= 0.0 and MeadowLife.iso_distance(pos, wp) < DEER_SHY:
			# Into the trees: the edge spot farthest from the walker.
			var far: Vector2 = pos
			var far_d: float = -1.0
			for e: Vector2 in _edge:
				var ed: float = MeadowLife.iso_distance(e, wp)
				if ed > far_d:
					far_d = ed
					far = e
			d.to = far
			d.flee = DEER_FLEE_TIME
		var to: Vector2 = d.to as Vector2
		if pos.distance_to(to) > 0.5:
			var step: Vector2 = to - pos
			var speed: float = DEER_RUN if float(d.flee) > 0.0 else DEER_SPEED
			var nxt: Vector2 = pos + step.normalized() * minf(speed * delta, step.length())
			if _blocked(nxt):
				d.to = pos
			else:
				d.pos = nxt
				if absf(step.x) > 0.1:
					d.dir = signf(step.x)
		else:
			d.wait = float(d.wait) - delta
			if float(d.wait) <= 0.0:
				d.wait = _range(DEER_WAIT, int(d.seed) * 5 + int(_t * 3.0) + 41)
				var graze: Vector2 = _edge_within(wp, int(d.seed) * 23 + int(_t * 3.0), 0.0, REACH)
				d.to = graze if graze.is_finite() else pos


func _update_owls(delta: float, wp: Vector2, calm: bool) -> void:
	var share: float = owl_share()
	for o: Dictionary in _owls:
		if float(o.fly) > 0.0:
			o.fly = float(o.fly) - delta
			o.fade = move_toward(float(o.fade), 0.0, FADE_RATE * delta)
			if float(o.fly) <= 0.0:
				o.perch = int(o.next)
			continue
		var perch: Vector2 = _perches[int(o.perch)]
		if not calm and float(o.fade) > 0.5 and MeadowLife.iso_distance(perch, wp) < OWL_SHY:
			o.next = _far_perch(wp, int(o.perch))
			o.fly = OWL_FLY_TIME
			continue
		var want: bool = _rank_out(int(o.rank), OWL_MAX, share)
		if want and float(o.fade) <= 0.0 and MeadowLife.iso_distance(perch, wp) > GONE:
			var spot: int = _perch_within(wp, int(o.seed), int(o.perch))
			if spot >= 0:
				o.perch = spot
				o.next = spot
				perch = _perches[spot]
		var near: bool = MeadowLife.iso_distance(perch, wp) <= GONE
		o.fade = move_toward(float(o.fade), 1.0 if want and near else 0.0, FADE_RATE * delta)
		o.blink = float(o.blink) - delta
		if float(o.blink) <= 0.0:
			o.shut = OWL_BLINK_TIME
			o.blink = _range(OWL_BLINK_EVERY, int(o.seed) * 3 + int(_t * 2.0))
		o.shut = maxf(float(o.shut) - delta, 0.0)


## A perch the walker is well clear of, starting after the current one. A perch still in reach is preferred.
func _far_perch(wp: Vector2, current: int) -> int:
	var band: int = _perch_within(wp, current + 1, current)
	if band >= 0:
		return band
	for k: int in _perches.size():
		var c: int = (current + 1 + k) % _perches.size()
		if MeadowLife.iso_distance(_perches[c], wp) > OWL_SHY * 2.0:
			return c
	return current


## A perch whose distance from the walker is between OWL_SHY * 2 and REACH, starting at index seed_n; -1 when none is.
func _perch_within(wp: Vector2, seed_n: int, current: int) -> int:
	var count: int = _perches.size()
	if count == 0:
		return -1
	for k: int in count:
		var c: int = (seed_n + k) % count
		var dist: float = MeadowLife.iso_distance(_perches[c], wp)
		if c != current and dist >= OWL_SHY * 2.0 and dist <= REACH:
			return c
	return -1


## A forest-edge spot whose distance from the walker is between near_min and reach, or Vector2.INF when none is.
func _edge_within(wp: Vector2, seed_n: int, near_min: float, reach: float) -> Vector2:
	var near: Array[Vector2] = []
	for e: Vector2 in _edge:
		var dist: float = MeadowLife.iso_distance(e, wp)
		if dist >= near_min and dist <= reach:
			near.append(e)
	if near.is_empty():
		return Vector2.INF
	return near[int(MeadowLife.hash01(seed_n) * float(near.size())) % near.size()]


func _blocked(p: Vector2) -> bool:
	return MeadowLife.near_any(p, _pads, DEER_PAD_KEEP) or MeadowLife.in_water(p, _water, 1.1)


## A water point whose distance from the walker is between near_min and reach, or Vector2.INF when no water is that close.
func _water_within(wp: Vector2, seed_n: int, near_min: float, reach: float) -> Vector2:
	var n: int = _water.size()
	if n == 0:
		return Vector2.INF
	for tries: int in 24:
		var cand: Vector2 = _water_point((seed_n + tries) % n, seed_n * 13 + tries * 5)
		var dist: float = MeadowLife.iso_distance(cand, wp)
		if dist >= near_min and dist <= reach:
			return cand
	return Vector2.INF


## A point inside water body b, chosen by hash and kept inside WATER_INNER of its edge.
func _water_point(b: int, seed_n: int) -> Vector2:
	var w: Dictionary = _water[b]
	var a: float = TAU * MeadowLife.hash01(seed_n)
	var r: float = sqrt(MeadowLife.hash01(seed_n + 1)) * WATER_INNER
	return Vector2(float(w.x) + float(w.rx) * cos(a) * r, float(w.y) + float(w.ry) * sin(a) * r)


func _range(r: Vector2, seed_n: int) -> float:
	return r.x + MeadowLife.hash01(seed_n) * (r.y - r.x)


func _seen(p: Vector2) -> bool:
	return not _view.has_area() or _view.grow(12.0).has_point(p)


func _draw_dragon(d: Dictionary, tb: float) -> void:
	if float(d.fade) <= 0.0:
		return
	var at: Vector2 = d.pos as Vector2
	if not _seen(at):
		return
	var up: bool = posmod(int(tb * 8.0) + int(d.seed), 2) == 0
	var spr: Dictionary = _sprites["dragon_up" if up else "dragon_down"] as Dictionary
	var origin: Vector2i = Vector2i(roundi(at.x) - 5, roundi(at.y) - 2)
	MeadowLife.blit(_ci, palette, spr, origin, (d.to as Vector2).x < at.x, float(d.fade))


func _draw_fish(f: Dictionary) -> void:
	if not bool(f.jump):
		return
	var at: Vector2 = f.pos as Vector2
	if not _seen(at):
		return
	var k: float = clampf(float(f.t) / FISH_TIME, 0.0, 1.0)
	var lift: float = sin(PI * k) * FISH_HEIGHT
	var origin: Vector2i = Vector2i(roundi(at.x) - 4, roundi(at.y - lift) - 2)
	MeadowLife.blit(_ci, palette, _sprites["fish"] as Dictionary, origin, bool(f.flip), 1.0)


func _draw_deer(e: Dictionary) -> void:
	if float(e.fade) <= 0.0:
		return
	var at: Vector2 = e.pos as Vector2
	if not _seen(at):
		return
	var origin: Vector2i = Vector2i(roundi(at.x) - 5, roundi(at.y) - 7)
	MeadowLife.blit(_ci, palette, _sprites["deer"] as Dictionary, origin, float(e.dir) < 0.0, float(e.fade))


func _draw_owl(o: Dictionary) -> void:
	if float(o.fade) <= 0.0:
		return
	var at: Vector2 = _perches[int(o.perch)]
	if not _seen(at):
		return
	var spr: Dictionary = _sprites["owl_shut" if float(o.shut) > 0.0 else "owl"] as Dictionary
	var origin: Vector2i = Vector2i(roundi(at.x) - 2, roundi(at.y) - 2)
	MeadowLife.blit(_ci, palette, spr, origin, false, float(o.fade))


func _draw_ring(r: Dictionary) -> void:
	var f: float = float(r.age) / RING_LIFE
	var rx: float = 2.0 + f * 9.0
	var ry: float = rx * 0.5
	var c: Vector2 = r.pos as Vector2
	var n: int = 28
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var x: int = roundi(c.x + cos(a) * rx)
		var y: int = roundi(c.y + sin(a) * ry)
		if MeadowLife.bayer(x, y) < 1.0 - f:
			_ci.draw_rect(Rect2(x, y, 1, 1), palette[7])


func _build_sprites() -> void:
	if not _sprites.is_empty():
		return
	_sprites["dragon_up"] = LifeCritters._make_sprite(DRAGON_UP)
	_sprites["dragon_down"] = LifeCritters._make_sprite(DRAGON_DOWN)
	_sprites["fish"] = LifeCritters._make_sprite(FISH_ART)
	_sprites["deer"] = LifeCritters._make_sprite(DEER_ART)
	_sprites["owl"] = LifeCritters._make_sprite(OWL_OPEN)
	_sprites["owl_shut"] = LifeCritters._make_sprite(OWL_SHUT)


static func _points(a: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Variant in a:
		var q: Array = p as Array
		out.append(Vector2(float(q[0]), float(q[1])))
	return out
