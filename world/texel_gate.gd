class_name TexelGate
extends Node2D
## Zone gate marker. Walking in once the Sim has latched the gate enters the next zone. A zone can give the gate
## its own drawn arch (ZoneDef.gate_art): "forge" is the Ember Quarry's basalt and iron arch with glowing seams,
## shut behind an iron grate until the gate opens. Zones without art keep the plain pulsing ring.

signal dead_end   ## the gate is open but leads nowhere yet (the last zone built); main shows a banner

const RADIUS: float = 16.0
const HALF_SPAN: float = 26.0        ## pillar centres sit this far either side of the gate anchor
const PILLAR_W: int = 10
const HEIGHT: int = 46
const HIT: Rect2 = Rect2(-34.0, -56.0, 68.0, 62.0)

var zone_id: StringName
var art: StringName = &""
var walker: TexelWalker
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _t: float = 0.0
var _inside: bool = false


func _process(delta: float) -> void:
	_t += delta
	var gs: Node = _gs()
	if gs == null:
		return
	var sim: Sim = gs.get("sim") as Sim
	if art != &"" or sim.is_gate_open(zone_id):
		queue_redraw()
	var near: bool = walker.position.distance_to(position) <= RADIUS
	if not sim.is_gate_open(zone_id):
		_inside = near
		return
	if not near:
		_inside = false
		return
	var z: ZoneDef = sim.zone_defs.get(zone_id) as ZoneDef
	if z != null and z.next_zone != &"":
		gs.call("enter_zone", z.next_zone)
	elif not _inside:
		dead_end.emit()
	_inside = true


## The GameState autoload, looked up by path so this script also compiles under --script (tests have no autoloads).
func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")


## True when a point in world texels is over the drawn arch (only zones with gate art are hoverable).
func hit(world_pos: Vector2) -> bool:
	return art != &"" and HIT.has_point(world_pos - position)


## Tooltip content for the shared Tip system: what the gate needs, or where it goes.
static func spec_for(sim: Sim, z_id: StringName) -> Dictionary:
	var z: ZoneDef = sim.zone_defs.get(z_id) as ZoneDef
	if z == null:
		return {}
	var open: bool = sim.is_gate_open(z_id)
	var col: Color = Palettes.colors(Palettes.for_zone(z_id))[4]
	var spec: Dictionary = {"title": "%s Gate" % z.display_name, "title_color": col, "color": col, "icon": String(z.gate_stat)}
	var need: BigNum = BigNum.from_float(z.gate_threshold)
	var have: BigNum = sim.get_stat(z.gate_stat) if z.gate_stat != &"" else need
	var sd: StatDef = sim.stat_defs.get(z.gate_stat) as StatDef
	var sname: String = sd.display_name if sd != null else String(z.gate_stat)
	if not open:
		spec["body"] = "Sealed behind an iron grate."
		spec["lines"] = [["Needs ", Tip.icon(String(z.gate_stat)), Tip.seg(need.format(), StatStyle.BUY_GREEN), " ", Tip.seg(sname, StatStyle.color(z.gate_stat))]]
		spec["hint"] = "Need %s more" % need.sub(have).format()
		spec["hint_color"] = StatStyle.buy(false)
	elif z.next_zone != &"":
		var nz: ZoneDef = sim.zone_defs.get(z.next_zone) as ZoneDef
		spec["body"] = "Open. Walk in to travel to %s." % (nz.display_name if nz != null else String(z.next_zone))
		spec["hint"] = "Open"
		spec["hint_color"] = StatStyle.buy(true)
	else:
		spec["body"] = "The grate is up, but the way on is still being forged."
		spec["hint"] = "Nothing beyond yet"
		spec["hint_color"] = col
	return spec


func _draw() -> void:
	var gs: Node = _gs()
	if gs == null:
		return
	var open: bool = (gs.get("sim") as Sim).is_gate_open(zone_id)
	if art == &"forge":
		_draw_forge(open)
		return
	if not open:
		return
	var r: float = 10.0 + float(int(_t * 6.0) % 3)
	draw_polyline(PackedVector2Array([Vector2(-r, 0), Vector2(0, -r * 0.5), Vector2(r, 0), Vector2(0, r * 0.5), Vector2(-r, 0)]), palette[4], 1.0)
	draw_rect(Rect2(-1, -20 - float(int(_t * 4.0) % 2), 2, 6), palette[5])


