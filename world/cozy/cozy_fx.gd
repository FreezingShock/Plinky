class_name CozyFx
extends Node2D
## Effects on a cozy prop, drawn once per life step with palette indices only (as LifeAir does): a campfire's
## flames and sparks, a cottage's chimney smoke (Bayer-dithered puffs that drift with the wind) and a fountain's jets.
## Drawn as a child of its prop, so it sits on top of the sprite it belongs to. Moving parts freeze under Reduce Motion;
## flicker and blinks stay, because they change in place.

enum Mode { FLAME, SMOKE, JETS }

const IDX_INK: int = 0
const IDX_LIGHT: int = 4
const IDX_ACCENT: int = 5
const IDX_EARTH: int = 6
const IDX_PAPER: int = 7
const SMOKE_PUFFS: int = 5
const SMOKE_HEIGHT: float = 16.0
const JET_DROPS: int = 10

var mode: Mode = Mode.FLAME
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _t: float = 0.0
var _step: int = -1


static func make(m: Mode, at: Vector2) -> CozyFx:
	var fx := CozyFx.new()
	fx.mode = m
	fx.position = at
	return fx


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var s: int = int(_t / GraphicsQuality.life_step())
	if s != _step:
		_step = s
		queue_redraw()


func _draw() -> void:
	var tb: float = float(maxi(_step, 0)) * GraphicsQuality.life_step()
	var still: bool = MeadowLife.reduce_motion
	var tm: float = 0.0 if still else tb
	match mode:
		Mode.FLAME:
			_flame(tb)
		Mode.SMOKE:
			_smoke(tm)
		Mode.JETS:
			_jets(tm)


func _dot(p: Vector2i, idx: int) -> void:
	draw_rect(Rect2(p.x, p.y, 1, 1), palette[idx])


## Three tongues of flame over the logs. Each one's height flickers on the life step (in place, so Reduce Motion keeps it).
func _flame(tb: float) -> void:
	var beat: int = int(tb * 12.0)
	for k: int in 3:
		var base_x: int = (k - 1) * 3
		var h: int = 3 + int(MeadowLife.hash01(beat * 3 + k) * 4.0)
		for y: int in h:
			var half: int = maxi(int(float(h - y) * 0.45), 0)
			for x: int in range(-half, half + 1):
				var idx: int = IDX_EARTH
				if y >= 1:
					idx = IDX_ACCENT
				if y >= h - 2:
					idx = IDX_PAPER
				_dot(Vector2i(base_x + x, -2 - y), idx)
	# a spark or two, climbing and fading out on the step
	for k: int in 2:
		var age: float = fposmod(tb * 0.8 + float(k) * 0.5, 1.0)
		var p: Vector2i = Vector2i(roundi(float(k * 5 - 3) + sin(age * 6.0) * 1.5), roundi(-6.0 - age * 9.0))
		if MeadowLife.bayer(p.x, p.y) < 1.0 - age:
			_dot(p, IDX_LIGHT)


## Puffs that rise from the chimney top, widen, drift with the wind and thin out by dither.
func _smoke(tm: float) -> void:
	var drift: float = MeadowLife.wind * 7.0
	for k: int in SMOKE_PUFFS:
		var age: float = fposmod(tm * 0.32 + float(k) / float(SMOKE_PUFFS), 1.0)
		var r: float = 1.0 + age * 2.6
		var cx: float = age * drift + sin(age * 3.0 + float(k)) * 1.2
		var cy: float = -age * SMOKE_HEIGHT
		var fade: float = (1.0 - age) * 0.9
		for dy: int in range(-ceili(r), ceili(r) + 1):
			for dx: int in range(-ceili(r), ceili(r) + 1):
				if float(dx * dx + dy * dy) > r * r:
					continue
				var p: Vector2i = Vector2i(roundi(cx) + dx, roundi(cy) + dy)
				if MeadowLife.bayer(p.x, p.y) < fade:
					_dot(p, IDX_PAPER)


## Water rises from the pillar top in arcs and falls back into the basin. Each drop follows the same parabola
## and starts at its own point in the cycle, so the jet looks continuous.
func _jets(tm: float) -> void:
	for k: int in JET_DROPS:
		var t: float = fposmod(tm * 0.7 + float(k) / float(JET_DROPS), 1.0)
		var vx: float = (float(k % 3) - 1.0) * 2.5
		var p: Vector2i = Vector2i(roundi(vx * t * 2.0), roundi(8.0 * t - 48.0 * t * (1.0 - t)))
		_dot(p, IDX_PAPER if k % 2 == 0 else IDX_ACCENT)
