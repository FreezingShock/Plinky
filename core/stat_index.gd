class_name StatIndex
extends RefCounted
## Rows for the Stats and Attributes index, built from a Sim. Pure data: no nodes, so tests can check it headless.
## A row is {id, group, name, icon, value, note, tip, pending}. `icon` is a file name under assets/icons.

const STAT_TIPS: Dictionary = {
	&"sunlight": "Trickles in on its own and pays for the first pads. Dewdrops and Thistle Down make it flow faster. Resets on Bloom.",
	&"dewdrop": "Paid by the Sprout pads. Boosts Sunlight income, and Clover Leaves make each press pay more. Resets on Bloom.",
	&"clover": "Paid by the Clover pads. Boosts Dewdrops per press and opens the gate to Larkmoor. Resets on Bloom.",
	&"thistle": "Paid by the Thistle pads in Larkmoor. Boosts Sunlight income, and Heather Sprigs make each press pay more.",
	&"heather": "Paid by the Heather pads. Spent on Foxglove pads, and boosts Thistle Down per press.",
	&"foxglove": "Paid by the Foxglove pads. Spent on Starbloom pads, and boosts Heather Sprigs per press.",
	&"starbloom": "Paid by the Starbloom pads, the last row. Boosts Foxglove Bells per press and opens the far gate.",
	&"cash": "Earned every second and from presses. Spend it to unlock pads. Resets on rebirth.",
	&"mult": "Multiplies Cash income. Earned from presses, and boosted by Rebirths. Resets on rebirth.",
	&"seeds": "Paid by every Bloom, more the higher your Starbloom Petals were. Spend it on Bloom gifts in Upgrades.",
	&"rp": "Earned on every rebirth, and a little more each time. Spend it on Rebirth perks in Upgrades.",
	&"reb": "Rebirths you have banked. Each one boosts how fast the Multiplier grows.",
	&"slag": "Quarry currency. Earned on the quarry pads.",
	&"prestige": "Earned by rebirthing. Boosts all income and buys Attributes.",
}
const ATTR_ICONS: Dictionary = {
	&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck",
	&"offline_hours": "offline", &"crit_damage": "crit_dmg", &"mastery_xp": "mastery", &"pad_yield": "cash",
	&"head_start": "seeds", &"sun_rate": "heat",
}
## Attribute id -> its own icon, where an attribute should not share its effect's icon.
const ID_ICONS: Dictionary = {&"rp_rest": "rest", &"rp_lore": "lore", &"rp_fortune": "fortune"}
## Card labels for names too long for a card (12 characters at 6 px). The full name stays on the detail page.
const SHORT: Dictionary = {"Rebirth Points": "Rebirth Pts", "Rebirths Done": "Rebirths", "Clover Leaves": "Clover", "Heather Sprigs": "Heather", "Foxglove Bells": "Foxglove", "Starbloom Petals": "Starbloom"}
const MAX_LABEL: int = 12

const ATTR_TIPS: Dictionary = {
	&"walk_speed": "How fast the walker moves between pads.",
	&"press_rate": "How often a pad pays while you stand on it.",
	&"crit_chance": "Chance that a press is a critical hit and pays extra.",
	&"luck": "Better odds that a press drops a relic.",
	&"offline_hours": "Hours of income you collect while the game is closed.",
	&"crit_damage": "How much extra a critical hit pays.",
	&"mastery_xp": "Pads earn Mastery XP faster, so they level sooner.",
	&"pad_yield": "Every press pays more, on every pad.",
	&"head_start": "Each run after a Bloom starts with extra Sunlight, so the first pads come sooner.",
	&"sun_rate": "Sunlight trickles in faster all the time.",
}


