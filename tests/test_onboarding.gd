extends RefCounted
## Onboarding: staged unlocks, tip order and spacing, saving, old saves, tips off, and a greedy-play timeline.

const ALL: Array[StringName] = [Onboarding.F_DEWDROP, Onboarding.F_CLOVER_ROW, Onboarding.F_REBIRTH_BUTTON, Onboarding.F_UPGRADES, Onboarding.F_RELICS]


func run(t: Object) -> void:
	var cfg := OnboardingConfig.new()
	_stages(t, cfg)
	_saving(t, cfg)
	_old_save_and_off(t, cfg)
	_pointer(t)
	_timeline(t)


func _stages(t: Object, cfg: OnboardingConfig) -> void:
	var sim: Sim = t.make_sim()
	var ob := Onboarding.new(sim, cfg)
	var fired: Array = []
	ob.feature_unlocked.connect(func(f: StringName) -> void: fired.append(f))
	ob.update()
	for f: StringName in ALL:
		t.ok(not ob.is_unlocked(f), "fresh game hides %s" % f)
	t.eq(ob.next_tip(), &"", "no tip before the first-tip delay")
	sim.step(cfg.first_tip_delay + 0.1)
	t.eq(ob.next_tip(), &"welcome", "welcome comes first")
	t.ok(ob.tip_text(&"welcome").contains("10"), "welcome names the starting Cash")
	ob.tip_shown(&"welcome")
	t.eq(ob.next_tip(), &"", "a shown tip is not offered again")

	t.ok(sim.try_press(&"sprout_1"), "press m1")
	ob.update()
	t.ok(ob.is_unlocked(Onboarding.F_DEWDROP), "first press shows the Multiplier row")
	t.ok(not ob.is_unlocked(Onboarding.F_CLOVER_ROW), "rebirth row still hidden")
	t.eq(fired.count(Onboarding.F_DEWDROP), 1, "feature_unlocked fired once for the Multiplier row")
	t.ok(not fired.has(Onboarding.F_CLOVER_ROW), "no other core system fired yet")
	t.eq(ob.next_tip(), &"", "an urgent tip still waits out the urgent gap")
	sim.step(cfg.urgent_gap_seconds + 0.1)
	t.eq(ob.next_tip(), &"first_press", "first press tip follows")
	ob.tip_shown(&"first_press")

	sim.stats[&"dewdrop"] = BigNum.from_float(cfg.clover_reveal_dewdrops - 1.0)
	ob.update()
	t.ok(not ob.is_unlocked(Onboarding.F_CLOVER_ROW), "below the reveal Multiplier, rebirth row stays hidden")
	sim.stats[&"dewdrop"] = BigNum.from_float(cfg.clover_reveal_dewdrops)
	ob.update()
	t.ok(ob.is_unlocked(Onboarding.F_CLOVER_ROW), "at the reveal Multiplier the rebirth row appears")
	sim.stats[&"dewdrop"] = BigNum.zero()
	ob.update()
	t.ok(ob.is_unlocked(Onboarding.F_CLOVER_ROW), "an unlocked system stays unlocked when the stat falls")
	t.ok(not ob.is_unlocked(Onboarding.F_REBIRTH_BUTTON), "Rebirth action hidden until it is possible")

	sim.stats[&"clover"] = BigNum.from_float(1.0)
	ob.update()
	t.ok(ob.is_unlocked(Onboarding.F_REBIRTH_BUTTON), "Rebirth action appears at 1 Rebirth")
	t.ok(not ob.is_unlocked(Onboarding.F_UPGRADES), "Upgrades wait for the first rebirth")
	t.ok(sim.try_rebirth(), "rebirth")
	ob.update()
	t.ok(ob.is_unlocked(Onboarding.F_UPGRADES), "first rebirth shows Prestige and Upgrades")

	# Relics: a press may already have dropped one, so test the rule on a fresh game.
	var rsim: Sim = t.make_sim()
	var rob := Onboarding.new(rsim, cfg)
	rob.update()
	t.ok(not rob.is_unlocked(Onboarding.F_RELICS), "relics hidden before a drop")
	rsim.relics.add_relic(&"r_rate")
	rob.update()
	t.ok(rob.is_unlocked(Onboarding.F_RELICS), "first relic shows the Relics button")

	var done: Array = []
	ob.completed.connect(func() -> void: done.append(true))
	t.ok(not ob.is_complete(), "not complete before the gate opens")
	sim.gates_open[&"zone1"] = true
	ob.update()
	ob.update()
	t.ok(ob.is_complete() and done.size() == 1, "gate opening completes onboarding once")
	sim.gates_open.clear()

	# urgent tips: a critter jumps the queue (after the urgent gap)
	sim.step(cfg.urgent_gap_seconds + 0.1)
	for id: StringName in [&"first_press", &"rebirth_button", &"upgrades", &"relic", &"clover_row", &"walk", &"streak", &"welcome"]:
		ob.tip_shown(id)
	sim.step(cfg.urgent_gap_seconds + 0.1)
	sim.critter_active = true
	t.eq(ob.next_tip(), &"critter", "critter tip appears while a critter is out")
	t.ok(ob.is_urgent(&"critter") and not ob.is_urgent(&"walk"), "urgency flags")
	ob.tip_shown(&"critter")
	sim.gates_open[&"zone1"] = true
	sim.step(cfg.urgent_gap_seconds + 0.1)
	t.eq(ob.next_tip(), &"gate_open", "gate tip appears once the gate opens")
	t.ok(ob.tip_text(&"gate_open").contains("Larkmoor"), "gate tip names the next zone")
	for id: StringName in [&"rebirth_button", &"upgrades", &"relic", &"first_press", &"clover_row", &"walk", &"streak", &"critter", &"welcome", &"gate_open"]:
		t.ok(ob.tip_text(id) != "" and ob.tip_title(id) != "", "tip %s has a title and text" % id)
		t.ok(not ob.tip_text(id).contains("Plinko"), "tip %s avoids the banned word" % id)


