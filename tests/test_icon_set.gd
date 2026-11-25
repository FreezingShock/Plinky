extends RefCounted
## Staged icons: five sizes per stat icon, each exactly its own size, and the picker chooses by slot size.

const NAMES: Array[String] = ["rp", "cash", "mult", "reb", "prestige", "slag", "heat", "crit", "crit_dmg", "rate", "luck",
	"offline", "walk", "mastery", "presses", "clock", "rest", "lore", "fortune",
	"alloy", "cinder", "clover", "dewdrop", "emberheart", "embers", "foxglove", "heather", "ingot", "ironore", "seeds",
	"starbloom", "sunlight", "thistle", "r_cash", "r_crit", "r_double", "r_mult", "r_pulse", "r_rate", "menu_stats",
	"menu_attributes", "menu_upgrades", "menu_relics", "menu_travel", "menu_settings", "menu_history", "menu_ledger", "menu_log"]


func run(t: Object) -> void:
	# Every stat on the strip has an icon main colour, and its number uses it (not the tooltip colour).
	var ids: Array = StatStyle.ICON_TINT.keys()
	var mode_before: String = AccessOptions.color_mode
	for mode: String in [AccessOptions.MODE_OFF, AccessOptions.MODE_RED_GREEN, AccessOptions.MODE_BLUE_YELLOW]:
		AccessOptions.set_color_mode(mode)
		for sid: StringName in [&"sunlight", &"clover", &"embers", &"seeds", &"foxglove"]:
			t.ok(ids.has(sid), "%s has an icon main colour for its strip number" % sid)
			t.ok(StatStyle.value_color(sid) == StatStyle.ICON_TINT[sid], "%s's number matches its icon in mode %s" % [sid, mode])
	AccessOptions.set_color_mode(mode_before)
	t.eq(IconSet.best_size(8), 8, "8 px slot gets the 8 px icon")
	t.eq(IconSet.best_size(15), 12, "a 15 px slot gets the 12 px icon, never a scaled 16")
	t.eq(IconSet.best_size(16), 16, "16 px slot gets 16")
	t.eq(IconSet.best_size(31), 24, "31 gets 24")
	t.eq(IconSet.best_size(64), 32, "big slots take the largest")
	t.eq(IconSet.best_size(4), 8, "tiny slots take the smallest")
	for n: String in NAMES:
		for s: int in IconSet.SIZES:
			var tex: Texture2D = load(IconSet.path(n, s)) as Texture2D
			t.ok(tex != null, "%s exists at %d" % [n, s])
			if tex != null:
				t.eq(tex.get_width(), s, "%s at %d is %d wide" % [n, s, s])
				t.eq(tex.get_height(), s, "%s at %d is %d tall" % [n, s, s])
