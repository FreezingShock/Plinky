class_name PopupNumber
extends Label
## Rises and fades over ~0.8 s, palette 5. Spawn with PopupNumber.spawn().

static func spawn(parent: Node, pos: Vector2, amount: float, big := false) -> PopupNumber:
	var p := PopupNumber.new()
	p.text = "+" + NumberFormat.short(amount)
	p.position = FxConfig.snap(pos)
	p.z_index = 100
	# Font, colour and outline come from plinky_theme.tres (PopupLabel = Pixelify Sans 16),
	# so they re-tint per zone. Nearest filtering keeps glyph edges hard.
	p.theme_type_variation = &"PopupLabel"
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p._run(big)
	return p

func _run(big: bool) -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * (1.6 if big else 1.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Stepped rise (4 steps) reads as pixel art, not smooth motion.
	var start := position
	for i in 4:
		t.tween_property(self, "position:y", roundf(start.y - FxConfig.POPUP_RISE_TEXELS * (i + 1) / 4.0), 0.0).set_delay(FxConfig.POPUP_LIFE * i / 4.0)
	t.tween_property(self, "modulate:a", 0.0, FxConfig.POPUP_LIFE * 0.35).set_delay(FxConfig.POPUP_LIFE * 0.65)
	t.chain().tween_callback(queue_free)
