class_name StatIndex
extends RefCounted
## Rows for the Stats and Attributes index, built from a Sim. Pure data: no nodes, so tests can check it headless.
## A row is {id, group, name, icon, value, note, tip, pending}. `icon` is a file name under assets/icons.
## Crit damage and pad mastery come from another thread: until the Sim has their API the rows stay as
## "pending" placeholders, then light up on their own (see CRIT_DAMAGE_API and MASTERY_API).

## Sim methods that may carry the new stats. The first one the Sim has is used.
const CRIT_DAMAGE_API: Array[StringName] = [&"crit_damage", &"crit_multiplier", &"crit_damage_mult"]
const MASTERY_API: Array[StringName] = [&"mastery_total_level", &"total_mastery_level", &"mastery_levels"]

const STAT_TIPS: Dictionary = {
	&"cash": "Earned every second and from presses. Spend it to unlock pads. Resets on rebirth.",
	&"mult": "Multiplies Cash income. Earned from presses, and boosted by Rebirths. Resets on rebirth.",
	&"reb": "Rebirths you have banked. Each one boosts how fast the Multiplier grows.",
	&"slag": "Quarry currency. Earned on the quarry pads.",
	&"prestige": "Earned by rebirthing. Boosts all income and buys Attributes.",
}
const ATTR_ICONS: Dictionary = {
	&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck",
	&"offline_hours": "offline", &"crit_damage": "crit_dmg",
}
const ATTR_TIPS: Dictionary = {
	&"walk_speed": "How fast the walker moves between pads.",
	&"press_rate": "How often a pad pays while you stand on it.",
	&"crit_chance": "Chance that a press is a critical hit and pays extra.",
	&"luck": "Better odds that a press drops a relic.",
	&"offline_hours": "Hours of income you collect while the game is closed.",
	&"crit_damage": "How much extra a critical hit pays.",
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
	var cd: Variant = _call_first(sim, CRIT_DAMAGE_API)
	if cd == null:
		rows.append(_pending(&"crit_damage", "Presses", "Crit damage", "crit_dmg", "Arrives with the crit update."))
	else:
		rows.append(_row(&"crit_damage", "Presses", "Crit damage", "crit_dmg", "x%.2f" % float(cd), "", "How much a critical hit pays, as a multiple of a normal press."))
	rows.append(_row(&"press_rate", "Presses", "Press rate", "rate", "%.2f/s" % (1.0 / maxf(sim.press_interval(), 0.001)), "",
		"Presses per second while you stand on a pad."))
	rows.append(_row(&"luck", "Presses", "Luck", "luck", "Lv %d" % sim.luck_level(), "", "Each level improves the chance of a relic drop."))
	rows.append(_row(&"walk_speed", "Travel", "Walk speed", "walk", "x%.2f" % sim.walk_speed_mult(), "", "How fast the walker moves."))
	rows.append(_row(&"offline_cap", "Travel", "Offline cap", "offline", "%s h" % _trim(sim.offline_cap_seconds() / 3600.0), "",
		"The most income you can collect while the game is closed."))
	var m: Variant = _call_first(sim, MASTERY_API)
	if m == null:
		rows.append(_pending(&"mastery", "Mastery", "Pad mastery", "mastery", "Pads gain levels as you press them. Arrives with the mastery update."))
	else:
		rows.append(_row(&"mastery", "Mastery", "Pad mastery", "mastery", "Lv %d" % _mastery_total(m), "", "Total mastery level across all pads."))
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
	var has_crit_dmg: bool = false
	for aid: StringName in ids:
		var a: AttributeDef = sim.attribute_defs[aid]
		has_crit_dmg = has_crit_dmg or a.effect == &"crit_damage"
		var lv: int = sim.attr_level(aid)
		var now: String = effect_text(a, float(lv) * a.per_level)
		var tip: String = String(ATTR_TIPS.get(a.effect, "A permanent upgrade."))
		if lv >= a.cap:
			tip += "\nMaxed out."
		else:
			tip += "\nNext level: %s\nCost: %s Prestige" % [effect_text(a, float(lv + 1) * a.per_level), sim.attribute_cost(aid).format()]
		var r: Dictionary = _row(aid, "Attributes", a.display_name, String(ATTR_ICONS.get(a.effect, "prestige")), "Lv %d/%d" % [lv, a.cap], now, tip)
		r["level"] = lv
		r["cap"] = a.cap
		rows.append(r)
	if not has_crit_dmg:
		rows.append(_pending(&"crit_damage", "Attributes", "Crit damage", "crit_dmg", "Arrives with the crit update."))
	return rows


static func effect_text(a: AttributeDef, amount: float) -> String:
	match a.effect:
		&"walk_speed": return "+%s%% walk speed" % _trim(amount * 100.0)
		&"press_rate": return "+%s%% press rate" % _trim(amount * 100.0)
		&"crit_chance": return "%s%% crit chance" % _trim(amount * 100.0)
		&"crit_damage": return "+%s%% crit damage" % _trim(amount * 100.0)
		&"luck": return "+%s%% luck" % _trim(amount * 100.0)
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


static func _call_first(sim: Sim, names: Array[StringName]) -> Variant:
	for n: StringName in names:
		if sim.has_method(n):
			return sim.call(n)
	return null


static func _mastery_total(v: Variant) -> int:
	if v is Dictionary:
		var n: int = 0
		for x: Variant in (v as Dictionary).values():
			n += int(x)
		return n
	return int(v)
