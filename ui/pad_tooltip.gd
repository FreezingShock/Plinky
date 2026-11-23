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


func hide_tip() -> void:
	if visible:
		visible = false
		Tip.hide_free(get_tree() if is_inside_tree() else null)


## {title, body, hint, color} for a pad, or {} if the button is unknown.
static func spec_for(sim: Sim, button_id: StringName) -> Dictionary:
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		return {}
	var cost_def: StatDef = sim.stat_defs[b.cost_stat] as StatDef
	var reward_def: StatDef = sim.stat_defs[b.reward_stat] as StatDef
	var cost: BigNum = Formulas.button_cost(b)
	var have: BigNum = sim.get_stat(b.cost_stat)
	var lines: PackedStringArray = []
	var color := Color(0, 0, 0, 0)
	var rar: RarityDef = _rarity(sim, button_id)
	if rar != null:
		color = rar.readable_color(RelicStyle.ink)
		lines.append("Rarity: %s" % rar.display_name)
	lines.append("Costs %s %s" % [cost.format(), cost_def.display_name])
	lines.append("Gives +%s %s" % [sim.press_gain_preview(button_id).format(), reward_def.display_name])
	var hint: String = "Ready. Stand here or hold click." if have.gte(cost) else "Need %s more" % cost.sub(have).format()
	return {"title": "%s %d" % [String(b.row).capitalize(), b.row_index + 1], "body": "\n".join(lines), "hint": hint, "color": color}


## The pad's rarity when the sim has one and it is above common; null otherwise.
static func _rarity(sim: Sim, button_id: StringName) -> RarityDef:
	if not sim.has_method(&"pad_rarity"):
		return null
	var rid: StringName = sim.call(&"pad_rarity", button_id)
	if rid == &"" or rid == &"common":
		return null
	var path: String = "res://content/rarities/%s.tres" % String(rid)
	return load(path) as RarityDef if ResourceLoader.exists(path) else null
