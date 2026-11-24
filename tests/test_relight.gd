extends RefCounted
## Prop relight data (tools/art/depth_pass.py): every tall-prop sprite has a same-size normal texture, and the
## palette baked into the shader include is the meadow palette.

const SCENES: Array[String] = ["res://assets/art/zone1/meadow3d/", "res://assets/art/zone1b/larkmoor/"]

func run(t: Object) -> void:
	for dir: String in SCENES:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "placements3d.json"))
		var sprites: Array = data.get("sprites", []) as Array
		t.ok(sprites.size() > 10, "%s lists tall props" % dir)
		var missing: int = 0
		var wrong_size: int = 0
		for s: Dictionary in sprites:
			if not s.has("nrm"):
				missing += 1
				continue
			var a: Image = _decoded(dir + String(s.file))
			var b: Image = _decoded(dir + String(s.nrm))
			if a == null or b == null or a.get_size() != b.get_size():
				wrong_size += 1
		t.eq(missing, 0, "%s: every sprite has relight data" % dir)
		t.eq(wrong_size, 0, "%s: relight data matches its sprite size" % dir)
	for dir2: String in SCENES:
		var g: Image = _decoded(dir2 + "ground.png")
		var gn: Image = _decoded(dir2 + "ground_n.png")
		var gh: Image = _decoded(dir2 + "ground_h.png")
		t.ok(g != null and gn != null and gh != null and g.get_size() == gn.get_size() and g.get_size() == gh.get_size(),
				"%s: ground G-buffer (normal and height) matches the ground art size" % dir2)
	# Larkmoor's whole map gets the sun: a 9 by 9 grid over the world rect (corners included) must all carry relight data.
	var lm: Image = _decoded("res://assets/art/zone1b/larkmoor/ground_n.png")
	var unlit: int = 0
	var probes: int = 0
	if lm != null:
		for gy: int in 9:
			for gx: int in 9:
				var x: int = int(lerpf(290.0, 2750.0, gx / 8.0))
				var y: int = int(lerpf(70.0, 1630.0, gy / 8.0))
				var px: Color = lm.get_pixel(x, y)
				var code: int = int(roundf(px.b * 255.0))
				probes += 1
				if px.a <= 0.0 or code < 10 or code >= 110:
					unlit += 1
	t.ok(lm != null and probes == 81, "Larkmoor: relight data loads for the map grid")
	t.eq(unlit, 0, "Larkmoor: every grid point over the map, corners included, is relit by the sun")
	for dir3: String in SCENES:
		var gfull: Image = _decoded(dir3 + "ground.png")
		var gfg: Image = _decoded(dir3 + "ground_fg.png")
		var far: Image = _decoded(dir3 + "backdrop_far.png")
		t.ok(gfull != null and gfg != null and far != null and gfg.get_size() == gfull.get_size()
				and far.get_width() == gfull.get_width() + 128 and far.get_height() < gfull.get_height(),
				"%s: parallax layers (cut-out ground, wide far backdrop) match the ground art" % dir3)
	var inc: String = FileAccess.get_file_as_string("res://render/shaders/prop_ramps.gdshaderinc")
	var pal: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	var first: Color = pal[0]
	t.ok(inc.contains("vec3(%.5f, %.5f, %.5f)" % [first.r, first.g, first.b]), "shader palette starts with the meadow ink colour")


## Pixels of an imported res:// image. Image.load_from_file warns on every res:// read (it will not work in an export),
## so the test reads the imported texture instead; the sizes and pixels it checks are the same.
static func _decoded(path: String) -> Image:
	var tex: Texture2D = load(path) as Texture2D
	return tex.get_image() if tex != null else null
