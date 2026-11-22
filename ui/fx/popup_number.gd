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

# --- running popup (hold-to-repeat): one number that keeps climbing ---
var is_running := false
var _tier := 0

static func spawn_running(parent: Node, pos: Vector2, amount: float) -> PopupNumber:
	var p := PopupNumber.new()
	p.is_running = true
	p.text = "+" + NumberFormat.short(amount)
	p.position = FxConfig.snap(pos + Vector2(0, -26))
	p.z_index = 100
	p.theme_type_variation = &"PopupLabel"
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.pivot_offset = p.size / 2.0
	return p

func bump(total: float) -> void:
	text = "+" + NumberFormat.short(total)
	_tier = clampi(int(floor(log(maxf(total, 1.0)) / log(10.0))) - 1, 0, 3) # 10, 100, 1000+
	pivot_offset = size / 2.0
	scale = Vector2.ONE * (1.0 + 0.25 + 0.15 * _tier)  # pop, settles back
	create_tween().tween_property(self, "scale", Vector2.ONE * (1.0 + 0.2 * _tier), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Tier colours by palette role: accent, accent, light, paper (theme re-tints per zone).
	var roles := ["accent", "accent", "good", "text"]
	add_theme_color_override("font_color", PlinkyPalette.role(PopupStack.zone, roles[_tier]))

func release() -> void:
	is_running = false
	var t := create_tween()
	t.tween_interval(0.5)
	t.set_parallel(true)
	for i in 4:
		t.tween_property(self, "position:y", roundf(position.y - 4.0 * (i + 1)), 0.0).set_delay(0.3 * i / 4.0)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(queue_free)
