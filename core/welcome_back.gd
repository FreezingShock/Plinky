class_name WelcomeBack
extends RefCounted
## The Welcome Back card as data. The offline report (the gains the caller passes in, plus Sim.last_offline) is sorted
## into four sections of tiles, and every number is worked out here so the card only lays things out. Pure: no nodes and
## no colours. The card maps a rarity id to its tint with rarity_def(). Amounts stay BigNum; text goes through NumberFormat.
##
## A tile is a Dictionary:
##   kind         &"gain", &"spent", &"tend" or &"found"
##   id           stat id (gain, spent), tier id (tend) or relic id (found)
##   icon         the IconSet name to draw: a stat id, or a relic id
##   name         title for the tooltip
##   rarity       a content/rarities id: the tier's rarity, or the relic's. Currency with no tier is &"common"
##   rarity_name  its display name, for the tooltip tag
##   amount       BigNum to count up to, or null for tiles that show a count
##   prefix       "+" (gain), "-" (spent) or "" (count tiles); the card puts it in front of the counting number
##   text         the amount as it reads once counted up, e.g. "+858.1T", "-120K", "x25" or "x2" ("" for one find)
##   count        presses (tend) or times found (found); 0 for gain and spent
##   level        mastery level now (tend only)
##   levels       mastery levels gained on this return (tend only)
##   lines        tooltip prose, one String per line

const SECTION_ORDER: Array[StringName] = [&"earned", &"spent", &"tend", &"found"]
const SECTION_TITLES: Dictionary = {&"earned": "Earned", &"spent": "Spent Tending", &"tend": "Pads Tended", &"found": "Found"}
const COMMON: StringName = &"common"
## Away time within this many seconds of the cap counts as "the most you can bank".
const CAP_SLACK: float = 1.0

static var _rarities: Dictionary = {}   # rarity id -> RarityDef, loaded once


## The rarity resource for a content/rarities id, or null when there is none.
static func rarity_def(id: StringName) -> RarityDef:
	if not _rarities.has(id):
		var path: String = "res://content/rarities/%s.tres" % String(id)
		_rarities[id] = load(path) as RarityDef if ResourceLoader.exists(path) else null
	return _rarities[id] as RarityDef


## "You were away 8 min." Whole minutes, hours once there are any.
static func away_text(seconds: float) -> String:
	var mins: int = int(seconds / 60.0)
	if mins < 60:
		return "You were away %d min." % mins
	var hrs: int = floori(mins / 60.0)
	if hrs < 48:
		return "You were away %d h %d min." % [hrs, mins % 60]
	return "You were away %d days %d h." % [floori(hrs / 24.0), hrs % 24]


