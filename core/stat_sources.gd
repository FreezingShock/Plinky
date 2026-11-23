class_name StatSources
extends RefCounted
## Where a stat comes from. `of(sim, id)` returns rows {source, amount, how_to, kind}:
##   source  what contributes ("Press rate attribute", "Pad mastery", "Equipped relics")
##   amount  its contribution as display text ("+80%", "x1.40", "Lv 3")
##   how_to  one line on how to get more from it
##   kind    which kind of thing it is: base, attribute, relic, mastery, prestige, zone, action, total
## `id` is a stat id from StatIndex (cash, crit_chance, ...), or an attribute id when `is_attribute` is true (attribute
## ids such as crit_chance and luck match stat ids, so the caller says which one it means). Unknown ids give an empty list.
## Pure data, no nodes. Sim.stat_sources forwards here.


static func of(sim: Sim, id: StringName, is_attribute: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if is_attribute:
		if not sim.attribute_defs.has(id):
			return rows
		return _attribute(sim, sim.attribute_defs[id] as AttributeDef)
	match id:
		&"cash": _cash(sim, rows)
		&"mult": _mult(sim, rows)
		&"reb": _reb(sim, rows)
		&"slag": _pads_paying(sim, &"slag", rows)
		&"prestige": _prestige(sim, rows)
		&"rp":
			rows.append(_r("Next rebirth", "+%d" % sim.rp_for_rebirth(sim.rebirth_count), "Each rebirth pays a little more than the last.", "action"))
			rows.append(_r("To spend", sim.rp_available().format(), "Spend it on Rebirth perks in Upgrades.", "total"))
		&"crit_chance":
			_attr_row(sim, &"crit_chance", "Crit chance attribute", rows)
			rows.append(_r("Pad mastery", "+%s%% on your best pad" % StatIndex._trim(_best(sim, true) * 100.0), "Press a pad often to raise its mastery. Each level adds crit chance on that pad.", "mastery"))
		&"crit_damage":
			rows.append(_r("Base crit", "x%.2f" % sim.config.crit_multiplier, "Every critical press starts here.", "base"))
			rows.append(_r("Pad mastery", "+%.2f on your best pad" % _best(sim, false), "Pad mastery levels add crit damage on that pad.", "mastery"))
			rows.append(_r("Equipped relics", "x%.2f" % _relic(sim, RelicDef.Effect.CRIT_DAMAGE), "Equip a relic that boosts crit damage.", "relic"))
		&"press_rate":
			var z: ZoneDef = sim.current_zone()
			rows.append(_r("This zone", "%.2f/s" % (z.press_rate if z != null else 1.0), "Each zone sets its own base press rate.", "zone"))
			_attr_row(sim, &"press_rate", "Press rate attribute", rows)
			rows.append(_r("Equipped relics", "x%.2f" % _relic(sim, RelicDef.Effect.PRESS_RATE), "Equip a relic that boosts press rate.", "relic"))
		&"luck":
			_attr_row(sim, &"luck", "Luck attribute", rows)
		&"walk_speed":
			rows.append(_r("Base", "x1.00", "The walker's normal pace.", "base"))
			_attr_row(sim, &"walk_speed", "Walk speed attribute", rows)
		&"offline_cap":
			rows.append(_r("Base", "%s h" % StatIndex._trim(sim.config.offline_base_cap_hours), "Everyone starts with this much offline time.", "base"))
			_attr_row(sim, &"offline_hours", "Offline attribute", rows)
		&"mastery":
			for zid: StringName in sim.zone_defs:
				var m: Dictionary = sim.area_mastery(zid)
				if int(m.get("pads", 0)) > 0:
					rows.append(_r((sim.zone_defs[zid] as ZoneDef).display_name, "Lv %d/%d" % [int(m["level_sum"]), int(m["level_cap"])], "Press the pads in this zone to level them.", "zone"))
		&"presses":
			rows.append(_r("Your presses", StatIndex.stats_value_presses(sim), "Stand on a pad, or click it, to press.", "total"))
		&"rebirths_done":
			rows.append(_r("Rebirths", str(sim.rebirth_count), "Rebirth from the bottom bar once the gate allows it.", "action"))
		&"relic_drops":
			rows.append(_r("Press drops", str(sim.relic_drops), "Pads sometimes drop a relic. Luck makes it likelier.", "total"))
		&"play_time":
			rows.append(_r("This save", StatIndex.clock_text(sim.play_seconds), "Time passes while you play.", "total"))
	return rows


# ---------------------------------------------------------------- stats

static func _cash(sim: Sim, rows: Array[Dictionary]) -> void:
	var z: ZoneDef = sim.current_zone()
	rows.append(_r("This zone", "%s/s" % BigNum.from_float(z.base_cash_per_second if z != null else 0.0).format(), "Each zone pays its own base income.", "zone"))
	rows.append(_r("Multiplier", "x%s" % sim.get_stat(&"mult").add(BigNum.one()).format(), "Press the Multiplier pads.", "base"))
	rows.append(_r("Prestige", "x%s" % sim.prestige_mult().format(), "Rebirth to earn Prestige.", "prestige"))
	rows.append(_r("Equipped relics", "x%.2f" % _relic(sim, RelicDef.Effect.CASH_MULT), "Equip a relic that boosts cash.", "relic"))
	rows.append(_r("Momentum", "x%.2f" % (1.0 + sim.momentum_bonus()), "Keep walking to fill the momentum meter.", "action"))
	_pads_paying(sim, &"cash", rows)


static func _mult(sim: Sim, rows: Array[Dictionary]) -> void:
	_pads_paying(sim, &"mult", rows)
	rows.append(_r("Rebirths", "x%s" % sim.get_stat(&"reb").add(BigNum.one()).format(), "Each rebirth makes Multiplier presses pay more.", "action"))
	rows.append(_r("Equipped relics", "x%.2f" % _relic(sim, RelicDef.Effect.MULT_GAIN), "Equip a relic that boosts Multiplier gain.", "relic"))


static func _reb(sim: Sim, rows: Array[Dictionary]) -> void:
	_pads_paying(sim, &"reb", rows)


static func _prestige(sim: Sim, rows: Array[Dictionary]) -> void:
	rows.append(_r("Next rebirth", "+%s" % sim.prestige_gain_preview().format(), "Rebirth when the gate is ready.", "action"))
	rows.append(_r("To spend", sim.prestige_available().format(), "Spend it on Attributes in Upgrades.", "total"))
	rows.append(_r("Income bonus", "x%s" % sim.prestige_mult().format(), "More Prestige multiplies all income.", "prestige"))


static func _pads_paying(sim: Sim, reward: StringName, rows: Array[Dictionary]) -> void:
	var n: int = 0
	for b: ButtonDef in sim.button_defs.values():
		if b.reward_stat == reward:
			n += 1
	if n > 0:
		rows.append(_r("Pads that pay it", str(n), "Walk to a pad and stand on it. Higher mastery pays more.", "zone"))


# ---------------------------------------------------------------- attributes

static func _attribute(sim: Sim, a: AttributeDef) -> Array[Dictionary]:
	var lv: int = sim.attr_level(a.id)
	var rows: Array[Dictionary] = []
	rows.append(_r("Levels bought", "Lv %d/%d" % [lv, a.cap], "Spend %s in Upgrades." % UpgradeText.currency_name(a), "attribute"))
	rows.append(_r("Current bonus", StatIndex.effect_text(a, float(lv) * a.per_level), "Each level adds " + StatIndex.effect_text(a, a.per_level) + ".", "attribute"))
	if lv < a.cap:
		rows.append(_r("Next level", sim.attribute_cost(a.id).format() + " " + UpgradeText.currency_name(a), "Earn it by rebirthing.", "prestige"))
	return rows


static func _attr_row(sim: Sim, effect: StringName, label: String, rows: Array[Dictionary]) -> void:
	var total: float = sim.effect_total(effect)
	for a: AttributeDef in sim.attribute_defs.values():
		if a.effect == effect:
			rows.append(_r(label, StatIndex.effect_text(a, total), "Spend %s in Upgrades (%d/%d)." % [UpgradeText.currency_name(a), sim.attr_level(a.id), a.cap], "attribute"))
			return


# ---------------------------------------------------------------- helpers

static func _relic(sim: Sim, e: RelicDef.Effect) -> float:
	return sim.relics.multiplier(e) if sim.relics != null else 1.0


## Best single-pad mastery bonus: crit chance (true) or crit damage (false).
static func _best(sim: Sim, chance: bool) -> float:
	var best: float = 0.0
	for bid: StringName in sim.button_defs:
		best = maxf(best, sim.mastery.crit_chance_bonus(bid) if chance else sim.mastery.crit_damage_bonus(bid))
	return best


static func _r(source: String, amount: String, how_to: String, kind: String) -> Dictionary:
	return {"source": source, "amount": amount, "how_to": how_to, "kind": kind}
