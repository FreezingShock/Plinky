extends RefCounted
## Area content is consistent, the reveal box folds, and the zone panel builds, travels and follows districts.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.eq(sim.areas_in_zone(&"larkmoor").size(), 7, "Larkmoor lists its seven districts")
	t.eq(sim.areas_in_zone(&"zone1").size(), 2, "the Meadow has two areas")
	for z: ZoneDef in sim.zone_defs.values():
		var seen: Dictionary = {}
		for a in sim.areas_in_zone(z.id):
			for bid in a.pad_buttons:
				seen[bid] = true
		t.eq(seen.size(), z.pad_buttons.size(), "%s: its areas list every pad once" % z.id)
		t.ok(z.description != "", "%s has a description" % z.id)

	var box := RevealBox.new()
	var body := Control.new()
	body.custom_minimum_size = Vector2(40, 80)
	box.add_child(body)
	t.root.add_child(box)   # minimum sizes only update inside the tree
	t.eq(box.get_combined_minimum_size().y, 80.0, "open box shows the whole body")
	box.set_open(false, false)
	t.eq(box.get_combined_minimum_size().y, 0.0, "shut box has no height")
	t.ok(not body.visible, "shut body is hidden so focus skips it")
	box.floor_px = 26.0
	t.eq(box.get_combined_minimum_size().y, 26.0, "a floor keeps a stub showing")
	box.amount = 0.5
	t.eq(box.get_combined_minimum_size().y, 53.0, "half open lands between floor and full")
	box.free()

	var panel := ZonePanel.new()
	panel.setup(sim)
	panel.refresh()
	t.eq(panel.view_area(), &"clearing", "the Meadow card starts on its first area")
	panel.set_travel_open(true, false)
	t.ok(panel.travel_open, "travel menu opens")
	panel.set_travel_open(false, false)
	sim.gates_open[&"zone1"] = true
	panel._go(&"larkmoor", &"oak")
	t.eq(sim.zone_id, &"larkmoor", "clicking an area travels to its zone")
	t.eq(panel.view_area(), &"oak", "and views that area")
	panel.set_district(&"emberwatch")
	t.eq(panel.view_area(), &"emberwatch", "walking into a district moves the card")
	panel.set_district(&"forge")
	t.eq(panel.view_area(), &"emberwatch", "an area of another zone is ignored")
	panel.free()