## Palette indices: 0 soot, 1 deep red, 2 brick, 3 ember, 4 gold, 5 ash rose, 6 basalt violet, 7 pale.
func _draw_forge(open: bool) -> void:
	var p: PackedColorArray = palette
	var soot: Color = p[0]
	var seam_on: Color = p[4] if int(_t * 5.0) % 4 != 0 else p[3]
	var seam: Color = seam_on if open else p[2]
	# ground glow under the opening when open
	if open:
		draw_rect(Rect2(-HALF_SPAN + 6, -2, HALF_SPAN * 2 - 12, 2), p[3])
		draw_rect(Rect2(-HALF_SPAN + 12, -1, HALF_SPAN * 2 - 24, 1), p[4])
	# the grate: iron bars across the opening while shut
	if not open:
		var x: int = int(-HALF_SPAN) + PILLAR_W / 2 + 2
		while x < int(HALF_SPAN) - PILLAR_W / 2 - 1:
			draw_rect(Rect2(x, -HEIGHT + 4, 1, HEIGHT - 4), soot)
			draw_rect(Rect2(x + 1, -HEIGHT + 4, 1, HEIGHT - 4), p[1])
			x += 4
		for y: int in [-34, -20, -8]:
			draw_rect(Rect2(-HALF_SPAN + 7, y, HALF_SPAN * 2 - 14, 2), soot)
			draw_rect(Rect2(-HALF_SPAN + 7, y, HALF_SPAN * 2 - 14, 1), p[6])
	else:
		# heat shimmer rising in the doorway: gold and ember flecks climbing the opening
		for i in 9:
			var fx: float = -HALF_SPAN + 9.0 + float(i) * 4.4
			var ph: float = fmod(_t * (14.0 + float(i % 3) * 4.0) + float(i) * 7.0, float(HEIGHT - 6))
			draw_rect(Rect2(floorf(fx), -2.0 - floorf(ph), 1, 2), p[4] if i % 2 == 0 else p[3])
	for side: int in [-1, 1]:
		var cx: int = int(side * HALF_SPAN) - PILLAR_W / 2
		# basalt column: shaded left face, lit right face, ash rim on the top edge
		draw_rect(Rect2(cx, -HEIGHT, PILLAR_W / 2, HEIGHT), p[1])
		draw_rect(Rect2(cx + PILLAR_W / 2, -HEIGHT, PILLAR_W / 2, HEIGHT), p[6])
		draw_rect(Rect2(cx, -HEIGHT, PILLAR_W, 1), p[5])
		# iron bands
		for y: int in [-HEIGHT + 2, -28, -10]:
			draw_rect(Rect2(cx - 1, y, PILLAR_W + 2, 3), soot)
			draw_rect(Rect2(cx - 1, y, PILLAR_W + 2, 1), p[1])
		# glowing seam down the lit face, flowing upward when open
		for y in range(-HEIGHT + 5, -2):
			if open:
				draw_rect(Rect2(cx + 6, y, 1, 1), seam_on if (y + int(_t * 18.0)) % 6 < 4 else p[3])
			elif y % 7 == 0:
				draw_rect(Rect2(cx + 6, y, 1, 1), seam)
		# plinth
		draw_rect(Rect2(cx - 2, -3, PILLAR_W + 4, 3), soot)
		draw_rect(Rect2(cx - 2, -3, PILLAR_W + 4, 1), p[6])
	# lintel: an iron beam across the pillar tops with a rune keystone
	var lx: int = int(-HALF_SPAN) - PILLAR_W / 2 - 3
	var lw: int = int(HALF_SPAN) * 2 + PILLAR_W + 6
	draw_rect(Rect2(lx, -HEIGHT - 6, lw, 6), soot)
	draw_rect(Rect2(lx, -HEIGHT - 6, lw, 1), p[6])
	draw_rect(Rect2(lx, -HEIGHT - 2, lw, 1), p[1])
	for x in range(lx + 3, lx + lw - 3):
		if open and (x + int(_t * 16.0)) % 8 < 3:
			draw_rect(Rect2(x, -HEIGHT - 4, 1, 1), seam_on)
		elif not open and x % 9 == 0:
			draw_rect(Rect2(x, -HEIGHT - 4, 1, 1), seam)
	draw_rect(Rect2(-4, -HEIGHT - 2, 8, 8), soot)
	draw_rect(Rect2(-3, -HEIGHT - 1, 6, 6), p[6])
	draw_rect(Rect2(-1, -HEIGHT + 1, 2, 2), seam_on if open else p[1])
