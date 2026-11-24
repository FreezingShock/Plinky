extends RefCounted
## Press streak tiers (core/press_streak.gd), the popup look tables (ui/fx/popup_style.gd) and the relic pulse source.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var cfg: GameConfig = sim.config
	t.eq(cfg.popup_tier_names.size(), cfg.popup_tier_thresholds.size() + 1, "one tier name per threshold, plus Plain")
	t.eq(cfg.popup_tier_names.size(), PopupStyle.TIERS, "the popup style defines one look per tier name")
	for i in cfg.popup_tier_thresholds.size() - 1:
		t.ok(cfg.popup_tier_thresholds[i] < cfg.popup_tier_thresholds[i + 1], "thresholds rise")

	# --- streak: chain, boost, break
	var s := PressStreak.new()
	t.eq(s.tier, 0, "a fresh streak is Plain")
	var now: float = 100.0
	var seen: Array[int] = []
	for i in 400:
		now += 0.25
		var tier: int = s.feed(now, 0, cfg)
		if seen.is_empty() or seen[seen.size() - 1] != tier:
			seen.append(tier)
	var want: Array[int] = [0, 1, 2, 3, 4, 5]
	t.eq(seen, want, "a long chain climbs every tier in order and stops at Galaxy")
	var lost: int = s.expire(now + cfg.popup_streak_gap * 0.5, cfg)
	t.eq(lost, -1, "a short pause keeps the chain")
	lost = s.expire(now + cfg.popup_streak_gap + 0.1, cfg)
	t.eq(lost, 5, "a long pause reports the tier that was lost")
	t.eq(s.count, 0, "and the chain starts over")
	t.eq(s.expire(now + 99.0, cfg), -1, "an empty chain has nothing to lose")

	s.reset()
	for i in 6:
		now += 0.25
		s.feed(now, 0, cfg)
	var plain: int = s.tier
	s.reset()
	for i in 6:
		now += 0.25
		s.feed(now, 4, cfg)
	t.ok(s.tier > plain, "Surge momentum reaches a higher tier in the same number of presses")
	var before: int = s.tier
	s.feed(now + 0.25, 0, cfg)
	t.ok(s.tier >= before, "momentum falling mid-chain never takes a tier away")

	s.reset()
	s.feed(500.0, 0, cfg)
	s.feed(500.0 + cfg.popup_streak_gap + 1.0, 0, cfg)
	t.eq(s.count, 1, "a press after a long pause starts a new chain")
	t.near(s.time_left(500.0 + cfg.popup_streak_gap + 1.0, cfg), cfg.popup_streak_gap, 1e-6, "time_left is the full gap right after a press")

	var rose_at: int = -1
	s.reset()
	for i in 12:
		s.feed(900.0 + 0.2 * float(i), 0, cfg)
		if s.rose and rose_at < 0:
			rose_at = s.count
	t.eq(rose_at, int(ceilf(cfg.popup_tier_thresholds[0])), "rose is set on the press that crosses the first threshold")

	# --- look tables
	for id in PopupStyle.EASE_COUNT:
		t.near(PopupStyle.ease_fn(id, 0.0), 0.0, 1e-6, "ease %d starts at 0" % id)
		t.near(PopupStyle.ease_fn(id, 1.0), 1.0, 1e-6, "ease %d ends at 1" % id)
	for tier in PopupStyle.TIERS:
		var m: int = PopupStyle.pick_motion(tier, 0.0)
		var m2: int = PopupStyle.pick_motion(tier, 0.999)
		t.ok(m >= 0 and m2 >= 0, "tier %d picks a motion at both ends of the roll" % tier)
		for mo in PopupStyle.Motion.values():
			var o0: Vector2 = PopupStyle.motion_offset(mo, 0.0, 77, 1.0, 20.0, 1)
			var o1: Vector2 = PopupStyle.motion_offset(mo, 1.0, 77, 1.0, 20.0, 1)
			t.ok(absf(o0.x) < 12.0 and o0.y <= 20.0 and o1.y <= 0.0, "motion %d stays inside the lane (start %s, end %s)" % [mo, o0, o1])
		for i in 8:
			var c: Color = PopupStyle.char_color(tier, i, 8, 0.37 * float(i), 1234 + i, "meadow")
			t.ok(c.a == 1.0, "tier %d letter colours are opaque" % tier)
		t.ok(PopupStyle.spark_colors(tier, "meadow").size() >= 2, "tier %d has sparkle colours" % tier)
		t.ok(PopupStyle.size_index(tier, true, false, 2) <= PopupStyle.SIZES.size() - 1, "size index stays in range")
		t.ok(PopupStyle.size_index(tier, false, true, 0) >= 0, "a pulse popup never goes below the smallest size")
		t.ok(PopupStyle.glitch_x(tier, 5, 3, 0.4, true) == 0.0, "calm turns the glitch off")
	t.ok(PopupStyle.size_index(5, false, false, 0) > PopupStyle.size_index(0, false, false, 0), "a higher tier reads bigger")
	t.ok(PopupStyle.rise_for(5, 3) > PopupStyle.rise_for(0, 3), "a higher tier floats further")
	for k in 200:
		var h: float = PopupStyle.hash01(k, k * 7)
		t.ok(h >= 0.0 and h <= 1.0, "hash01 stays in 0 to 1")
	var distinct: Dictionary = {}
	for tier in PopupStyle.TIERS:
		distinct[PopupStyle.char_color(tier, 2, 8, 0.31, 11, "meadow").to_html()] = true
	t.ok(distinct.size() >= 4, "tiers look different from each other")

	# --- relic pulse tells the world which pad started it
	var sim2: Sim = t.make_sim()
	sim2.god_mode = true
	sim2.relics.add_relic(&"r_pulse", 12)
	t.ok(sim2.relics.equip(&"r_pulse"), "pulse relic equips")
	var src: StringName = &""
	for b: ButtonDef in sim2.button_defs.values():
		if b.zone != sim2.zone_id or sim2.is_pad_locked(b.id):
			continue
		for o: ButtonDef in sim2.button_defs.values():
			if o.zone == b.zone and o.row == b.row and absi(o.row_index - b.row_index) == 1:
				src = b.id
				break
		if src != &"":
			break
	t.ok(src != &"", "the first zone has a pad with a row neighbour")
	var pulsed: Array = []
	var direct: Array = []
	sim2.button_pressed.connect(func(id: StringName, _w: Vector3, _g: BigNum, _c: bool) -> void:
		if sim2.pulse_source != &"":
			pulsed.append([id, sim2.pulse_source, sim2.pulse_order])
		else:
			direct.append(id))
	for i in 300:
		sim2.try_press(src)
	t.ok(pulsed.size() > 0, "a 52% pulse relic fires within 300 presses")
	t.eq(direct.size(), 300, "the pad you press is never reported as a pulse")
	var ok_src: bool = true
	var ok_other: bool = true
	for e: Array in pulsed:
		ok_src = ok_src and e[1] == src
		ok_other = ok_other and e[0] != src and int(e[2]) >= 0
	t.ok(ok_src and ok_other, "pulse presses name their source and hit other pads")
	t.eq(sim2.pulse_source, &"", "pulse_source clears after the press")

	# --- popup text: crisp glyphs and stepped fades (no half-transparent letters)
	var theme: Theme = load("res://theme/plinky_theme.tres") as Theme
	t.ok(theme != null, "the plinky theme loads")
	var pf: Font = CrispFont.theme_font(theme, &"PopupLabel")
	t.ok(pf is FontFile, "the popup face is a font file")
	if pf is FontFile:
		var ff: FontFile = pf as FontFile
		t.eq(ff.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "popup glyphs render without grey anti-aliasing")
		t.eq(ff.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED, "popup glyphs sit on whole pixels")
	t.ok(PopupStyle.shows_now(0.2, 0.3, true) and PopupStyle.shows_now(0.69, 0.5, true), "a popup is solid until its last 30%")
	var tail_on: int = 0
	var tail_off: int = 0
	var tail_solid: bool = true
	for i in 60:
		var age: float = 0.5 + float(i) * 0.02
		if PopupStyle.shows_now(0.85, age, true):
			tail_on += 1
		else:
			tail_off += 1
		tail_solid = tail_solid and PopupStyle.shows_now(0.85, age, false)
	t.ok(tail_on > 0 and tail_off > 0, "the last 30% blinks off and on in whole steps")
	t.ok(tail_solid, "Reduce Flashing keeps the popup solid to its end, with no blink")

	# --- pad captions stay readable on dark rock
	var rock: Color = Color("8a3a2e")   # the mid quarry rock palette entry, where captions sit
	t.ok(_contrast(StatStyle.COLORS[&"ironore"] as Color, rock) < 3.5, "the old Iron Ore caption colour was under 3.5:1 on rock")
	var worst: float = 99.0
	for id: StringName in StatStyle.COLORS.keys():
		worst = minf(worst, _contrast(PopupStyle.caption_color(StatStyle.COLORS[id] as Color), rock))
	t.ok(worst >= 4.0, "every stat caption keeps 4:1 contrast on the quarry rock (worst %.2f)" % worst)


## WCAG relative contrast between two colours, for the caption test.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
