extends RefCounted
## Hamburger gallery: entries, version in the header, locked tiles, tile lift, and the update log parser.

func run(t: Object) -> void:
	t.eq(GalleryMenu.version_text(), "v%s" % BuildInfo.VERSION, "the menu shows the build version")
	var kinds: Array = []
	for e: Array in GalleryMenu.ENTRIES:
		kinds.append(e[0])
		t.ok(ResourceLoader.exists("res://assets/icons/big/%s.png" % e[2]), "icon exists for %s" % e[0])
	for k: StringName in [&"stats", &"attributes", &"upgrades", &"relics", &"travel", &"settings", &"log"]:
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

	var rows: Array[Dictionary] = UpdateLogPanel.parse("# Changelog\n\n## 0.1.1\n- Added the hamburger\n* Fixed menus\nPlain line\n")
	t.eq(rows.size(), 4, "the parser keeps headings, bullets and text, and drops the title")
	t.eq(rows[0]["kind"], "h", "a ## line is a heading")
	t.eq(rows[0]["text"], "0.1.1", "heading text has no hashes")
	t.eq(rows[1]["text"], "- Added the hamburger", "bullets keep a dash")
	t.eq(rows[2]["kind"], "b", "a * line is a bullet too")
	t.eq(rows[3]["kind"], "p", "other lines are body text")
	t.ok(UpdateLogPanel.parse("").is_empty(), "an empty log parses to nothing")
