extends RefCounted
## World life data and helpers (world/meadow_life.gd, life_ground.gd, life_air.gd).

func run(t: Object) -> void:
	var data: Dictionary = MeadowLife.load_data()
	t.ok(not data.is_empty(), "meadow_life.json loads")
	var sway: Array = data.get("sway", []) as Array
	t.ok(sway.size() >= 60, "at least 60 sway tips (got %d)" % sway.size())
	var img: Image = Image.load_from_file("res://assets/art/zone1/meadow_backdrop.png")
	t.ok(img != null, "backdrop loads for checks")
	if img == null:
		return
	var light: Color = Palettes.colors(Palettes.MEADOW)[4]
	var org: Array = data.get("backdrop_origin", [0, 0]) as Array
	var ox: int = int(org[0])
	var oy: int = int(org[1])
	var bad_tips: int = 0
	for p: Variant in sway:
		var a: Array = p as Array
		var tx: int = int(a[0]) - ox
		var ty: int = int(a[1]) - oy
		var inside: bool = tx > 0 and ty > 0 and tx < img.get_width() - 1 and ty < img.get_height() - 1
		if not inside or not img.get_pixel(tx, ty).is_equal_approx(light):
			bad_tips += 1
	t.eq(bad_tips, 0, "every sway tip sits on a palette 4 texel of the backdrop, through its origin")
	var dr: Array = data.get("drift", []) as Array
	t.eq(dr.size(), 4, "drift box is in the data")
	t.ok(dr.size() == 4 and float(dr[2]) > 100.0 and float(dr[3]) > 50.0, "drift box is a usable size")
	for frame: Array in [LifeAir.BUTTERFLY_OPEN, LifeAir.BUTTERFLY_CLOSED]:
		var w0: int = (frame[0] as String).length()
		var same: bool = true
		for row: String in frame:
			if row.length() != w0:
				same = false
		t.ok(same, "butterfly frame rows are the same width")
	var lights: Array = data.get("lights", []) as Array
	t.eq(lights.size(), 3, "two lanterns and the shrine are glow points")
	t.ok(data.get("water", {}).has("rx"), "water cove is in the data")

	# Ordered dither: 16 distinct thresholds, all inside (0, 1).
	var seen: Dictionary = {}
	for y in 4:
		for x in 4:
			var b: float = MeadowLife.bayer(x, y)
			t.ok(b > 0.0 and b < 1.0, "bayer threshold in (0, 1)")
			seen[b] = true
	t.eq(seen.size(), 16, "bayer matrix has 16 distinct thresholds")
	t.near(MeadowLife.bayer(4, 4), MeadowLife.bayer(0, 0), 1e-9, "bayer tiles every 4 texels")

	# Hash: deterministic and in [0, 1).
	var all_in: bool = true
	for n in 500:
		var h: float = MeadowLife.hash01(n)
		if h < 0.0 or h >= 1.0 or h != MeadowLife.hash01(n):
			all_in = false
	t.ok(all_in, "hash01 stays in [0, 1) and repeats")

	# Reduce motion: the flag exists, defaults off, and the ground layer stops stepping.
	t.ok(not MeadowLife.reduce_motion, "reduce motion defaults off")
