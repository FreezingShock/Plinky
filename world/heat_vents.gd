class_name HeatVents
extends Node2D
## Zone 2 vents. Standing on a vent charges Heat (Sim.feed_heat), the pips over the walker show it, and a Hot press
## pays more. All numbers live on the ZoneDef. Draws palette indices only, stepped at 12 fps, no alpha.

const PIPS: int = 10
const STEP: float = 1.0 / 12.0

var walker: TexelWalker
var palette: PackedColorArray = Palettes.colors(Palettes.QUARRY)
var vents: Array[Vector3] = []   ## x, y = texel position, z = radius (vertical distance doubled for the 2:1 ground)
var _t: float = 0.0
var _acc: float = 0.0
var _on_vent: bool = false
var _pips: Pips


## Reads Vent0, Vent1, ... markers from the zone scene's Anchors node.
func setup(anchors: Node) -> void:
	vents.clear()
	for c: Node in anchors.get_children():
		if String(c.name).begins_with("Vent"):
			var m: Marker2D = c as Marker2D
			vents.append(Vector3(m.position.x, m.position.y, float(m.get_meta("radius", 14.0))))
	if _pips == null:
		_pips = Pips.new()
		_pips.owner_vents = self
		_pips.z_index = 20
		add_child(_pips)


func _physics_process(delta: float) -> void:
	var sim: Sim = GameState.sim
	if walker == null or not sim.heat_enabled():
		return
	_on_vent = false
	for v: Vector3 in vents:
		var d: Vector2 = walker.position - Vector2(v.x, v.y)
		if Vector2(d.x, d.y * 2.0).length() <= v.z:
			_on_vent = true
	if _on_vent:
		sim.feed_heat(delta)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= STEP:
		_acc = 0.0
		queue_redraw()
		if _pips != null:
			_pips.queue_redraw()


func _draw() -> void:
	var sim: Sim = GameState.sim
	if walker == null or not sim.heat_enabled():
		return
	var frame: int = int(_t * 6.0)
	for v: Vector3 in vents:
		var r: float = v.z - 4.0 + float((frame + int(v.x)) % 4)
		var pts := PackedVector2Array()
		for i in 13:
			var a: float = float(i) / 12.0 * TAU
			pts.append(Vector2(v.x + cos(a) * r, v.y + sin(a) * r * 0.5).round())
		draw_polyline(pts, palette[4] if frame % 2 == 0 else palette[3], 1.0)


## Pips over the walker: one per heat point. Base colour while charging, paper once Hot, a tick at the hot line.
class Pips extends Node2D:
	var owner_vents: HeatVents

	func _draw() -> void:
		var sim: Sim = GameState.sim
		var w: TexelWalker = owner_vents.walker
		if w == null or not sim.heat_enabled() or sim.heat <= 0.01:
			return
		var pal: PackedColorArray = owner_vents.palette
		var hot: bool = sim.is_hot()
		var n: int = ceili(sim.heat)
		var origin: Vector2 = (w.position + Vector2(-float(HeatVents.PIPS) * 2.0, -26.0)).round()
		for i in HeatVents.PIPS:
			var lit: bool = i < n
			var at: Vector2 = origin + Vector2(float(i) * 4.0, 0.0)
			draw_rect(Rect2(at, Vector2(3, 3)), pal[0])
			if lit:
				draw_rect(Rect2(at, Vector2(3, 3)), pal[7] if hot else pal[3])
			else:
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 1)), pal[1])
		var line: int = int(sim.current_zone().heat_hot_at)
		draw_rect(Rect2(origin + Vector2(float(line) * 4.0 - 1.0, 4.0), Vector2(1, 2)), pal[4])
