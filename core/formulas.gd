class_name Formulas
extends RefCounted
## Pure formula functions from SPEC section 3. No state, no balance numbers (those arrive as arguments).


## prestige_mult = 1 + prestige ^ exponent
static func prestige_mult(prestige: BigNum, exponent: float) -> BigNum:
	return BigNum.one().add(prestige.pow_f(exponent))


## cash_per_second = base * (1 + boost_stat) * prestige_mult * relic_mult
## Pass BigNum.one() for factors that do not apply to the stat.
static func income(base: float, boost_plus_one: BigNum, pmult: BigNum, relic_mult: BigNum) -> BigNum:
	return BigNum.from_float(base).mul(boost_plus_one).mul(pmult).mul(relic_mult)


## button_gain = reward * boost_from_tier_above * relic_mult * crit_mult
static func button_gain(def: ButtonDef, boost_plus_one: BigNum, relic_mult: BigNum, crit_mult: float) -> BigNum:
	return BigNum.from_float(def.reward).mul(boost_plus_one).mul(relic_mult).mul(BigNum.from_float(crit_mult))


static func button_cost(def: ButtonDef) -> BigNum:
	return BigNum.from_float(def.base_cost)


## attribute cost = base_cost * growth ^ level (level = levels already bought)
static func attribute_cost(def: AttributeDef, level: int) -> BigNum:
	return BigNum.from_float(def.base_cost * pow(def.cost_growth, float(level)))
