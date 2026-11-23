extends RefCounted

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	sim.stats[&"sunlight"] = BigNum.make(1.5, 40)
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	sim.step(0.1)  # latches gate
	sim.attr_levels[&"luck"] = 3
	sim.prestige_spent = BigNum.from_float(4.0)
	sim.relics.add_relic(&"r_rate", 2)
	sim.relics.equip(&"r_rate")
	sim.rebirth_count = 6
	var text: String = SaveCodec.encode(sim, 1000.0)
	var d: Dictionary = SaveCodec.decode(text)
	t.ok(not d.is_empty(), "decode succeeds")
	var sim2: Sim = t.make_sim()
	t.ok(sim2.from_dict(d["game"]), "from_dict succeeds")
	t.ok(sim2.get_stat(&"sunlight").gte(BigNum.make(1.49, 40)) and sim2.get_stat(&"sunlight").lte(BigNum.make(1.6, 40)), "big cash survives JSON")
	t.near(sim2.get_stat(&"clover").to_float(), 9.0, 1e-9, "reb survives")
	t.ok(sim2.is_gate_open(&"zone1"), "gate latch survives")
	t.eq(sim2.attr_level(&"luck"), 3, "attribute level survives")
	t.eq(sim2.relics.stacks_of(&"r_rate"), 2, "relic stacks survive")
	t.ok(sim2.relics.is_equipped(&"r_rate"), "equipped relic survives")
	t.eq(sim2.rebirth_count, 6, "rebirth count survives")
	t.near(sim2.prestige_spent.to_float(), 4.0, 1e-9, "prestige_spent survives")

	t.ok(SaveCodec.decode("not json {").is_empty(), "garbage is rejected")
	t.ok(SaveCodec.decode("[1,2]").is_empty(), "wrong shape is rejected")
	t.ok(SaveCodec.decode('{"version": 999, "game": {}}').is_empty(), "future version is rejected")
	t.ok(SaveCodec.decode('{"game": {}}').is_empty(), "missing version is rejected")
	var sim3: Sim = t.make_sim()
	t.ok(not sim3.from_dict({}), "empty dict gives a new game, no crash")
	t.near(sim3.get_stat(&"sunlight").to_float(), 10.0, 1e-9, "new game after empty load starts with 10 cash")
	sim3.from_dict({"stats": {"cash": "oops", "ghost": [1, 1]}, "zone": "nowhere", "attributes": {"luck": 9999}})
	t.eq(sim3.zone_id, &"zone1", "unknown zone falls back")
	t.eq(sim3.attr_level(&"luck"), 20, "attribute level clamps to cap")

	# File round trip with backup fallback
	var path: String = "user://test_save.json"
	t.ok(SaveCodec.write_file(path, text), "write")
	t.ok(SaveCodec.write_file(path, text), "write twice makes a .bak")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "atomic write leaves no .tmp behind")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("corrupt")
	f.close()
	t.ok(not SaveCodec.read_with_fallback(path).is_empty(), "corrupt main falls back to .bak")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	t.ok(SaveCodec.read_with_fallback(path).is_empty(), "nothing saved gives empty, caller starts new game")
