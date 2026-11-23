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
			var a: Image = Image.load_from_file(dir + String(s.file))
			var b: Image = Image.load_from_file(dir + String(s.nrm))
			if a == null or b == null or a.get_size() != b.get_size():
				wrong_size += 1
		t.eq(missing, 0, "%s: every sprite has relight data" % dir)
		t.eq(wrong_size, 0, "%s: relight data matches its sprite size" % dir)
	for dir2: String in SCENES:
		var g: Image = Image.load_from_file(dir2 + "ground.png")
		var gn: Image = Image.load_from_file(dir2 + "ground_n.png")
		var gh: Image = Image.load_from_file(dir2 + "ground_h.png")
		t.ok(g != null and gn != null and gh != null and g.get_size() == gn.get_size() and g.get_size() == gh.get_size(),
				"%s: ground G-buffer (normal and height) matches the ground art size" % dir2)
	for dir3: String in SCENES:
		var gfull: Image = Image.load_from_file(dir3 + "ground.png")
		var gfg: Image = Image.load_from_file(dir3 + "ground_fg.png")
		var far: Image = Image.load_from_file(dir3 + "backdrop_far.png")
		t.ok(gfull != null and gfg != null and far != null and gfg.get_size() == gfull.get_size()
				and far.get_width() == gfull.get_width() + 128 and far.get_height() < gfull.get_height(),
				"%s: parallax layers (cut-out ground, wide far backdrop) match the ground art" % dir3)
	var inc: String = FileAccess.get_file_as_string("res://render/shaders/prop_ramps.gdshaderinc")
	var pal: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	var first: Color = pal[0]
	t.ok(inc.contains("vec3(%.5f, %.5f, %.5f)" % [first.r, first.g, first.b]), "shader palette starts with the meadow ink colour")
