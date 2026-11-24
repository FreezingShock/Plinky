extends RefCounted
## Pad signs: every pad draws its cost sign from its first price, on a spot clear of every bed and plate on its zone and
## of its walker press spot (world/texel_pad.gd build_sign and choose_sign_spot). Checked on the real placements of the
## three zones, with a real TexelPad built for every pad.

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
		var signed := 0
		for i in mini(at.size(), z.pad_buttons.size()):
			var id: StringName = StringName(z.pad_buttons[i])
			var b: ButtonDef = sim.button_defs.get(id) as ButtonDef
			t.ok(b != null, "%s %s: has a button definition" % [zid, id])
			if b == null:
				continue
			# Every pad gets a real TexelPad, as the zone builds it: the sign node is made, shown, and moved to its spot.
			var pad := TexelPad.new()
			pad.button_id = id
			pad.position = at[i]
			pad.build_sign(sim, b)
			pad.set_sign_neighbours(at)
			pad._sync_lock_chip()
			var chip: Node2D = pad._chip
			t.ok(chip != null, "%s %s: the pad has a sign node" % [zid, id])
			if chip != null:
				t.ok(chip.visible and TexelPad.shows_cost_sign(pad._lock_cost), "%s %s: the sign shows its cost from the first price" % [zid, id])
				t.ok(pad._lock_cost != "", "%s %s: the sign carries a cost text" % [zid, id])
				t.eq(chip.position, pad._sign_rel - Vector2(TexelPad.SIGN_X, TexelPad.SIGN_Y), "%s %s: the sign node sits on its chosen spot" % [zid, id])
				signed += 1
			var s: Vector2 = TexelPad.choose_sign_spot(at[i], at)
			t.ok(TexelPad.sign_clear(s, at[i], at), "%s %s: its sign sits clear of every bed, plate and press spot" % [zid, id])
			pad.free()
		t.eq(signed, z.pad_buttons.size(), "%s: every pad shows its sign" % zid)
