class_name RelicDef
extends Resource
## One relic. Content lives in content/relics/*.tres, one file per relic.

enum Effect {
	CASH_MULT,      ## multiplies cash income
	MULT_GAIN,      ## multiplies Multiplier gain from presses
	PRESS_RATE,     ## adds to presses per second
	CRIT_DAMAGE,    ## adds to crit press multiplier
	DOUBLE_CHANCE,  ## chance a press counts twice
	PULSE_CHANCE,   ## chance a press also presses adjacent buttons
}

enum Stacking {
	LINEAR,       ## value = per_stack * stacks
	DIMINISHING,  ## value = 1 - (1 - per_stack) ^ stacks, for chances that must stay below 100%
}

@export var id: StringName
@export var display_name: String
@export var rarity: RarityDef
@export var icon: Texture2D
@export var effect: Effect = Effect.CASH_MULT
@export var stacking: Stacking = Stacking.LINEAR
## Effect per stack. A fraction: 0.10 means +10% (or 10% chance).
@export var per_stack: float = 0.1
## 0 means no cap.
@export var max_stacks: int = 0
## Tooltip body. {value} is replaced by the current total, {step} by the gain of one more stack.
@export_multiline var description: String = ""

## Total effect for a stack count, after the stacking rule and cap.
func value_for(stacks: int) -> float:
	var n: int = stacks if max_stacks <= 0 else mini(stacks, max_stacks)
	if n <= 0:
		return 0.0
	match stacking:
		Stacking.DIMINISHING:
			return 1.0 - pow(1.0 - per_stack, n)
		_:
			return per_stack * n

func is_capped(stacks: int) -> bool:
	return max_stacks > 0 and stacks >= max_stacks

## Text for the tooltip with {value} and {step} filled in as percentages.
func describe(stacks: int) -> String:
	var now: float = value_for(stacks)
	var step: float = value_for(stacks + 1) - now
	return description.replace("{value}", _pct(now)).replace("{step}", _pct(step))

static func _pct(v: float) -> String:
	var p: float = v * 100.0
	return "%d%%" % roundi(p) if absf(p - roundf(p)) < 0.05 else "%.1f%%" % p

## Title Case name of an effect, for the panel's bonus lines and compare rows.
static func effect_name(e: Effect) -> String:
	match e:
		Effect.CASH_MULT: return "Cash Income"
		Effect.MULT_GAIN: return "Multiplier Gain"
		Effect.PRESS_RATE: return "Presses Per Second"
		Effect.CRIT_DAMAGE: return "Crit Damage"
		Effect.DOUBLE_CHANCE: return "Double Press Chance"
		Effect.PULSE_CHANCE: return "Pulse Chance"
	return "Bonus"

## Percentage text for a total effect, with a sign. Press rate is a flat add, shown without a percent.
static func effect_text(e: Effect, v: float) -> String:
	if e == Effect.PRESS_RATE:
		return "+%s" % (("%d" % roundi(v)) if absf(v - roundf(v)) < 0.005 else "%.2f" % v)
	return "+" + _pct(v)
