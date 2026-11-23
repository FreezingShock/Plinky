extends RefCounted
## Area content is consistent, the reveal box folds, and the zone panel builds, travels and follows districts.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.eq(sim.areas_in_zone(&"larkmoor").size(), 7, "Larkmoor lists its seven districts")
	t.eq(sim.areas_in_zone(&"zone1").size(), 2, "the Meadow has two areas")
	for z: ZoneDef in sim.zone_defs.values():
		var seen: Dictionary = {}
		for a in sim.areas_in_zone(z.id):
			t.ok(AreaIcons.has(a.icon), "%s has a drawn icon" % a.id)
			for bid in a.pad_buttons:
				seen[bid] = true
		t.eq(seen.size(), z.pad_buttons.size(), "%s: its areas list every pad once" % z.id)
		t.ok(z.description != "", "%s has a description" % z.id)

	var box := RevealBox.new()
	var body := Control.new()
	body.custom_minimum_size = Vector2(40, 80)
	box.add_child(body)
	t.eq(box.shown_height(), 80.0, "open box shows the whole body")
	box.set_open(false, false)
	t.eq(box.shown_height(), 0.0, "shut box has no height")
	t.ok(not body.visible, "shut body is hidden so focus skips it")
	box.floor_px = 26.0
	t.eq(box.shown_height(), 26.0, "a floor keeps a stub showing")
	box.amount = 0.5
	t.eq(box.shown_height(), 53.0, "half open lands between floor and full")
	box.free()

	var panel := ZonePanel.new()
	panel.setup(sim)
	panel.refresh()
	t.eq(panel.view_area(), &"clearing", "the Meadow card starts on its first area")
	panel.set_travel_open(true, false)
	t.ok(panel.travel_open, "travel menu opens")
	var tops: Array[ZoneDef] = panel.top_zones()
	t.eq(tops.size(), 2, "travel lists only the Meadow and Ember Quarry")
	t.eq(panel.top_of(&"larkmoor"), &"zone1", "Larkmoor sits inside the Meadow, not on its own row")
	t.eq(panel._teaser_rows.size(), sim.config.travel_teased_rows, "locked teaser rows follow the config")
	t.ok(panel._teaser_rows[0].disabled, "teaser rows can't be clicked")
	t.eq(panel.destination(&"zone1"), &"zone1", "Meadow row stays in the Meadow while its gate is shut")
	t.eq(panel.destination(&"zone2"), &"zone2", "a locked area has itself as its (disabled) target")
	panel.set_travel_open(false, false)
	sim.gates_open[&"zone1"] = true
	panel._go(&"larkmoor", &"oak")
	t.eq(sim.zone_id, &"larkmoor", "clicking an area travels to its zone")
	sim.gates_open[&"larkmoor"] = true
	sim.enter_zone(&"zone2")
	t.eq(panel.destination(&"zone1"), &"larkmoor", "from outside, the Meadow row lands in Larkmoor once its gate is open")
	t.eq(panel.destination(&"zone2"), &"zone2", "the row of the zone you are in stays put")
	panel._go(&"larkmoor", &"oak")
	t.eq(panel.view_area(), &"oak", "and views that area")
	panel.set_district(&"emberwatch")
	t.eq(panel.view_area(), &"emberwatch", "walking into a district moves the card")
	panel.set_district(&"forge")
	t.eq(panel.view_area(), &"emberwatch", "an area of another zone is ignored")
	# Long pad lists fold behind a "N more..." line and unfold again.
	var long_area: StringName = &""
	for a: AreaDef in sim.area_defs.values():
		if a.pad_buttons.size() > ZonePanel.PADS_FOLD:
			long_area = a.id
	if long_area != &"":
		var la: AreaDef = sim.area_defs[long_area] as AreaDef
		sim.gates_open[&"zone1"] = true
		sim.gates_open[&"larkmoor"] = true
		panel._go(la.zone, long_area)
		panel.refresh()
		var shown: int = 0
		for l: Label in panel._pad_rows.values():
			shown += 1 if l.visible else 0
		t.eq(shown, ZonePanel.PADS_SHOWN, "a long pad list shows only the first few")
		t.ok(panel._pads_more.visible and panel._pads_more.text.ends_with("more..."), "and a greyed N more... line")
		panel._pads_expanded = true
		panel._layout_pads()
		shown = 0
		for l: Label in panel._pad_rows.values():
			shown += 1 if l.visible else 0
		t.eq(shown, la.pad_buttons.size(), "expanding shows every pad")
		t.ok(panel._pads_scroll.custom_minimum_size.y <= ZonePanel.PADS_MAX_PX, "the expanded list is height-capped")
	panel.free()
	_banner_checks(t, sim)


## The slim district card: themed by the area's zone palette, short, and plain notices still work.
func _banner_checks(t: Object, sim: Sim) -> void:
	var b := DistrictBanner.new()
	var a: AreaDef = sim.area_defs[&"heronmere"] as AreaDef
	b.show_area(a, sim.zone_defs[&"larkmoor"] as ZoneDef)
	t.ok(b.visible, "area card shows")
	t.ok(DistrictBanner.LIFETIME <= 2.0, "zone card stays short")
	b.show_name("Notice")
	t.ok(b.visible, "plain notice shows")
	b.free()
