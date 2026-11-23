class_name LockIcon
extends Control
## A 9x9 pixel padlock in the dim colour, drawn rect by rect so it stays on the texel grid. Sits where an icon would.

const SHACKLE: Array[Rect2] = [Rect2(3, 0, 3, 1), Rect2(2, 1, 1, 2), Rect2(6, 1, 1, 2)]
const BODY: Rect2 = Rect2(1, 3, 7, 5)
const KEYHOLE: Rect2 = Rect2(4, 5, 1, 2)


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var o := Vector2(floorf((size.x - 9.0) / 2.0), floorf((size.y - 9.0) / 2.0))
	for r: Rect2 in SHACKLE:
		draw_rect(Rect2(o + r.position, r.size), RelicStyle.dim)
	draw_rect(Rect2(o + BODY.position, BODY.size), RelicStyle.dim)
	draw_rect(Rect2(o + KEYHOLE.position, KEYHOLE.size), RelicStyle.ink)
