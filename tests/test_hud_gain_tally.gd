extends RefCounted
## The HUD gain label's sum and timing (ui/hud_gain_tally.gd): gains add up per stat, the label holds HOLD seconds after the
## last gain, fades over OUT, and a gain after a finished run starts again from zero.


func run(t: Object) -> void:
	var tally := HudGainTally.new()
	var seeds := &"seeds"
	var five: BigNum = BigNum.from_float(5.0)

	# --- sums: gains of one stat add up into one number, with a plus sign
	tally.add(seeds, five, 0.0, false)
	tally.add(seeds, five, 1.0, false)
	tally.add(seeds, five, 2.0, false)
	t.eq(tally.total_text(seeds), "+" + BigNum.from_float(15.0).format(), "three gains of 5 read as +15")
	t.eq(tally.total_text(&"clover"), "", "a stat with no gain has no text")

	# --- timing: held through HOLD after the last gain, then fading out over OUT
	t.near(tally.alpha(seeds, 2.5), 1.0, 1e-6, "the label stays fully shown during the hold")
	t.near(tally.alpha(seeds, 2.0 + HudGainTally.HOLD), 1.0, 1e-6, "the hold lasts exactly HOLD seconds")
	t.near(tally.alpha(seeds, 2.0 + HudGainTally.HOLD + HudGainTally.OUT * 0.5), 0.5, 1e-6, "halfway through the fade the label is half shown")
	t.near(tally.alpha(seeds, 2.0 + HudGainTally.HOLD + HudGainTally.OUT + 1.0), 0.0, 1e-6, "after the fade the label is gone")

	# --- a gain during the hold keeps adding to the same number and restarts the hold
	tally.add(seeds, five, 4.0, false)
	t.eq(tally.total_text(seeds), "+" + BigNum.from_float(20.0).format(), "a gain during the hold keeps adding to the run")
	t.near(tally.alpha(seeds, 4.0 + HudGainTally.HOLD - 0.1), 1.0, 1e-6, "the hold restarts from the newest gain")
	t.near(tally.age(seeds, 4.0), 4.0, 1e-6, "the run's age counts from its first gain, so the label animates in once")

	# --- a gain after the run has animated out starts a new run from zero
	var gone: float = 4.0 + HudGainTally.HOLD + HudGainTally.OUT + 2.0
	tally.add(seeds, five, gone, false)
	t.eq(tally.total_text(seeds), "+" + five.format(), "a gain after the run has ended starts again from zero")
	t.near(tally.age(seeds, gone), 0.0, 1e-6, "a new run animates in from its own first gain")

	# --- a crit anywhere in a run shows as "!" until the run ends
	tally.add(seeds, five, gone + 0.5, true)
	t.ok(tally.total_text(seeds).ends_with("!"), "a crit in the run marks the number with !")

	# --- zero gains do nothing
	var clover := &"clover"
	tally.add(clover, BigNum.zero(), 0.0, false)
	t.eq(tally.total_text(clover), "", "a zero gain starts no run")
	t.near(tally.alpha(clover, 0.0), 0.0, 1e-6, "a zero gain shows nothing")

	# --- prune forgets runs that have animated out, and keeps live ones
	var sunlight := &"sunlight"
	tally.add(clover, five, 10.0, false)
	tally.add(sunlight, five, 13.5, false)
	tally.prune(14.0)
	t.eq(tally.total_text(clover), "", "a run that has animated out is pruned")
	t.ok(tally.total_text(sunlight) != "", "a run still within its hold is kept")
