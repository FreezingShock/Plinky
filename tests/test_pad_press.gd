extends RefCounted
## Pad press clock (core/pad_press_timer.gd, used by world/texel_pad.gd). A walker standing on a pad and a mouse
## held on it share one clock at Sim.press_interval(), so they press at the same rate. Pure: fake frame times, no nodes.

const DT: float = 1.0 / 60.0


func _count(clock: PadPressTimer, seconds: float, pressing: bool, interval: float) -> int:
	var n: int = 0
	for i: int in int(round(seconds / DT)):
		if clock.step(DT, pressing, interval):
			n += 1
	return n


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var interval: float = sim.press_interval()
	t.near(interval, 0.25, 1e-6, "zone 1 pads press four times a second (0.25 s apart)")

	# Standing walker: the arrival press is immediate, then one every interval.
	var stand := PadPressTimer.new()
	stand.arm()
	var standing: int = _count(stand, 20.0, true, interval)

	# Held mouse: the click is its own press, then the same clock runs one interval later.
	var hold := PadPressTimer.new()
	hold.start(interval)
	var held: int = _count(hold, 20.0, true, interval)

	t.ok(absi(standing - held) <= 2, "a held mouse and a standing walker press at the same rate (%d vs %d in 20 s)" % [held, standing])
	# A 0.25 s interval at 60 Hz lands every 15 or 16 frames, so 20 s gives 75 to 80 presses.
	t.ok(absi(held - 80) <= 6, "a held pad repeats about 80 times in 20 s at zone 1's rate (got %d)" % held)

	# Standing and holding at once share one clock, so they do not double the rate.
	var both := PadPressTimer.new()
	both.start(interval)
	var doubled: int = _count(both, 20.0, true, interval)
	t.ok(absi(doubled - held) <= 2, "standing on a pad while holding it does not press twice as often (%d)" % doubled)

	# A repeat comes one interval after the click, not sooner.
	var first := PadPressTimer.new()
	first.start(interval)
	t.eq(_count(first, interval - 0.05, true, interval), 0, "no repeat before one interval after the click")

	# Holding is a real press: the held clock presses the sim as often as a standing walker would.
	var sim2: Sim = t.make_sim()
	sim2.stats[&"sunlight"] = BigNum.from_float(1e30)   # enough stock to press all the way through
	var sim_interval: float = sim2.press_interval()
	var clock := PadPressTimer.new()
	clock.start(sim_interval)
	var sim_presses: int = 0
	for i: int in int(round(10.0 / DT)):
		if clock.step(DT, true, sim_interval) and sim2.try_press(&"sprout_1"):
			sim_presses += 1
	t.ok(absi(sim_presses - 40) <= 4, "a held pad presses the sim about 40 times in 10 s (got %d)" % sim_presses)

	# A player press pays press_scale of its old reward. Auto presses and pulses pay the full reward (see sim tests).
	var original_scale: float = sim2.config.press_scale   # the config resource may be shared, so put it back
	sim2.config.press_scale = 1.0
	var full: float = sim2.press_gain(&"sprout_1").to_float()
	sim2.config.press_scale = 0.125
	var scaled: float = sim2.press_gain(&"sprout_1").to_float()
	sim2.config.press_scale = original_scale
	t.near(scaled, full * 0.125, full * 1e-6 + 1e-9, "a press pays press_scale of its reward")

	# A player press needs the full pad price in stock, then charges press_scale of it. An automatic press needs and
	# pays the full price. The gate keeps the purchase order and the ready state the same as before.
	var sim3: Sim = t.make_sim(true)
	var full_cost: float = Formulas.button_cost(sim3.button_defs[&"sprout_1"] as ButtonDef).to_float()
	sim3.stats[&"sunlight"] = BigNum.from_float(full_cost - 1e-6)
	t.ok(not sim3.try_press(&"sprout_1"), "a player press needs the full pad price in stock")
	sim3.stats[&"sunlight"] = BigNum.from_float(full_cost)
	t.ok(sim3.try_press(&"sprout_1"), "a player press goes through on the full pad price")
	t.near(sim3.get_stat(&"sunlight").to_float(), full_cost * (1.0 - sim3.config.press_scale), 1e-6, "the player press charged press_scale of the pad price")
	sim3.stats[&"sunlight"] = BigNum.from_float(full_cost * sim3.config.press_scale + 1e-6)
	t.ok(not sim3._press(&"sprout_1", Vector3.ZERO, false), "an automatic press needs the full pad cost")

	# Off the pad, nothing fires, and the arrival press is immediate again.
	var away := PadPressTimer.new()
	away.arm()
	t.eq(_count(away, 10.0, false, interval), 0, "nothing presses while the pad is not pressed")
	t.ok(away.step(DT, true, interval), "arriving on the pad presses at once")
