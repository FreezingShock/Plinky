extends RefCounted
## Ground and water critters (world/life_critters.gd), butterflies on flower beds (world/life_butterflies.gd) and
## the birds' daylight and rain gate (world/life_react.gd). Pure checks on the data, plus a few stepped runs where the
## walker is passed in as a position (the helpers are RefCounted and need no scene tree).

const LARK_LIFE: String = "res://world/larkmoor_life.json"
const MEADOW_LIFE: String = "res://world/meadow_life.json"


func _w(a: float, b: float, c: float, d: float) -> Array[float]:
	var w: Array[float] = [a, b, c, d]
	return w


func _drawn_texels(rows: Array) -> int:
	var n: int = 0
	for r: Variant in rows:
		n += (r as String).replace(".", "").length()
	return n


func run(t: Object) -> void:
	var keep_season: Array[float] = MeadowLife.season.duplicate()
	var keep: Array[float] = [MeadowLife.night, MeadowLife.low_sun, MeadowLife.rain]
	var keep_calm: bool = MeadowLife.reduce_motion

	# Data: the flower beds and the pad sites the critters keep off.
	var lark: Dictionary = MeadowLife.load_data(LARK_LIFE)
	var meadow: Dictionary = MeadowLife.load_data(MEADOW_LIFE)
	t.ok((lark.get("flowers", []) as Array).size() >= 100, "Larkmoor has flower beds for butterflies")
	t.ok((meadow.get("flowers", []) as Array).size() >= 10, "the Starting Clearing has flower beds too")
	t.eq((lark.get("pad_sites", []) as Array).size(), (lark.get("pads", []) as Array).size(), "pad_sites holds every pad (none are hidden)")
	var lark_pads: Array[Vector2] = _vecs(lark.get("pad_sites", []) as Array)
	var lark_water: Array[Dictionary] = _waters(lark)
	var bad_bed: int = 0
	for p: Vector2 in _vecs(lark.get("flowers", []) as Array):
		if MeadowLife.near_any(p, lark_pads, 18.0) or MeadowLife.in_water(p, lark_water, 1.0):
			bad_bed += 1
	t.eq(bad_bed, 0, "no flower bed sits on a pad or in the water (Larkmoor)")

	# Sprites: every row of one sprite is the same width, so the runs line up.
	for rows: Array in [LifeCritters.RABBIT_SIT, LifeCritters.RABBIT_ALERT, LifeCritters.RABBIT_NIBBLE_ART,
			LifeCritters.RABBIT_HOP_ART, LifeCritters.DUCK_ART, LifeCritters.DUCK_SLEEP_ART,
			LifeCritters.FROG_ART, LifeCritters.FROG_TUCK_ART]:
		var w0: int = (rows[0] as String).length()
		var same: bool = true
		for r: Variant in rows:
			if (r as String).length() != w0:
				same = false
		t.ok(same, "sprite rows share one width (%d rows of %d)" % [rows.size(), w0])
	var sit: Dictionary = LifeCritters._make_sprite(LifeCritters.RABBIT_SIT)
	var texels: int = 0
	for run: Variant in sit.runs as Array:
		texels += (run as PackedInt32Array)[2]
	t.eq(texels, _drawn_texels(LifeCritters.RABBIT_SIT), "runs cover every drawn texel of the rabbit")

	# Dither fade: half the texels at half strength, and all of them at full.
	var kept: int = 0
	for y: int in 4:
		for x: int in 4:
			if MeadowLife.dissolved(0.5, x, y):
				kept += 1
	t.eq(kept, 8, "a fade of one half keeps half the dither cells")
	t.ok(MeadowLife.dissolved(1.0, 1, 2) and not MeadowLife.dissolved(0.0, 1, 2), "fade 1 shows everything, fade 0 nothing")

	# Shares: rain, winter and the middle of the day keep critters in.
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 0.0
	t.ok(LifeCritters.rabbit_share() < 0.25, "midday in summer: few rabbits out (%.2f)" % LifeCritters.rabbit_share())
	MeadowLife.night = 1.0
	t.ok(LifeCritters.rabbit_share() > 0.8, "night in summer: rabbits are out (%.2f)" % LifeCritters.rabbit_share())
	MeadowLife.rain = 1.0
	t.eq(LifeCritters.rabbit_share(), 0.0, "heavy rain: rabbits sit out")
	t.ok(LifeCritters.frog_share() > 0.7, "rain brings the frogs out (%.2f)" % LifeCritters.frog_share())
	MeadowLife.season = _w(0.0, 0.0, 0.0, 1.0)
	MeadowLife.rain = 0.0
	MeadowLife.night = 0.0
	t.eq(LifeCritters.frog_share(), 0.0, "winter: frogs stay under")
	t.ok(LifeCritters.rabbit_share() < 0.2, "winter: few rabbits (%.2f)" % LifeCritters.rabbit_share())
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 0.0
	t.ok(LifeReact.bird_share() > 0.95, "summer day: nearly every bird is on its perch")
	MeadowLife.night = 1.0
	t.ok(LifeReact.bird_share() < 0.15, "night: most birds roost (%.2f)" % LifeReact.bird_share())
	MeadowLife.night = 0.0
	MeadowLife.rain = 1.0
	t.ok(LifeReact.bird_share() < 0.2, "heavy rain: birds shelter (%.2f)" % LifeReact.bird_share())
	MeadowLife.rain = 0.0

	# Critters: stay off the pads and out of the water, duck in the water, frogs on the shore.
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 1.0
	var crit := LifeCritters.new()
	crit.setup(lark)
	var rabbits: Array = crit.get("_rabbits") as Array
	var ducks: Array = crit.get("_ducks") as Array
	var frogs: Array = crit.get("_frogs") as Array
	t.ok(rabbits.size() >= 2, "Larkmoor has rabbits (%d)" % rabbits.size())
	t.ok(ducks.size() >= lark_water.size(), "every water body has a duck (%d ducks)" % ducks.size())
	t.ok(frogs.size() >= lark_water.size(), "every water body has frogs on its shore (%d)" % frogs.size())
	var bad_home: int = 0
	for r: Variant in rabbits:
		var home: Vector2 = (r as Dictionary).home as Vector2
		if MeadowLife.near_any(home, lark_pads, LifeCritters.PAD_KEEP) or MeadowLife.in_water(home, lark_water, 1.0):
			bad_home += 1
	t.eq(bad_home, 0, "no rabbit burrow sits on a pad or in the water")
	var bad_duck: int = 0
	for d: Variant in ducks:
		if not MeadowLife.in_water((d as Dictionary).pos as Vector2, lark_water, 1.0):
			bad_duck += 1
	t.eq(bad_duck, 0, "every duck floats in the water")
	var bad_frog: int = 0
	for f: Variant in frogs:
		var home_f: Vector2 = (f as Dictionary).home as Vector2
		var on_shore: bool = false
		for w: Dictionary in lark_water:
			var k: float = MeadowLife.water_k(home_f, w)
			if k >= LifeCritters.WATER_KEEP and k <= LifeCritters.SHORE_OUT:
				on_shore = true
		if not on_shore:
			bad_frog += 1
	t.eq(bad_frog, 0, "every frog sits on the shore, just out of the water")
	var bad_shore: int = 0
	for f: Variant in frogs:
		var k: float = MeadowLife.water_k((f as Dictionary).home as Vector2, _water_of(lark, (f as Dictionary).body))
		if k < LifeCritters.WATER_KEEP or k > LifeCritters.SHORE_OUT:
			bad_shore += 1
	t.eq(bad_shore, 0, "frogs sit in the shore band around their own water")

	# Stepped run, reduce motion: a rabbit near the walker sits up and watches, and nothing travels.
	var walker := Node2D.new()
	MeadowLife.reduce_motion = true
	MeadowLife.rain = 0.0
	var rab: Dictionary = rabbits[0] as Dictionary
	var budget: int = GraphicsQuality.life_scaled(rabbits.size())   # Low draws fewer critters
	for i: int in mini(budget, rabbits.size()):
		var r: Dictionary = rabbits[i] as Dictionary
		if LifeCritters._out(int(r.seed) * 7 + 1, LifeCritters.rabbit_share()):
			rab = r
			break
	var home0: Vector2 = rab.home as Vector2
	walker.position = home0 + Vector2(12.0, 0.0)
	for i: int in 240:
		crit.update(1.0 / 30.0, walker.position)
	t.eq(rab.pos as Vector2, home0, "reduce motion: a rabbit does not hop away")
	t.ok(float(rab.watch) > 0.0, "reduce motion: the rabbit still watches the walker")

	# Stepped run, motion on: the same rabbit flees and ends well away from the walker.
	MeadowLife.reduce_motion = false
	walker.position = home0 + Vector2(-400.0, 0.0)
	for i: int in 180:
		crit.update(1.0 / 30.0, walker.position)   # fade in, walker far
	rab.fade = 1.0
	walker.position = home0 + Vector2(10.0, 0.0)
	var fled: bool = false
	for i: int in 240:
		crit.update(1.0 / 30.0, walker.position)
		if float(rab.hop_dur) > 0.0 or bool(rab.fleeing):
			fled = true
	t.ok(fled, "a walker close by sends a rabbit into a flight")
	t.ok(MeadowLife.iso_distance(rab.pos as Vector2, walker.position) > 30.0, "the fled rabbit ends well away from the walker")
	var bad_flight: int = 0
	for i: int in 60:
		if MeadowLife.in_water(rab.pos as Vector2, lark_water, 1.0):
			bad_flight += 1
		crit.update(1.0 / 30.0, walker.position)
	t.eq(bad_flight, 0, "a rabbit never runs into the water")

	# Frog: a walker close by sends a fading-in frog leaping into the water, out of sight. Summer rain brings them out.
	MeadowLife.rain = 1.0
	walker.position = (_first_home(frogs) + Vector2(-400.0, 0.0))
	var frog: Dictionary = {}
	for f: Variant in frogs:
		if LifeCritters._out(int((f as Dictionary).seed) * 11 + 3, LifeCritters.frog_share()):
			frog = f as Dictionary
			break
	if not frog.is_empty():
		for i: int in 60:
			crit.update(1.0 / 30.0, walker.position)   # fade in
		walker.position = (frog.home as Vector2) + Vector2(8.0, 0.0)
		crit.update(0.1, walker.position)
		t.eq(int(frog.state), 1, "a walker close by sends a frog leaping")
		for i: int in 60:
			crit.update(1.0 / 30.0, walker.position)
		t.eq(int(frog.state), 2, "a frog that has leapt is in the water, out of sight")
	else:
		t.ok(false, "a frog is out in summer rain to test the leap")

	MeadowLife.rain = 0.0

	# Butterflies: they rest on beds, flit when left alone, and scatter from a walker. Reduce motion keeps them on the bed.
	var fly := LifeButterflies.new()
	fly.setup(lark)
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 0.0
	walker.position = Vector2(-9000.0, -9000.0)
	for i: int in 90:
		fly.update(1.0 / 30.0, walker.position)
	var out_n: int = 0
	for f: Variant in fly.get("_flies") as Array:
		if float((f as Dictionary).fade) > 0.5:
			out_n += 1
	t.ok(out_n >= 1, "summer noon: butterflies are out (%d)" % out_n)
	MeadowLife.reduce_motion = true
	var bed_ok: bool = true
	for i: int in 120:
		fly.update(1.0 / 30.0, walker.position)
	for f: Variant in fly.get("_flies") as Array:
		var fd2: Dictionary = f as Dictionary
		if float(fd2.fade) > 0.0 and (fd2.pos as Vector2).distance_to(_bed_of(fly, fd2)) > 0.01:
			bed_ok = false
	t.ok(bed_ok, "reduce motion: butterflies stay on their bed")
	MeadowLife.reduce_motion = false
	var first: Dictionary = {}
	for f: Variant in fly.get("_flies") as Array:
		if float((f as Dictionary).fade) > 0.5:
			first = f as Dictionary
			break
	if not first.is_empty():
		first.hover = 0.0
		walker.position = (first.pos as Vector2) + Vector2(4.0, 0.0)
		fly.update(1.0 / 30.0, walker.position)
		t.ok(float(first.dur) > 0.0, "a walker close by sends a butterfly off its bed")
		t.ok(MeadowLife.iso_distance(first.to as Vector2, walker.position) >= LifeButterflies.SCARE,
			"the butterfly flies to a bed away from the walker")

	# Tidy up the scene tree and the globals the suite changed.
	walker.free()
	MeadowLife.season = keep_season
	MeadowLife.night = keep[0]
	MeadowLife.low_sun = keep[1]
	MeadowLife.rain = keep[2]
	MeadowLife.reduce_motion = keep_calm

	# The Starting Clearing's life builds the same way.
	var mcrit := LifeCritters.new()
	mcrit.setup(meadow)
	t.ok((mcrit.get("_rabbits") as Array).size() >= 2, "the Starting Clearing has rabbits")
	t.ok((mcrit.get("_ducks") as Array).size() >= 1, "the Starting Clearing has a duck on its water")


func _vecs(a: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Variant in a:
		var q: Array = p as Array
		out.append(Vector2(float(q[0]), float(q[1])))
	return out


func _waters(d: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Variant in d.get("water", []) as Array:
		out.append(w as Dictionary)
	return out


func _water_of(d: Dictionary, body: Variant) -> Dictionary:
	return (d.water as Array)[int(body)] as Dictionary


func _first_home(frogs: Array) -> Vector2:
	return (frogs[0] as Dictionary).home as Vector2


func _bed_of(fly: RefCounted, f: Dictionary) -> Vector2:
	var beds: Array = fly.get("_beds") as Array
	return beds[int(f.bed)] as Vector2