## Returns {away, away_text, capped, sections: [{id, title, tiles}], tiles, best_rarity}. Empty sections are left out.
## best_rarity is the highest-ranked relic rarity found (&"" when nothing was found), so the card can pick its sound.
static func build(sim: Sim, seconds: float, gains: Dictionary) -> Dictionary:
	var by_section: Dictionary = {}
	for sid: StringName in SECTION_ORDER:
		by_section[sid] = []
	var tier_of_stat: Dictionary = {}   # stat id -> the first TierDef that pays it
	for tv: Variant in sim.tier_defs.values():
		var td: TierDef = tv as TierDef
		if td != null and not tier_of_stat.has(td.stat):
			tier_of_stat[td.stat] = td
	var best: StringName = &""
	var best_rank: int = -1

	# Earned: the income gained while away, in ladder order.
	var gain_ids: Array = gains.keys()
	gain_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return _stat_tier(sim, a) < _stat_tier(sim, b))
	for sid_v: Variant in gain_ids:
		var sid: StringName = sid_v as StringName
		var g: BigNum = gains[sid] as BigNum
		if g == null or g.is_zero():
			continue
		var td_g: TierDef = tier_of_stat.get(sid) as TierDef
		var rarity: StringName = td_g.rarity if td_g != null else COMMON
		var lines: Array = ["Exact: %s" % NumberFormat.exact(g)]
		var rate: BigNum = sim.income_per_second(sid)
		if not rate.is_zero():
			lines.append("Earns %s/s while awake." % NumberFormat.format(rate))
		lines.append("Away time pays %d%% of the awake rate." % roundi(sim.offline_fraction() * 100.0))
		(by_section[&"earned"] as Array).append(_tile(&"gain", sid, _stat_name(sim, sid), rarity, g, "+%s" % NumberFormat.format(g), "+", 0, 0, 0, lines))

	# Spent tending: what the tended pads cost, paid out of the income above.
	var spent: Dictionary = sim.last_offline.get("spent", {})
	for sid_s: Variant in spent:
		var sp: StringName = sid_s as StringName
		var paid: BigNum = spent[sp] as BigNum
		if paid == null or paid.is_zero():
			continue
		var td_s: TierDef = tier_of_stat.get(sp) as TierDef
		var lines_s: Array = ["Exact: %s" % NumberFormat.exact(paid), "Spent on tending pads while you were away."]
		(by_section[&"spent"] as Array).append(_tile(&"spent", sp, _stat_name(sim, sp), td_s.rarity if td_s != null else COMMON,
			paid, "-%s" % NumberFormat.format(paid), "-", 0, 0, 0, lines_s))

	# Pads tended: one tile per flower row, with its presses and any mastery it gained.
	var tend: Dictionary = sim.last_offline.get("tend", {})
	for tid_v: Variant in tend:
		var tid: StringName = tid_v as StringName
		var r: Dictionary = tend[tid]
		var td_t: TierDef = sim.tier_defs.get(tid) as TierDef
		var presses: int = int(r["presses"])
		var levels: int = int(r["levels"])
		var level: int = int(r["level"])
		var lines_t: Array = ["Pressed %d times while you were away." % presses]
		if levels > 0:
			lines_t.append("Mastery +%d, now Level %d." % [levels, level])
		else:
			lines_t.append("Mastery Level %d." % level)
		var icon: StringName = td_t.stat if td_t != null else tid
		var name_t: String = td_t.display_name if td_t != null else String(tid)
		(by_section[&"tend"] as Array).append(_tile(&"tend", tid, name_t, td_t.rarity if td_t != null else COMMON,
			null, "x%d" % presses, "", presses, level, levels, lines_t, icon))

	# Found: relics, one tile each with its count, in the order they dropped.
	var counts: Dictionary = {}
	for rid_v: Variant in sim.last_offline.get("relics", []):
		var rid: StringName = rid_v as StringName
		counts[rid] = int(counts.get(rid, 0)) + 1
	for rid_k: Variant in counts:
		var rid_f: StringName = rid_k as StringName
		var rd: RelicDef = sim.relics.defs.get(rid_f) as RelicDef
		if rd == null or rd.rarity == null:
			continue
		var n: int = int(counts[rid_f])
		var lines_f: Array = []
		if rd.description != "":
			lines_f.append(rd.description)
		lines_f.append("Found %d while you were away." % n if n > 1 else "Found while you were away.")
		var tile_f: Dictionary = _tile(&"found", rid_f, rd.display_name, rd.rarity.id, null, "x%d" % n if n > 1 else "", "", n, 0, 0, lines_f, rid_f)
		(by_section[&"found"] as Array).append(tile_f)
		if rd.rarity.rank > best_rank:
			best_rank = rd.rarity.rank
			best = rd.rarity.id

	var sections: Array = []
	var total: int = 0
	for sec: StringName in SECTION_ORDER:
		var tiles: Array = by_section[sec]
		if tiles.is_empty():
			continue
		sections.append({"id": sec, "title": SECTION_TITLES[sec], "tiles": tiles})
		total += tiles.size()
	return {
		"away": seconds, "away_text": away_text(seconds),
		"capped": seconds >= sim.offline_cap_seconds() - CAP_SLACK,
		"sections": sections, "tiles": total, "best_rarity": best,
	}


static func _tile(kind: StringName, id: StringName, name: String, rarity: StringName, amount: BigNum, text: String,
		prefix: String, count: int, level: int, levels: int, lines: Array, icon: StringName = &"") -> Dictionary:
	return {
		"kind": kind, "id": id, "icon": String(icon if icon != &"" else id), "name": name,
		"rarity": rarity, "rarity_name": _rarity_name(rarity), "amount": amount, "prefix": prefix, "text": text,
		"count": count, "level": level, "levels": levels, "lines": lines,
	}


static func _stat_tier(sim: Sim, sid: Variant) -> int:
	var sd: StatDef = sim.stat_defs.get(sid) as StatDef
	return sd.tier if sd != null else 0


static func _stat_name(sim: Sim, sid: StringName) -> String:
	var sd: StatDef = sim.stat_defs.get(sid) as StatDef
	return sd.display_name if sd != null else String(sid)


static func _rarity_name(id: StringName) -> String:
	var rd: RarityDef = rarity_def(id)
	return rd.display_name if rd != null else String(id).capitalize()
