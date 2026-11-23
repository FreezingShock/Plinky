class_name StatIndex
extends RefCounted
## Rows for the Stats and Attributes index, built from a Sim. Pure data: no nodes, so tests can check it headless.
## A row is {id, group, name, icon, value, note, tip, pending}. `icon` is a file name under assets/icons.

const STAT_TIPS: Dictionary = {
	&"cash": "Earned every second and from presses. Spend it to unlock pads. Resets on rebirth.",
	&"mult": "Multiplies Cash income. Earned from presses, and boosted by Rebirths. Resets on rebirth.",
	&"reb": "Rebirths you have banked. Each one boosts how fast the Multiplier grows.",
	&"slag": "Quarry currency. Earned on the quarry pads.",
	&"prestige": "Earned by rebirthing. Boosts all income and buys Attributes.",
}
const ATTR_ICONS: Dictionary = {
	&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck",
	&"offline_hours": "offline", &"crit_damage": "crit_dmg", &"mastery_xp": "mastery", &"pad_yield": "cash",
}
const ATTR_TIPS: Dictionary = {
	&"walk_speed": "How fast the walker moves between pads.",
	&"press_rate": "How often a pad pays while you stand on it.",
	&"crit_chance": "Chance that a press is a critical hit and pays extra.",
	&"luck": "Better odds that a press drops a relic.",
	&"offline_hours": "Hours of income you collect while the game is closed.",
	&"crit_damage": "How much extra a critical hit pays.",
	&"mastery_xp": "Pads earn Mastery XP faster, so they level sooner.",
	&"pad_yield": "Every press pays more, on every pad.",
}


## Every stat the player can see, grouped. Empty groups are left out.
static func stats(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for sid: StringName in [&"cash", &"mult", &"reb", &"slag", &"prestige"]:
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		if sid == &"slag" and sim.get_stat(sid).is_zero() and sim.zone_id != &"zone2":
			continue
		var inc: BigNum = sim.income_per_second(sid)
		var note: String = "+%s/s" % inc.format() if not inc.is_zero() else ""
		var value: String = sim.get_stat(sid).format()
		if sid == &"prestige":
			note = "x%s income" % sim.prestige_mult().format()
		rows.append(_row(sid, "Currencies", def.display_name, String(sid), value, note, String(STAT_TIPS.get(sid, ""))))
	rows.append(_row(&"crit_chance", "Presses", "Crit chance", "crit", _pct(sim.crit_chance()), "",
		"Chance that a press is a critical hit. Raised by the Crit chance attribute and relics."))
	rows.append(_row(&"crit_damage", "Presses", "Crit damage", "crit_dmg", "x%.2f" % sim.crit_damage(), "",
		"What a critical hit multiplies a press by. Raised by pad mastery and relics."))
	rows.append(_row(&"press_rate", "Presses", "Press rate", "rate", "%.2f/s" % (1.0 / maxf(sim.press_interval(), 0.001)), "",
		"Presses per second while you stand on a pad."))
	rows.append(_row(&"luck", "Presses", "Luck", "luck", "Lv %d" % sim.luck_level(), "", "Each level improves the chance of a relic drop."))
	rows.append(_row(&"walk_speed", "Travel", "Walk speed", "walk", "x%.2f" % sim.walk_speed_mult(), "", "How fast the walker moves."))
	rows.append(_row(&"offline_cap", "Travel", "Offline cap", "offline", "%s h" % _trim(sim.offline_cap_seconds() / 3600.0), "",
		"The most income you can collect while the game is closed."))
	var lv_total: int = 0
	var lv_max: int = 0
	for bid: StringName in sim.button_defs:
		lv_total += sim.mastery.level(bid)
		lv_max = maxi(lv_max, sim.mastery.level(bid))
	rows.append(_row(&"mastery", "Mastery", "Pad mastery", "mastery", "Lv %d" % lv_total, "best pad Lv %d" % lv_max,
		"Pads gain levels as you press them. Each level adds crit chance and crit damage on that pad."))
	rows.append(_row(&"presses", "Totals", "Presses", "presses", BigNum.from_float(float(sim.press_count)).format(), "", "Every press you have made in this save."))
	rows.append(_row(&"rebirths_done", "Totals", "Rebirths done", "reb", str(sim.rebirth_count), "", "Times you have rebirthed. Extra relic slots unlock at 5 and 20."))
	rows.append(_row(&"relic_drops", "Totals", "Relic drops", "relics/r_double", str(sim.relic_drops), "", "Relics dropped from presses."))
	rows.append(_row(&"play_time", "Totals", "Time played", "clock", clock_text(sim.play_seconds), "", "Time spent in this save, offline time not counted."))
	return rows


## One row per Attribute, then placeholders for the ones that are still on their way.
static func attributes(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var ids: Array = sim.attribute_defs.keys()
	ids.sort()
	for aid: StringName in ids:
		var a: AttributeDef = sim.attribute_defs[aid]
		var lv: int = sim.attr_level(aid)
		var now: String = effect_text(a, float(lv) * a.per_level)
		var tip: String = String(ATTR_TIPS.get(a.effect, "A permanent upgrade."))
		if not sim.attr_unlocked(aid):
			tip += "\n%s." % UpgradeText.lock_text(a)
		elif lv >= a.cap:
			tip += "\nMaxed out."
		else:
			tip += "\nNext level: %s\nCost: %s Prestige" % [effect_text(a, float(lv + 1) * a.per_level), sim.attribute_cost(aid).format()]
		var r: Dictionary = _row(aid, "Attributes", a.display_name, String(ATTR_ICONS.get(a.effect, "prestige")), "Lv %d/%d" % [lv, a.cap], now, tip)
		r["level"] = lv
		r["cap"] = a.cap
		rows.append(r)
	return rows


static func effect_text(a: AttributeDef, amount: float) -> String:
	match a.effect:
		&"walk_speed": return "+%s%% walk speed" % _trim(amount * 100.0)
		&"press_rate": return "+%s%% press rate" % _trim(amount * 100.0)
		&"crit_chance": return "%s%% crit chance" % _trim(amount * 100.0)
		&"crit_damage": return "+%s%% crit damage" % _trim(amount * 100.0)
		&"luck": return "+%s%% luck" % _trim(amount * 100.0)
		&"mastery_xp": return "+%s%% pad XP" % _trim(amount * 100.0)
		&"pad_yield": return "+%s%% pad yield" % _trim(amount * 100.0)
		&"offline_hours": return "+%s h offline cap" % _trim(amount)
	return "+%s%%" % _trim(amount * 100.0)


## Play time as h:mm:ss, or m:ss under an hour.
static func clock_text(seconds: float) -> String:
	var s: int = int(maxf(seconds, 0.0))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


static func _pct(f: float) -> String:
	return "%s%%" % _trim(f * 100.0)


## 3 -> "3", 2.5 -> "2.5", 2.50001 -> "2.5".
static func _trim(f: float) -> String:
	var s: String = "%.1f" % f
	return s.trim_suffix(".0")


static func _row(id: StringName, group: String, label: String, icon: String, value: String, note: String, tip: String) -> Dictionary:
	return {"id": id, "group": group, "name": label, "icon": icon, "value": value, "note": note, "tip": tip, "pending": false}


static func _pending(id: StringName, group: String, label: String, icon: String, tip: String) -> Dictionary:
	var r: Dictionary = _row(id, group, label, icon, "Soon", "", tip)
	r["pending"] = true
	return r
