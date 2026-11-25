extends RefCounted
## One Reduce Motion switch: FxConfig.still() is on when either option is, the master row follows both and sets both,
## the calm gates hold (menu slide, pad sink), and the player-facing copy has no "Button". Writes no settings.

func run(t: Object) -> void:
	SettingsFile.persist = false
	var keep_banner: bool = FxConfig.reduce_motion
	var keep_meadow: bool = MeadowLife.reduce_motion
	var keep_flash: bool = FxConfig.reduce_flashing
	var keep_mode: String = AccessOptions.color_mode

	# The predicate is the OR of the two options, and neither one alone is enough to miss it.
	FxConfig.reduce_motion = false
	MeadowLife.reduce_motion = false
	t.ok(not FxConfig.still(), "still() is off when neither Reduce Motion option is on")
	FxConfig.reduce_motion = true
	t.ok(FxConfig.still(), "still() is on for Still banners alone")
	FxConfig.reduce_motion = false
	MeadowLife.reduce_motion = true
	t.ok(FxConfig.still(), "still() is on for Still meadow alone")
	FxConfig.reduce_flashing = true
	MeadowLife.reduce_motion = false
	t.ok(not FxConfig.still(), "Reduce flashing is its own switch and does not make still() true")
	FxConfig.reduce_flashing = false

	# The master row reads the predicate and sets both options, each through its own saved setting.
	t.ok(SettingsRegistry.find(&"reduce_motion").has("get"), "the master row reads Reduce Motion live")
	FxConfig.reduce_motion = true
	MeadowLife.reduce_motion = true
	SettingsRegistry.set_value(&"reduce_motion", false)
	t.ok(not FxConfig.reduce_motion and not MeadowLife.reduce_motion, "the master row off clears both options")
	t.ok(not bool(SettingsRegistry.value(&"reduce_motion")), "the master row reads off after that")
	SettingsRegistry.set_value(&"reduce_motion", true)
	t.ok(FxConfig.reduce_motion and MeadowLife.reduce_motion, "the master row on sets both options")
	t.ok(bool(SettingsRegistry.value(&"reduce_motion")), "the master row reads on after that")
	var subs: Array[String] = []
	for d: Dictionary in SettingsRegistry.entries("Access"):
		if bool(d.get("sub", false)):
			subs.append(String(d["id"]))
	t.eq(subs, ["reduce_text_motion", "reduce_meadow_motion"], "both options sit under the master row")

	# The menu slide stops under Reduce Motion and under Reduce flashing; the stepped wipe is still there.
	FxConfig.reduce_motion = false
	MeadowLife.reduce_motion = false
	var p := PanelContainer.new()
	p.visible = false
	var a: MenuAnim = MenuAnim.attach(p)
	a._set_t(0.0)
	t.eq(p.get_meta(&"menu_slide", -1.0), float(MenuAnim.SLIDE), "a closed menu slides 14 texels when motion is on")
	FxConfig.reduce_motion = true
	a._set_t(0.0)
	t.eq(p.get_meta(&"menu_slide", -1.0), 0.0, "Reduce Motion drops the menu slide")
	FxConfig.reduce_motion = false
	FxConfig.reduce_flashing = true
	a._set_t(0.0)
	t.eq(p.get_meta(&"menu_slide", -1.0), 0.0, "Reduce flashing drops the menu slide too")
	FxConfig.reduce_flashing = false

	# Colour-safe red-green swaps the four stat colours that were missing from the table.
	AccessOptions.set_color_mode(AccessOptions.MODE_RED_GREEN)
	t.eq(AccessOptions.tint(Color("6be86b")), Color("009e73"), "rg: Clover is swapped")
	t.eq(AccessOptions.tint(Color("5fb26a")), Color("0072b2"), "rg: Iron Ore is swapped")
	t.eq(AccessOptions.tint(Color("ffd95a")), Color("f0e442"), "rg: Sunlight is swapped")
	t.eq(AccessOptions.tint(Color("ff8a3d")), Color("d55e00"), "rg: Embers is swapped")
	AccessOptions.set_color_mode(keep_mode)

	# Copy: no relic description says "button", and the rarity tag reads PAD.
	var dir: DirAccess = DirAccess.open("res://content/relics")
	var clean: bool = true
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			var r: Resource = load("res://content/relics/" + f)
			if r != null and "description" in r and String(r.get("description")).to_lower().contains("button"):
				clean = false
	t.ok(clean, "no relic description says button")

	FxConfig.reduce_motion = keep_banner
	MeadowLife.reduce_motion = keep_meadow
	FxConfig.reduce_flashing = keep_flash
