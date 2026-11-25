extends RefCounted

func run(t: Object) -> void:
	t.eq(BigNum.from_float(0.0).format(), "0", "zero")
	t.eq(BigNum.from_float(0.25).format(), "0.25", "fraction")
	t.eq(BigNum.from_float(999.0).format(), "999", "full digits to 999")
	t.eq(BigNum.from_float(1000.0).format(), "1K", "1K")
	t.eq(BigNum.from_float(1234.0).format(), "1.23K", "1.23K")
	t.eq(BigNum.from_float(2.5e6).format(), "2.5M", "M")
	t.eq(BigNum.make(1.0, 9).format(), "1B", "B")
	t.eq(BigNum.make(1.0, 12).format(), "1T", "T")
	t.eq(BigNum.make(1.5, 15).format(), "1.5Qd", "Qd")
	t.eq(BigNum.make(1.0, 18).format(), "1Qn", "Qn")
	t.eq(BigNum.make(1.0, 33).format(), "1Dc", "Dc")
	t.eq(BigNum.make(1.0, 36).format(), "1UDc", "UDc")
	t.eq(BigNum.make(1.0, 42).format(), "1TDc", "TDc")
	t.eq(BigNum.make(1.0, 45).format(), "1QdDc", "QdDc")
	t.eq(BigNum.make(1.0, 63).format(), "1Vg", "Vg")
	t.eq(BigNum.make(1.0, 303).format(), "1Ce", "last suffix")
	t.eq(BigNum.make(1.0, 306).format(), "1UCe", "101st -illion is UCe")
	t.eq(BigNum.make(1.0, 336).format(), "1UDcCe", "units + tens + hundreds order")
	t.eq(NumberFormat.suffix_for(1000), "NoNgNe", "last named group")
	t.eq(NumberFormat.suffix_for(1001), "", "no name past the last group")
	t.eq(BigNum.make(1.23, 4000).format(), "1.23e4000", "scientific past the names")
	t.eq(BigNum.make(1.0, 80).format(), "100QnVg", "1e80 reads 100 QnVg, not a digit run")
	t.eq(BigNum.from_float(1e80).format(), "100QnVg", "float entry at 1e80")
	t.eq(BigNum.make(1.0, 3003).format(), "1e3003", "e-notation past the last suffix")
	t.eq(BigNum.make(1.0, 3000).format(), "1NoNgNe", "last suffix still reads as a suffix")
	t.eq(BigNum.from_float(999999.0).format(), "1M", "rounding carries into the next suffix")
	t.eq(NumberFormat.short(1500.0), "1.5K", "float entry point for ui/fx")
	t.eq(NumberFormat.short(1.5e15), "1.5Qd", "popup entry point reads 1.5e15 as 1.5Qd")
	t.eq(NumberFormat.short(1.0e80), "100QnVg", "popup entry point reads 1e80 as 100QnVg")
	# Three significant figures from 1 up to the next suffix: 1.23K, 12.3K, 123K. Carries at 999.5.
	t.eq(BigNum.from_float(123400.0).format(), "123K", "123K, not 123.4K")
	t.eq(BigNum.from_float(1234567.0).format(), "1.23M", "1.23M")
	t.eq(BigNum.from_float(12345678.0).format(), "12.3M", "12.3M")
	t.eq(BigNum.from_float(123456789.0).format(), "123M", "123M")
	t.eq(BigNum.from_float(999400.0).format(), "999K", "999.4K stays K")
	t.eq(BigNum.from_float(999600.0).format(), "1M", "999.6K rounds up to 1M")
	t.eq(BigNum.from_float(0.5).format(), "0.5", "fractions keep their digits")
	# Whole payouts group thousands so a long run of digits can be counted.
	t.eq(BigNum.from_float(1234.0).whole_text(), "1,234", "whole text groups thousands")
	t.eq(BigNum.make(8.581, 14).whole_text(), "858,100,000,000,000", "whole text keeps every digit below 1e15")
	# Rates and added multipliers use the one formatter.
	t.eq(NumberFormat.rate(4.0), "4/s", "a whole rate")
	t.eq(NumberFormat.rate(3.3333), "3.33/s", "a fractional rate keeps two places")
	t.eq(NumberFormat.rate(1234.0), "1.23K/s", "a big rate takes a suffix")
	# The Multiplier display setting covers the Stats index, not only the HUD.
	var was: int = NumberFormat.mult_style
	NumberFormat.mult_style = NumberFormat.MultStyle.FACTOR
	t.eq(NumberFormat.bonus_mult(0.35), "+0.35x", "factor bonus")
	t.eq(NumberFormat.mult_f(5.0), "x5", "factor multiplier")
	var sim: Sim = t.make_sim()
	t.eq(_row_value(sim, &"crit_damage"), "x5", "Stats index crit damage in factor style")
	NumberFormat.mult_style = NumberFormat.MultStyle.PERCENT
	t.eq(NumberFormat.bonus_mult(0.35), "+35%", "percent bonus")
	t.eq(NumberFormat.mult_f(5.0), "500%", "percent multiplier")
	t.eq(_row_value(sim, &"crit_damage"), "500%", "Stats index crit damage in percent style")
	NumberFormat.mult_style = was


func _row_value(sim: Sim, id: StringName) -> String:
	for r: Dictionary in StatIndex.stats(sim):
		if r["id"] == id:
			return String(r["value"])
	return "missing"
