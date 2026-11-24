extends RefCounted
## Pad signs: a row's first pad draws its cost sign on a spot clear of every bed and plate on its zone, and of its
## walker press spot (world/texel_pad.gd choose_sign_spot). Checked on the real placements of the three zones.

const LAYOUTS: Dictionary = {
	&"zone1": "res://assets/art/zone1/meadow3d/placements3d.json",
	&"larkmoor": "res://assets/art/zone1b/larkmoor/placements3d.json",
	&"zone2": "res://assets/art/zone2/quarry/placements3d.json",
}


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	# The Larkmoor case from the screenshot: a neighbour up and to the right sat under the default spot.
	var pair: Array[Vector2] = [Vector2.ZERO, Vector2(28.0, -19.0)]
	var spot: Vector2 = TexelPad.choose_sign_spot(Vector2.ZERO, pair)
	t.ok(spot != TexelPad.SIGN_SPOTS[0], "a neighbour up and to the right moves the sign off its default spot")
	t.ok(TexelPad.sign_clear(spot, Vector2.ZERO, pair), "the moved sign is clear of that neighbour's bed")
	t.ok(not TexelPad.sign_clear(TexelPad.SIGN_SPOTS[0], Vector2.ZERO, pair), "the default spot is caught by the neighbour (the test would fail without the fix)")
	for zid: StringName in LAYOUTS:
		var z: ZoneDef = sim.zone_defs.get(zid) as ZoneDef
		t.ok(z != null, "zone %s exists" % zid)
		if z == null:
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUTS[zid]))
		var at: Array[Vector2] = []
		for a: Dictionary in data.anchors:
			if String(a.kind) == "pad":
				at.append(Vector2(float(a.sx), float(a.sy)))
		t.eq(at.size(), z.pad_buttons.size(), "%s: one placed pad per pad button" % zid)
		var first_pads := 0
		for i in mini(at.size(), z.pad_buttons.size()):
			var id: String = String(z.pad_buttons[i])
			if not id.ends_with("_1"):
				continue   # only a row's first pad draws the sign
			first_pads += 1
			var s: Vector2 = TexelPad.choose_sign_spot(at[i], at)
			t.ok(TexelPad.sign_clear(s, at[i], at), "%s %s: its sign sits clear of every bed, plate and press spot" % [zid, id])
		t.ok(first_pads > 0, "%s: has row-first pads to check" % zid)
