extends RefCounted
## Larkmoor's wildlife (world/life_wild.gd): dragonflies over the water, fish that leap in the mere, the forest-edge deer
## and the owls in the pines. Data and sprite checks, the light and season shares, and stepped runs with the walker
## passed in as a position (the helper is RefCounted, so no scene tree).

const LARK_LIFE: String = "res://world/larkmoor_life.json"


func _w(a: float, b: float, c: float, d: float) -> Array[float]:
	var w: Array[float] = [a, b, c, d]
	return w


func run(t: Object) -> void:
	var keep_season: Array[float] = MeadowLife.season.duplicate()
	var keep: Array[float] = [MeadowLife.night, MeadowLife.low_sun, MeadowLife.rain]
	var keep_calm: bool = MeadowLife.reduce_motion

	var lark: Dictionary = MeadowLife.load_data(LARK_LIFE)
	var water: Array[Dictionary] = []
	for w: Variant in lark.get("water", []) as Array:
		water.append(w as Dictionary)
	t.ok((lark.get("forest_edge", []) as Array).size() >= 6, "Larkmoor has forest-edge grass for the deer")
	t.ok((lark.get("perches", []) as Array).size() >= 3, "Larkmoor has owl perches in the pines")
	var far: Vector2 = Vector2(-9000.0, -9000.0)

	# Sprites: every row of one sprite is the same width, so the runs line up.
	for rows: Array in [LifeWild.DRAGON_UP, LifeWild.DRAGON_DOWN, LifeWild.FISH_ART, LifeWild.DEER_ART,
			LifeWild.OWL_OPEN, LifeWild.OWL_SHUT]:
		var w0: int = (rows[0] as String).length()
		var same: bool = true
		for r: Variant in rows:
			if (r as String).length() != w0:
				same = false
		t.ok(same, "wildlife sprite rows share one width (%d rows of %d)" % [rows.size(), w0])

	# Shares: the light, the season and the rain decide who is out.
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 0.0
	t.eq(LifeWild.dragonfly_share(), 1.0, "summer noon: every dragonfly is out")
	t.eq(LifeWild.deer_share(), 0.0, "summer noon: no deer at the forest edge")
	t.eq(LifeWild.owl_share(), 0.0, "summer noon: no owls")
	MeadowLife.low_sun = 1.0
	t.ok(LifeWild.deer_share() > 0.8, "golden hour in summer: the deer comes out (%.2f)" % LifeWild.deer_share())
	MeadowLife.low_sun = 0.0
	MeadowLife.night = 1.0
	t.eq(LifeWild.dragonfly_share(), 0.0, "night: no dragonflies")
	t.ok(LifeWild.owl_share() > 0.8, "night in summer: the owls are out (%.2f)" % LifeWild.owl_share())
	MeadowLife.night = 0.0
	MeadowLife.season = _w(0.0, 0.0, 0.0, 1.0)
	t.eq(LifeWild.dragonfly_share(), 0.0, "winter: no dragonflies")
	t.ok(LifeWild.fish_share() < 0.3, "winter: the fish keep down (%.2f)" % LifeWild.fish_share())
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.rain = 1.0
	t.eq(LifeWild.dragonfly_share(), 0.0, "heavy rain: no dragonflies")
	t.eq(LifeWild.deer_share(), 0.0, "heavy rain: no deer")
	MeadowLife.rain = 0.0

	# Dragonflies: they come out over the water and stay there, and a walker close by sends one darting.
	var wild := LifeWild.new()
	wild.setup(lark, water)
	var dragons: Array = wild.get("_dragons") as Array
	for i: int in 180:
		wild.update(1.0 / 30.0, far)
	var over: int = 0
	for d: Variant in dragons:
		if MeadowLife.in_water((d as Dictionary).pos as Vector2, water, 1.0):
			over += 1
	t.ok(dragons.size() > 0 and over == dragons.size(), "every dragonfly stays over the water (%d of %d)" % [over, dragons.size()])
	var d0: Dictionary = dragons[0] as Dictionary
	var before: Vector2 = d0.pos as Vector2
	for i: int in 60:
		wild.update(1.0 / 30.0, far)
	t.ok((d0.pos as Vector2).distance_to(before) > 1.0 or float(d0.fade) > 0.9, "a dragonfly hovers and darts over the water")
	var near_d: Vector2 = (d0.pos as Vector2) + Vector2(5.0, 0.0)
	wild.update(1.0 / 30.0, near_d)
	t.ok(float(d0.flee) > 0.0, "a walker close by sends a dragonfly darting away")

	# Fish: they leap in daylight when the walker is not in the way (reduce motion keeps them down).
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	var fish_wild := LifeWild.new()
	fish_wild.setup(lark, water)
	var leaps: int = 0
	for i: int in 1200:
		fish_wild.update(1.0 / 30.0, far)
		for f: Variant in fish_wild.get("_fish") as Array:
			if bool((f as Dictionary).jump) and float((f as Dictionary).t) < 1.0 / 30.0 + 0.001:
				leaps += 1
	t.ok(leaps >= 1, "the fish leap in the mere in summer daylight (%d leaps in 40 s)" % leaps)

	# The forest-edge deer: out at dawn and dusk, grazes along the edge, and runs into the trees when the walker comes.
	MeadowLife.low_sun = 1.0
	var deer_wild := LifeWild.new()
	deer_wild.setup(lark, water)
	for i: int in 90:
		deer_wild.update(1.0 / 30.0, far)
	var deer: Dictionary = deer_wild.get("_deer") as Dictionary
	t.ok(float(deer.fade) > 0.5, "at dusk the deer comes out to the forest edge")
	var deer_at: Vector2 = deer.pos as Vector2
	deer_wild.update(1.0 / 30.0, deer_at + Vector2(6.0, 0.0))
	t.ok(float(deer.flee) > 0.0, "a walker close by sends the deer into the trees")
	MeadowLife.low_sun = 0.0
	var noon_deer := LifeWild.new()
	noon_deer.setup(lark, water)
	for i: int in 90:
		noon_deer.update(1.0 / 30.0, far)
	t.eq(float((noon_deer.get("_deer") as Dictionary).fade), 0.0, "midday: no deer")

	# Owls: out at night on a pine perch, and sent off a perch the walker comes near.
	MeadowLife.low_sun = 0.0
	MeadowLife.night = 1.0
	var owl_wild := LifeWild.new()
	owl_wild.setup(lark, water)
	for i: int in 90:
		owl_wild.update(1.0 / 30.0, far)
	var owls: Array = owl_wild.get("_owls") as Array
	t.ok(owls.size() >= 1, "Larkmoor has an owl on a perch")
	var o0: Dictionary = owls[0] as Dictionary
	var pq: Array = (lark.get("perches", []) as Array)[int(o0.perch)] as Array
	var perch: Vector2 = Vector2(float(pq[0]), float(pq[1]))
	t.ok(float(o0.fade) > 0.5, "at night an owl sits in the pines")
	owl_wild.update(1.0 / 30.0, perch + Vector2(6.0, 0.0))
	t.ok(float(o0.fly) > 0.0, "a walker close by sends the owl off its perch")
	MeadowLife.night = 0.0
	var day_owl := LifeWild.new()
	day_owl.setup(lark, water)
	for i: int in 90:
		day_owl.update(1.0 / 30.0, far)
	t.eq(float(((day_owl.get("_owls") as Array)[0] as Dictionary).fade), 0.0, "by day the owls are not out")

	# Reduce motion: the dragonflies hover, and the fish and the deer stay put.
	MeadowLife.reduce_motion = true
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 1.0
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	var calm := LifeWild.new()
	calm.setup(lark, water)
	for i: int in 60:
		calm.update(1.0 / 30.0, far)
	var calm_d: Dictionary = (calm.get("_dragons") as Array)[0] as Dictionary
	var calm_at: Vector2 = calm_d.pos as Vector2
	var calm_deer: Dictionary = calm.get("_deer") as Dictionary
	var deer_start: Vector2 = calm_deer.pos as Vector2
	var jumped: bool = false
	for i: int in 300:
		calm.update(1.0 / 30.0, calm_at + Vector2(4.0, 0.0))
		for f: Variant in calm.get("_fish") as Array:
			if bool((f as Dictionary).jump):
				jumped = true
	t.ok((calm_d.pos as Vector2).distance_to(calm_at) < 0.001, "reduce motion: a dragonfly does not dart")
	t.ok((calm_deer.pos as Vector2).distance_to(deer_start) < 0.001, "reduce motion: the deer stays where it is")
	t.ok(not jumped, "reduce motion: the fish do not leap")

	# Tidy up the globals the suite changed.
	MeadowLife.season = keep_season
	MeadowLife.night = keep[0]
	MeadowLife.low_sun = keep[1]
	MeadowLife.rain = keep[2]
	MeadowLife.reduce_motion = keep_calm
