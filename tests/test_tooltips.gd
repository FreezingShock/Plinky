extends RefCounted
## Tooltip system: spec normalising, bind bookkeeping, delay, grace window, and staying on screen.

func run(t: Object) -> void:
	var d: Dictionary = Tip.normalize("hello")
	t.eq(d["body"], "hello", "a String spec becomes the body")
	t.eq(d["title"], "", "a String spec has no title")
	d = Tip.normalize({"title": "Luck", "hint": "Rebirth"})
	t.eq(d["title"], "Luck", "a Dictionary spec keeps its title")
	t.eq(d["body"], "", "missing parts default to empty")
	d = Tip.normalize(func() -> Variant: return {"body": "live"})
	t.eq(d["body"], "live", "a Callable spec is evaluated")

	for sid: StringName in [&"cash", &"mult", &"reb", &"slag", &"prestige"]:
		t.ok(str(TipText.stat(sid, "x")["body"]) != "", "stat tooltip text exists for %s" % sid)
	var a := AttributeDef.new()
	a.display_name = "Luck"
	a.effect = &"luck"
	a.cap = 5
	t.eq(TipText.attribute(a, 5, "3", true)["hint"], "Max level.", "a maxed attribute says so")
	t.ok(str(TipText.attribute(a, 1, "3", false)["hint"]).begins_with("Need"), "an unaffordable attribute says what is needed")
	t.ok(str(TipText.rebirth(false, "1")["hint"]) != "", "rebirth explains when it is unavailable")

	var sim: Sim = t.make_sim()
	var bid: StringName = sim.button_defs.keys()[0]
	var ps: Dictionary = PadTooltip.spec_for(sim, bid)
	t.ok(str(ps["body"]).contains("Costs") and str(ps["body"]).contains("Gives"), "pad tooltip lists cost and reward")
	t.ok(not str(ps["body"]).contains("Rarity"), "no rarity line while the sim has no pad_rarity or it is common")
	t.ok(PadTooltip.spec_for(sim, &"nope").is_empty(), "unknown pad gives an empty spec")

	var root: Node = (t as SceneTree).root
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	Tip.bind(c, "one")
	Tip.bind(c, "two")
	t.eq(c.get_meta(Tip.META), "two", "binding again replaces the spec")
	t.ok(c.mouse_filter == Control.MOUSE_FILTER_PASS, "an ignoring control is switched to PASS so it can hover")
	t.eq(c.mouse_entered.get_connections().size(), 1, "binding twice connects once")

	var h := TipHost.new()
	root.add_child(h)
	h.request(c, false)
	t.ok(not h.visible, "a hover tip waits for its delay")
	h._process(TipHost.HOVER_DELAY + 0.01)
	t.ok(h.visible, "a hover tip shows after the delay")
	h.dismiss()
	t.ok(not h.visible, "dismiss hides it")
	h.request(c, false)
	t.ok(h.visible, "the next tip shows at once inside the grace window")
	h.dismiss()
	h._process(TipHost.GRACE + 0.5)
	h.request(c, true)
	t.ok(not h.visible and TipHost.FOCUS_DELAY < TipHost.HOVER_DELAY, "focus uses the shorter delay")
	h._process(TipHost.FOCUS_DELAY + 0.01)
	t.ok(h.visible, "a focus tip shows after its short delay")
	h.dismiss()

	# Stays on screen even when asked for far outside the corner.
	h.show_free({"title": "Pad", "body": "Costs a lot of something, so the box is wide enough to need wrapping."}, Vector2(99999, 99999))
	h._process(TipHost.HOVER_DELAY + 0.01)
	var view: Vector2 = h._view_size()
	t.ok(h.visible, "a free tip shows")
	t.ok(h.position.x >= 0.0 and h.position.y >= 0.0, "a free tip is not above or left of the screen")
	t.ok(h.position.x + h.size.x <= view.x and h.position.y + h.size.y <= view.y, "a free tip is not past the right or bottom edge")
	h.hide_free()
	t.ok(not h.visible, "hide_free hides it")

	c.queue_free()
	h.queue_free()
