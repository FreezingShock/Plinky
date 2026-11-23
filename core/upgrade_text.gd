class_name UpgradeText
extends RefCounted
## Pure text and state for the Upgrades menu: what an upgrade gives now, what the next level gives, what it costs and
## whether it is unlocked. No nodes, so tests check it headless. Takes a Sim, never touches the scene.

const UNITS: Dictionary = {
	&"walk_speed": "walk speed", &"press_rate": "press rate", &"crit_chance": "crit chance", &"luck": "luck",
	&"offline_hours": "offline cap", &"crit_damage": "crit damage", &"mastery_xp": "pad XP", &"pad_yield": "pad yield",
	&"head_start": "starting Sunlight", &"sun_rate": "Sunlight income",
}


## Bonus an upgrade gives at `level`, in its own units (a fraction, or hours for the offline cap).
static func amount_at(a: AttributeDef, level: int) -> float:
	return float(level) * a.per_level


## "+120%" or "+5 h". Same string the tooltip and the stats index use for the number.
static func value(a: AttributeDef, amount: float) -> String:
	if a.effect == &"offline_hours":
		return "+%s h" % _trim(amount)
	if a.effect == &"head_start":
		return "+%s" % _trim(amount)
	return "+%s%%" % _trim(amount * 100.0)


## Name of the stat an upgrade is paid in.
const CURRENCY_NAMES: Dictionary = {&"prestige": "Prestige", &"rp": "Rebirth Points", &"seeds": "Seeds"}
## Menu order of the upgrade groups, and the heading each group wears (Prestige upgrades have none).
const CURRENCY_RANK: Dictionary = {&"prestige": 0, &"rp": 1, &"seeds": 2}
const GROUP_HEADS: Dictionary = {&"rp": "REBIRTH PERKS", &"seeds": "BLOOM GIFTS"}


## True when the group paid in `currency` shows here: Bloom gifts always, Prestige and Rebirth Point upgrades in the
## zones that run Rebirth (the meadow does not).
static func group_shown(sim: Sim, currency: StringName) -> bool:
	if currency == &"seeds":
		return sim.bloom_count > 0 or sim.bloom_unlocked() or not sim.get_stat(&"seeds").is_zero()
	if currency == &"rp":
		return sim.rebirth_here() and (sim.rebirth_count > 0 or not sim.rp_available().is_zero())
	return sim.rebirth_here()


static func currency_name(a: AttributeDef) -> String:
	return String(CURRENCY_NAMES.get(a.currency, "Prestige"))


static func unit(a: AttributeDef) -> String:
	return String(UNITS.get(a.effect, a.display_name.to_lower()))


static func lock_text(a: AttributeDef) -> String:
	return "Unlocks at %d Rebirths" % a.unlock_rebirths


## Upgrades in menu order: Prestige upgrades, then Rebirth Point perks. Each group: open from the start first, then by Rebirths needed.
static func ordered(sim: Sim) -> Array[AttributeDef]:
	var out: Array[AttributeDef] = []
	for a: AttributeDef in sim.attribute_defs.values():
		out.append(a)
	out.sort_custom(func(x: AttributeDef, y: AttributeDef) -> bool:
		if x.currency != y.currency:
			return int(CURRENCY_RANK.get(x.currency, 9)) < int(CURRENCY_RANK.get(y.currency, 9))
		if x.unlock_rebirths != y.unlock_rebirths:
			return x.unlock_rebirths < y.unlock_rebirths
		if x.order != y.order:
			return x.order < y.order
		return String(x.id) < String(y.id))
	return out


## Everything one row needs: {id, name, unit, level, cap, unlocked, maxed, now, next, cost_text, can_afford, lock, rebirths}.
## `now` and `next` are the value strings ("+120%"); `next` is empty at max level.
static func state(sim: Sim, a: AttributeDef) -> Dictionary:
	var lv: int = sim.attr_level(a.id)
	var maxed: bool = lv >= a.cap
	var cost: BigNum = sim.attribute_cost(a.id)
	return {
		"id": a.id, "name": a.display_name, "unit": unit(a), "level": lv, "cap": a.cap,
		"unlocked": sim.attr_unlocked(a.id), "maxed": maxed,
		"now": value(a, amount_at(a, lv)),
		"next": "" if maxed else value(a, amount_at(a, lv + 1)),
		"cost_text": cost.format(), "can_afford": not maxed and not sim.attribute_available(a).lt(cost),
		"currency": a.currency, "currency_name": currency_name(a),
		"lock": lock_text(a), "rebirths": sim.rebirth_count, "need": a.unlock_rebirths,
	}


## Tooltip for a row: what it does, the real totals, and why it can or can't be bought. Same dictionary shape as Tip.
static func tip(s: Dictionary, effect: StringName) -> Dictionary:
	var body: String = String(StatIndex.ATTR_TIPS.get(effect, "A permanent upgrade."))
	var hint: String
	if not bool(s["unlocked"]):
		hint = "%s. You have %d." % [s["lock"], s["rebirths"]]
	elif bool(s["maxed"]):
		hint = "Max level."
	elif bool(s["can_afford"]):
		hint = "Costs %s %s." % [s["cost_text"], s["currency_name"]]
	else:
		hint = "Need %s %s." % [s["cost_text"], s["currency_name"]]
	var title: String = "%s %d/%d" % [s["name"], s["level"], s["cap"]]
	if bool(s["unlocked"]) and not bool(s["maxed"]):
		body += "\nNow %s, next %s %s." % [s["now"], s["next"], s["unit"]]
	return {"title": title, "body": body, "hint": hint}


## 3 -> "3", 2.5 -> "2.5".
static func _trim(f: float) -> String:
	var s: String = "%.1f" % f
	return s.trim_suffix(".0")
