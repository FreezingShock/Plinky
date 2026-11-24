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
	t.near(interval, 2.0, 1e-6, "zone 1 pads press every 2 s (0.5 a second)")

	# Standing walker: the arrival press is immediate, then one every interval.
	var stand := PadPressTimer.new()
	stand.arm()
	var standing: int = _count(stand, 120.0, true, interval)

	# Held mouse: the click is its own press, then the same clock runs one interval later.
	var hold := PadPressTimer.new()
	hold.start(interval)
	var held: int = _count(hold, 120.0, true, interval)

	t.ok(absi(standing - held) <= 1, "a held mouse and a standing walker press at the same rate (%d vs %d in 120 s)" % [held, standing])
	t.ok(absi(held - 60) <= 1, "a held pad repeats 60 times in 120 s at zone 1's rate (got %d)" % held)

	# Standing and holding at once share one clock, so they do not double the rate.
	var both := PadPressTimer.new()
	both.start(interval)
	var doubled: int = _count(both, 120.0, true, interval)
	t.ok(absi(doubled - held) <= 1, "standing on a pad while holding it does not press twice as often (%d)" % doubled)

	# A repeat comes one interval after the click, not sooner.
	var first := PadPressTimer.new()
	first.start(interval)
	t.eq(_count(first, interval - 0.1, true, interval), 0, "no repeat before one interval after the click")

	# Off the pad, nothing fires, and the arrival press is immediate again.
	var away := PadPressTimer.new()
	away.arm()
	t.eq(_count(away, 10.0, false, interval), 0, "nothing presses while the pad is not pressed")
	t.ok(away.step(DT, true, interval), "arriving on the pad presses at once")
