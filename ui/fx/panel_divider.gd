class_name PanelDivider
extends Control
## A one-texel dotted rule between sections of a panel, in the panel edge colour. Gives each section air above and
## below it (pad texels each side). Whole texels only, no alpha.

var pad: int = 3


func _init(p_pad: int = 3) -> void:
	pad = p_pad
	custom_minimum_size = Vector2(0.0, float(pad * 2 + 1))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var y: float = float(pad)
	var x: int = 0
	while float(x) < size.x:
		draw_rect(Rect2(float(x), y, 2.0, 1.0), RelicStyle.edge)
		x += 4
