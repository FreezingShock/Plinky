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
	match a.value_kind:
		&"flat", &"count":
			return "+%s" % _trim(amount)
		&"rate":
			return "+%s/s" % _trim(amount)
	if a.effect == &"offline_hours":
		return "+%s h" % _trim(amount)
	if a.effect == &"head_start":
		return "+%s" % _trim(amount)
	return "+%s%%" % _trim(amount * 100.0)


## Name of the stat an upgrade is paid in (Prestige and Rebirth Points; a zone reset's currency is named by its stat).
const CURRENCY_NAMES: Dictionary = {&"prestige": "Prestige", &"rp": "Rebirth Points"}
const RP_HEAD: String = "REBIRTH PERKS"


## Menu order of the upgrade groups: Prestige, Rebirth Points, then each zone reset's gifts in the reset's own order.
static func rank(sim: Sim, currency: StringName) -> int:
	if currency == &"prestige":
		return 0
	if currency == &"rp":
		return 1
	var r: ZoneResetDef = sim.reset_for_currency(currency)
	return 2 + (r.order if r != null else 99)


## The small heading above a group (Prestige upgrades have none).
static func group_head(sim: Sim, currency: StringName) -> String:
	if currency == &"rp":
		return RP_HEAD
	var r: ZoneResetDef = sim.reset_for_currency(currency)
	return r.menu_title.to_upper() if r != null and r.menu_title != "" else String(currency).to_upper()


## One tab per zone reset's gift group, in reset order. Prestige and Rebirth Perks are no longer tabs (removed with the
## Rebirth ladder, #209), so their upgrades have no page unless a reset pays in that currency.
static func tab_currencies(sim: Sim) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: ZoneResetDef in sim.resets_ordered():
		out.append(r.currency)
	return out


## Every currency the Upgrades header and menu know, in menu order.
static func currencies(sim: Sim) -> Array[StringName]:
	var out: Array[StringName] = [&"prestige", &"rp"]
	for r: ZoneResetDef in sim.resets_ordered():
		out.append(r.currency)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return rank(sim, a) < rank(sim, b))
	return out


## True when the group paid in `currency` shows here: a zone reset's gifts once it is open, used or paid, Prestige and
## Rebirth Point upgrades in the zones that run Rebirth.
static func group_shown(sim: Sim, currency: StringName) -> bool:
	var r: ZoneResetDef = sim.reset_for_currency(currency)
	if r != null:
		if r != sim.reset_for_zone():
			return false   # only the zone you are in shows its own gifts
		return sim.reset_count(r.id) > 0 or sim.reset_unlocked(r.id) or not sim.get_stat(currency).is_zero()
	if currency == &"rp":
		return sim.rebirth_here() and (sim.rebirth_count > 0 or not sim.rp_available().is_zero())
	return sim.rebirth_here()


static func currency_name(a: AttributeDef) -> String:
	return String(CURRENCY_NAMES.get(a.currency, String(a.currency).capitalize()))


static func unit(a: AttributeDef) -> String:
	if a.unit_text != "":
		return a.unit_text
	return String(UNITS.get(a.effect, a.display_name.to_lower()))


static func lock_text(a: AttributeDef, sim: Sim = null) -> String:
	if a.unlock_resets > 0:
		var r: ZoneResetDef = sim.reset_for_currency(a.currency) if sim != null else null
		if r == null:
			return "Unlocks after %d resets" % a.unlock_resets
		return "Unlocks after %d %s %s" % [a.unlock_resets, r.display_name, "reset" if a.unlock_resets == 1 else "resets"]
	return "Unlocks at %d Rebirths" % a.unlock_rebirths


## Upgrades in menu order: Prestige upgrades, then Rebirth Point perks. Each group: open from the start first, then by Rebirths needed.
static func ordered(sim: Sim) -> Array[AttributeDef]:
	var out: Array[AttributeDef] = []
	for a: AttributeDef in sim.attribute_defs.values():
		out.append(a)
	out.sort_custom(func(x: AttributeDef, y: AttributeDef) -> bool:
		if x.currency != y.currency:
			return rank(sim, x.currency) < rank(sim, y.currency)
		if x.unlock_rebirths != y.unlock_rebirths:
			return x.unlock_rebirths < y.unlock_rebirths
		if x.unlock_resets != y.unlock_resets:
			return x.unlock_resets < y.unlock_resets
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
		"currency": a.currency, "currency_name": currency_name(a), "blurb": a.blurb,
		"lock": lock_text(a, sim), "rebirths": _have_for_lock(sim, a), "need": a.unlock_rebirths,
	}


static func _have_for_lock(sim: Sim, a: AttributeDef) -> int:
	if a.unlock_resets > 0:
		var r: ZoneResetDef = sim.reset_for_currency(a.currency)
		return sim.reset_count(r.id) if r != null else 0
	return sim.rebirth_count


## Tooltip for a row: what it does, the real totals, and why it can or can't be bought. Same dictionary shape as Tip.
static func tip(s: Dictionary, effect: StringName) -> Dictionary:
	var body: String = String(s["blurb"]) if String(s.get("blurb", "")) != "" else String(StatIndex.ATTR_TIPS.get(effect, "A permanent upgrade."))
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


## The tab name of a currency's group in the Upgrades gallery: Prestige, Rebirth Perks, or the zone reset's own menu title.
static func tab_name(sim: Sim, currency: StringName) -> String:
	if currency == &"prestige":
		return "Prestige"
	if currency == &"rp":
		return "Rebirth Perks"
	var r: ZoneResetDef = sim.reset_for_currency(currency)
	if r == null:
		return String(currency).capitalize()
	return r.menu_title if r.menu_title != "" else r.display_name


## Two upgrades share a tier when their unlock gates match. `ordered()` sorts by these gates, so tiers come out in order.
static func tier_key(a: AttributeDef) -> String:
	return "%d/%d" % [a.unlock_rebirths, a.unlock_resets]


## The heading over a tier of the Upgrades gallery: "Open" for the start, else the gate in Title Case.
static func tier_head(sim: Sim, a: AttributeDef) -> String:
	if a.unlock_resets > 0:
		var r: ZoneResetDef = sim.reset_for_currency(a.currency)
		var nm: String = r.display_name if r != null else "Reset"
		return "Unlocks After %d %s" % [a.unlock_resets, nm if a.unlock_resets == 1 else nm + "s"]
	if a.unlock_rebirths > 0:
		return "Unlocks At %d %s" % [a.unlock_rebirths, "Rebirth" if a.unlock_rebirths == 1 else "Rebirths"]
	return "Open"


## 3 -> "3", 2.5 -> "2.5".
static func _trim(f: float) -> String:
	var s: String = "%.1f" % f
	return s.trim_suffix(".0")
