extends RefCounted
## Tooltip system: spec normalising, bind bookkeeping, instant show and hide, and staying on screen.

func run(t: Object) -> void:
	var d: Dictionary = Tip.normalize("hello")
	t.eq(d["body"], "hello", "a String spec becomes the body")
	t.eq(d["title"], "", "a String spec has no title")
	d = Tip.normalize({"title": "Luck", "hint": "Rebirth"})
	t.eq(d["title"], "Luck", "a Dictionary spec keeps its title")
	t.eq(d["body"], "", "missing parts default to empty")
	d = Tip.normalize(func() -> Variant: return {"body": "live"})
	t.eq(d["body"], "live", "a Callable spec is evaluated")

	for sid: StringName in [&"sunlight", &"dewdrop", &"clover", &"slag", &"prestige"]:
		t.ok(str(TipText.stat(sid, "x")["body"]) != "", "stat tooltip text exists for %s" % sid)
	var a := AttributeDef.new()
	a.display_name = "Luck"
	a.effect = &"luck"
	a.cap = 5
	t.eq(TipText.attribute(a, 5, "3", true)["hint"], "Max level.", "a maxed attribute says so")
	t.ok(str(TipText.attribute(a, 1, "3", false)["hint"]).begins_with("Need"), "an unaffordable attribute says what is needed")
	t.ok(str(TipText.rebirth(false, "1")["hint"]) != "", "rebirth explains when it is unavailable")

	var rar: RarityDef = load("res://content/rarities/uncommon.tres") as RarityDef
	var tag: Dictionary = TipText.rarity_tag(rar, "button", Color.WHITE)[0] as Dictionary
	t.eq(tag["t"], "UNCOMMON BUTTON", "the rarity tag is rarity then type, all caps")
	t.ok(bool(tag["tag"]), "the rarity tag is drawn in the bold tag face")
	t.ok(StatStyle.tag_font().base_font.resource_path.ends_with("PixelifySans.ttf") and StatStyle.tag_font().variation_embolden > 0.0, "the tag face is emboldened Pixelify Sans")
	var sim: Sim = t.make_sim()
	var bid: StringName = sim.button_defs.keys()[0]
	var ps: Dictionary = PadTooltip.spec_for(sim, bid)
	t.ok((ps["lines"] as Array).size() >= 2, "pad tooltip has cost and gain lines")
	var rid: StringName = sim.call(&"pad_rarity", bid) if sim.has_method(&"pad_rarity") else &"common"
	t.eq((ps["lines"] as Array).size() == 3, rid != &"" and rid != &"common", "the rarity line shows exactly when the pad is above common")
	var cost_seg: Dictionary = (ps["lines"] as Array)[(ps["lines"] as Array).size() - 2][2] as Dictionary
	var can: bool = sim.get_stat((sim.button_defs[bid] as ButtonDef).cost_stat).gte(Formulas.button_cost(sim.button_defs[bid] as ButtonDef))
	t.eq(cost_seg["c"], StatStyle.buy(can), "the cost number is green when affordable and red when not")
	var gain_seg: Dictionary = (ps["lines"] as Array)[(ps["lines"] as Array).size() - 1][2] as Dictionary
	t.eq(gain_seg["c"], StatStyle.BUY_GREEN, "the gain number is green")
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
	var body: Font = h._body.get_theme_font(&"font")
	t.ok(body != null and body.resource_path == TipHost.BODY_FONT, "tooltip body uses Spleen 6x12, not the default font")
	t.eq(h._body.get_theme_font_size(&"font_size"), 12, "tooltip body is 12 px, native size")
	var ttl: Font = h._title.get_theme_font(&"font")
	t.ok(ttl != null and ttl.resource_path == TipHost.TITLE_FONT, "tooltip title uses Pixelify Sans")
	t.ok(h.theme != null, "tooltip has a theme even before it borrows the HUD's")
	var th := Theme.new()
	var themed := Control.new()
	themed.theme = th
	root.add_child(themed)
	var inner := Control.new()
	themed.add_child(inner)
	h._adopt_theme(inner)
	t.ok(h.theme == th, "the tooltip borrows the theme of the control it describes, so it gets the game's fonts")
	themed.queue_free()
	# Minecraft-style: no delay, no grace, no fade. The tip is up the same frame the control is entered.
	h.request(c, false)
	t.ok(h.visible, "a hover tip shows at once, with no delay")
	h.dismiss()
	t.ok(not h.visible, "dismiss hides it")
	h.request(c, true)
	t.ok(h.visible, "a focus tip shows at once too")
	h.dismiss()

	# Stays on screen even when asked for far outside the corner.
	h.show_free({"title": "Pad", "body": "Costs a lot of something, so the box is wide enough to need wrapping."}, Vector2(99999, 99999))
	var view: Vector2 = h._view_size()
	t.ok(h.visible, "a free tip shows")
	t.ok(h.position.x >= 0.0 and h.position.y >= 0.0, "a free tip is not above or left of the screen")
	t.ok(h.position.x + h.size.x <= view.x and h.position.y + h.size.y <= view.y, "a free tip is not past the right or bottom edge")
	h.hide_free()
	t.ok(not h.visible, "hide_free hides it")

	# Hover: picked up on the frame the mouse is over a bound control, stays while it rests there, and is gone on
	# the very frame the mouse leaves. Sliding straight onto another bound control swaps on that same frame.
	h.dismiss()
	h.test_hover_enabled = true
	h.test_hover = c
	h._process(1.0 / 60.0)
	t.ok(h.target == c and h.visible, "a bound control under the mouse shows on the first frame, with no mouse_entered signal")
	var held: bool = true
	for i in 90:
		h._process(1.0 / 60.0)
		if not h.visible:
			held = false
	t.ok(held, "a hover tooltip stays visible for 1.5 s while the mouse rests on the control")
	var c2 := Control.new()
	c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c2)
	Tip.bind(c2, "two")
	h.test_hover = c2
	h._process(1.0 / 60.0)
	t.ok(h.target == c2 and h.visible, "moving straight onto another bound control swaps the tip on that frame")
	h.test_hover = null
	h._process(1.0 / 60.0)
	t.ok(not h.visible, "the tip hides on the same frame the mouse leaves the control")
	c2.queue_free()
	h.test_hover_enabled = false
	t.ok(Tip.normalize(null)["empty"], "a null spec is empty and shows nothing")
	t.ok(not Tip.normalize({"title": "x"})["empty"], "a titled spec is not empty")

	# Beside a slot: skips a spot that would cover an avoid panel.
	var wall := Rect2(430, 0, 200, 300)
	h.avoid_extra = [wall]
	h.show_free({"body": "Short"}, Vector2(400, 100), true)
	h.set_beside(Rect2(400, 100, 20, 20))
	h._process(1.0 / 60.0)
	t.ok(not Rect2(h.position, h.size).intersects(wall), "a tooltip beside a slot stays off avoid panels")
	h.hide_free()
	h.avoid_extra = []

	c.queue_free()
	h.queue_free()
