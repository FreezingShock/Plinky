class_name TipText
extends RefCounted
## Words and layout for the tooltips on existing UI, in one place so they stay consistent. Specs for Tip.bind.
## Colour rules (docs/tooltips.md): stat names in their stat colour (StatStyle), numbers green when they are a
## gain or affordable and red when not, rarity in its rarity colour. No balance numbers: live values come from the caller.

const STATS: Dictionary = {
	&"sunlight": {"body": "What the first pads cost. It trickles in by itself.", "hint": "Dewdrops make it flow faster."},
	&"dewdrop": {"body": "Boosts how fast Sunlight flows.", "hint": "Press the Sprout pads. Clover Leaves make each press pay more."},
	&"clover": {"body": "Makes every Dewdrop press pay more, and opens the gate to Larkmoor.", "hint": "Press the Clover pads."},
	&"thistle": {"body": "Boosts how fast Sunlight flows, on a bigger scale than Dewdrops.", "hint": "Press the Thistle pads. Heather Sprigs make each press pay more."},
	&"heather": {"body": "Makes every Thistle Down press pay more. Foxglove pads cost it.", "hint": "Press the Heather pads."},
	&"foxglove": {"body": "Makes every Heather Sprig press pay more. Starbloom pads cost it.", "hint": "Press the Foxglove pads."},
	&"starbloom": {"body": "Makes every Foxglove Bell press pay more, and opens the far gate.", "hint": "Press the Starbloom pads."},
	&"cash": {"body": "What pads cost and pay. Walk and press pads to earn it.", "hint": "Resets when you rebirth."},
	&"mult": {"body": "Boosts your Cash income and press rewards.", "hint": "Grows from pads. Rebirths make it grow faster."},
	&"reb": {"body": "Times you have started over. Each one speeds up Multiplier gain.", "hint": "Use the Rebirth button once you can afford it."},
	&"slag": {"body": "Quarry currency, made by the pads there.", "hint": "Spend it on quarry pads."},
	&"rp": {"body": "Earned on every rebirth. Spend it on Rebirth perks.", "hint": "Open Upgrades to spend it."},
	&"prestige": {"body": "Earned by rebirthing. Spend it on permanent upgrades.", "hint": "Open Upgrades to spend it."},
}

const ATTR_ICONS: Dictionary = {
	&"walk_speed": "walk", &"press_rate": "rate", &"crit_chance": "crit", &"luck": "luck",
	&"offline_hours": "offline", &"crit_damage": "crit_dmg", &"head_start": "seeds", &"sun_rate": "heat",
}
const ATTRS: Dictionary = {
	&"walk_speed": "Walk faster between pads.",
	&"press_rate": "Hold-to-press repeats faster.",
	&"crit_chance": "A bigger chance for a press to crit.",
	&"crit_damage": "A critical hit pays more.",
	&"luck": "Better odds on relic drops.",
	&"offline_hours": "Earn for more hours while you are away.",
	&"head_start": "Every run after a Bloom starts with extra Sunlight.",
	&"sun_rate": "Sunlight flows in faster all the time.",
}


## Stat tooltip. `have` and `per_second` are optional live values (already formatted) for the HUD rows.
static func stat(sid: StringName, display_name: String, have: String = "", per_second: String = "") -> Dictionary:
	var base: Dictionary = STATS.get(sid, {"body": ""}) as Dictionary
	var c: Color = StatStyle.color(sid)
	var lines: Array = []
	if have != "":
		lines.append(["You have ", Tip.icon(String(sid)), Tip.seg(have, c)])
	if per_second != "":
		lines.append(["Income ", Tip.seg("+%s/s" % per_second, StatStyle.gain())])
	return {"title": display_name, "title_color": c, "color": c, "icon": String(sid),
		"body": base.get("body", ""), "lines": lines, "hint": base.get("hint", "")}


static func attribute(a: AttributeDef, level: int, cost_text: String, can_afford: bool) -> Dictionary:
	var c: Color = StatStyle.color(a.effect)
	var maxed: bool = level >= a.cap
	var lines: Array = [["Level ", Tip.seg("%d/%d" % [level, a.cap], c)]]
	lines.append(["Now ", Tip.seg(StatIndex.effect_text(a, float(level) * a.per_level), StatStyle.gain())])
	if not maxed:
		lines.append(["Next ", Tip.seg(StatIndex.effect_text(a, float(level + 1) * a.per_level), StatStyle.gain())])
		lines.append(["Costs ", Tip.icon(String(a.currency)), Tip.seg(cost_text, StatStyle.buy(can_afford)), " ", Tip.seg(UpgradeText.currency_name(a), StatStyle.color(a.currency))])
	return {"title": a.display_name, "title_color": c, "color": c, "icon": StatIndex.attr_icon(a),
		"body": a.blurb if a.blurb != "" else ATTRS.get(a.effect, ""), "lines": lines,
		"hint": "Max level." if maxed else ("Click Buy to upgrade." if can_afford else "Need more %s." % UpgradeText.currency_name(a)),
		"hint_color": StatStyle.gain() if (maxed or can_afford) else StatStyle.cant()}


