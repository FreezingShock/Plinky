class_name RelicTooltip
extends Node
## Tooltip for a relic or a slot. A thin wrapper over the shared Tip system: it builds the spec and
## shows it beside the slot. Show with show_relic / show_text, hide with hide_tip.

var visible: bool = false


## owned: stacks owned. is_equipped: whether it counts right now.
func show_relic(def: RelicDef, owned: int, is_equipped: bool, hint: String, anchor: Rect2) -> void:
	var rc: Color = def.rarity.readable_color(RelicStyle.ink)
	var lines: PackedStringArray = []
	lines.append("%s relic" % def.rarity.display_name.to_upper())
	lines.append(def.describe(maxi(owned, 1)))
	lines.append("Owned: %d%s" % [owned, " (max)" if def.is_capped(owned) else ""])
	if owned > 0 and not is_equipped:
		lines.append("Not equipped: no effect")
	elif not def.is_capped(owned):
		lines.append("Next stack: +%s" % RelicDef._pct(def.value_for(owned + 1) - def.value_for(owned)))
	_show({"title": def.display_name, "body": "\n".join(lines), "hint": hint, "color": rc}, anchor)


## Plain text tooltip for empty and locked slots.
func show_text(title: String, body: String, anchor: Rect2) -> void:
	_show({"title": title, "body": body}, anchor)


func _show(spec: Dictionary, anchor: Rect2) -> void:
	visible = true
	if is_inside_tree():
		Tip.show_beside(get_tree(), spec, anchor)


func hide_tip() -> void:
	if visible:
		visible = false
		Tip.hide_free(get_tree() if is_inside_tree() else null)