func _saving(t: Object, cfg: OnboardingConfig) -> void:
	var sim: Sim = t.make_sim()
	var ob := Onboarding.new(sim, cfg)
	ob.update()
	sim.try_press(&"sprout_1")
	ob.update()
	ob.tip_shown(&"welcome")
	var d: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 100.0))
	var sim2: Sim = t.make_sim()
	t.ok(sim2.from_dict(d["game"]), "load")
	var ob2 := Onboarding.new(sim2, cfg)
	t.ok(ob2.is_unlocked(Onboarding.F_DEWDROP), "unlocked systems survive a save")
	t.ok(ob2.is_seen(&"welcome"), "seen tips survive a save")
	t.ok(not ob2.is_seen(&"walk"), "unseen tips stay unseen")
	sim2.new_game()
	t.ok(not Onboarding.new(sim2, cfg).is_unlocked(Onboarding.F_DEWDROP), "a new game starts hidden again")


func _old_save_and_off(t: Object, cfg: OnboardingConfig) -> void:
	# A save from before onboarding has no ui_flags. The player is not taught, and what they have is visible.
	var old: Sim = t.make_sim()
	old.press_count = 80
	old.play_seconds = 600.0
	old.rebirth_count = 2
	old.stats[&"clover"] = BigNum.from_float(3.0)
	var ob := Onboarding.new(old, cfg)
	ob.update()
	old.step(200.0)
	t.eq(ob.next_tip(), &"", "an old save gets no tips")
	for f: StringName in [Onboarding.F_DEWDROP, Onboarding.F_CLOVER_ROW, Onboarding.F_REBIRTH_BUTTON, Onboarding.F_UPGRADES]:
		t.ok(ob.is_unlocked(f), "an old save shows %s" % f)
	ob.replay_tips()
	t.ok(not ob.is_seen(&"first_press"), "replay forgets seen tips")
	t.ok(ob.tips_enabled, "replay turns tips on")

	# A new game that presses before its first update (0.1 s in) is not an old save.
	var quick: Sim = t.make_sim()
	quick.step(0.1)
	quick.try_press(&"sprout_1")
	var qob := Onboarding.new(quick, cfg)
	qob.update()
	quick.step(cfg.first_tip_delay + cfg.urgent_gap_seconds)
	t.eq(qob.next_tip(), &"first_press", "an early press still gets its tips")

	# Tips off: nothing is offered and every system shows.
	var fresh: Sim = t.make_sim()
	var off := Onboarding.new(fresh, cfg)
	off.tips_enabled = false
	off.update()
	fresh.step(60.0)
	t.eq(off.next_tip(), &"", "tips off offers nothing")
	for f: StringName in ALL:
		t.ok(off.is_unlocked(f), "tips off shows %s" % f)
	off.tips_enabled = true
	t.ok(not off.is_unlocked(Onboarding.F_RELICS), "tips back on hides what is not unlocked")

	# The shipped config loads and is sane.
	var shipped: OnboardingConfig = Onboarding.load_config()
	t.ok(shipped.clover_reveal_dewdrops > 0.0 and shipped.tip_gap_seconds > shipped.urgent_gap_seconds, "shipped pacing config is sane")


