class_name CozySwarm
extends Node2D
## Fireflies that gather in swarms around the water's edge and the wheat, on top of the meadow's own fireflies.
## They come out with the dark and the season (the same curve LifeAir uses), and they blink on the same 1.2 s lit
## phase. Drift stops under Reduce Motion; the blinks stay. Every position is a pure function of time, as in LifeAir.

const IDX_DARK: int = 1
const IDX_ACCENT: int = 5
const IDX_PAPER: int = 7
const TOTAL: int = 36                 # the most swarm fireflies out at full dark
const SWARM_RADIUS: float = 7.0       # how far a firefly strays from its swarm's centre
const STEP_MAX: float = 1.0 / 12.0

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _centres: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0
var _step: int = -1
var _view: Rect2 = Rect2()


## Share of the swarm fireflies out: the dark, less in the rain, and the season's mix (spring 0.7, summer 1, autumn 0.45).
static func share_for(night: float, low_sun: float, rain: float, season: Array[float]) -> float:
	var dark: float = clampf(night * 1.3 + low_sun * 0.55, 0.0, 1.0)
	var by_season: float = season[0] * 0.7 + season[1] * 1.0 + season[2] * 0.45 + season[3] * 0.0
	return dark * (1.0 - clampf(rain, 0.0, 1.0)) * by_season


static func count_for(share: float) -> int:
	return GraphicsQuality.life_scaled(roundi(float(TOTAL) * clampf(share, 0.0, 1.0)))


## Swarm centres from the shoreline of each water body (its ellipse, a little outside the edge), plus the given grass spots.
static func centres_for(water: Array, grass: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Variant in water:
		var d: Dictionary = v as Dictionary
		var c := Vector2(float(d.get("sx", 0.0)), float(d.get("sy", 0.0)))
		var r := Vector2(float(d.get("rx", 1.0)), float(d.get("ry", 1.0)))
		var n: int = 6 if r.x > 40.0 else 4
		for i: int in n:
			var a: float = TAU * float(i) / float(n) + 0.3
			out.append(c + Vector2(cos(a) * r.x * 1.08, sin(a) * r.y * 1.08))
	for g: Variant in grass:
		out.append(g as Vector2)
	return out


static func make(centres: PackedVector2Array) -> CozySwarm:
	var s := CozySwarm.new()
	s._centres = centres
	s.z_index = 10   # above the meadow props, as the air layer is
	return s


func _ready() -> void:
	set_process(not _centres.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var s: int = int(_t / GraphicsQuality.life_step())
	if s != _step:
		_step = s
		queue_redraw()


func _draw() -> void:
	if _centres.is_empty():
		return
	var tb: float = float(maxi(_step, 0)) * GraphicsQuality.life_step()
	var tm: float = 0.0 if MeadowLife.reduce_motion else tb
	_view = GraphicsQuality.visible_local_rect(self)
	var n: int = count_for(share_for(MeadowLife.night, MeadowLife.low_sun, MeadowLife.rain, MeadowLife.season))
	for i: int in n:
		var home: Vector2 = _centres[i % _centres.size()]
		var s: float = float(i)
		var offset := Vector2(
			(MeadowLife.hash01(i * 5 + 1) - 0.5) * SWARM_RADIUS * 2.0,
			(MeadowLife.hash01(i * 5 + 2) - 0.5) * SWARM_RADIUS)
		var p: Vector2 = home + offset + Vector2(
			sin(tm * 0.41 + s * 1.7) * 4.0 + sin(tm * 0.17 + s) * 2.0,
			cos(tm * 0.31 + s * 2.1) * 3.0 - 4.0)
		var pos := Vector2i(roundi(p.x), roundi(p.y))
		if _view.has_area() and not _view.has_point(Vector2(pos)):
			continue
		var cycle: float = 4.0 + MeadowLife.hash01(i * 7 + 2) * 3.0
		var phase: float = fposmod(tb + MeadowLife.hash01(i * 11 + 3) * cycle, cycle)
		if phase >= 1.2:
			_dot(pos, IDX_DARK)
			continue
		var level: int = int(clampf(1.0 - absf(phase - 0.6) / 0.6, 0.0, 1.0) * 3.99)
		_dot(pos, IDX_PAPER if level == 3 else IDX_ACCENT)
		for dy: int in range(-level, level + 1):
			for dx: int in range(-level, level + 1):
				var d: int = absi(dx) + absi(dy)
				if d == 0 or d > level:
					continue
				if MeadowLife.bayer(pos.x + dx, pos.y + dy) < 1.0 - float(d) / float(level + 1):
					_dot(pos + Vector2i(dx, dy), IDX_ACCENT)


func _dot(p: Vector2i, idx: int) -> void:
	draw_rect(Rect2(p.x, p.y, 1, 1), palette[idx])