static func rebirth(can: bool, gain_text: String, rp_text: String = "") -> Dictionary:
	var pc: Color = StatStyle.color(&"prestige")
	if can:
		return {"title": "Rebirth", "title_color": StatStyle.color(&"reb"), "color": StatStyle.color(&"reb"), "icon": "reb",
			"body": "Reset your stock and pads for a Rebirth.",
			"lines": [["Gives ", Tip.icon("prestige"), Tip.seg("+%s" % gain_text, StatStyle.gain()), " ", Tip.seg("Prestige", pc)]]
				+ ([["Gives ", Tip.icon("rp"), Tip.seg("+%s" % rp_text, StatStyle.gain()), " ", Tip.seg("Rebirth Points", StatStyle.color(&"rp"))]] if rp_text != "" else []),
			"hint": "Prestige and relics are kept.", "hint_color": StatStyle.gain()}
	return {"title": "Rebirth", "title_color": StatStyle.color(&"reb"), "color": StatStyle.color(&"reb"), "icon": "reb",
		"body": "Start over for Prestige and faster income.", "hint": "Not available yet.", "hint_color": StatStyle.cant()}


## Tooltip of a zone reset's button (Bloom in the meadow), skinned by its ZoneResetDef.
static func zone_reset(r: ZoneResetDef, currency_name: String, can: bool, gain: int, need_text: String) -> Dictionary:
	var sc: Color = StatStyle.color(r.currency)
	var icon: String = String(r.currency)
	if can:
		return {"title": r.display_name, "title_color": sc, "color": sc, "icon": icon, "body": r.tip_body,
			"lines": [["Gives ", Tip.icon(icon), Tip.seg("+%d" % gain, StatStyle.gain()), " ", Tip.seg(currency_name, sc)],
				["Every pad pays ", Tip.seg("+%d%%" % int(roundf(r.bonus_per_use * 100.0)), StatStyle.gain()), " more for good"]],
			"hint": r.keeps_text, "hint_color": StatStyle.gain()}
	return {"title": r.display_name, "title_color": sc, "color": sc, "icon": icon,
		"body": r.button_hint, "hint": need_text, "hint_color": StatStyle.cant()}


static func zone_button(display_name: String) -> Dictionary:
	return {"title": display_name, "body": "Travel there. Your progress here is kept."}


## Row in the Stats / Attributes index: {id, name, icon, value, note, tip}.
static func index_row(d: Dictionary) -> Dictionary:
	var id: StringName = StringName(str(d["id"]))
	var c: Color = StatStyle.color(id)
	var lines: Array = []
	if str(d.get("value", "")) != "":
		lines.append(["Now ", Tip.seg(str(d["value"]), c)])
	if str(d.get("note", "")) != "":
		lines.append([Tip.seg(str(d["note"]), StatStyle.gain())])
	return {"title": str(d["name"]), "title_color": c, "color": c, "icon": str(d.get("icon", "")),
		"body": str(d["tip"]), "lines": lines}


## A relic in a slot. `owned` stacks, `is_equipped` whether it counts right now, `hint` what a click does.
static func relic(def: RelicDef, owned: int, is_equipped: bool, hint: String) -> Dictionary:
	var rc: Color = def.rarity.readable_color(RelicStyle.ink)
	var lines: Array = [rarity_tag(def.rarity, "relic", rc)]
	lines.append(["Owned ", Tip.seg("%d%s" % [owned, " (max)" if def.is_capped(owned) else ""], RelicStyle.accent)])
	if owned > 0 and not is_equipped:
		lines.append([Tip.seg("Not equipped: no effect", StatStyle.cant())])
	elif not def.is_capped(owned):
		lines.append(["Next stack ", Tip.seg("+%s" % RelicDef._pct(def.value_for(owned + 1) - def.value_for(owned)), StatStyle.gain())])
	return {"title": def.display_name, "title_color": rc, "color": rc, "body": def.describe(maxi(owned, 1)),
		"lines": lines, "hint": hint, "beside": true}


static func slot_note(title: String, body: String) -> Dictionary:
	return {"title": title, "body": body, "beside": true}


## The one rarity line every tooltip uses: all caps, bold display face, rarity colour, rarity then type
## ("UNCOMMON PAD", "RARE RELIC", "COMMON UPGRADE"). `c` is the readable rarity colour.
static func rarity_tag(rarity: RarityDef, kind: String, c: Color) -> Array:
	return [Tip.tag("%s %s" % [rarity.display_name, kind], c)]
