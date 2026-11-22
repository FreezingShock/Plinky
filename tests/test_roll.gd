extends RefCounted

func run(t: Object) -> void:
	# step() eases toward the target and lands on it
	var s: BigNum = BigNum.zero()
	var to: BigNum = BigNum.from_float(1000.0)
	var first: BigNum = RollValue.step(s, to, 1.0 / 30.0)
	t.ok(first.gt(s) and first.lt(to), "step moves partway")
	var n: int = 0
	while not s.eq(to) and n < 400:
		s = RollValue.step(s, to, 1.0 / 30.0)
		n += 1
	t.ok(s.eq(to) and n < 400, "step reaches the target")
	# rolls down too (spending, rebirth reset)
	var d: BigNum = RollValue.step(BigNum.from_float(500.0), BigNum.zero(), 1.0 / 30.0)
	t.ok(d.lt(BigNum.from_float(500.0)) and d.gt(BigNum.zero()), "step rolls down")
	# works at huge magnitudes
	var big: BigNum = RollValue.step(BigNum.make(1.0, 60), BigNum.make(2.0, 60), 1.0 / 30.0)
	t.ok(big.gt(BigNum.make(1.0, 60)) and big.lt(BigNum.make(2.0, 60)), "step at 1e60")
	# gain ratio
	t.eq(RollValue.gain_ratio(BigNum.zero(), BigNum.one()), 1.0, "gain onto zero counts as 1")
	t.ok(absf(RollValue.gain_ratio(BigNum.from_float(100.0), BigNum.from_float(25.0)) - 0.25) < 0.001, "gain ratio")
	# RollValue: first value is shown at once, small gains do not emit, big ones do
	var rv := RollValue.new()
	var got: Array[String] = []
	rv.big_gain.connect(func(a: BigNum) -> void: got.append(a.format()))
	rv.set_target(BigNum.from_float(100.0))
	t.eq(rv.text, "100", "first value is not rolled")
	rv.set_target(BigNum.from_float(102.0))
	t.eq(got.size(), 0, "small gain does not float")
	rv.set_target(BigNum.from_float(202.0))
	t.eq(got, ["100"] as Array[String], "big gain floats once")
	# whole-number stats never show fractions while rolling
	rv.shown = BigNum.from_float(150.7)
	rv._show()
	t.eq(rv.text, "150", "whole stat floors while rolling")
	rv.free()
	# setting is on by default
	t.ok(DisplaySettings.momentum_meter, "momentum meter defaults on")
