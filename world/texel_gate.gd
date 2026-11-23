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
var back_to: StringName = &""   ## set on the arch at the way back: always open, and main walks the player through it
var walker: Node2D   ## typed loosely: TexelWalker reads the GameState autoload, which --script tests cannot compile
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
	if back_to != &"":
		return   # the way back is walked through by main (_update_arch)
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


## Tooltip for the way back: where it leads.
static func back_spec(sim: Sim, from_id: StringName, to_id: StringName) -> Dictionary:
	var from_z: ZoneDef = sim.zone_defs.get(from_id) as ZoneDef
	var to_z: ZoneDef = sim.zone_defs.get(to_id) as ZoneDef
	if from_z == null or to_z == null:
		return {}
	var green: Color = Palettes.colors(Palettes.MEADOW)[4]
	return {"title": "Passage to %s" % to_z.display_name, "title_color": green, "color": green,
		"body": "A cave mouth in the rock. Green light and cool air drift out. Walk in to go back.", "hint": "Open", "hint_color": StatStyle.buy(true)}


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
		spec["lines"] = [["Needs ", Tip.icon(String(z.gate_stat)), Tip.seg(need.format(), StatStyle.gain()), " ", Tip.seg(sname, StatStyle.color(z.gate_stat))]]
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
	var open: bool = back_to != &"" or (gs.get("sim") as Sim).is_gate_open(zone_id)
	if art == &"forge" and back_to != &"":
		_draw_cave()
		return
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
	if back_to != &"":
		seam_on = p[7] if int(_t * 5.0) % 4 != 0 else p[5]   # the way back glows cool ash, the way on glows ember
	var seam: Color = seam_on if open else p[2]
	# the doorway: a dark recess in the rock, glowing from the floor up when the gate is open
	var rx: float = -HALF_SPAN + float(PILLAR_W) * 0.5
	var rw: float = HALF_SPAN * 2.0 - float(PILLAR_W)
	draw_rect(Rect2(rx, -HEIGHT, rw, HEIGHT), soot)
	if open:
		for i in 14:
			var gy: float = -float(i) * 1.5
			var col: Color = p[3] if i < 5 else p[2] if i < 9 else p[1]
			if i % 2 == 0 or i < 4:
				draw_rect(Rect2(rx + float(i % 3), gy - 1.0, rw - float(i % 3) * 2.0, 1.5), col)
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


# ---------------------------------------------------------------- the way back: a cave mouth to the meadow
const CAVE_W: int = 66       ## baked image size; origin x is the centre, y 0 is the floor line at row CAVE_FLOOR
const CAVE_H: int = 54
const CAVE_FLOOR: int = 50
static var _cave_tex: ImageTexture = null


static func _hash(a: int, b: int = 0) -> float:
	var n: int = (a * 374761393 + b * 668265263 + 1274126177) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(n & 0xFFFF) / 65535.0


## Rough basalt opening in the rock, a dark inside with a patch of green daylight deep in it, and a lit floor.
## Quarry palette for the rock, meadow palette for the light and grass, so it reads as another place.
static func _bake_cave() -> ImageTexture:
	var q: PackedColorArray = Palettes.colors(Palettes.for_zone(&"zone2"))
	var m: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	var img: Image = Image.create(CAVE_W, CAVE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox: int = CAVE_W / 2
	for x in range(-31, 32):
		var n: float = _hash(x, 3)
		var outer_top: int = int(-46.0 + float(x * x) / 120.0 + n * 3.0)
		var open_top: int = int(-34.0 + float(x * x) / 31.5) if absi(x) <= 21 else 1
		for y in range(outer_top, open_top):
			var c: Color = q[6]
			if x < -8 and (x + y) % 2 == 0:
				c = q[1]
			if y == outer_top:
				c = q[5]
			elif (y - outer_top) % 6 == 5:
				c = q[1]
			elif y >= open_top - 2 and absi(x) <= 21:
				c = q[0]
			img.set_pixel(x + ox, y + CAVE_FLOOR, c)
		if absi(x) <= 21:
			for y in range(open_top, 0):
				var d: float = pow(float(x) / 14.0, 2.0) + pow(float(y + 12) / 9.0, 2.0)
				var c2: Color = q[0]
				if d < 1.0:
					# a window onto the meadow: pale sky over a band of grass, ringed by a soft green edge
					if y >= -11:
						c2 = m[3] if (x + y) % 2 == 0 else m[2]
						if y == -11:
							c2 = m[4]
					elif d < 0.5:
						c2 = m[7]
					else:
						c2 = m[4]
					if d > 0.8:
						c2 = m[2] if (x + y) % 2 == 0 else q[0]
				elif d < 1.25 and (x + y) % 2 == 0:
					c2 = m[1]
				img.set_pixel(x + ox, y + CAVE_FLOOR, c2)
			# floor inside: green light spilling toward the door
			for y: int in [-2, -1, 0]:
				var span: int = 12 + 3 * (y + 2)
				if absi(x) <= span:
					img.set_pixel(x + ox, y + CAVE_FLOOR, m[3] if (x + y) % 2 == 0 else m[4])
	# moss on the rock top and draping down the sides of the opening
	for x in range(-31, 32):
		if _hash(x, 9) > 0.55:
			var ty: int = int(-46.0 + float(x * x) / 120.0 + _hash(x, 3) * 3.0)
			img.set_pixel(x + ox, ty + CAVE_FLOOR, m[3])
			if _hash(x, 11) > 0.5:
				img.set_pixel(x + ox, ty + 1 + CAVE_FLOOR, m[2])
	return ImageTexture.create_from_image(img)


func _draw_cave() -> void:
	if _cave_tex == null:
		_cave_tex = _bake_cave()
	draw_texture(_cave_tex, Vector2(-CAVE_W / 2, -CAVE_FLOOR))
	var m: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	# green light on the ground outside, shrinking away from the mouth
	for i in 5:
		var half: int = 16 - i * 3
		for x in range(-half, half + 1):
			if (x + i) % 2 == 0:
				draw_rect(Rect2(x, 1 + i, 1, 1), m[3] if i < 3 else m[2])
	# grass tufts along the base, tips swaying; a few meadow flowers
	for x in range(-31, 32, 2):
		var h: float = _hash(x, 21)
		if h < 0.35:
			continue
		var tall: int = 2 + int(h * 3.0)
		var sway: int = int(sin(_t * 1.6 + float(x) * 0.6) * 0.99 + 0.5)
		draw_rect(Rect2(x, -tall, 1, tall), m[3] if h < 0.75 else m[2])
		draw_rect(Rect2(x + sway, -tall - 1, 1, 1), m[4])
	var flowers: PackedInt32Array = PackedInt32Array([-27, -17, -11, 13, 20, 28])
	for i in flowers.size():
		var fx: int = flowers[i]
		draw_rect(Rect2(fx, -3, 1, 3), m[2])
		draw_rect(Rect2(fx - 1 + int(sin(_t * 1.2 + float(i)) * 0.99 + 0.5), -5, 2, 2), m[5] if i % 3 == 0 else m[7] if i % 3 == 1 else m[6])
	# cool air: motes drifting out of the dark
	for i in 7:
		var rise: float = fmod(_t * (5.0 + float(i % 3) * 2.0) + float(i) * 6.0, 26.0)
		var mx: float = -12.0 + float(i) * 4.0 + sin(_t * 0.9 + float(i)) * 2.0
		draw_rect(Rect2(floorf(mx), -4.0 - rise, 1, 1), m[4] if i % 2 == 0 else m[7])
