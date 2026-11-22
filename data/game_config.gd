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
