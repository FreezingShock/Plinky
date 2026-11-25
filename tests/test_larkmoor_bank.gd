extends RefCounted
## The Larkmoor bank ring: every stone sits on land, touching the water's edge, and none lands in the water.
## The generator (tools/art/gen_larkmoor.py) writes each ring stone's texel with its distance to open water (wd, negative
## on land) and its distance in texels to the water (dw). This test reads that record and checks it.

const DATA: String = "res://assets/art/zone1b/larkmoor/bank_stones.json"


func run(t: Object) -> void:
	var file: FileAccess = FileAccess.open(DATA, FileAccess.READ)
	t.ok(file != null, "the Larkmoor bank stone record opens")
	if file == null:
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	t.ok(data != null and data.has("stones"), "the bank stone record has a stones list")
	if data == null or not data.has("stones"):
		return
	var stones: Array = data["stones"] as Array
	t.ok(stones.size() >= 100, "the ring has at least 100 stones (got %d)" % stones.size())
	var in_water: int = 0
	var not_touching: int = 0
	for s: Variant in stones:
		var a: Array = s as Array
		var wd: float = float(a[2])
		var dw: float = float(a[3])
		if wd > -0.3:
			in_water += 1
		if dw < 0.8 or dw > 1.7:
			not_touching += 1
	t.eq(in_water, 0, "no bank stone lands on a water texel")
	t.eq(not_touching, 0, "every bank stone touches the water's edge (1 texel off, 0.8 to 1.7)")
