extends RefCounted
## Accessibility options: colour-safe swaps, large tooltip text, sound captions, subtitle bar. Writes no settings.

func run(t: Object) -> void:
	SettingsFile.persist = false
	AccessOptions.set_color_mode(AccessOptions.MODE_OFF)

	# Off passes every colour through.
	t.eq(StatStyle.gain(), StatStyle.BUY_GREEN, "off: gain is the normal buy green")
	t.eq(StatStyle.cant(), StatStyle.BUY_RED, "off: cant is the normal red")
	var rare: RarityDef = load("res://content/rarities/rare.tres") as RarityDef
	t.eq(rare.tint(), rare.color, "off: rarity colour is unchanged")

	# Red-green safe: buy green and red stop being green and red, and the eight tiers stay distinct.
	AccessOptions.set_color_mode(AccessOptions.MODE_RED_GREEN)
	t.ok(StatStyle.gain() != StatStyle.BUY_GREEN and StatStyle.cant() != StatStyle.BUY_RED, "rg: buy colours are swapped")
	t.ok(StatStyle.gain().b > StatStyle.gain().r, "rg: a gain reads blue")
	var seen: Dictionary = {}
	var dir: DirAccess = DirAccess.open("res://content/rarities")
	var n: int = 0
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r: RarityDef = load("res://content/rarities/" + f) as RarityDef
			seen[r.tint().to_html(false)] = true
			n += 1
	t.eq(seen.size(), n, "rg: every rarity keeps its own colour")
	t.eq(AccessOptions.tint(Color(0.372, 0.816, 0.408, 0.5)).a, 0.5, "tint keeps alpha")
	t.eq(AccessOptions.tint(Color.MAGENTA), Color.MAGENTA, "colours with no swap pass through")

	# Blue-yellow safe leaves the buy pair alone and changes the stat blues.
	AccessOptions.set_color_mode(AccessOptions.MODE_BLUE_YELLOW)
	t.eq(StatStyle.gain(), StatStyle.BUY_GREEN, "by: buy green stays")
	t.ok(StatStyle.color(&"mult") != Color("55aaff"), "by: Multiplier blue is swapped")
	AccessOptions.set_color_mode("nonsense")
	t.eq(AccessOptions.color_mode, AccessOptions.MODE_OFF, "an unknown mode falls back to off")

	# Text size and revision.
	var rev: int = AccessOptions.revision
	AccessOptions.set_large_text(true)
	t.ok(AccessOptions.revision > rev, "changing an option bumps the revision")
	t.ok(AccessOptions.body_size() > 12 and AccessOptions.title_size() > 16, "large text raises both sizes")
	AccessOptions.set_large_text(false)
	t.eq(AccessOptions.body_size(), 12, "normal body text is 12")

	# Settings rows exist in the Access tab.
	for id: StringName in [&"color_mode", &"large_text", &"subtitles"]:
		var d: Dictionary = SettingsRegistry.find(id)
		t.ok(not d.is_empty() and d["tab"] == "Access", "%s is in the Access tab" % id)

	# Captions.
	var audio: GDScript = load("res://audio/audio.gd") as GDScript
	t.eq(audio.caption_for(&"pad_big"), "[Critical press]", "crit has a caption")
	t.eq(audio.caption_for(&"relic_epic"), "[Relic chime: Epic]", "relic captions name the rarity")
	t.eq(audio.caption_for(&"bird_3"), "[Birdsong]", "bird variants share a caption")
	t.eq(audio.caption_for(&"step_grass_1"), "[Footsteps]", "steps share a caption")
	t.eq(audio.caption_for(&"ui_hover"), "", "hovers have no caption")
	t.eq(audio.caption_for(&"pad_press"), "", "the pad click has no caption")

	# Subtitle bar: off shows nothing, on shows, duplicates refresh, three at most.
	var bar := SubtitleBar.new()
	AccessOptions.subtitles = false
	bar.show_cue("[Gate opens]")
	t.eq(bar._lines.size(), 0, "subtitles off: nothing shows")
	AccessOptions.subtitles = true
	bar.show_cue("[Gate opens]")
	bar.show_cue("[Gate opens]")
	t.eq(bar._lines.size(), 1, "the same caption twice shows once")
	bar.show_cue("[Birdsong]")
	bar.show_cue("[Footsteps]")
	bar.show_cue("[Rebirth chime]")
	t.eq(bar._lines.size(), SubtitleBar.MAX_LINES, "at most three captions at once")
	t.eq(bar._lines[0]["text"], "[Birdsong]", "the oldest caption drops first")
	AccessOptions.subtitles = false
	bar.free()
	AccessOptions.set_color_mode(AccessOptions.MODE_OFF)
	SettingsFile.persist = true
