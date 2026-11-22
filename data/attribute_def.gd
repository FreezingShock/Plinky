class_name AttributeDef
extends Resource
## Permanent upgrade bought with available Prestige.
## effect is one of: walk_speed, press_rate, crit_chance, luck, offline_hours.

@export var id: StringName
@export var display_name: String
@export var effect: StringName
@export var per_level: float = 0.05
@export var cap: int = 20
@export var base_cost: float = 3.0
@export var cost_growth: float = 1.4
