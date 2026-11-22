class_name TexelGate
extends Node2D
## Zone gate marker. Draws a pulsing ring once the Sim has latched the gate; walking in enters the next zone.

const RADIUS: float = 16.0

var zone_id: StringName
var walker: TexelWalker
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	var sim: Sim = GameState.sim
	if not sim.is_gate_open(zone_id):
		return
	queue_redraw()
	if walker.position.distance_to(position) <= RADIUS:
		var z: ZoneDef = sim.zone_defs.get(zone_id) as ZoneDef
		if z != null and z.next_zone != &"":
			GameState.enter_zone(z.next_zone)


func _draw() -> void:
	if not GameState.sim.is_gate_open(zone_id):
		return
	var r: float = 10.0 + float(int(_t * 6.0) % 3)
	draw_polyline(PackedVector2Array([Vector2(-r, 0), Vector2(0, -r * 0.5), Vector2(r, 0), Vector2(0, r * 0.5), Vector2(-r, 0)]), palette[4], 1.0)
	draw_rect(Rect2(-1, -20 - float(int(_t * 4.0) % 2), 2, 6), palette[5])
