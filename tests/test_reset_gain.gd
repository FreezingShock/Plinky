extends RefCounted
## Zone reset payouts and prestige gain on BigNum. Inside the float range they must match the float formula the sim used
## before (floor(pay_scale * sqrt(source / ref)), then the effect, then min_pay); past it they must still come out right
## instead of overflowing to inf or saturating an int.


func run(t: Object) -> void:
	# The BigNum helpers the payouts are built from.
	t.near(BigNum.make(4.0, 0).sqrt_big().to_float(), 2.0, 1e-15, "sqrt of 4 is 2")
	t.near(BigNum.make(1.0, 2).sqrt_big().to_float(), 10.0, 1e-12, "sqrt of 100 is 10")
	t.near(BigNum.make(2.0, 1).sqrt_big().to_float(), sqrt(20.0), 1e-12, "sqrt of 20")
	t.near(BigNum.make(1.0, 40).sqrt_big().e + log(BigNum.make(1.0, 40).sqrt_big().m) / log(10.0), 20.0, 1e-9, "sqrt of 1e40 is 1e20 with an even split")
	t.near(BigNum.make(1.0, 41).sqrt_big().e + log(BigNum.make(1.0, 41).sqrt_big().m) / log(10.0), 20.5, 1e-9, "sqrt of 1e41 halves an odd exponent")
	t.eq(BigNum.zero().sqrt_big().is_zero(), true, "sqrt of zero is zero")
	t.eq(BigNum.from_float(3.7).floor_big().to_float(), 3.0, "floor drops the fraction")
	t.eq(BigNum.from_float(-0.5).floor_big().to_float(), -1.0, "floor of a negative fraction goes down")
	t.eq(BigNum.make(2.5, 20).floor_big().e, 20, "a huge value is already whole")
	t.eq(BigNum.from_float(1234.0).whole_text(), "1234", "whole text is exact digits below 1e15")
	t.eq(BigNum.zero().whole_text(), "0", "whole text of zero")
	t.eq(BigNum.make(1.0, 20).whole_text(), BigNum.make(1.0, 20).format(), "huge whole text uses the short format")

	var sim: Sim = t.make_sim()
	# Normal values: every reset, a grid of source amounts, against the float formula the sim used before.
	for rid: StringName in [&"bloom", &"nucleus"]:
		var r: ZoneResetDef = sim.reset_defs[rid] as ZoneResetDef
		sim.gates_open[r.gate_zone] = true
		var ref: float = sim.reset_ref(rid)
		var mismatches: int = 0
		var checked: int = 0
		for k: int in range(0, 400):
			for frac: float in [1.0, 1.5, 2.0]:
				var stat: BigNum = BigNum.from_float(ref * float(k * k) * frac)
				sim.stats[r.source_stat] = stat
				checked += 1
				# Payouts are whole numbers. BigNum returns them within a rounding step, so compare rounded.
				if roundf(sim.reset_gain(rid).to_float()) != _legacy_gain(sim, r, rid, stat.to_float()):
					mismatches += 1
		t.eq(mismatches, 0, "%s pays exactly what the float formula paid across %d source amounts" % [rid, checked])
		sim.stats[r.source_stat] = BigNum.zero()
		t.eq(sim.reset_gain(rid).to_float(), 0.0, "%s pays nothing from an empty source" % rid)

	# Past the float range: a source of 3e400 still pays, with the right magnitude.
	var bloom: ZoneResetDef = sim.reset_defs[&"bloom"] as ZoneResetDef
	sim.stats[bloom.source_stat] = BigNum.make(3.0, 400)
	var got: BigNum = sim.reset_gain(&"bloom")
	var want_log10: float = log(bloom.pay_scale) / log(10.0) \
			+ 0.5 * (log(3.0) / log(10.0) + 400.0 - log(sim.reset_ref(&"bloom")) / log(10.0))
	t.ok(got.sign_of() > 0 and got.e < 10000, "a 3e400 source pays a finite amount")
	t.near(float(got.e) + log(got.m) / log(10.0), want_log10, 1e-9, "the huge payout has the magnitude of pay x sqrt(source / ref)")
	t.ok(sim.can_reset(&"bloom"), "a huge source can reset")

	# Prestige past the float range: the push term keeps growing instead of going to inf.
	var src: StringName = sim.prestige_source()
	sim.stats[src] = BigNum.make(5.0, 400)
	var gain: BigNum = sim.prestige_gain_preview()
	var th: float = sim.config.prestige_push_threshold
	var v_log10: float = 400.0 + log(5.0) / log(10.0)
	var want_gain_log10: float = v_log10 + 0.5 * (v_log10 - log(th) / log(10.0))
	t.ok(gain.sign_of() > 0 and gain.e < 10000, "a 5e400 stat gives a finite prestige gain")
	t.near(float(gain.e) + log(gain.m) / log(10.0), want_gain_log10, 1e-9, "prestige is v x sqrt(v / threshold) past the float range")


## The payout the float formula gave before the BigNum rewrite, from a float source amount. The floor allows a hair of
## float error (1e-9): the source stat is stored as a rounded mantissa, so a float sqrt can land a whisker under a whole
## number that the exact maths puts on it, and the old formula then paid one less.
func _legacy_gain(sim: Sim, r: ZoneResetDef, rid: StringName, v: float) -> float:
	var raw: float = r.pay_scale * sqrt(maxf(0.0, v) / sim.reset_ref(rid))
	var n: float = floorf(raw + 1e-9)
	if n < r.min_pay:
		return 0.0
	if r.pay_effect != &"":
		n = floorf(raw * (1.0 + sim.effect_total(r.pay_effect)) + 1e-9)
	return n
