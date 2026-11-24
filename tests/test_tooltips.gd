extends RefCounted
## Tooltip system: spec normalising, bind bookkeeping, instant show and hide, and staying on screen.

func run(t: Object) -> void:
	test_live_gain(t)
	test_index_tips(t)
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
	var can: bool = sim.get_stat((sim.button_defs[bid] as ButtonDef).cost_stat).gte(sim.press_cost(sim.button_defs[bid] as ButtonDef))
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


## The pad tooltip's gain is what a press really pays: buffs, mastery, yield, heat all included, and it tracks changes.
func test_live_gain(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var id: StringName = sim.buttons_in_zone(sim.zone_id)[0].id
	var b: ButtonDef = sim.button_defs[id] as ButtonDef
	sim.god_mode = true
	sim.rng.seed = 1
	sim.tiers_open[sim.tier_of(id).id] = true
	var before: BigNum = sim.get_stat(b.reward_stat)
	var shown: BigNum = sim.press_gain_preview(id)
	var seg: Dictionary = ((PadTooltip.spec_for(sim, id)["lines"] as Array).back() as Array)[2] as Dictionary
	t.eq(seg["t"], "+%s" % shown.format(), "the tooltip prints the previewed gain")
	if sim.crit_chance(id) == 0.0 and sim.relics.total_effect(RelicDef.Effect.DOUBLE_CHANCE) == 0.0:
		sim.try_press(id)
		t.eq(sim.get_stat(b.reward_stat).sub(before).format(), shown.format(), "the tooltip gain equals what an actual press pays")
	sim.attr_levels[&"pad_yield"] = 3
	t.ok(sim.press_gain_preview(id).format() != shown.format() or sim.pad_yield_mult() == 1.0, "the tooltip gain follows attribute changes")


func test_index_tips(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rows: Array = StatIndex.stats(sim) + StatIndex.attributes(sim)
	var all_click: bool = not rows.is_empty()
	var all_named: bool = true
	for r: Variant in rows:
		var spec: Dictionary = TipText.index_row(r as Dictionary)
		all_named = all_named and str(spec["title"]) == str((r as Dictionary)["name"]) and str(spec["body"]) != ""
		all_click = all_click and str(spec["hint"]) == "Click to open!" and spec["hint_color"] == TipText.click_color()
	t.ok(all_click, "every index card ends with a yellow Click to open! line")
	t.ok(all_named, "every index card is titled with its name and has a description")
	t.ok(TipText.CLICK.r > 0.9 and TipText.CLICK.g > 0.8 and TipText.CLICK.b < 0.4, "the call to action is yellow")
	# A currency wears the rarity of the pads that pay it, under its name, as the pads' own tag does. Sunlight is the starter.
	var want: Dictionary = {&"sunlight": "STARTER STATISTIC", &"dewdrop": "COMMON STATISTIC", &"clover": "UNCOMMON STATISTIC",
		&"thistle": "RARE STATISTIC", &"heather": "EPIC STATISTIC", &"foxglove": "LEGENDARY STATISTIC", &"starbloom": "MYTHIC STATISTIC"}
	var seen_sunlight: bool = false
	var tags_ok: bool = true
	for r: Variant in StatIndex.stats(sim):
		var row: Dictionary = r as Dictionary
		var sid: StringName = row["id"]
		if not want.has(sid):
			continue
		seen_sunlight = seen_sunlight or sid == &"sunlight"
		var kick: Array = TipText.index_row(row)["kicker"] as Array
		tags_ok = tags_ok and not kick.is_empty() and str((kick[0] as Dictionary)["t"]) == str(want[sid])
	t.ok(seen_sunlight and tags_ok, "each pad-paid currency shows its rarity under the name, Sunlight as STARTER STATISTIC")
	t.eq(StatIndex.rarity_of_stat(sim, &"seeds"), "", "a currency no pad touches (Seeds) gets no rarity line")
	t.eq(StatIndex.rarity_of_stat(sim, &"embers"), "common", "Embers, spent by the common Cinder pads, reads Common")
	var pay_rarity: Dictionary = {}
	var one_rarity: bool = true
	for bid: StringName in sim.button_defs:
		var pb: ButtonDef = sim.button_defs[bid] as ButtonDef
		one_rarity = one_rarity and (not pay_rarity.has(pb.reward_stat) or pay_rarity[pb.reward_stat] == pb.rarity)
		pay_rarity[pb.reward_stat] = pb.rarity
	t.ok(one_rarity, "every pad that pays a currency has the same rarity, so the currency has one")
	var attrs: Array = StatIndex.attributes(sim)
	if not attrs.is_empty():
		t.ok(attrs[0].has("can") and attrs[0].has("currency_name") and attrs[0].has("now"), "attribute rows carry their level, effect and cost")
	var b_can: Dictionary = TipText.buy("rp", "Rebirth Points", "3", true, false)
	t.eq(b_can["hint"], "Click to buy!", "a Buy button you can afford says Click to buy!")
	t.eq(b_can["hint_color"], TipText.click_color(), "Click to buy! is yellow")
	t.ok(str(TipText.buy("rp", "Rebirth Points", "3", false, false)["hint"]).begins_with("Need"), "an unaffordable Buy says what is needed, with no yellow line")
	t.eq(TipText.buy("rp", "Rebirth Points", "3", false, true)["title"], "Max Level", "a maxed attribute's Buy says so")

	# The shared host reuses its nodes: the same spec shown again, or another spec, builds nothing new once warm.
	var h := TipHost.new()
	t.root.add_child(h)
	var spec_a: Dictionary = TipText.index_row(rows[0] as Dictionary)
	h._fill(spec_a)
	var warm: int = _nodes(h)
	h._fill(spec_a)
	t.eq(_nodes(h), warm, "showing the same tip again builds no new nodes")
	h._fill({"title": "Short", "body": "One line.", "lines": [["Now ", Tip.seg("1", StatStyle.gain())]]})
	h._fill(spec_a)
	t.eq(_nodes(h), warm, "switching tips reuses the pooled nodes")
	t.eq(h._root.get_theme_constant("separation"), TipHost.ROOMY_GAP, "a roomy tip spaces its sections out")
	h._fill({"title": "Plain", "body": "Tight."})
	t.eq(h._root.get_theme_constant("separation"), 2, "a plain tip keeps the tight spacing")
	h.free()

	# The Stats and Attributes gallery: no bottom info strip, no Prestige and RP header, and every card carries the tip.
	var host := Control.new()
	host.size = Vector2(640, 360)
	t.root.add_child(host)
	var panel := IndexPanel.new()
	host.add_child(panel)
	panel.bind(sim)
	panel.open_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(panel.get("_strip") == null and panel.get("_sub") == null, "the info strip and the stale header are gone")
	var tipped: bool = not panel._cards.is_empty()
	for c: Variant in panel._cards.values():
		tipped = tipped and (c as Control).has_meta(Tip.META)
	t.ok(tipped, "every card on the gallery is bound to the shared tooltip")
	host.free()


## Count every node under `n`, itself included.
func _nodes(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _nodes(ch)
	return c