## The stats the index lists, in order: the current zone's ladder first, then the rest, then Prestige and Rebirth Points.
static func listed_stats(sim: Sim) -> Array[StringName]:
	var ids: Array[StringName] = []
	var defs: Array = sim.stat_defs.values()
	defs.sort_custom(func(a: StatDef, b: StatDef) -> bool: return a.tier < b.tier if a.tier != b.tier else String(a.id) < String(b.id))
	var currencies: Array[StringName] = []   # zone reset currencies are listed last, with Prestige and Rebirth Points
	for rd: ZoneResetDef in sim.resets_ordered():
		currencies.append(rd.currency)
	for pass_in_zone: bool in [true, false]:
		for d: StatDef in defs:
			if d.id in [&"prestige", &"rp"] or d.id in currencies or d.id in ids:
				continue
			if d.in_zone(sim.zone_id) == pass_in_zone:
				ids.append(d.id)
	ids.append_array(currencies)
	ids.append(&"prestige")
	ids.append(&"rp")
	return ids


## Every stat the player can see, grouped. Empty groups are left out.
static func stats(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for sid: StringName in listed_stats(sim):
		var def: StatDef = sim.stat_defs.get(sid) as StatDef
		if def == null:
			continue
		if not def.in_zone(sim.zone_id) and sim.get_stat(sid).is_zero():
			continue
		if sim.reset_for_currency(sid) != null and not UpgradeText.group_shown(sim, sid):
			continue
		if sid in [&"prestige", &"rp"] and not sim.rebirth_here() and sim.get_stat(sid).is_zero():
			continue   # the meadow runs on Bloom; Prestige and Rebirth Points come back in Zone 2
		var inc: BigNum = sim.income_per_second(sid)
		var note: String = "+%s/s" % inc.format() if not inc.is_zero() else ""
		var value: String = sim.get_stat(sid).format()
		if sid == &"rp":   # RP is paid in whole points, so never show a fraction
			value = BigNum.from_float(floorf(sim.get_stat(sid).to_float() + 0.0001)).format()
		if sid == &"prestige":
			note = "%s income" % NumberFormat.mult(sim.prestige_mult())
		elif sid == &"rp" and sim.can_rebirth():
			note = "+%d next rebirth" % sim.rp_gain_preview()
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
			tip += "\nNext level: %s\nCost: %s %s" % [effect_text(a, float(lv + 1) * a.per_level), sim.attribute_cost(aid).format(), UpgradeText.currency_name(a)]
		var perk: bool = a.currency == &"rp"
		var zr: ZoneResetDef = sim.reset_for_currency(a.currency)
		var group_name: String = "Rebirth Perks" if perk else (zr.menu_title if zr != null else "Attributes")
		var r: Dictionary = _row(aid, group_name, a.display_name, String(ID_ICONS.get(aid, ATTR_ICONS.get(a.effect, "prestige"))), "Lv %d/%d" % [lv, a.cap], now, tip)
		r["level"] = lv
		r["cap"] = a.cap
		r["maxed"] = lv >= a.cap
		r["color_id"] = &"rp" if perk else (a.currency if zr != null else a.effect)   # StatStyle colour: perks wear their currency's colour
		r["group_color_id"] = &"rp" if perk else (a.currency if zr != null else &"")
		rows.append(r)
	return rows


## The presses total as display text.
static func stats_value_presses(sim: Sim) -> String:
	return BigNum.from_float(float(sim.press_count)).format()


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
		&"head_start": return "+%s starting Sunlight" % _trim(amount)
		&"sun_rate": return "+%s%% Sunlight income" % _trim(amount * 100.0)
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
	var nm: String = title_case(label)
	var short: String = String(SHORT.get(nm, nm))
	return {"id": id, "group": group, "name": nm, "short": short, "icon": icon, "value": value, "note": note, "tip": tip, "pending": false, "maxed": false, "color_id": id}


## "Crit chance" -> "Crit Chance": every word capitalised, the rest left as written.
static func title_case(s: String) -> String:
	var words: PackedStringArray = s.split(" ")
	for i in words.size():
		if words[i] != "":
			words[i] = words[i].left(1).to_upper() + words[i].substr(1)
	return " ".join(words)


static func _pending(id: StringName, group: String, label: String, icon: String, tip: String) -> Dictionary:
	var r: Dictionary = _row(id, group, label, icon, "Soon", "", tip)
	r["pending"] = true
	return r
