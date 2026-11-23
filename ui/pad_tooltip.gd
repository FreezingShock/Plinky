class_name PadTooltip
extends Node
## Hover tooltip for a pad: what it costs, what it gives, and how far off you are.
## A thin wrapper over the shared Tip system; the content comes from spec_for.

var visible: bool = false


## Fill for one button and place near `at` (screen texels). Call every frame while hovered.
func show_for(sim: Sim, button_id: StringName, at: Vector2) -> void:
	var spec: Dictionary = spec_for(sim, button_id)
	if spec.is_empty():
		hide_tip()
		return
	visible = true
	if is_inside_tree():
		Tip.show_free(get_tree(), spec, at)


## Show a ready-made spec (the gate's) near `at`.
func show_spec(spec: Dictionary, at: Vector2) -> void:
	if spec.is_empty():
		hide_tip()
		return
	visible = true
	if is_inside_tree():
		Tip.show_free(get_tree(), spec, at)


func hide_tip() -> void:
	if visible:
		visible = false
		Tip.hide_free(get_tree() if is_inside_tree() else null)


## Rich spec for a pad, or {} if the button is unknown. Cost number green if affordable and red if not, the
## gain green, stat names in their stat colour, the rarity line in its rarity colour.
static func spec_for(sim: Sim, button_id: StringName) -> Dictionary:
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		return {}
	var cost_def: StatDef = sim.stat_defs[b.cost_stat] as StatDef
	var reward_def: StatDef = sim.stat_defs[b.reward_stat] as StatDef
	var cost: BigNum = Formulas.button_cost(b)
	var have: BigNum = sim.get_stat(b.cost_stat)
	var can: bool = have.gte(cost)
	var rc: Color = StatStyle.color(b.reward_stat)
	var lines: Array = []
	var edge: Color = rc
	var rar: RarityDef = _rarity(sim, button_id)
	var body: String = ""
	if rar != null:
		edge = rar.readable_color(RelicStyle.ink)
		lines.append(TipText.rarity_tag(rar, "button", edge))
	lines.append(["Costs ", Tip.icon(String(b.cost_stat)), Tip.seg(cost.format(), StatStyle.buy(can)), " ", Tip.seg(cost_def.display_name, StatStyle.color(b.cost_stat))])
	lines.append(["Gives ", Tip.icon(String(b.reward_stat)), Tip.seg("+%s" % sim.press_gain_preview(button_id).format(), StatStyle.gain()), " ", Tip.seg(reward_def.display_name, rc)])
	var hint: String = "Ready. Stand here or hold click." if can else "Need %s more" % cost.sub(have).format()
	var hint_color: Color = StatStyle.buy(can)
	if sim.is_pad_locked(button_id):
		var below: TierDef = null
		for t: TierDef in sim.tiers_in_zone(sim.tier_of(button_id).zone):
			if sim.next_tier(t.id) == sim.tier_of(button_id):
				below = t
		hint = "Locked. Press the last %s pad once to open it." % (below.display_name if below != null else "previous")
		hint_color = StatStyle.cant()
	return {
		"title": "%s %d" % [String(b.row).capitalize(), b.row_index + 1], "title_color": rc, "color": edge,
		"icon": String(b.reward_stat), "body": body, "lines": lines,
		"hint": hint, "hint_color": hint_color,
	}


## The pad's rarity when the sim has one and it is above common; null otherwise.
static func _rarity(sim: Sim, button_id: StringName) -> RarityDef:
	if not sim.has_method(&"pad_rarity"):
		return null
	var rid: StringName = sim.call(&"pad_rarity", button_id)
	if rid == &"" or rid == &"common":
		return null
	var path: String = "res://content/rarities/%s.tres" % String(rid)
	return load(path) as RarityDef if ResourceLoader.exists(path) else null
