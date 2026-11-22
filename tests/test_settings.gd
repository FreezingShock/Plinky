extends RefCounted
## Settings registry, keybinds, number styles, slider. Nothing here writes the real settings file.

func run(t: Object) -> void:
	SettingsFile.persist = false

	# Registry shape.
	var tabs: PackedStringArray = SettingsRegistry.tabs()
	t.eq(Array(tabs).slice(0, 6), ["Audio", "Display", "Gameplay", "Access", "Controls", "Data"], "built-in tabs are in menu order")
	var seen: Dictionary = {}
	for tab in tabs:
		for d in SettingsRegistry.entries(tab):
			t.ok(d.has("id") and d.has("label") and d.has("kind"), "%s row has id, label and kind" % tab)
			t.ok(not seen.has(d["id"]), "setting id %s is unique" % d["id"])
			seen[d["id"]] = true
			if int(d["kind"]) == SettingsRegistry.Kind.CHOICE:
				t.ok(d.get("options") is Callable, "%s is a choice with an options callable" % d["id"])
	t.ok(SettingsRegistry.entries("Audio").size() >= 7, "Audio has five sliders, mute and a device choice")
	t.ok(not SettingsRegistry.find(&"audio_device").is_empty(), "output device selector is registered")
	t.ok(not SettingsRegistry.find(&"resolution").is_empty(), "resolution selector is registered")
	var res_opts: Array = (SettingsRegistry.find(&"resolution")["options"] as Callable).call()
	t.eq((res_opts[0] as Array)[0], Vector2i.ZERO, "first window size option is Free")
	for i in range(1, res_opts.size()):
		var sz: Vector2i = (res_opts[i] as Array)[0]
		t.ok(sz.x >= DisplaySettings.BASE.x and sz.y >= DisplaySettings.BASE.y, "window size option %s is at least 640x360" % str(sz))

	# Stored settings: value, set, apply.
	var applied: Array = []
	SettingsRegistry.register_stored(&"test_toggle", "Test", "Test toggle", SettingsRegistry.Kind.TOGGLE, false,
		func(v: Variant) -> void: applied.append(v))
	t.ok(SettingsRegistry.tabs().has("Test"), "a new tab appears when a setting registers in it")
	t.eq(SettingsRegistry.value(&"test_toggle"), false, "stored setting starts at its default")
	SettingsRegistry.set_value(&"test_toggle", true)
	t.eq(SettingsRegistry.value(&"test_toggle"), true, "stored setting keeps the new value")
	t.eq(applied, [true], "apply runs when a stored setting changes")
	SettingsRegistry.register_stored(&"test_toggle", "Test", "Test toggle again", SettingsRegistry.Kind.TOGGLE, false)
	t.eq(SettingsRegistry.entries("Test").size(), 1, "registering an id twice replaces the row")
	t.ok(SettingsRegistry.find(&"nope").is_empty(), "unknown id finds nothing")

	# Keybinds.
	t.eq(Keybinds.key_for(&"settings"), KEY_F10, "settings defaults to F10")
	t.eq(Keybinds.key_for(&"fullscreen"), KEY_F11, "fullscreen defaults to F11")
	var swapped: StringName = Keybinds.set_key(&"settings", KEY_F11)
	t.eq(swapped, &"fullscreen", "taking a used key swaps that action")
	t.eq(Keybinds.key_for(&"fullscreen"), KEY_F10, "the other action gets the old key")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F11
	ev.pressed = true
	t.ok(Keybinds.matches(&"settings", ev), "matches() follows the rebind")
	ev.echo = true
	t.ok(not Keybinds.matches(&"settings", ev), "key repeat does not match")
	Keybinds.reset_all()
	t.eq(Keybinds.key_for(&"settings"), KEY_F10, "reset restores defaults")

	# Number styles.
	NumberFormat.style = NumberFormat.Style.SCIENTIFIC
	t.eq(NumberFormat.format(BigNum.make(1.5, 6)), "1.5e6", "scientific style")
	t.eq(NumberFormat.format(BigNum.from_float(250.0)), "250", "scientific leaves small numbers alone")
	NumberFormat.style = NumberFormat.Style.ENGINEERING
	t.eq(NumberFormat.format(BigNum.make(1.5, 7)), "15e6", "engineering style steps by three")
	NumberFormat.style = NumberFormat.Style.SUFFIX
	t.eq(NumberFormat.format(BigNum.make(1.5, 6)), "1.5M", "suffix style is the default")

	# Slider.
	var s := AsciiSlider.new()
	s.value = 0.52
	t.near(s.value, 0.5, 0.0001, "slider snaps to its step")
	s.value = 7.0
	t.near(s.value, 1.0, 0.0001, "slider clamps high")
	s.value = -3.0
	t.near(s.value, 0.0, 0.0001, "slider clamps low")
	s.free()

	SettingsFile.persist = true
