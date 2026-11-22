class_name GameConfig
extends Resource
## Global rules and tunables. Single file: content/config/game.tres.

@export var tick_rate: int = 10
@export var max_ticks_per_frame: int = 50
@export var autosave_seconds: float = 30.0
@export var offline_base_cap_hours: float = 2.0
@export var prestige_exponent: float = 0.8
@export var crit_multiplier: float = 5.0
## Rebirth needs this stat at or above rebirth_min_value, and converts it to prestige.
@export var prestige_source_stat: StringName = &"reb"
@export var prestige_stat: StringName = &"prestige"
@export var rebirth_min_value: float = 1.0

## Rebirth payoff grows past this much of the source stat: gain = value * (value / threshold) ^ exponent.
## Set threshold to 0 to turn the bonus off.
@export var prestige_push_threshold: float = 9.0
@export var prestige_push_exponent: float = 0.5
## Momentum: walking charges it, standing lets it fall. Income gets x(1 + momentum * momentum_max_bonus).
@export var momentum_max_bonus: float = 0.4
@export var momentum_per_unit: float = 0.0055    ## charge per texel walked (about 180 texels fills it)
@export var momentum_decay_per_second: float = 0.1
## Pad streak: press a row's buttons in order, each within streak_window seconds of the last.
@export var streak_window: float = 10.0
@export var streak_bonus_seconds: float = 5.0    ## income paid on completing a streak
@export var streak_cooldown: float = 20.0
## Golden critter: appears now and then, click it for critter_income_seconds of income.
@export var critter_min_interval: float = 75.0
@export var critter_max_interval: float = 150.0
@export var critter_lifetime: float = 12.0
@export var critter_income_seconds: float = 30.0
