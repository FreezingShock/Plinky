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
	# The glow node: every pad has one from construction, visible, above the night shade (z 5) and under the air layer (z 10).
	var glow_pad := TexelPad.new()
	t.ok(glow_pad._halo != null, "a pad always has its glow node, in every zone")
	t.ok(glow_pad._halo != null and glow_pad._halo.get_parent() == glow_pad, "the glow node is a child of its pad")
	t.ok(glow_pad._halo != null and glow_pad._halo.visible, "the glow node is visible")
	t.ok(TexelPad.HALO_Z > 5 and TexelPad.HALO_Z < 10, "the glow sits above the night shade (z 5) and under the air layer (z 10)")
	# Guard: a bare draw_rect inside the glow's draw code paints the pad, not the glow node, and errors every frame in-engine.
	var src: String = FileAccess.get_file_as_string("res://world/texel_pad.gd")
	var in_halo: bool = false
	var bare_draws: int = 0
	for line: String in src.split("\n"):
		if line.begins_with("func "):
			in_halo = line.begins_with("func _draw_halo") or line.begins_with("func _glint")
		if in_halo and (line.contains("draw_rect(") or line.contains("draw_texture(")) and not line.contains("_halo.draw_"):
			bare_draws += 1
	t.eq(bare_draws, 0, "the glow draws only through its own node (_halo.draw_rect / _halo.draw_texture)")
	t.ok(glow_pad._halo.material is CanvasItemMaterial and (glow_pad._halo.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "the glow is additive, so it lights the ground under it")
	t.ok(glow_pad._halo.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "the glow is filtered nearest, so it stays pixel-crisp")
	var day_halo: ImageTexture = TexelPad.glow_texture(true, 0)
	var night_halo: ImageTexture = TexelPad.glow_texture(true, 8)
	t.ok(night_halo.get_width() > day_halo.get_width(), "the halo reaches further at night")
	t.ok(night_halo.get_width() > 4 * int(TexelPad.HALF.x), "the halo spills well past the plate (more than twice its width)")
	t.ok(TexelPad.glow_texture(false, 8) != null, "the red halo builds too")
	var haze_tex: ImageTexture = TexelPad.glow_haze_texture(true, 8)
	t.ok(haze_tex.get_width() < night_halo.get_width(), "the bloom above the pad is smaller than the halo")
	t.ok(night_halo.get_image().get_pixel(night_halo.get_width() >> 1, night_halo.get_height() >> 1).a > 0.0, "the centre of the halo lights the plate itself")
	var pulse: float = TexelPad.glow_pulse_alpha()
	t.ok(pulse <= 1.0 and pulse >= 1.0 - TexelPad.GLOW_PULSE_DEPTH - 0.001, "the breath dims the halo by at most its depth")
	var night_glow := PadGlow.new()
	night_glow.night01 = 1.0
	glow_pad.glow = night_glow
	t.eq(glow_pad._night(), 1.0, "a pad reads the zone's night level through PadGlow")
	glow_pad.glow = null
	night_glow.free()
	glow_pad.free()
	# Buy glow: green when buyable, red a little softer, magnified at night, and never past full density.
	t.ok(TexelPad.glow_amount(true, 0.0) > 0.0, "a buyable pad has a glow by day")
	t.ok(TexelPad.glow_amount(true, 1.0) > TexelPad.glow_amount(true, 0.0), "the glow is stronger at night")
	t.ok(TexelPad.glow_amount(false, 0.0) < TexelPad.glow_amount(true, 0.0), "the red glow sits softer than the green")
	t.ok(TexelPad.glow_amount(true, 1.0) <= 1.0, "the glow never passes full density")
	t.ok(TexelPad.glow_spread(1.0) > TexelPad.glow_spread(0.0), "the glow band widens at night")
	t.eq(TexelPad.glow_night_step(0.0), 0, "day is night step 0")
	t.eq(TexelPad.glow_night_step(1.0), 8, "full night is night step 8")
	# The pad's light pool in the shared shade shader: green when buyable, red when not, the warm default (alpha 0) when locked.
	var lit_pad := TexelPad.new()
	lit_pad.affordable = true
	t.ok(lit_pad.light_tint().is_equal_approx(StatStyle.gain()), "a buyable pad's light pool is green")
	lit_pad.affordable = false
	t.ok(lit_pad.light_tint().is_equal_approx(StatStyle.cant()), "an unaffordable pad's light pool is red")
	lit_pad.locked = true
	t.ok(lit_pad.light_tint().a == 0.0, "a locked pad keeps the warm pool colour")
	lit_pad.free()
	# Crowding: a lone pad keeps all its light, and any crowd of lit pads adds up to about two pads' worth, never one per pad.
	t.eq(TexelPad.crowd_scale(1), 1.0, "a lone pad keeps its full halo and pool")
	t.eq(TexelPad.crowd_scale(2), 1.0, "a pair of pads keeps its full light")
	for n in range(1, 11):
		t.ok(float(n) * TexelPad.crowd_scale(n) <= 2.0 + 0.001, "%d pads together add up to at most about two pads' light" % n)
	t.ok(TexelPad.crowd_scale(5) < TexelPad.crowd_scale(2), "a pad in a busy row is dimmer than one in a pair")
	var crowd_pad := TexelPad.new()
	crowd_pad.crowd = 5
	t.ok(crowd_pad.light_strength() < 1.0, "a pad in a busy row lights less than a lone pad")
	crowd_pad.locked = true
	t.eq(crowd_pad.light_strength(), 1.0, "a locked pad keeps its warm pool at full strength")
	crowd_pad.free()
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
	t.ok(TexelPad.LOCK_CHIP_Z > 10, "the chip draws above the air layer at z 10, so shimmer and fireflies never cover it")
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
