extends RefCounted
## Hamburger gallery: entries, version in the header, locked tiles, tile lift, and the update log parser.

func run(t: Object) -> void:
	t.eq(GalleryMenu.version_text(), "v%s" % BuildInfo.VERSION, "the menu shows the build version")
	var kinds: Array = []
	for e: Array in GalleryMenu.ENTRIES:
		kinds.append(e[0])
		t.ok(ResourceLoader.exists("res://assets/icons/big/%s.png" % e[2]), "icon exists for %s" % e[0])
	for k: StringName in [&"stats", &"attributes", &"upgrades", &"relics", &"travel", &"settings", &"history", &"log"]:
		t.ok(kinds.has(k), "the gallery has a %s tile" % k)

	var g := GalleryMenu.new()
	t.eq(g.tile(&"settings").label, "Settings", "tiles carry their label")
	t.ok(g.tile(&"log").big_icon != null, "tiles carry a big icon")
	g.is_locked = func(k: StringName) -> bool: return k == &"relics"
	g.visible = true
	g._process(0.2)
	t.ok(g.tile(&"relics").disabled and not g.tile(&"stats").disabled, "locked sections show as disabled tiles")
	var got: Array = []
	g.chosen.connect(func(k: StringName) -> void: got.append(k))
	for i in 20:
		g.tile(&"stats").pressed.emit()
	t.eq(got.size(), 20, "every tile press is reported (spam safe, no state of its own)")
	g.free()

	t.eq(GalleryTile.lift_px(0.0), 0, "a resting tile is not lifted")
	t.eq(GalleryTile.lift_px(1.0), GalleryTile.LIFT, "a hovered tile lifts fully")
	t.eq(GalleryTile.lift_px(2.0), GalleryTile.LIFT, "lift is clamped")

	var entries: Array[Dictionary] = BuildInfo.parse_changelog("## Unreleased\n- later\n\n## 0.5.0 - 2026-11-23\n- Added the hamburger\n- Fixed menus\n\n## 0.4.0\n- Older\n")
	var rows: Array[Dictionary] = UpdateLogPanel.rows_from(entries)
	t.eq(rows.size(), 5, "each version gives a heading plus its notes")
	t.eq(rows[0]["text"], "v0.5.0  2026-11-23", "a heading shows version and date")
	t.eq(rows[1]["text"], "- Added the hamburger", "notes keep a dash")
	t.eq(rows[3]["text"], "v0.4.0", "an entry with no date shows just the version")
	t.ok(UpdateLogPanel.rows_from([] as Array[Dictionary]).is_empty(), "no entries gives no rows")
