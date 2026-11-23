class_name MasteryConfig
extends Resource
## Pad mastery tuning. Single file: content/config/mastery.tres. Every press earns the pad XP; each level
## adds a little yield, crit chance and crit damage to that pad only. Mastery is permanent (rebirth keeps it).

@export var xp_per_press: float = 1.0
## XP to go from level 0 to 1. Each next level needs xp_growth times the one before.
@export var first_level_xp: float = 12.0
@export var xp_growth: float = 1.35
@export var max_level: int = 25
## Press reward is multiplied by (1 + level * yield_per_level).
@export var yield_per_level: float = 0.001
## Added to the global crit chance (a fraction, 0.003 = 0.3 percent) on this pad's presses.
@export var crit_chance_per_level: float = 0.001
## Added to GameConfig.crit_multiplier on this pad's crits (before relic crit damage).
@export var crit_damage_per_level: float = 0.04
