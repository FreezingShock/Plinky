extends RefCounted
## Hamburger gallery: entries, version in the header, locked tiles, tile lift, and the update log parser.

func run(t: Object) -> void:
	t.eq(GalleryMenu.version_text(), "v%s" % BuildInfo.VERSION, "the menu shows the build version")
	var kinds: Array = []
	for e: Array in GalleryMenu.ENTRIES:
		kinds.append(e[0])
		t.ok(ResourceLoader.exists("res://assets/icons/big/%s.png" % e[2]), "icon exists for %s" % e[0])
	for k: StringName in [&"stats", &"attributes", &"upgrades", &"relics", &"travel", &"settings", &"history", &"ledger", &"log"]:
		t.ok(kinds.has(k), "the gallery has a %s tile" % k)

	var g := GalleryMenu.new()
	g.visible = true   # the tiles are built on open, so the menu is shown before its tiles are read
	t.eq(g.tile(&"settings").label, "Settings", "tiles carry their label")
	t.ok(g.tile(&"log").big_icon != null, "tiles carry a big icon")
	g.is_locked = func(k: StringName) -> bool: return k == &"relics"
	g.visible = true
	g._process(0.2)
	t.ok(g.tile(&"relics").locked and not g.tile(&"stats").locked, "locked sections show as locked tiles")
	t.ok(not g.tile(&"relics").disabled, "locked tiles stay focusable so arrows can land on them")
	var got: Array = []
	g.chosen.connect(func(k: StringName) -> void: got.append(k))
	for i in 20:
		g.tile(&"stats").pressed.emit()
	t.eq(got.size(), 20, "every tile press is reported (spam safe, no state of its own)")
	g.tile(&"relics").pressed.emit()
	t.eq(got.size(), 20, "pressing a locked tile does nothing")

	# Arrow keys: 7 tiles in 4 columns (a short last row) always land on a real tile, wrapping at the edges.
	var n0: Dictionary = GalleryMenu.neighbors(7, 4, 0)
	t.ok(n0["right"] == 1 and n0["down"] == 4 and n0["left"] == 3 and n0["up"] == 4, "tile 0: right 1, down 4, left wraps to the row end, up wraps to the column bottom")
	var n6: Dictionary = GalleryMenu.neighbors(7, 4, 6)
	t.ok(n6["right"] == 4 and n6["left"] == 5 and n6["up"] == 2 and n6["down"] == 2, "last tile: right wraps to its row start, up 2, down wraps to the top")
	var n3: Dictionary = GalleryMenu.neighbors(7, 4, 3)
	t.ok(n3["down"] == 3 and n3["right"] == 0, "a column with no tile below wraps to the top")
	for i in 7:
		var nb: Dictionary = GalleryMenu.neighbors(7, 4, i)
		for k: String in ["left", "right", "up", "down"]:
			t.ok(int(nb[k]) >= 0 and int(nb[k]) < 7, "tile %d %s is a real tile" % [i, k])
	for k: StringName in kinds:
		t.ok(GalleryMenu.COLORS.has(k) and g.tile(k).accent.a > 0.0, "the %s tile has its own section colour" % k)

	# Layout: Play, then Info, then Settings alone; the grid is as wide as its four columns, so no strip is left over.
	var order: Array = []
	for e: Array in GalleryMenu.ENTRIES:
		order.append(e[0])
	t.eq(order.slice(0, 4), [&"upgrades", &"relics", &"attributes", &"travel"], "Play tiles come first")
	t.eq(order.slice(4, 8), [&"stats", &"history", &"ledger", &"log"], "Info tiles come next")
	t.eq(order[8], &"settings", "Settings comes last")
	var grouped: int = 0
	for n: int in GalleryMenu.GROUPS:
		grouped += n
	t.eq(grouped, GalleryMenu.ENTRIES.size(), "every tile is in a row group")
	t.ok((g.tile(&"settings").size_flags_horizontal & Control.SIZE_EXPAND) != 0, "the lone Settings tile stretches to the full width")
	t.ok((g.tile(&"upgrades").size_flags_horizontal & Control.SIZE_EXPAND) == 0, "the grid tiles keep their own width")
	var n8: Dictionary = GalleryMenu.neighbors(9, GalleryMenu.COLUMNS, 8)
	t.ok(n8["up"] == 4 and n8["down"] == 0, "Settings: up goes to the Info row, down wraps to the first Play tile")
	g.free()

	t.eq(DisplayPanel.title_case("Mute all"), "Mute All", "settings labels display in Title Case")
	t.eq(DisplayPanel.title_case("VSync on 60 fps"), "VSync On 60 Fps", "words with capitals or digits are left alone")
	for tab: String in SettingsRegistry.TAB_ORDER:
		t.ok(DisplayPanel.TAB_COLORS.has(tab), "the %s tab has a colour" % tab)
	t.eq(DisplayPanel.tab_color("Brand New"), StatStyle.PAPER, "an unknown tab falls back to paper")

	t.eq(GalleryTile.lift_px(0.0), 0, "a resting tile is not lifted")
	t.eq(GalleryTile.lift_px(1.0), GalleryTile.LIFT, "a hovered tile lifts fully")
	t.eq(GalleryTile.lift_px(2.0), GalleryTile.LIFT, "lift is clamped")
	t.ok(not GalleryTile.dither_lit(0, 0, 0.0), "zero density lights nothing")
	t.ok(GalleryTile.dither_lit(1, 1, 1.0), "full density lights every cell")

	var entries: Array[Dictionary] = BuildInfo.parse_changelog("## Unreleased\n- later\n\n## 0.5.0 - 2026-11-23\n- Added the hamburger\n- Fixed menus\n\n## 0.4.0\n- Older\n")
	var rows: Array[Dictionary] = UpdateLogPanel.rows_from(entries)
	t.eq(rows.size(), 5, "each version gives a heading plus its notes")
	t.eq(rows[0]["text"], "v0.5.0  2026-11-23", "a heading shows version and date")
	t.eq(rows[1]["text"], "- Added the hamburger", "notes keep a dash")
	t.eq(rows[3]["text"], "v0.4.0", "an entry with no date shows just the version")
	t.ok(UpdateLogPanel.rows_from([] as Array[Dictionary]).is_empty(), "no entries gives no rows")
