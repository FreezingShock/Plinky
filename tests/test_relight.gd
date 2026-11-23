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
	var inc: String = FileAccess.get_file_as_string("res://render/shaders/prop_ramps.gdshaderinc")
	var pal: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	var first: Color = pal[0]
	t.ok(inc.contains("vec3(%.5f, %.5f, %.5f)" % [first.r, first.g, first.b]), "shader palette starts with the meadow ink colour")
