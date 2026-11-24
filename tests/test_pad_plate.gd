extends RefCounted
## Pad plate states, press sink and rarity (world/texel_pad.gd, content/buttons).

func run(t: Object) -> void:
	var pad := TexelPad.new()
	pad.affordable = false
	pad.progress = 0.0
	t.eq(pad.pad_state(), TexelPad.PadState.FAR, "no money looks inert")
	pad.progress = 0.4
	t.eq(pad.pad_state(), TexelPad.PadState.CLOSE, "part of the cost shows the gauge")
	pad.affordable = true
	t.eq(pad.pad_state(), TexelPad.PadState.READY, "affordable is ready")
	t.eq(pad.sink_texels(), 0, "at rest the plate is up")
	pad.punch()
	t.eq(pad.sink_texels(), FxConfig.PRESS_SINK_TEXELS, "a press sinks the plate the full amount")
	for i in 5:
		pad.punch()  # spam restarts one timer, never stacks
	t.eq(pad.sink_texels(), FxConfig.PRESS_SINK_TEXELS, "spam-pressing does not sink further")
	pad.standing = true
	t.ok(pad.sink_texels() >= 1, "standing keeps the plate pressed")
	pad.level_flash()
	t.ok(pad._level_step() > 0, "a level-up starts the ring flash")
	pad.free()
	var sim: Sim = t.make_sim()
	for id: StringName in sim.button_defs:
		var r: StringName = sim.pad_rarity(id)
		t.ok(ResourceLoader.exists("res://content/rarities/%s.tres" % r), "%s has a real rarity (%s)" % [id, r])
	t.eq(sim.pad_rarity(&"sprout_1"), &"common", "the first pad is Common")
	t.eq(sim.pad_rarity(&"foxglove_2"), &"legendary", "a Foxglove pad is Legendary")
	# The locked-row cost chip: drawn on a locked first pad, at the font's native size, inside a box that holds its text.
	var hint: String = "Needs Dewdrops"
	t.ok(TexelPad.shows_lock_chip(true, hint), "a locked first pad draws its cost chip")
	t.ok(not TexelPad.shows_lock_chip(false, hint), "an open pad draws no cost chip")
	t.ok(not TexelPad.shows_lock_chip(true, ""), "no hint, no chip")
	t.eq(TexelPad.LOCK_SIZE, 8, "the chip text uses the font's native 8 px size")
	var text_w: float = TexelPad.LOCK_FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TexelPad.LOCK_SIZE).x
	var box: Rect2 = TexelPad.lock_chip_box(hint)
	t.ok(text_w > 0.0, "the cost hint has a measurable width at the native size")
	t.ok(box.size.x >= text_w + 6.0, "the chip box is wider than its text")
	t.eq(box.size.y, 12.0, "the chip is 12 rows tall")
	t.ok(box.position.y >= float(TexelPad.THICK), "the chip sits under the plate")
	for i in hint.length():
		t.ok(TexelPad.LOCK_FONT.has_char(hint.unicode_at(i)), "the font has a glyph for '%s'" % hint.substr(i, 1))
