class_name PopupNumber
extends Label
## Rises and fades over ~0.8 s, palette 5. Spawn with PopupNumber.spawn().
## Lives in a screen-space overlay (see fx_bus.gd), NOT under the zoomed world, so it is never
## scaled by camera zoom. It carries its own Theme because a Node2D parent breaks theme
## inheritance (that is why it once fell back to the thin default font).

static var ui_theme: Theme  # set by fx_bus from the Main control's theme

static func spawn(parent: Node, pos: Vector2, amount: float, big := false) -> PopupNumber:
	return spawn_text(parent, pos, "+" + NumberFormat.short(amount), big)

## Same popup with ready-made text (BigNum gains, "+3 Prestige"). Under a Control parent the theme is inherited.
static func spawn_text(parent: Node, pos: Vector2, label: String, big := false) -> PopupNumber:
	var p := PopupNumber.new()
	p.text = label
	p.position = FxConfig.snap(pos)
	p.z_index = 100
	# Font, colour and outline come from plinky_theme.tres (PopupLabel = Pixelify Sans 16),
	# so they re-tint per zone. Nearest filtering keeps glyph edges hard.
	if ui_theme != null:
		p.theme = ui_theme
	p.theme_type_variation = &"PopupLabel"
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p._run(big)
	return p

func _run(big: bool) -> void:
	# Whole-number font sizes only (16, or 24 for crits). Scaling a label by a fraction would blur it.
	add_theme_font_size_override("font_size", 24 if big else 16)
	var t := create_tween().set_parallel(true)
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
	p.position = FxConfig.snap(pos)
	p.z_index = 100
	p.theme = ui_theme
	p.theme_type_variation = &"PopupLabel"
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.pivot_offset = p.size / 2.0
	return p

func bump(total: float) -> void:
	text = "+" + NumberFormat.short(total)
	_tier = clampi(int(floor(log(maxf(total, 1.0)) / log(10.0))) - 1, 0, 3) # 10, 100, 1000+
	add_theme_font_size_override("font_size", 16 + 4 * _tier)  # integer sizes, grows with the number
	position.y += 2.0  # tiny stepped nudge instead of a fractional scale pop
	create_tween().tween_property(self, "position:y", position.y - 2.0, 0.06)
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
