extends RefCounted
## Ember Quarry: only quarry props (no meadow trees), pads and spawn on visible ground, and a working gate.

const DIR: String = "res://assets/art/zone2/quarry/"
const MEADOW_KINDS: Array[String] = ["oak", "pine", "bush", "flower", "lantern", "shrine", "tree"]


func run(t: Object) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json"))
	t.ok(data is Dictionary, "quarry placements load")
	var d: Dictionary = data as Dictionary
	var kinds: Dictionary = {}
	for s: Dictionary in d.get("sprites", []):
		kinds[str(s.get("kind", ""))] = true
		var f: String = str(s.get("file", ""))
		t.ok(f.begins_with("sprites/") and ResourceLoader.exists(DIR + f), "quarry sprite exists: %s" % f)
	for k: String in MEADOW_KINDS:
		t.ok(not kinds.has(k), "Zone 2 has no %s props" % k)
	t.ok(not kinds.has("gate_pillar") and not kinds.has("lintel"), "the gate arch is drawn by TexelGate, not baked sprites")
	var z2: ZoneDef = load("res://content/zones/zone2.tres") as ZoneDef
	t.eq(z2.scene_path, "res://world/quarry_scene.tscn", "zone 2 uses its own scene")

	# pads and spawn stand on ground you can see and walk on, not on the rim wall in front of the plateau
	var im: Image = Image.load_from_file(ProjectSettings.globalize_path(DIR + "walkable.png"))
	for a: Dictionary in d.get("anchors", []):
		var kind: String = str(a.get("kind", ""))
		if kind in ["pad", "player_spawn", "gate", "vent"]:
			var x: int = int(float(a.sx))
			var y: int = int(float(a.sy))
			t.ok(im.get_pixel(x, y).r > 0.5, "quarry %s at (%d, %d) is on walkable ground" % [kind, x, y])

	# the way back: an Arch anchor at the end of the south road, with its own art, leading to the previous zone
	var has_arch: bool = false
	for a: Dictionary in d.get("anchors", []):
		if str(a.get("kind", "")) == "arch":
			has_arch = true
			t.ok(im.get_pixel(int(float(a.sx)), int(float(a.sy))).r > 0.5, "the quarry's way back is on walkable ground")
	t.ok(has_arch, "the quarry has an Arch anchor for the way back to Larkmoor")
	var qsrc: String = FileAccess.get_file_as_string("res://world/quarry_scene.gd")
	t.ok(qsrc.contains("\"Arch\""), "quarry_scene.gd creates the Arch marker")
	var sim0: Sim = t.make_sim()
	var back: Dictionary = TexelGate.back_spec(sim0, &"zone2", &"larkmoor")
	t.ok(str(back.get("title", "")).contains("Larkmoor"), "the way back's tooltip names Larkmoor")

	# the gate
	var sim: Sim = t.make_sim()
	t.eq(z2.gate_art, &"forge", "zone 2 has the forge gate art")
	var z1: ZoneDef = load("res://content/zones/zone1.tres") as ZoneDef
	t.eq(z1.gate_art, &"meadow", "the meadow gate has its own timber and flower arch")
	var locked: Dictionary = TexelGate.spec_for(sim, &"zone2")
	t.ok(str(locked.get("hint", "")).begins_with("Need"), "locked gate says what is missing")
	sim.gates_open[&"zone2"] = true
	var open: Dictionary = TexelGate.spec_for(sim, &"zone2")
	t.ok(str(open.get("body", "")) != str(locked.get("body", "")), "open gate reads differently from a locked one")
	var gate := TexelGate.new()
	gate.art = &"forge"
	gate.position = Vector2(332.0, 41.0)
	t.ok(gate.hit(Vector2(332.0, 20.0)) and not gate.hit(Vector2(332.0, 120.0)), "the arch is hoverable, the ground below is not")
	gate.art = &""
	t.ok(not gate.hit(Vector2(332.0, 20.0)), "gates without art are not hoverable")
	gate.free()
	var mg := TexelGate.new()
	mg.art = &"meadow"
	mg.position = Vector2(330.0, 96.0)
	t.ok(mg.hit(Vector2(330.0, 36.0)) and mg.hit(Vector2(330.0, 90.0)) and not mg.hit(Vector2(330.0, 130.0)), "the meadow arch is hoverable from its keystone to its feet, not the ground below")
	t.ok(str(TexelGate.spec_for(sim, &"zone1").get("title", "")) != "", "the meadow gate has a tooltip spec")
	mg.free()

	# zone swaps free the old scene's props by reference (a name match lost them: meadow trees in the quarry)
	var parent := Node2D.new()
	var a := Sprite2D.new()
	a.name = "Occ_x"
	parent.add_child(a)
	a.queue_free()
	var b := Sprite2D.new()
	b.name = "Occ_x"
	parent.add_child(b)
	t.ok(not String(b.name).begins_with("Occ_"), "a name clash renames the new sprite, so name-prefix cleanup would miss it")
	parent.free()
	var src: String = FileAccess.get_file_as_string("res://main.gd")
	t.ok(src.contains("_free_occluders()") and not src.contains("begins_with(\"Occ_\")"), "main frees zone props by reference")

	# a click on the cliff face snaps to ground (the walk ring and the walker use the same rule): walk up from the first pad
	# until the mask ends, which is a terrace wall or a prop, then click just past it
	WalkMask.use("res://assets/art/zone2/quarry/walkable.png", Vector2i.ZERO)
	var pad0: Vector2 = Vector2.ZERO
	for anc: Dictionary in d.get("anchors", []):
		if str(anc.get("kind", "")) == "pad":
			pad0 = Vector2(float(anc.sx), float(anc.sy))
			break
	var cliff: Vector2 = pad0
	while WalkMask.walkable(cliff) and cliff.y > pad0.y - 120.0:
		cliff.y -= 1.0
	cliff.y -= 2.0
	t.ok(not WalkMask.walkable(cliff), "the wall behind the first terrace is not walkable")
	t.ok(WalkMask.walkable(WalkMask.nearest(cliff)), "a click on the wall snaps to walkable ground")
	var inset: Vector2 = WalkMask.nearest_inset(cliff)
	t.ok(WalkMask.walkable(inset) and WalkMask.walkable(inset + Vector2(0.0, 6.0)), "a wall click lands 6 texels back from the edge")
	WalkMask.use("")
