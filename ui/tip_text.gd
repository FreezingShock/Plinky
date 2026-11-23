class_name TipText
extends RefCounted
## Words for the tooltips on existing UI, in one place so they stay consistent. Specs for Tip.bind.
## No numbers that belong to balance: live values are passed in by the caller.

const STATS: Dictionary = {
	&"cash": {"title": "Cash", "body": "What pads cost and pay. Walk and press pads to earn it.", "hint": "Resets when you rebirth."},
	&"mult": {"title": "Multiplier", "body": "Boosts your Cash income and press rewards.", "hint": "Grows from pads. Rebirths make it grow faster."},
	&"reb": {"title": "Rebirths", "body": "Times you have started over. Each one speeds up Multiplier gain.", "hint": "Use the Rebirth button once you can afford it."},
	&"slag": {"title": "Slag", "body": "Quarry currency, made by the pads there.", "hint": "Spend it on quarry pads."},
	&"prestige": {"title": "Prestige", "body": "Earned by rebirthing. Spend it on permanent upgrades.", "hint": "Open Upgrades to spend it."},
}

const ATTRS: Dictionary = {
	&"walk_speed": "Walk faster between pads.",
	&"press_rate": "Hold-to-press repeats faster.",
	&"crit_chance": "A bigger chance for a press to crit.",
	&"luck": "Better odds on relic drops.",
	&"offline_hours": "Earn for more hours while you are away.",
}


static func stat(sid: StringName, display_name: String) -> Dictionary:
	return STATS.get(sid, {"title": display_name, "body": ""}) as Dictionary


static func attribute(a: AttributeDef, level: int, cost_text: String, can_afford: bool) -> Dictionary:
	var hint: String = "Max level." if level >= a.cap else ("Costs %s Prestige." % cost_text if can_afford else "Need %s Prestige." % cost_text)
	return {
		"title": "%s %d/%d" % [a.display_name, level, a.cap],
		"body": ATTRS.get(a.effect, ""),
		"hint": hint,
	}


static func rebirth(can: bool, gain_text: String) -> Dictionary:
	if can:
		return {"title": "Rebirth", "body": "Reset your Cash and pads for +%s Prestige and a Rebirth." % gain_text, "hint": "Prestige and relics are kept."}
	return {"title": "Rebirth", "body": "Start over for Prestige and a faster Multiplier.", "hint": "Not available yet."}


static func zone_button(display_name: String) -> Dictionary:
	return {"title": display_name, "body": "Travel there. Your progress here is kept.", "hint": "Zones you have opened are listed."}
