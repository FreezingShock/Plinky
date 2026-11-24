extends RefCounted
## The Larkmoor flower gardens: sprite tables, the sway lean, and the placed flowers (world/larkmoor_gardens.json).

const DIR: String = "res://assets/art/zone1b/larkmoor/"
const DATA: String = "res://world/larkmoor_gardens.json"


func run(t: Object) -> void:
	# sprite tables: four variants per statistic, equal-width rows, every letter known
	for stat: StringName in GardenArt.STATS:
		t.ok(GardenArt.COLORS.has(stat) and GardenArt.VARIANTS.has(stat), "%s has colours and sprites" % stat)
		t.eq(GardenArt.variant_count(stat), GardenArt.FLOWER_VARIANTS + 2, "%s has four flower variants and two shrubs" % stat)
		for v in GardenArt.variant_count(stat):
			var rows: Array = (GardenArt.VARIANTS[stat] as Array)[v]
			var w0: int = (rows[0] as String).length()
			var same: bool = true
			var known: bool = true
			for r: String in rows:
				same = same and r.length() == w0
				for ch in r:
					known = known and ch in ".#dlcgGs"
			t.ok(same and known, "%s variant %d: equal rows, known letters" % [stat, v])
			for lean in [-1, 0, 1]:
				var tex: Texture2D = GardenArt.frame(stat, v, lean)
				t.eq(tex.get_size(), Vector2(w0 + 2, rows.size()), "%s variant %d lean %d is baked at its size" % [stat, v, lean])
	# the lean: the walker pushes a flower away from itself, a calm spell leaves it upright, wind tips it
	t.eq(GardenLayer.lean(110, 100, 0.0, 0.2, Vector2(100, 100)), 1, "a flower right of the walker leans right")
	t.eq(GardenLayer.lean(90, 100, 0.0, 0.2, Vector2(100, 100)), -1, "a flower left of the walker leans left")
	t.eq(GardenLayer.lean(500, 100, 0.0, 0.2, Vector2(100, 100)), GardenLayer.lean(500, 100, 0.0, 0.2, Vector2.INF), "far from the walker only the wind counts")
	var seen: Dictionary = {}
	for step in 60:
		seen[GardenLayer.lean(300, 200, float(step) * 0.17, 0.5, Vector2.INF)] = true
	t.ok(seen.has(0) and (seen.has(1) or seen.has(-1)), "the wind tips a flower now and then and lets it rest")
	# the placed flowers
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	t.ok(parsed is Dictionary, "gardens json loads")
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed as Dictionary
	var flowers: Array = data.get("flowers", []) as Array
	t.ok(flowers.size() >= 600 and flowers.size() <= 4000, "lots of flowers, not too many (%d)" % flowers.size())
	var ground: Image = Image.load_from_file(DIR + "ground.png")
	t.ok(ground != null, "ground loads for the placement checks")
	if ground == null:
		return
	var grass: Array[Color] = [Color("5fa36a"), Color("b7d978"), Color("2f6b55")]
	var per_stat: Dictionary = {}
	var bad_stat: int = 0
	var bad_ground: int = 0
	var out_of_order: int = 0
	var last_y: int = -1
	for f: Variant in flowers:
		var a: Array = f as Array
		var x: int = int(a[0])
		var y: int = int(a[1])
		var s: int = int(a[2])
		if s < 0 or s >= GardenArt.STATS.size() or int(a[3]) < 0 or int(a[3]) >= GardenArt.variant_count(GardenArt.STATS[s]):
			bad_stat += 1
			continue
		per_stat[s] = int(per_stat.get(s, 0)) + 1
		if x < 0 or y < 0 or x >= ground.get_width() or y >= ground.get_height() or not (ground.get_pixel(x, y) in grass):
			bad_ground += 1
		if y < last_y:
			out_of_order += 1
		last_y = y
	t.eq(bad_stat, 0, "every flower names a real statistic and variant")
	t.eq(bad_ground, 0, "every flower stands on open grass (never a path, water or dirt)")
	t.eq(out_of_order, 0, "flowers are sorted by y, so they draw back to front")
	for s in GardenArt.STATS.size():
		t.ok(int(per_stat.get(s, 0)) >= 80, "%s has a real garden (%d flowers)" % [GardenArt.STATS[s], int(per_stat.get(s, 0))])
