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
	var lake: Vector2 = Vector2(float(water[0].x), float(water[0].y))   # the lake's middle: a walker here sees dragonflies and fish
	var edge_first: Array = (lark.get("forest_edge", []) as Array)[0] as Array
	var edge_wp: Vector2 = Vector2(float(edge_first[0]), float(edge_first[1]) + 60.0)   # just off the forest edge: the deer in reach, not scared
	var perch_first: Array = (lark.get("perches", []) as Array)[0] as Array
	var owl_wp: Vector2 = Vector2(float(perch_first[0]), float(perch_first[1]) + 60.0)   # below the first perch: the owl in reach

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
	MeadowLife.night = 0.5
	t.ok(LifeWild.deer_share() > 0.5, "dusk in summer: the deer come out at the forest edge (%.2f)" % LifeWild.deer_share())
	MeadowLife.night = 0.0
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
		wild.update(1.0 / 30.0, lake)
	var over: int = 0
	for d: Variant in dragons:
		if MeadowLife.in_water((d as Dictionary).pos as Vector2, water, 1.0):
			over += 1
	t.ok(dragons.size() > 0 and over == dragons.size(), "every dragonfly stays over the water (%d of %d)" % [over, dragons.size()])
	var d0: Dictionary = dragons[0] as Dictionary
	var before: Vector2 = d0.pos as Vector2
	for i: int in 60:
		wild.update(1.0 / 30.0, lake)
	t.ok((d0.pos as Vector2).distance_to(before) > 1.0 or float(d0.fade) > 0.9, "a dragonfly hovers and darts over the water")
	var near_d: Vector2 = (d0.pos as Vector2) + Vector2(5.0, 0.0)
	wild.update(1.0 / 30.0, near_d)
	t.ok(float(d0.flee) > 0.0, "a walker close by sends a dragonfly darting away")

	# Presence: far from any water no dragonfly is out, and at the lake they come out within reach of the walker.
	var far_wild := LifeWild.new()
	far_wild.setup(lark, water)
	for i: int in 120:
		far_wild.update(1.0 / 30.0, far)
	var out_far: int = 0
	for d: Variant in far_wild.get("_dragons") as Array:
		if float((d as Dictionary).fade) > 0.0:
			out_far += 1
	t.eq(out_far, 0, "far from the water no dragonfly is out")
	for i: int in 60:
		far_wild.update(1.0 / 30.0, lake)
	var at_lake: int = 0
	for d: Variant in far_wild.get("_dragons") as Array:
		if float((d as Dictionary).fade) > 0.5 and MeadowLife.iso_distance((d as Dictionary).pos as Vector2, lake) <= LifeWild.REACH:
			at_lake += 1
	t.ok(at_lake >= 1, "at the lake the dragonflies come out within reach of the walker (%d)" % at_lake)

	# Fish: they leap in daylight when the walker is not in the way (reduce motion keeps them down).
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	var fish_wild := LifeWild.new()
	fish_wild.setup(lark, water)
	var leaps: int = 0
	for i: int in 1200:
		fish_wild.update(1.0 / 30.0, lake)
		for f: Variant in fish_wild.get("_fish") as Array:
			if bool((f as Dictionary).jump) and float((f as Dictionary).t) < 1.0 / 30.0 + 0.001:
				leaps += 1
	t.ok(leaps >= 1, "the fish leap in the mere in summer daylight (%d leaps in 40 s)" % leaps)

	# The forest-edge deer: out at dawn and dusk, grazes along the edge, and runs into the trees when the walker comes.
	MeadowLife.low_sun = 1.0
	var deer_wild := LifeWild.new()
	deer_wild.setup(lark, water)
	for i: int in 90:
		deer_wild.update(1.0 / 30.0, edge_wp)
	var deer: Dictionary = (deer_wild.get("_deers") as Array)[0] as Dictionary
	t.ok(float(deer.fade) > 0.5, "at dusk the deer comes out to the forest edge")
	var deer_at: Vector2 = deer.pos as Vector2
	deer_wild.update(1.0 / 30.0, deer_at + Vector2(6.0, 0.0))
	t.ok(float(deer.flee) > 0.0, "a walker close by sends the deer into the trees")
	MeadowLife.low_sun = 0.0
	var noon_deer := LifeWild.new()
	noon_deer.setup(lark, water)
	for i: int in 90:
		noon_deer.update(1.0 / 30.0, far)
	t.eq(float(((noon_deer.get("_deers") as Array)[0] as Dictionary).fade), 0.0, "midday: no deer")

	# Owls: out at night on a pine perch, and sent off a perch the walker comes near.
	MeadowLife.low_sun = 0.0
	MeadowLife.night = 1.0
	var owl_wild := LifeWild.new()
	owl_wild.setup(lark, water)
	for i: int in 90:
		owl_wild.update(1.0 / 30.0, owl_wp)
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

	# Counts follow the share (the lowest ranks come out first), and the spots they pick are near the walker when they can be.
	t.ok(LifeWild._rank_out(0, 6, 0.5) and not LifeWild._rank_out(5, 6, 0.5), "half the share: the first half of the count is out")
	t.ok(not LifeWild._rank_out(0, 3, 0.0), "no share, nothing out")
	var edge0: Array = (lark.get("forest_edge", []) as Array)[0] as Array
	var e_here: Vector2 = Vector2(float(edge0[0]), float(edge0[1]))
	var picked: Vector2 = deer_wild._edge_within(e_here, 5, 0.0, LifeWild.REACH)
	t.ok(picked.is_finite() and MeadowLife.iso_distance(picked, e_here) < LifeWild.REACH, "a deer picks a forest-edge spot within reach of the walker")
	var water_mid: Vector2 = Vector2(float(water[0].x), float(water[0].y))
	var wpick: Vector2 = deer_wild._water_within(water_mid, 9, 0.0, LifeWild.REACH)
	t.ok(wpick.is_finite() and MeadowLife.iso_distance(wpick, water_mid) < LifeWild.REACH, "a dragonfly or fish picks water within reach of the walker")
	t.ok(not deer_wild._water_within(far, 9, 0.0, LifeWild.REACH).is_finite(), "no water in reach of a far walker: nothing to pick")

	# Reduce motion: the dragonflies hover, and the fish and the deer stay put.
	MeadowLife.reduce_motion = true
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 1.0
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	var calm := LifeWild.new()
	calm.setup(lark, water)
	for i: int in 60:
		calm.update(1.0 / 30.0, lake)
	var calm_d: Dictionary = (calm.get("_dragons") as Array)[0] as Dictionary
	var calm_at: Vector2 = calm_d.pos as Vector2
	var jumped: bool = false
	for i: int in 300:
		calm.update(1.0 / 30.0, calm_at + Vector2(4.0, 0.0))
		for f: Variant in calm.get("_fish") as Array:
			if bool((f as Dictionary).jump):
				jumped = true
	t.ok((calm_d.pos as Vector2).distance_to(calm_at) < 0.001, "reduce motion: a dragonfly does not dart")
	var calm_edge := LifeWild.new()
	calm_edge.setup(lark, water)
	for i: int in 90:
		calm_edge.update(1.0 / 30.0, edge_wp)
	var calm_deer: Dictionary = (calm_edge.get("_deers") as Array)[0] as Dictionary
	var deer_start: Vector2 = calm_deer.pos as Vector2
	t.ok(float(calm_deer.fade) > 0.5, "reduce motion: the deer still comes out at dusk")
	for i: int in 300:
		calm_edge.update(1.0 / 30.0, edge_wp)
	t.ok((calm_deer.pos as Vector2).distance_to(deer_start) < 0.001, "reduce motion: the deer stays where it is")
	t.ok(not jumped, "reduce motion: the fish do not leap")

	# The arrival point (life data "start"): two rabbits sit at the grass edge near it, and two butterflies start over the flowers near it.
	var sa: Array = lark.get("start", []) as Array
	var arrival := Vector2(float(sa[0]), float(sa[1]))
	var arrive := LifeCritters.new()
	arrive.setup(lark)
	var near_rabbits: int = 0
	for r: Variant in arrive.get("_rabbits") as Array:
		if MeadowLife.iso_distance((r as Dictionary).home as Vector2, arrival) <= LifeCritters.START_REACH:
			near_rabbits += 1
	t.ok(near_rabbits >= 2, "two rabbits sit at the grass edge near the arrival point (%d)" % near_rabbits)
	var fly := LifeButterflies.new()
	fly.setup(lark)
	var beds: Array = fly.get("_beds") as Array
	var near_fly: int = 0
	for f: Variant in fly.get("_flies") as Array:
		if MeadowLife.iso_distance(beds[int((f as Dictionary).bed)] as Vector2, arrival) <= LifeButterflies.START_REACH:
			near_fly += 1
	t.ok(near_fly >= 2, "two butterflies start over the flowers near the arrival point (%d)" % near_fly)

	# Tidy up the globals the suite changed.
	MeadowLife.season = keep_season
	MeadowLife.night = keep[0]
	MeadowLife.low_sun = keep[1]
	MeadowLife.rain = keep[2]
	MeadowLife.reduce_motion = keep_calm
