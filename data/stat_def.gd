class_name StatDef
extends Resource
## One stat in the chain (Cash, Multiplier, Rebirths, Prestige, later Slag).

@export var id: StringName
@export var display_name: String
@export var tier: int = 0
@export var start: float = 0.0
## Zones where this stat is live: its passive income runs, its income factor applies, and the HUD lists it. Empty = every
## zone. A stat you still hold from another zone keeps its value; it just stops working and hides until it is non-zero.
@export var zones: PackedStringArray = PackedStringArray()
## Earns income every tick from the current zone's base_cash_per_second.
@export var passive: bool = false
## Income is multiplied by (1 + value of this stat). Empty = none.
@export var income_boost_stat: StringName = &""
## Passive income is also multiplied by (1 + value x this). 0 = off. Separate factor from income_boost_stat, so they stack.
@export var income_factor_per_unit: float = 0.0
## Button rewards into this stat are multiplied by (1 + value of this stat). Empty = none.
@export var gain_boost_stat: StringName = &""
## Income is also multiplied by prestige_mult.
@export var prestige_boosts_income: bool = false
## Reset to start by the rebirth action.
@export var resets_on_rebirth: bool = false
## CASH_MULT relics multiply this stat's income.
@export var relics_boost_income: bool = false
## MULT_GAIN relics multiply button rewards that go into this stat.
@export var relics_boost_gain: bool = false


## True when this stat is live in `zone_id` (see `zones`).
func in_zone(zone_id: StringName) -> bool:
	return zones.is_empty() or String(zone_id) in zones
