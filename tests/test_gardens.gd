extends RefCounted
## The Larkmoor flower gardens: sprite tables, the sway lean, and the placed flowers (world/larkmoor_gardens.json).

const DIR: String = "res://assets/art/zone1b/larkmoor/"
const DATA: String = "res://world/larkmoor_gardens.json"


func run(t: Object) -> void:
	# sprite tables: four small flowers, two shrubs and twelve field flowers per statistic, all baked to real sizes
	for stat: StringName in GardenArt.STATS:
		t.ok(GardenArt.COLORS.has(stat) and GardenArt.SHAPE.has(stat), "%s has colours and a head shape" % stat)
		t.eq(GardenArt.table_count(stat), GardenArt.FLOWER_VARIANTS + 2, "%s has four flower variants and two shrubs" % stat)
		t.eq(GardenArt.variant_count(stat), GardenArt.FIELD_FIRST + 12, "%s adds twelve field flowers (three sizes, four tints)" % stat)
		for v in GardenArt.table_count(stat):
			for lean in [-1, 0, 1]:
				var tex: Texture2D = GardenArt.frame(stat, v, lean)
				t.ok(tex.get_width() % 2 == 1 and tex.get_height() >= 6, "%s variant %d lean %d is baked, centred and tall enough" % [stat, v, lean])
			t.ok(GardenArt.frame(stat, v, 0).get_image().get_data() != GardenArt.frame(stat, v, 0, GardenArt.SEASON_WINTER).get_image().get_data(), "%s variant %d changes in winter" % [stat, v])
	# the looking-down look: a flower's head is wider than it is tall, and the foot row is a translucent ground shadow
	for stat: StringName in GardenArt.STATS:
		for v in range(GardenArt.FIELD_FIRST, GardenArt.variant_count(stat)):
			var k: int = GardenArt.field_scale(v)
			var up: Image = GardenArt.frame(stat, v, 0).get_image()
			t.ok(up.get_width() >= 2 * (4 * k + 1) + 1, "%s field flower %d is at least its head wide at %dx" % [stat, v, k])
			t.ok(up.get_pixel(up.get_width() >> 1, up.get_height() - 2).a < 0.99, "%s field flower %d sits on a translucent ground shadow" % [stat, v])
			# the shadow is an oval, not a flat plate: each row under the foot is narrower than the one above, and none is inked
			var rows: Array[int] = []
			for row in [up.get_height() - 1, up.get_height() - 2, up.get_height() - 3]:
				var filled: int = 0
				for x in up.get_width():
					if up.get_pixel(x, row).a > 0.0:
						filled += 1
				rows.append(filled)
			t.ok(rows[0] < rows[1] and rows[1] < rows[2], "%s field flower %d shadow narrows as it drops: %s" % [stat, v, str(rows)])
			t.ok(GardenArt.frame(stat, v, 1).get_image().get_data() != up.get_data(), "%s field flower %d leans" % [stat, v])
			# no ink on nature: the rim is the zone's deep leaf green on the shadow side only, so the lit edge is open
			var inked: int = 0
			var rim: int = 0
			for y in up.get_height():
				for x in up.get_width():
					var px: Color = up.get_pixel(x, y)
					if px.a > 0.5 and px.is_equal_approx(Color("14161c")):
						inked += 1
					if px.a > 0.5 and px.is_equal_approx(GardenArt.FLOWER_RIM):
						rim += 1
			t.eq(inked, 0, "%s field flower %d has no ink outline" % [stat, v])
			t.ok(rim > 0, "%s field flower %d has a shadow-side rim" % [stat, v])
	# the season and night states bake distinct frames for a head, and a shrub keeps its shape
	t.ok(GardenArt.frame(&"clover", 0, 0, GardenArt.SEASON_SUMMER).get_image().get_data() != GardenArt.frame(&"clover", 0, 0, GardenArt.SEASON_SUMMER, true).get_image().get_data(), "a closed head is smaller than an open one")
	t.ok(GardenArt.frame(&"clover", 0, 0, GardenArt.SEASON_SPRING).get_image().get_data() != GardenArt.frame(&"clover", 0, 0, GardenArt.SEASON_AUTUMN).get_image().get_data(), "spring buds and autumn seed heads differ")
	t.eq(GardenArt.frame(&"heather", 4, 1).get_size(), GardenArt.frame(&"heather", 4, 0).get_size(), "a shrub does not lean but keeps its size")
	# winter field stalks show their variant: the tints differ in height and in seed heads or frost, not all one silhouette
	var winter_a: Image = GardenArt.frame(&"thistle", GardenArt.FIELD_FIRST, 0, GardenArt.SEASON_WINTER).get_image()
	var winter_b: Image = GardenArt.frame(&"thistle", GardenArt.FIELD_FIRST + 1, 0, GardenArt.SEASON_WINTER).get_image()
	var winter_c: Image = GardenArt.frame(&"thistle", GardenArt.FIELD_FIRST + 2, 0, GardenArt.SEASON_WINTER).get_image()
	t.ok(winter_a.get_height() != winter_b.get_height() and winter_a.get_data() != winter_b.get_data(), "winter field stalks differ by tint (a tall tint against a short one)")
	t.ok(winter_b.get_data() != winter_c.get_data(), "a seed head tint differs from a frosted tint in winter")
	# a shrub's ground shadow is the same oval: each row under the mound is narrower than the one above
	for v in [4, 5]:
		var shrub: Image = GardenArt.frame(&"heather", v, 0).get_image()
		var counts: Array[int] = []
		for row in [shrub.get_height() - 1, shrub.get_height() - 2, shrub.get_height() - 3]:
			var filled: int = 0
			for x in shrub.get_width():
				if shrub.get_pixel(x, row).a > 0.0:
					filled += 1
			counts.append(filled)
		t.ok(counts[0] < counts[1] and counts[1] < counts[2], "shrub %d shadow narrows as it drops: %s" % [v, str(counts)])
	# the lean: the walker pushes a flower away from itself, a calm spell leaves it upright, wind tips it
	t.eq(GardenLayer.lean(110, 100, 0.0, 0.2, Vector2(100, 100)), 1, "a flower right of the walker leans right")
	t.eq(GardenLayer.lean(90, 100, 0.0, 0.2, Vector2(100, 100)), -1, "a flower left of the walker leans left")
	t.eq(GardenLayer.lean(500, 100, 0.0, 0.2, Vector2(100, 100)), GardenLayer.lean(500, 100, 0.0, 0.2, Vector2.INF), "far from the walker only the wind counts")
	var seen: Dictionary = {}
	for step in 60:
		seen[GardenLayer.lean(300, 200, float(step) * 0.17, 0.5, Vector2.INF)] = true
	t.ok(seen.has(0) and (seen.has(1) or seen.has(-1)), "the wind tips a flower now and then and lets it rest")
	# the atlas: every frame is the same pixels as its own texture, and the lookup index reaches the right one
	var atlas_img: Image = GardenArt.atlas().get_image()
	var checked: int = 0
	var same_pixels: int = 0
	for s in GardenArt.STATS.size():
		for v in GardenArt.variant_count(GardenArt.STATS[s]):
			for lean in [-1, 0, 1]:
				for season in 4:
					for state in 3:   # open, shut at night, dew at dawn
						var closed: bool = state == 1
						var dew: bool = state == 2
						var src: Rect2 = GardenArt.atlas_rect(GardenArt.frame_index(s, v, lean, season, closed, dew))
						var frame_img: Image = GardenArt.frame(GardenArt.STATS[s], v, lean, season, closed, dew).get_image()
						checked += 1
						if Vector2(frame_img.get_size()) == src.size and atlas_img.get_region(Rect2i(src)).get_data() == frame_img.get_data():
							same_pixels += 1
	t.eq(same_pixels, checked, "all %d atlas frames (every season and head state) match their own sprites" % checked)
	var rows_lookup: GardenLayer = GardenLayer.new()
	rows_lookup.setup([[10, 5, 0, 0], [11, 5, 1, 0], [12, 9, 2, 0], [13, 9, 3, 0], [14, 20, 4, 0]])
	t.eq(rows_lookup._first_row(0.0), 0, "the row lookup starts at the first flower")
	t.eq(rows_lookup._first_row(5.0), 0, "a row on a flower's y finds that flower")
	t.eq(rows_lookup._first_row(6.0), 2, "between rows it finds the next row")
	t.eq(rows_lookup._first_row(20.0), 4, "a row past the last one finds the last flower")
	t.eq(rows_lookup._first_row(21.0), 5, "past the end is the count")
	rows_lookup.free()
	# the placed flowers
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	t.ok(parsed is Dictionary, "gardens json loads")
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed as Dictionary
	var flowers: Array = data.get("flowers", []) as Array
	t.ok(flowers.size() >= 600 and flowers.size() <= 4000, "lots of flowers, not too many (%d)" % flowers.size())
	var ground: Image = (load(DIR + "ground.png") as Texture2D).get_image()
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
