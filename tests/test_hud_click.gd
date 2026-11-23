extends RefCounted
## Regression: HUD buttons (Go: <zone>, Upgrades, ...) did nothing on a mouse click. Main released focus from whichever
## control had it every frame while no menu was open, so the Button lost focus between press and release and its click
## was cancelled. Focus may only be dropped on the frame a menu closes.

func run(t: Object) -> void:
	t.ok(not PadInput.should_release_focus(false, true), "a clicked HUD button keeps focus while no menu is open")
	t.ok(not PadInput.should_release_focus(false, false), "nothing to release when nothing has focus")
	t.ok(PadInput.should_release_focus(true, true), "focus is dropped when a menu closes")
	t.ok(not PadInput.should_release_focus(true, false), "a closing menu with no focus owner releases nothing")

	var sim: Sim = t.make_sim()
	var first: StringName = &"zone1"
	var next: StringName = (sim.zone_defs[first] as ZoneDef).next_zone
	t.ok(not sim.enter_zone(next), "the world button's target is locked until the gate opens")
	sim.gates_open[first] = true
	t.ok(sim.is_zone_unlocked(next), "an open gate unlocks the next world")
	t.ok(sim.enter_zone(next), "pressing Go switches to it")
	t.ok(sim.enter_zone(first), "and Go: Meadow switches back")
