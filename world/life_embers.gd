class_name LifeEmbers
extends Node2D
## Air layer of the Ember Quarry: embers rise off the heat vents and the lava seams, ash flakes drift down the wind
## and a few cinders skitter. Every particle is a pure function of time and its index (no state, like SkyRain), redrawn
## in 12 fps steps with whole-texel squares and no alpha, so it stays on the palette and the dither look. Nothing
## travels under Reduce motion (embers freeze in place and still twinkle), and Low graphics draws fewer.
## Colours are quarry palette indices (art-bible section 3).

const EMBERS_PER_VENT: int = 7
const ASH: int = 16
const RISE: float = 11.0        # texels per second an ember climbs
const LIFE: float = 4.2         # seconds from vent to fade
const IDX_DARK: int = 1
const IDX_FLAME: int = 3
const IDX_GLOW: int = 4
const IDX_ASH: int = 5
const IDX_PAPER: int = 7

var palette: PackedColorArray = Palettes.colors(Palettes.QUARRY)
var vents: Array[Vector2] = []
var area: Rect2 = Rect2(-100.0, -60.0, 840.0, 480.0)
var _t: float = 0.0
var _step: int = -1
var _view: Rect2 = Rect2()


## Vent positions are the Vent0.. anchors of the zone scene.
func setup(anchors: Node) -> void:
	vents.clear()
	for c: Node in anchors.get_children():
		if String(c.name).begins_with("Vent"):
			vents.append((c as Marker2D).position)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var s: int = int(_t / GraphicsQuality.life_step())
	if s != _step:
		_step = s
		queue_redraw()


func _dot(p: Vector2i, idx: int) -> void:
	draw_rect(Rect2(p.x, p.y, 1, 1), palette[idx])


func _draw() -> void:
	var tb: float = float(maxi(_step, 0)) * GraphicsQuality.life_step()
	var tm: float = 0.0 if MeadowLife.reduce_motion else tb
	_view = GraphicsQuality.visible_local_rect(self)
	_draw_embers(tm, tb)
	if not MeadowLife.reduce_motion:
		_draw_ash(tm)


## True when texel p is on screen (or the layer cannot tell, so everything draws).
func _seen(p: Vector2i) -> bool:
	return not _view.has_area() or _view.has_point(Vector2(p))


## Embers lift from each vent, wobble sideways and cool as they climb: flame, then glow, then a dark speck, then gone.
func _draw_embers(tm: float, tb: float) -> void:
	var per: int = GraphicsQuality.life_scaled(EMBERS_PER_VENT)
	for v: int in vents.size():
		for k: int in per:
			var id: int = v * 31 + k
			var cycle: float = LIFE * (0.75 + MeadowLife.hash01(id * 5 + 1) * 0.5)
			var age: float = fposmod(tm + MeadowLife.hash01(id * 5 + 2) * cycle, cycle) / cycle   # 0 just lit .. 1 gone
			var spread: float = (MeadowLife.hash01(id * 5 + 3) - 0.5) * 16.0
			var x: float = vents[v].x + spread + sin(tm * 1.3 + float(id)) * 3.0 * age
			var y: float = vents[v].y - age * cycle * RISE * (0.6 + MeadowLife.hash01(id * 5 + 4) * 0.6)
			var p: Vector2i = Vector2i(roundi(x), roundi(y))
			if not _seen(p):
				continue
			var idx: int = IDX_PAPER if age < 0.12 else (IDX_GLOW if age < 0.4 else (IDX_FLAME if age < 0.75 else IDX_DARK))
			if idx == IDX_DARK and int(tb * 6.0 + float(id)) % 2 == 0:
				continue   # the last of it flickers out
			_dot(p, idx)


## Ash flakes drift on the wind and sink slowly, wrapping at the area edge. Every 5th is a brighter cinder.
func _draw_ash(tm: float) -> void:
	for i: int in GraphicsQuality.life_scaled(ASH):
		var speed: float = 6.0 + MeadowLife.hash01(i * 7 + 1) * 6.0
		var x: float = area.position.x + fposmod(MeadowLife.hash01(i * 7 + 2) * area.size.x + tm * speed * (0.6 + MeadowLife.wind), area.size.x)
		var y: float = area.position.y + fposmod(MeadowLife.hash01(i * 7 + 3) * area.size.y + tm * (2.0 + MeadowLife.hash01(i * 7 + 4) * 3.0), area.size.y)
		var p: Vector2i = Vector2i(roundi(x + sin(tm * 0.6 + float(i)) * 4.0), roundi(y))
		if not _seen(p):
			continue
		_dot(p, IDX_GLOW if i % 5 == 4 else IDX_ASH)
