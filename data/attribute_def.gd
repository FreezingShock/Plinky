class_name AttributeDef
extends Resource
## Permanent upgrade bought with available Prestige.
## effect is one of: walk_speed, press_rate, crit_chance, luck, offline_hours, crit_damage, mastery_xp, pad_yield.
## unlock_rebirths: Rebirths needed before it can be bought (0 = from the start). order: sort key inside the menu.

@export var id: StringName
@export var display_name: String
@export var effect: StringName
@export var per_level: float = 0.05
@export var cap: int = 20
@export var base_cost: float = 3.0
@export var cost_growth: float = 1.4
@export var unlock_rebirths: int = 0
@export var order: int = 0
