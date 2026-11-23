class_name SeasonParticles
extends Node2D
## Seasonal air over the outdoor areas: petals in spring, sun motes in summer, falling leaves in autumn, snow in
## winter. Each particle is a pure function of time and its index (no state, like SkyRain). `weights` is the season
## mix from SkyCycle, so one kind fades out as the next fades in. Redrawn at 12 fps, 1-2 texel squares, nothing
## drawn under Reduce motion. Counts scale with GraphicsQuality and the area, and only the visible part is drawn.

const STEP: float = 1.0 / 12.0
const IDX_PAPER: int = 7
const IDX_LIGHT: int = 4
const IDX_ACCENT: int = 5
const IDX_EARTH: int = 6
const MAX_PER_KIND: int = 400

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var area: Rect2 = Rect2(-110.0, -70.0, 860.0, 500.0)
var config: CalendarConfig
var weights: Array[float] = [1.0, 0.0, 0.0, 0.0]
var snow_precip: float = 0.0   # 0..1, rain turned to snow
var wind: float = 0.0          # 0..1
var _t: float = 0.0
var _step: int = -1
var _empty: bool = false


func _process(delta: float) -> void:
	if MeadowLife.reduce_motion or _total() <= 0.001:
		if not _empty:
			_empty = true
			queue_redraw()   # clear once
		return
	_empty = false
	_t += delta
	var s: int = int(_t / STEP)
	if s != _step:
		_step = s
		queue_redraw()


func _total() -> float:
	var s: float = 0.0
	for w: float in weights:
		s += w
	return s


## How many particles of `kind` (0 petal, 1 sun mote, 2 leaf, 3 snow) are in the air at the moment.
func count_for(kind: int) -> int:
	if config == null or kind >= config.particle_counts.size():
		return 0
	var k: float = weights[kind]
	if kind == 3:
		k = clampf(k * 0.45 + snow_precip * 0.9, 0.0, 1.0)
	elif kind == 1:
		k *= 1.0 - MeadowLife.night            # motes are a daytime thing
	elif kind == 0 or kind == 2:
		k *= 1.0 - 0.7 * MeadowLife.rain       # wet petals and leaves stay down
	var area_k: float = minf(area.get_area() / 430000.0, 2.0)
	var n: int = int(ceilf(float(config.particle_counts[kind]) * k * area_k))
	return mini(GraphicsQuality.life_scaled(n), MAX_PER_KIND)


func _draw() -> void:
	if config == null or MeadowLife.reduce_motion:
		return
	var tb: float = float(maxi(_step, 0)) * STEP
	var view: Rect2 = GraphicsQuality.visible_local_rect(self)
	var culling: bool = view.has_area()
	for kind in 4:
		var n: int = count_for(kind)
		for i in n:
			_draw_one(kind, i, tb, view, culling)


func _draw_one(kind: int, i: int, tb: float, view: Rect2, culling: bool) -> void:
	var seed_i: int = i * 13 + kind * 977 + 5
	var ph: float = MeadowLife.hash01(seed_i)
	var ph2: float = MeadowLife.hash01(seed_i + 3)
	var h: float = area.size.y
	var speed: float
	match kind:
		0: speed = config.petal_speed * (0.7 + 0.6 * ph2)
		1: speed = -4.0 * (0.5 + ph2)                          # motes drift up
		2: speed = config.leaf_speed * (0.7 + 0.6 * ph2)
		_: speed = config.snow_speed * (0.6 + 0.8 * ph2) * (1.0 + 0.8 * snow_precip)
	var y: float = area.position.y + fposmod(ph * h + tb * speed, h)
	var sway_amp: float = 4.0 if kind == 3 else (14.0 if kind != 1 else 6.0)
	var drift: float = (0.25 + 0.8 * wind) * (y - area.position.y) * (0.3 if kind == 3 else 0.5)
	var x: float = area.position.x + fposmod(ph2 * area.size.x + drift + sin(tb * (0.8 + ph) + ph * 6.28) * sway_amp, area.size.x)
	var px: int = int(floorf(x))
	var py: int = int(floorf(y))
	if culling and not view.has_point(Vector2(px, py)):
		return
	match kind:
		0:
			var col: Color = config.petal_colors[i % config.petal_colors.size()] if config.petal_colors.size() > 0 else palette[IDX_PAPER]
			var flip: bool = int(tb * 3.0 + ph * 5.0) % 2 == 0
			draw_rect(Rect2(px, py, 2 if flip else 1, 1 if flip else 2), col)
		1:
			var tw: float = 0.5 + 0.5 * sin(tb * 2.5 + ph * 6.28)
			if tw > 0.35:
				draw_rect(Rect2(px, py, 1, 1), palette[IDX_ACCENT if i % 3 != 0 else IDX_PAPER])
		2:
			var flipl: bool = int(tb * 2.0 + ph * 7.0) % 2 == 0
			var lc: Color = palette[IDX_EARTH if i % 3 != 0 else IDX_ACCENT]
			draw_rect(Rect2(px, py, 2 if flipl else 1, 1 if flipl else 2), lc)
		_:
			var big: bool = i % 5 == 0
			draw_rect(Rect2(px, py, 2 if big else 1, 2 if big else 1), palette[IDX_PAPER])
