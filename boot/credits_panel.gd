class_name CreditsPanel
extends PanelContainer
## Credits and licences: who made the game, the engine and the two typefaces. Plain themed labels in a panel.

const WIDTH: float = 300.0
const LINES: Array[Array] = [
	["Made by", "Nathan"],
	["Built with", "Godot Engine 4.7"],
	["Titles", "Pixelify Sans, SIL Open Font License 1.1"],
	["Body text", "Spleen 6x12, BSD 2-Clause License"],
]


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Credits"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	v.add_child(PanelDivider.new())
	for pair: Array in LINES:
		var role := Label.new()
		role.text = String(pair[0])
		role.add_theme_color_override("font_color", RelicStyle.accent)
		v.add_child(role)
		var who := Label.new()
		who.text = String(pair[1])
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		who.custom_minimum_size = Vector2(WIDTH, 0.0)
		v.add_child(who)
	v.add_child(PanelDivider.new())
	var ver := Label.new()
	ver.text = "Plinky %s" % BuildInfo.string()
	ver.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(ver)