## Greedy play at the zone's own press rate. Checks the order and rough timing of the first ten minutes.
func _timeline(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var ob := Onboarding.new(sim, Onboarding.load_config())
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(sim.zone_id)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		return Formulas.button_cost(a).to_float() > Formulas.button_cost(b).to_float())
	var when: Dictionary = {}    # feature -> minutes
	var tips: Array = []         # [id, seconds]
	var secs: float = 0.0
	var next_press: float = 3.0  # a real player reads the welcome and walks over first
	var gate_at: float = -1.0
	while secs < 20.0 * 60.0 and (gate_at < 0.0 or secs < gate_at + 30.0):
		sim.step(0.1)
		secs += 0.1
		if secs >= next_press:
			next_press += sim.press_interval()
			for b: ButtonDef in buttons:
				if sim.try_press(b.id):
					break
		ob.update()
		for f: StringName in ALL:
			if not when.has(f) and ob.is_unlocked(f):
				when[f] = secs / 60.0
		var id: StringName = ob.next_tip()
		if id != &"":
			ob.tip_shown(id)
			tips.append([id, secs])
		if gate_at < 0.0 and sim.is_gate_open(sim.zone_id):
			gate_at = secs
	t.ok(gate_at > 0.0, "greedy play opens the gate within 20 minutes")
	t.ok(gate_at / 60.0 <= 12.0, "greedy play opens the gate by minute 12 (got %.1f)" % (gate_at / 60.0))
	t.ok(when.get(Onboarding.F_DEWDROP, 99.0) <= 0.2, "Multiplier row shows in the first seconds")
	var row: float = when.get(Onboarding.F_CLOVER_ROW, 99.0)
	var btn: float = when.get(Onboarding.F_REBIRTH_BUTTON, 99.0)
	t.ok(row >= 1.5 and row <= 6.0, "rebirth row appears between minute 1.5 and 6 (got %.1f)" % row)
	t.ok(btn >= 3.0 and btn <= 9.0, "Rebirth action appears between minute 3 and 9 (got %.1f)" % btn)
	t.ok(row < btn, "rebirth row appears before the Rebirth action")
	t.ok(when.get(Onboarding.F_RELICS, 99.0) <= 3.5, "first relic shows by minute 3.5")
	t.ok(not when.has(Onboarding.F_UPGRADES), "Upgrades stay hidden until the player rebirths")

	var order: Array = tips.map(func(p: Array) -> StringName: return p[0])
	t.eq(order[0] if not order.is_empty() else &"", &"welcome", "the first tip is the welcome")
	var last: int = -1
	t.ok(not order.has(&"rebirth_button"), "the Rebirth tip waits for Zone 2: the meadow runs on Bloom")
	for id: StringName in [&"welcome", &"first_press", &"clover_row", &"gate_open"]:
		var at: int = order.find(id)
		t.ok(at > last, "tip %s plays, in order" % id)
		last = maxi(last, at)
	var cfg: OnboardingConfig = ob.cfg
	for i in range(1, tips.size()):
		var gap: float = float(tips[i][1]) - float(tips[i - 1][1])
		t.ok(gap >= cfg.urgent_gap_seconds - 0.15, "tips %s and %s are at least the urgent gap apart" % [tips[i - 1][0], tips[i][0]])
		if not ob.is_urgent(tips[i][0]):
			t.ok(gap >= cfg.tip_gap_seconds - 0.15, "tip %s respects the normal gap" % tips[i][0])
	print("onboarding timeline (min): ", when, " tips: ", tips.map(func(p: Array) -> String: return "%s@%.0fs" % [p[0], p[1]]))


## The first-pad arrow is a child of the pad, so it shares its position. Its tip must hover just above the pad
## (the pad is 7 texels tall each way), at every point of the bob, not 30 texels off (the first version).
func _pointer(t: Object) -> void:
	for bob: float in [0.0, 1.0, 2.0, PadPointerShape.BOB_PX]:
		var tip: float = PadPointerShape.tip_y(bob)
		t.ok(tip <= -PadPointerShape.PAD_HALF_HEIGHT and tip >= -PadPointerShape.PAD_HALF_HEIGHT - 8.0, "arrow tip hovers within 8 texels above the pad (bob %.0f, tip %.0f)" % [bob, tip])
