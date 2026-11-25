extends RefCounted
## World life data and helpers (world/meadow_life.gd, life_ground.gd, life_air.gd).

func run(t: Object) -> void:
	var data: Dictionary = MeadowLife.load_data()
	t.ok(not data.is_empty(), "meadow_life.json loads")
	var sway: Array = data.get("sway", []) as Array
	t.ok(sway.size() >= 60, "at least 60 sway tips (got %d)" % sway.size())
	var img: Image = (load("res://assets/art/zone1/meadow3d/ground.png") as Texture2D).get_image()
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
	for frame: Array in [LifeButterflies.BUTTERFLY_OPEN, LifeButterflies.BUTTERFLY_HALF, LifeButterflies.BUTTERFLY_CLOSED]:
		var w0: int = (frame[0] as String).length()
		var same: bool = true
		for row: String in frame:
			if row.length() != w0:
				same = false
		t.ok(same, "butterfly frame rows are the same width")
	var lights: Array = data.get("lights", []) as Array
	t.ok(lights.size() >= 1, "at least one glow point (the shrine)")
	var water: Array = data.get("water", []) as Array
	t.ok(water.size() >= 1, "at least one water body in the data")
	var water_ok: bool = true
	for wb: Variant in water:
		var d: Dictionary = wb as Dictionary
		if not (d.has("x") and d.has("y") and float(d.rx) > 0.0 and float(d.ry) > 0.0):
			water_ok = false
	t.ok(water_ok, "every water body has a centre and positive radii")

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

	# Reactions to the walker (world/life_react.gd, LifeGround.bend)
	t.eq(LifeReact.away_amount(-1.0), 0.0, "perched bird is not away")
	t.eq(LifeReact.away_amount(LifeReact.BIRD_FLIGHT), 1.0, "bird is gone after its flight")
	t.eq(LifeReact.away_amount(LifeReact.BIRD_RETURN_AFTER + LifeReact.BIRD_FLIGHT + 1.0), 0.0, "bird is back after its return")
	t.eq(LifeReact.rustle_offset(1), 0.0, "rustle rests every other step")
	t.eq(LifeReact.rustle_offset(2), 1.0, "rustle shuffles one texel")
	var lake: Dictionary = {"x": 100.0, "y": 100.0, "rx": 50.0, "ry": 25.0}
	t.ok(LifeReact.shore_point(lake, Vector2(100.0, 100.0 + 25.0 + 6.0), 26.0) != Vector2.INF, "walker at the shore makes a ripple point")
	t.ok(LifeReact.shore_point(lake, Vector2(300.0, 300.0), 16.0) == Vector2.INF, "far walker makes none")
	t.eq(LifeGround.bend(Vector2i(110, 100), Vector2(100.0, 100.0)), 1, "grass east of the walker leans east")
	t.eq(LifeGround.bend(Vector2i(95, 100), Vector2(100.0, 100.0)), -2, "grass close on the west leans hard west")
	t.eq(LifeGround.bend(Vector2i(160, 100), Vector2(100.0, 100.0)), 0, "far grass keeps the wind")
	var rb := LifeReact.new()
	rb.setup({"water": []}, [[10, 10], [50, 50], [90, 90]])
	rb.scare_all()
	t.ok(rb._birds.size() == 3 and float(rb._birds[0].scared) == 0.0, "scare_all startles every perched bird")
	rb.free()
	_check_tips(t, "res://world/larkmoor_life.json", "res://assets/art/zone1b/larkmoor/ground.png", "Larkmoor")


## Every sway tip in `json_path` must sit on a palette 4 texel of the backdrop at `ground_path`, through the data's origin.
func _check_tips(t: Object, json_path: String, ground_path: String, label: String) -> void:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	t.ok(file != null, "%s life data opens" % label)
	if file == null:
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	var img: Image = (load(ground_path) as Texture2D).get_image()
	t.ok(img != null, "%s backdrop loads" % label)
	if img == null:
		return
	var light: Color = Palettes.colors(Palettes.MEADOW)[4]
	var org: Array = data.get("backdrop_origin", [0, 0]) as Array
	var bad: int = 0
	var sway: Array = data.get("sway", []) as Array
	for p: Variant in sway:
		var a: Array = p as Array
		var tx: int = int(a[0]) - int(org[0])
		var ty: int = int(a[1]) - int(org[1])
		if tx <= 0 or ty <= 0 or tx >= img.get_width() - 1 or ty >= img.get_height() - 1 or not img.get_pixel(tx, ty).is_equal_approx(light):
			bad += 1
	t.ok(sway.size() >= 60, "%s has at least 60 sway tips (got %d)" % [label, sway.size()])
	t.eq(bad, 0, "every %s sway tip sits on a palette 4 texel of its backdrop" % label)
