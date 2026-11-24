extends RefCounted
## Achievements and the Ledger: content, unlocking, peaks, titles, saves (including old saves), and the pure parts of the panel.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var a: Achievements = sim.achievements
	t.ok(a.total() >= 30 and a.total() <= 45, "there are 30 to 45 achievements (%d)" % a.total())
	t.eq(sim.validate().size(), 0, "achievement content validates against stats, tiers and zones")
	for c: Array in Achievements.CATEGORIES:
		t.ok(a.in_category(c[0]).size() >= 3, "category %s has at least three entries" % c[0])
		t.ok(LedgerPanel.CATEGORY_COLORS.has(c[0]), "category %s has a colour" % c[0])
		for size: int in [8, 12, 16, 24, 32]:
			t.ok(ResourceLoader.exists("res://assets/icons/ledger/%s_%d.png" % [c[0], size]), "%s icon exists at %d px" % [c[0], size])
	t.ok(ResourceLoader.exists("res://assets/icons/ledger/locked_16.png"), "the locked icon exists")
	t.ok(ResourceLoader.exists("res://assets/icons/big/menu_ledger.png"), "the gallery tile icon exists")
	for d: AchievementDef in a.sorted:
		t.ok(d.display_name != "" and d.description != "" and not d.display_name.to_lower().contains("plinko"), "%s has a name and a description" % d.id)
	t.eq(a.unlocked_count(), 0, "a new game has nothing unlocked")
	t.eq(a.current_title(), "", "and no title")

	var got: Array[StringName] = []
	sim.achievement_unlocked.connect(func(id: StringName) -> void: got.append(id))
	sim.check_achievements()
	t.eq(got.size(), 0, "nothing unlocks before it is earned")
	sim.press_count = 100
	sim.check_achievements()
	t.eq(got, [&"first_press", &"presses_100"] as Array[StringName], "reaching a total unlocks every entry it covers, in order")
	sim.check_achievements()
	t.eq(got.size(), 2, "an entry unlocks only once")
	t.eq(a.current_title(), "Newcomer", "the first title is Newcomer")
	t.near(a.progress(a.defs[&"presses_1000"], sim.achievement_counters()), 0.1, 1e-4, "progress is the share of the target")
	sim.press_count = 1000
	sim.step(1.0)
	t.ok(got.has(&"presses_1000"), "the sim checks achievements as it steps")

	sim.dev_set_stat(&"starbloom", BigNum.from_float(150.0))
	sim.dev_set_stat(&"starbloom", BigNum.zero())   # spent again before the next check: the peak still counts
	sim.check_achievements()
	t.ok(got.has(&"meadow_petals"), "holding enough of a stat unlocks it")
	t.eq(a.current_title(), "Meadow Keeper", "the newest title wins")
	t.ok(sim.achievement_counters()[&"peak_starbloom"] >= 150.0, "the peak stays after the stat is spent")
	t.ok(a.is_unlocked(&"meadow_petals"), "and the entry stays unlocked")

	sim.rebirth_count = 5
	sim.check_achievements()
	t.ok(got.has(&"rebirth_1") and got.has(&"rebirth_5") and not got.has(&"rebirth_20"), "rebirth counts unlock in steps")
	t.ok(sim.achievement_counters()[&"zone_zone1"] >= 0.0, "zone counters exist for every zone")

	# Save round trip.
	var before: int = a.unlocked_count()
	var data: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 1.0))["game"]
	var sim2: Sim = t.make_sim()
	var got2: Array[StringName] = []
	sim2.achievement_unlocked.connect(func(id: StringName) -> void: got2.append(id))
	t.ok(sim2.from_dict(data), "a save with achievements loads")
	t.eq(sim2.achievements.unlocked_count(), before, "unlocked achievements survive a save")
	t.eq(sim2.achievements.unlock_log, a.unlock_log, "and keep their order")
	t.eq(sim2.achievements.current_title(), a.current_title(), "and the title")
	t.ok(sim2.achievement_counters()[&"peak_starbloom"] >= 150.0, "and the stat peaks")
	sim2.check_achievements()
	t.eq(got2.size(), 0, "loading never replays old unlocks")

	# A save from before the Ledger: what is already earned counts, silently.
	var old: Dictionary = data.duplicate(true)
	old.erase("achievements")
	var sim3: Sim = t.make_sim()
	var got3: Array[StringName] = []
	sim3.achievement_unlocked.connect(func(id: StringName) -> void: got3.append(id))
	t.ok(sim3.from_dict(old), "a save from before the Ledger loads")
	t.ok(sim3.achievements.is_unlocked(&"presses_1000") and sim3.achievements.is_unlocked(&"rebirth_5"), "it is credited with what it already did")
	t.eq(got3.size(), 0, "without a single pop-up")

	# Bad data never throws.
	sim3.achievements.from_dict({"log": ["first_press", "nope", "first_press"], "peaks": {"cash": [1.0, 3]}})
	t.eq(sim3.achievements.unlock_log, [&"first_press"] as Array[StringName], "unknown and repeated ids are dropped")
	sim3.achievements.from_dict("junk")
	t.eq(sim3.achievements.unlocked_count(), 0, "a malformed block loads as empty")
	sim3.new_game()
	t.eq(sim3.achievements.unlocked_count(), 0, "a new game clears the Ledger")

	# The panel's pure parts.
	var rows: Array[Dictionary] = LedgerPanel.rows_for(sim)
	t.eq(rows.size(), a.total(), "the Ledger lists every achievement")
	var first: Dictionary = rows[0]
	t.ok(first["done"] and first["progress"] == 1.0, "a done row is full")
	var sig: int = LedgerPanel.signature_of(rows)
	sim.press_count = 100000
	sim.check_achievements()
	t.ok(LedgerPanel.signature_of(LedgerPanel.rows_for(sim)) != sig, "the rebuild signature changes when a row changes")
	t.eq(LedgerPanel.progress_text(3.0, 100.0), "3 / 100", "progress reads as count over target")
	t.eq(LedgerPanel.progress_text(0.46, 1.0), "0.4 / 1", "fractions below a whole show one decimal")
	t.eq(LedgerPanel.progress_text(1500.0, 10000.0), "1.5K / 10K", "large counts use the shared number format")

	var panel := LedgerPanel.new()
	panel.bind(sim)
	panel.visible = true
	t.ok(panel._body.get_child_count() > a.total(), "the open Ledger shows a title, headings and a row per entry")
	t.eq(panel._count.text, "%d / %d" % [a.unlocked_count(), a.total()], "the header counts unlocked entries")
	var kids: int = panel._body.get_child_count()
	panel.refresh()
	t.eq(panel._body.get_child_count(), kids, "refreshing with nothing new keeps the same rows")
	panel.free()

	# The toast queues unlocks and can be held back.
	var toast := AchievementToast.new()
	var toast_z: int = toast.z_index
	var held: Array = [false]
	toast.enabled = func() -> bool: return not held[0]
	toast.bind(sim)
	held[0] = true
	sim.dev_set_stat(&"slag", BigNum.from_float(500.0))
	t.eq(toast.queued(), 0, "a held toast shows nothing")
	held[0] = false
	sim.press_count = 0
	sim.achievements.clear()
	sim.check_achievements()
	t.ok(toast.visible, "an unlock shows the toast")
	t.ok(toast.queued() >= 1, "unlocks that arrive together queue behind it")
	t.ok(toast.z_index > 100 and toast.z_index < 150, "toasts draw above menu panels but below tip cards")
	toast.free()
	var relic_toast := RelicToast.new()
	t.eq(relic_toast.z_index, toast_z, "the relic toast shares the layer")
	relic_toast.free()

	# The banner waits while a menu is open, then shows; a menu opening mid-banner closes it and it comes back.
	var banner := AchievementToast.new()
	var menu_open: Array = [true]
	var sfx_played: Array = []
	banner.menu_open = func() -> bool: return menu_open[0]
	banner.play_sfx = func(sfx_name: StringName, _pitch: float, _db: float) -> void: sfx_played.append(sfx_name)
	banner.bind(sim)
	sim.achievements.clear()
	sim.check_achievements()
	t.ok(not banner.visible, "an unlock waits while a menu is open")
	t.ok(banner.queued() >= 1, "the waiting unlock stays queued")
	menu_open[0] = false
	banner._process(0.1)
	t.ok(banner.visible, "the banner shows once the menu closes")
	t.ok(sfx_played.size() >= 1, "the banner plays its section chime")
	menu_open[0] = true
	banner._process(0.05)   # the menu is seen: the banner starts to close
	banner._process(1.0)    # and the close finishes
	t.ok(not banner.visible, "a menu opening over the banner closes it")
	t.ok(banner.queued() >= 1, "the cut-short banner goes back in the queue")
	banner.free()

	# Geometry: scales with the window, is centred across and sits above the middle, and unfurls from a sliver.
	var area := Vector2(640.0, 360.0)
	var full: float = AchievementToast.banner_width(area.x)
	var card := Vector2(full, 40.0)
	var at: Vector2 = AchievementToast.origin_for(area, card)
	t.eq(at.x + card.x * 0.5, area.x * 0.5, "the banner is centred across the screen")
	t.ok(at.y + card.y * 0.5 < area.y * 0.5, "the banner sits above the vertical middle")
	t.ok(full < 300.0, "the banner is narrow at 640 wide: it no longer reaches the right-hand panels")
	t.eq(AchievementToast.banner_width(100.0), AchievementToast.MIN_WIDTH, "a tiny window keeps the minimum width")
	t.eq(AchievementToast.banner_width(4000.0), AchievementToast.MAX_WIDTH, "a huge window stops at the maximum width")
	t.ok(AchievementToast.width_for(0.0, full) < AchievementToast.width_for(0.5, full), "the banner unfurls from a sliver")
	t.eq(AchievementToast.width_for(1.0, full), full, "fully open it is the full banner width")
	t.ok(AchievementStyle.count_of(&"spark", true) > AchievementStyle.count_of(&"spark", false), "a titled unlock throws more particles")
	for c: Array in Achievements.CATEGORIES:
		var cat: StringName = c[0]
		var st: Dictionary = AchievementStyle.of(cat)
		t.ok(AchievementStyle.STYLES.has(cat), "category %s has a banner style" % cat)
		t.ok(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % st["sound"]), "category %s has a chime that exists" % cat)
	t.ok(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % AchievementStyle.TITLE_SOUND), "the title chime exists")
	for e: Array in GalleryMenu.ENTRIES:
		if e[0] == &"ledger":
			t.eq(e[1], "Achievements", "the hamburger tile is called Achievements")
