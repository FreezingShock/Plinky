extends RefCounted
## Title screen overhaul: menu icons, the readable clickable version, save slots, the Saves list text, the overlay
## host, and the backdrop's parallax and scenery maths. Run through tests/run.gd. Never touches the real save slots.

func run(t: Object) -> void:
	var root: Node = (t as SceneTree).root

	# Icons: 9x9, mirror symmetric (arrows are symmetric top to bottom instead), and every menu button has one.
	for id: String in MenuIcons.BITS:
		var rows: Array = MenuIcons.BITS[id]
		t.eq(rows.size(), MenuIcons.SIZE, "icon %s has 9 rows" % id)
		var sym: bool = true
		var vsym: bool = true
		for y in rows.size():
			var row: String = rows[y]
			if row.length() != MenuIcons.SIZE:
				sym = false
			if row != row.reverse():
				sym = false
			if row != String(rows[rows.size() - 1 - y]):
				vsym = false
		t.ok(sym or (vsym and (id == "play" or id == "back")), "icon %s is exactly symmetric" % id)
	for id: String in ["play", "new", "saves", "settings", "log", "credits", "quit"]:
		t.ok(MenuIcons.has(id), "menu icon %s exists" % id)

	# An icon button is wider by the icon slot and never changes size on hover.
	var plain := MenuTextButton.new()
	plain.label = "Saves"
	root.add_child(plain)
	var iconic := MenuTextButton.new()
	iconic.label = "Saves"
	iconic.icon_id = "saves"
	root.add_child(iconic)
	t.eq(iconic.custom_minimum_size.x - plain.custom_minimum_size.x, MenuTextButton.ICON_SLOT, "an icon adds exactly the icon slot")
	iconic.pad_y = 3.0
	t.ok(iconic.custom_minimum_size.y < plain.custom_minimum_size.y, "a tighter pad makes a shorter button")
	plain.free()
	iconic.free()

	# Version link: bright at rest (not the faded dim colour), accent plus underline when active, click emits.
	var v := VersionLink.new()
	root.add_child(v)
	t.eq(v.text, BuildInfo.string(), "the link shows the build version")
	t.ok(v.text_size().x > 0.0, "the version has a size")
	t.ok(VersionLink.is_active(true, false) and VersionLink.is_active(false, true) and not VersionLink.is_active(false, false), "hover or focus activates it")
	var hits: Array[int] = []
	v.pressed.connect(func() -> void: hits.append(1))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	v._gui_input(click)
	t.eq(hits.size(), 1, "clicking the version emits pressed")
	click.button_index = MOUSE_BUTTON_RIGHT
	v._gui_input(click)
	t.eq(hits.size(), 1, "only the left button opens it")
	v.free()

	# Save slots: files, summaries, no real slot touched.
	t.eq(SaveSlots.path_for(1), "user://save.json", "slot 1 keeps the original save file")
	t.eq(SaveSlots.path_for(3), "user://save_3.json", "other slots get their own file")
	t.ok(not bool(SaveCodec.summary({})["exists"]), "an empty slot does not exist")
	var sim: Sim = t.make_sim()
	sim.rebirth_count = 4
	sim.press_count = 321
	sim.play_seconds = 7500.0
	var data: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 1700000000.0))
	var sm: Dictionary = SaveCodec.summary(data)
	t.ok(bool(sm["exists"]), "a decoded save exists")
	t.eq(int(sm["rebirths"]), 4, "summary carries rebirths")
	t.eq(int(sm["presses"]), 321, "summary carries presses")
	t.near(float(sm["play_seconds"]), 7500.0, 1e-9, "summary carries play time")

	# Saves list text.
	t.eq(SlotPanel.format_playtime(20.0), "<1m", "under a minute")
	t.eq(SlotPanel.format_playtime(45.0 * 60.0), "45m", "minutes")
	t.eq(SlotPanel.format_playtime(7500.0), "2h 05m", "hours and zero-padded minutes")
	t.eq(SlotPanel.headline(sm), "4 rebirths, 2h 05m", "headline for a used slot")
	t.eq(SlotPanel.headline({"exists": false}), "Empty slot", "headline for an empty slot")
	sm["rebirths"] = 1
	t.ok(SlotPanel.headline(sm).begins_with("1 rebirth,"), "one rebirth is singular")
	t.ok(SlotPanel.detail(sm).begins_with("321 presses, saved 2023-11-14"), "detail shows presses and the save date")

	# Overlay host: opens centred, closes, and tells the screen.
	var parent := Control.new()
	parent.size = Vector2(640.0, 360.0)
	root.add_child(parent)
	var panel := PanelContainer.new()
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(200.0, 100.0)
	panel.add_child(filler)
	var ov: PanelOverlay = PanelOverlay.host(parent, panel, Color.BLACK, null)
	ov._ready()  # the test runner's tree has not started, so nodes get no _ready of their own
	ov.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)   # a full-rect anchor would override the size set next
	ov.size = parent.size
	var seen: Array[String] = []
	ov.opened.connect(func() -> void: seen.append("open"))
	ov.closed.connect(func() -> void: seen.append("close"))
	t.ok(not ov.is_open() and not panel.visible, "overlay starts closed")
	ov.open()
	t.ok(ov.is_open() and panel.visible, "overlay opens its panel")
	t.eq(panel.position, Vector2(220.0, 130.0), "the panel is centred")
	ov.toggle()
	t.ok(not ov.is_open() and not panel.visible, "toggle closes it")
	ov.close()
	t.eq(seen, ["open", "close"], "close fires once")
	parent.free()

	# Backdrop parallax and scenery maths.
	t.eq(TitleBackground.parallax_for(Vector2(320.0, 180.0), Vector2(640.0, 360.0)), Vector2.ZERO, "a centred cursor shifts nothing")
	t.eq(TitleBackground.parallax_for(Vector2(0.0, 180.0), Vector2(640.0, 360.0)).x, TitleBackground.PARALLAX_TEXELS, "far left shifts the layers right")
	t.eq(TitleBackground.parallax_for(Vector2(9999.0, 180.0), Vector2(640.0, 360.0)).x, -TitleBackground.PARALLAX_TEXELS, "a cursor outside the window is clamped")
	t.eq(TitleBackground.parallax_for(Vector2(1.0, 1.0), Vector2.ZERO), Vector2.ZERO, "no size, no shift")
	t.eq(TitleScenery.layer_shift(Vector2(8.0, -4.0), 1.0), Vector2(8.0, -4.0), "the near layer moves one for one")
	t.ok(absf(TitleScenery.layer_shift(Vector2(8.0, 0.0), 0.1).x) <= 1.0, "far layers barely move")
	var lo: float = 1000.0
	var hi: float = -1000.0
	for x in range(0, 641, 8):
		var y: float = TitleScenery.mid_ridge(float(x))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	t.ok(lo > 175.0 and hi < 214.0, "the mid ridge stays above the lake line")
	t.ok(TitleScenery.near_hill(300.0) > TitleScenery.near_hill(0.0), "the near meadow has a hump on the left")

	var scenery := TitleScenery.new()
	root.add_child(scenery)
	scenery._ready()
	t.ok(scenery._pines != null and scenery._canopies.size() == TitleScenery.TREES.size(), "pines and tree canopies are baked")
	t.ok(scenery._canopies[0].get_width() > 20, "the canopy has a size")
	scenery.free()

	# The panels build and refresh without errors (reads the real slots, never writes them).
	var slots := SlotPanel.new()
	root.add_child(slots)
	slots.refresh()
	t.eq(slots._rows.size(), SaveSlots.SLOT_COUNT, "the Saves list has one row per slot")
	slots.free()
	var credits := CreditsPanel.new()
	root.add_child(credits)
	t.ok(credits.get_child_count() > 0, "the credits panel builds")
	credits.free()
	var bg := TitleBackground.new()
	t.ok(bg.parallax == Vector2.ZERO, "the backdrop starts with no parallax")
	# The loading screen opens at sunrise (BOOT_PHASE 0.25). A press there must grab the sun the screen draws, not the moon.
	bg.clock = TitleMood.seconds_for(bg.sky, 0.25)
	bg._begin_grab()
	t.ok(bg.grabbing(), "a press on the sun at sunrise starts the grab")
	t.ok(bg._grab_sun == TitleMood.sun_half(bg.phase()), "the grab takes the same half the sun is drawn on at sunrise")
	t.ok(bg._grab_sun, "at sunrise the grab takes the sun, not the moon")
	bg._end_grab()
	bg.free()
	var title := TitleScreen.new()
	t.ok(title.has_method("_begin"), "the title screen compiles")
	title.free()
