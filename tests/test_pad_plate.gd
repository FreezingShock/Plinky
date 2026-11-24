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
	# The locked-row cost chip: the pad's real cost and its stat icon, at the font's native size, in a box that holds both.
	var cost_def: ButtonDef = sim.button_defs.get(&"lark_clover_1") as ButtonDef
	t.ok(cost_def != null, "the Clover row's first pad exists")
	var cost: String = Formulas.button_cost(cost_def).format()
	t.ok(TexelPad.shows_lock_chip(true, cost), "a locked first pad draws its cost chip")
	t.ok(not TexelPad.shows_lock_chip(false, cost), "an open pad draws no cost chip")
	t.ok(not TexelPad.shows_lock_chip(true, ""), "no cost, no chip")
	t.eq(TexelPad.LOCK_SIZE, 8, "the chip text uses the font's native 8 px size")
	var icon: Texture2D = IconSet.get_icon(String(cost_def.cost_stat), TexelPad.LOCK_ICON)
	t.ok(icon != null, "the Clover cost stat has an 8 px icon")
	var text_w: float = TexelPad.LOCK_FONT.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TexelPad.LOCK_SIZE).x
	var box: Rect2 = TexelPad.lock_chip_box(cost, icon != null)
	t.ok(text_w > 0.0, "the cost has a measurable width at the native size")
	t.ok(absf(TexelPad.chip_text_width(cost) - (text_w + float(cost.length() - 1))) < 0.01, "the digits sit one texel apart")
	t.eq(box.size.x, TexelPad.chip_text_width(cost) + float(TexelPad.LOCK_ICON + TexelPad.LOCK_GAP) + 6.0, "the box holds the icon, the gap and the digits")
	t.eq(box.size.y, 12.0, "the chip is 12 rows tall")
	t.ok(box.position.x >= TexelPad.HALF.x, "the chip sits beside the plate, out of the walker's footprint")
	t.eq(box.position.y + box.size.y * 0.5, 0.0, "the chip is centred on the plate's top face")
	for i in cost.length():
		t.ok(TexelPad.LOCK_FONT.has_char(cost.unicode_at(i)), "the font has a glyph for '%s'" % cost.substr(i, 1))
