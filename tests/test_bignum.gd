extends RefCounted

func run(t: Object) -> void:
	var a := BigNum.from_float(1234.0)
	t.eq(a.e, 3, "exponent of 1234")
	t.near(a.m, 1.234, 1e-9, "mantissa of 1234")
	t.near(a.add(BigNum.from_float(766.0)).to_float(), 2000.0, 1e-9, "add")
	t.near(a.sub(BigNum.from_float(234.0)).to_float(), 1000.0, 1e-9, "sub")
	t.near(a.mul(BigNum.from_float(10.0)).to_float(), 12340.0, 1e-9, "mul")
	t.near(a.div(BigNum.from_float(2.0)).to_float(), 617.0, 1e-9, "div")
	t.near(BigNum.from_float(9.0).pow_f(0.8).to_float(), pow(9.0, 0.8), 1e-9, "pow_f 9^0.8")
	# 20 orders apart: the small term vanishes, the big one is unchanged
	var big := BigNum.make(1.0, 30)
	var small := BigNum.make(1.0, 10)
	t.ok(big.add(small).eq(big), "adding 20 orders smaller changes nothing")
	t.ok(small.add(big).eq(big), "add is symmetric across 20 orders")
	t.ok(BigNum.make(1.0, 400).gt(BigNum.make(9.9, 399)), "compare beyond float range")
	t.ok(BigNum.make(1.0, 400).mul(BigNum.make(1.0, 400)).e == 800, "multiply beyond float range")
	t.ok(BigNum.zero().is_zero(), "zero")
	t.ok(BigNum.from_float(5.0).sub(BigNum.from_float(7.0)).lt(BigNum.zero()), "negative result")
	t.ok(BigNum.from_float(5.0).sub(BigNum.from_float(7.0)).max_zero().is_zero(), "max_zero clamps")
	t.ok(BigNum.from_float(3.0).cmp(BigNum.from_float(3.0)) == 0, "cmp equal")
	var rt := BigNum.from_variant(BigNum.make(4.2, 77).to_array())
	t.ok(rt.eq(BigNum.make(4.2, 77)), "array round trip")
