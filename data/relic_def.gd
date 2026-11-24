class_name RelicDef
extends Resource
## One relic. Content lives in content/relics/*.tres, one file per relic.

enum Effect {
	CASH_MULT,      ## multiplies cash income
	MULT_GAIN,      ## multiplies Multiplier gain from presses
	PRESS_RATE,     ## multiplies the zone press rate (1 + total), like the other gain effects
	CRIT_DAMAGE,    ## adds to crit press multiplier
	DOUBLE_CHANCE,  ## chance a press counts twice
	PULSE_CHANCE,   ## chance a press also presses adjacent buttons
	DROP_CHANCE,    ## multiplies the chance a press rolls a relic drop (1 + total)
	CRIT_CHANCE,    ## adds to the chance a press crits
	OFFLINE_RATE,   ## adds to the share of income that time away pays (base 0.5)
	SURGE,          ## every `period`th press gains `value` more reward
	ZONE_GAIN,      ## multiplies press reward on pads of one zone (`zone`)
	PRESS_REFUND,   ## chance a press costs nothing
	MASTERY_XP,     ## adds to pad mastery XP per press
	HOT_GAIN,       ## multiplies press reward while Heat is hot
	PITY_SPEED,     ## shortens the relic pity timer by this share
	REPEAT_GAIN,    ## multiplies press reward when it is on the same pad as the previous press
	DROP_REWARD,    ## a relic drop also pays this share of the press reward
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
## For ZONE_GAIN: the zone id the bonus applies to (e.g. &"zone2"). Empty for other effects.
@export var zone: StringName = &""
## For SURGE: every this many presses (counted across the whole run) the surge lands. 0 for other effects.
@export var period: int = 0
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
		Effect.CASH_MULT: return "Passive Income"
		Effect.MULT_GAIN: return "Press Gain"
		Effect.PRESS_RATE: return "Press Rate"
		Effect.CRIT_DAMAGE: return "Crit Damage"
		Effect.DOUBLE_CHANCE: return "Double Press Chance"
		Effect.PULSE_CHANCE: return "Pulse Chance"
		Effect.DROP_CHANCE: return "Relic Drop Chance"
		Effect.CRIT_CHANCE: return "Crit Chance"
		Effect.OFFLINE_RATE: return "Away Income"
		Effect.SURGE: return "Surge Press Gain"
		Effect.ZONE_GAIN: return "Zone Press Gain"
		Effect.PRESS_REFUND: return "Free Presses"
		Effect.MASTERY_XP: return "Mastery XP"
		Effect.HOT_GAIN: return "Hot Press Gain"
		Effect.PITY_SPEED: return "Pity Speed"
		Effect.REPEAT_GAIN: return "Repeat Press Gain"
		Effect.DROP_REWARD: return "Drop Bonus"
	return "Bonus"

## Percentage text for a total effect, with a sign. Press rate multiplies the base like every other effect, so it is a percent too.
static func effect_text(e: Effect, v: float) -> String:
	return "+" + _pct(v)
