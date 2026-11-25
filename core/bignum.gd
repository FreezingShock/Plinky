class_name BigNum
extends RefCounted
## Mantissa/exponent number for incremental-game values. Immutable by convention:
## every operation returns a new BigNum. Normalised so 1 <= |m| < 10, or m == 0 and e == 0.

const ADD_REACH: int = 17  # beyond this many orders apart, the smaller term is below float precision

var m: float = 0.0
var e: int = 0


static func make(mantissa: float, exponent: int = 0) -> BigNum:
	var b := BigNum.new()
	b.m = mantissa
	b.e = exponent
	b._normalize()
	return b


static func zero() -> BigNum:
	return BigNum.new()


static func one() -> BigNum:
	return BigNum.make(1.0, 0)


static func from_float(f: float) -> BigNum:
	return BigNum.make(f, 0)


## Accepts [m, e] arrays (the save format) or a plain number. Anything else gives the fallback.
static func from_variant(v: Variant, fallback: BigNum = null) -> BigNum:
	if v is Array and (v as Array).size() == 2:
		var a: Array = v
		if (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			return BigNum.make(float(a[0]), int(a[1]))
	elif v is float or v is int:
		return BigNum.from_float(float(v))
	return fallback if fallback != null else BigNum.zero()


func _normalize() -> void:
	if m == 0.0 or is_nan(m) or is_inf(m):
		if is_inf(m):
			m = signf(m) * 9.999999
			e = 308
		else:
			m = 0.0
			e = 0
		return
	var a: float = absf(m)
	if a >= 10.0 or a < 1.0:
		var shift: int = int(floor(log(a) / log(10.0)))
		m = m / pow(10.0, float(shift))
		e += shift
	# guard against float error at the edges
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	elif absf(m) < 1.0:
		m *= 10.0
		e -= 1


func copy() -> BigNum:
	var b := BigNum.new()
	b.m = m
	b.e = e
	return b


func is_zero() -> bool:
	return m == 0.0


func sign_of() -> int:
	return 0 if m == 0.0 else (1 if m > 0.0 else -1)


func neg() -> BigNum:
	var b := copy()
	b.m = -b.m
	return b


func add(o: BigNum) -> BigNum:
	if o.m == 0.0:
		return copy()
	if m == 0.0:
		return o.copy()
	var d: int = e - o.e
	if d > ADD_REACH:
		return copy()
	if d < -ADD_REACH:
		return o.copy()
	return BigNum.make(m + o.m * pow(10.0, float(-d)), e)


func sub(o: BigNum) -> BigNum:
	return add(o.neg())


func mul(o: BigNum) -> BigNum:
	if m == 0.0 or o.m == 0.0:
		return BigNum.zero()
	return BigNum.make(m * o.m, e + o.e)


func div(o: BigNum) -> BigNum:
	if o.m == 0.0:
		return BigNum.zero()  # callers never divide by zero on purpose; stay finite
	if m == 0.0:
		return BigNum.zero()
	return BigNum.make(m / o.m, e - o.e)


## Raise to a float power. Only defined for positive values; zero and negatives give zero.
func pow_f(p: float) -> BigNum:
	if m <= 0.0:
		return BigNum.zero()
	var l: float = (log(m) / log(10.0) + float(e)) * p
	var ex: float = floor(l)
	return BigNum.make(pow(10.0, l - ex), int(ex))


func cmp(o: BigNum) -> int:
	var sa: int = sign_of()
	var sb: int = o.sign_of()
	if sa != sb:
		return -1 if sa < sb else 1
	if sa == 0:
		return 0
	var r: int = 0
	if e != o.e:
		r = -1 if e < o.e else 1
	elif m != o.m:
		r = -1 if m < o.m else 1
	return r * sa


func gte(o: BigNum) -> bool:
	return cmp(o) >= 0


func gt(o: BigNum) -> bool:
	return cmp(o) > 0


func lt(o: BigNum) -> bool:
	return cmp(o) < 0


func lte(o: BigNum) -> bool:
	return cmp(o) <= 0


func eq(o: BigNum) -> bool:
	return cmp(o) == 0


func max_zero() -> BigNum:
	return BigNum.zero() if m < 0.0 else copy()


func to_float() -> float:
	if m == 0.0:
		return 0.0
	if e > 308:
		return INF * signf(m)
	if e < -300:
		return 0.0
	return m * pow(10.0, float(e))


## Square root of a non-negative value, sqrt(m * 10^e). The exponent is split first so the mantissa stays a float.
func sqrt_big() -> BigNum:
	if m <= 0.0:
		return BigNum.zero()
	var ex: int = e
	var mm: float = m
	if ex % 2 != 0:
		mm *= 10.0
		ex -= 1
	return BigNum.make(sqrt(mm), int(float(ex) / 2.0))


## The largest whole number not above this one. From 1e16 up every value is already whole. A value within float rounding
## of a whole number counts as that whole number: normalising the mantissa leaves a result like 15.999999999999998 where
## the exact value is 16.
func floor_big() -> BigNum:
	if m == 0.0 or e >= 16:
		return copy()
	if e < 0:
		return BigNum.from_float(-1.0) if m < 0.0 else BigNum.zero()
	var x: float = m * pow(10.0, float(e))
	var near: float = roundf(x)
	if absf(x - near) <= 1e-12 * maxf(1.0, absf(x)):
		return BigNum.from_float(near)
	return BigNum.from_float(floorf(x))


## Whole-number text for a payout: the exact digits below 1e15 with thousands commas ("858,100,000,000,000"),
## the usual short format above that.
func whole_text() -> String:
	return NumberFormat.exact(self)


func to_array() -> Array:
	return [m, e]


## Display text. Delegates to NumberFormat, the one canonical formatter.
func format() -> String:
	return NumberFormat.format(self)
