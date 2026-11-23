class_name NumberFormat
extends RefCounted
## The one canonical number formatter. BigNum.format() and every UI label call this.
## Full digits to 999, then suffixes from suffix_for() (K M B T Qd Qn Sx Sp Oc No Dc UDc ... up to 1e3003),
## then e-notation.

const SMALL: PackedStringArray = ["K", "M", "B", "T"]
## Short-scale -illion names, abbreviated. n = group - 1 (million = 1 ... quadrillion = 4).
const N_SMALL: PackedStringArray = ["", "", "", "", "Qd", "Qn", "Sx", "Sp", "Oc", "No"]
const UNITS: PackedStringArray = ["", "U", "D", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"]
const TENS: PackedStringArray = ["", "Dc", "Vg", "Tg", "Qg", "Qq", "Sg", "St", "Og", "Ng"]
const HUNDREDS: PackedStringArray = ["", "Ce", "Dn", "Tc", "Qe", "Qi", "Se", "Sm", "Oe", "Ne"]
## How big numbers are written. Set from the settings menu (Gameplay > Number format). Below 1000 all styles agree.
enum Style { SUFFIX, SCIENTIFIC, ENGINEERING }
static var style: int = Style.SUFFIX

## How multipliers read: a factor ("x1.5") or a percent ("150%"). Set from Settings > Gameplay > Multiplier display.
enum MultStyle { FACTOR, PERCENT }
static var mult_style: int = MultStyle.FACTOR


## A multiplier as text in the chosen style: 1.5 -> "x1.5" or "150%".
static func mult(m: BigNum) -> String:
	if mult_style == MultStyle.PERCENT:
		return "%s%%" % m.mul(BigNum.from_float(100.0)).format()
	return "x%s" % m.format()


static func mult_f(m: float) -> String:
	return mult(BigNum.from_float(m))


## Highest group with a name: n = 999, i.e. 10^3003. Past that, e-notation.
const MAX_GROUP: int = 1000


## Suffix for 10^(3*group). K, M, B, T, then Conway-Wechsler-style names built from
## units + tens + hundreds: Qd Qn Sx Sp Oc No Dc UDc DDc TDc QdDc ... Vg ... Tg ... Ce ... UDcCe ...
## Generated, not tabulated, so it goes to 10^3003 with no list to maintain.
static func suffix_for(group: int) -> String:
	if group < 1 or group > MAX_GROUP:
		return ""
	if group <= 4:
		return SMALL[group - 1]
	var n: int = group - 1
	if n < 10:
		return N_SMALL[n]
	return UNITS[n % 10] + TENS[(n / 10) % 10] + HUNDREDS[n / 100]


## Compatibility entry point for float callers (ui/fx).
static func short(n: float) -> String:
	return format(BigNum.from_float(n))


static func format(b: BigNum) -> String:
	if b.m == 0.0:
		return "0"
	var s: String = _fmt_abs(absf(b.m), b.e)
	return "-" + s if b.m < 0.0 else s


static func _trim(v: float, decimals: int) -> String:
	var s: String = ("%." + str(decimals) + "f") % v
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s


static func _sci(am: float, ex: int) -> String:
	return _trim(am, 2) + "e" + str(ex)


static func _fmt_abs(am: float, ex: int) -> String:
	if ex < 3:
		var v: float = am * pow(10.0, float(ex))
		if v >= 999.5:
			return _fmt_abs(v / 1000.0, 3)
		if v >= 100.0:
			return str(roundi(v))
		if v >= 10.0:
			return _trim(v, 1)
		return _trim(v, 2)
	if style == Style.SCIENTIFIC:
		return _sci(am, ex)
	if style == Style.ENGINEERING:
		return _trim(am * pow(10.0, float(ex % 3)), 2) + "e" + str(ex - ex % 3)
	var idx: int = ex / 3  # 1 = first suffix
	var scaled: float = am * pow(10.0, float(ex % 3))
	if snappedf(scaled, 0.01) >= 1000.0:
		scaled /= 1000.0
		idx += 1
	if idx > MAX_GROUP:
		return _sci(am, ex)
	var digits: String = _trim(scaled, 2) if scaled < 100.0 else _trim(scaled, 1)
	return digits + suffix_for(idx)
