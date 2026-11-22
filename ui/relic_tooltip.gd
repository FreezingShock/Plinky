class_name RelicTooltip
extends PanelContainer
## Floating tooltip for a relic. Show with show_for(slot, ...). Stays inside the 640x360 view.

const MAX_WIDTH: int = 150

var _name: Label
var _rarity: Label
var _body: Label
var _stats: Label
var _hint: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	_name = _label(v, RelicStyle.text)
	_name.theme_type_variation = &"TitleLabel"
	_rarity = _label(v, RelicStyle.text)
	_body = _label(v, RelicStyle.text)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = MAX_WIDTH
	_stats = _label(v, RelicStyle.good)
	_hint = _label(v, RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = MAX_WIDTH

func _label(parent: Node, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", RelicStyle.ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## owned: stacks owned. active: stacks currently counting (0 if not equipped).
func show_relic(def: RelicDef, owned: int, is_equipped: bool, hint: String, anchor: Rect2) -> void:
	var rc: Color = def.rarity.readable_color(RelicStyle.ink)
	_name.text = def.display_name
	_name.add_theme_color_override("font_color", rc)
	_rarity.text = "%s relic" % def.rarity.display_name.to_upper()
	_rarity.add_theme_color_override("font_color", rc)
	_body.text = def.describe(maxi(owned, 1))
	var lines: PackedStringArray = []
	lines.append("Owned: %d%s" % [owned, " (max)" if def.is_capped(owned) else ""])
	if owned > 0 and not is_equipped:
		lines.append("Not equipped: no effect")
	elif not def.is_capped(owned):
		lines.append("Next stack: +%s" % RelicDef._pct(def.value_for(owned + 1) - def.value_for(owned)))
	_stats.text = "\n".join(lines)
	_stats.add_theme_color_override("font_color", RelicStyle.dim if (owned > 0 and not is_equipped) else RelicStyle.good)
	_hint.text = hint
	_hint.visible = hint != ""
	add_theme_stylebox_override("panel", AsciiBox.panel(def.rarity.color))
	_place(anchor)

## Plain text tooltip for empty and locked slots.
func show_text(title: String, body: String, anchor: Rect2) -> void:
	_name.text = title
	_name.add_theme_color_override("font_color", RelicStyle.text)
	_rarity.text = ""
	_body.text = body
	_stats.text = ""
	_hint.text = ""
	_rarity.visible = false; _stats.visible = false; _hint.visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	_place(anchor)

func _place(anchor: Rect2) -> void:
	_rarity.visible = _rarity.text != ""
	_stats.visible = _stats.text != ""
	reset_size()
	visible = true
	await get_tree().process_frame   # let containers settle so size is real
	if not visible:
		return
	var view: Vector2 = get_viewport_rect().size
	var p := Vector2(anchor.end.x + 4, anchor.position.y)
	if p.x + size.x > view.x - 4:
		p.x = anchor.position.x - size.x - 4
	p.y = clampf(p.y, 4, maxf(4, view.y - size.y - 4))
	p.x = clampf(p.x, 4, maxf(4, view.x - size.x - 4))
	global_position = p.round()

func hide_tip() -> void:
	visible = false
