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
	t.eq(sim.pad_rarity(&"m1"), &"common", "the first pad is Common")
	t.eq(sim.pad_rarity(&"l1"), &"legendary", "a late Larkmoor pad is Legendary")
