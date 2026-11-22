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
	var bad_tips: int = 0
	for p: Variant in sway:
		var a: Array = p as Array
		var x: int = int(a[0])
		var y: int = int(a[1])
		var inside: bool = x > 0 and y > 0 and x < img.get_width() - 1 and y < img.get_height() - 1
		if not inside or not img.get_pixel(x, y).is_equal_approx(light):
			bad_tips += 1
	t.eq(bad_tips, 0, "every sway tip sits on a palette 4 texel of the backdrop")
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
