class_name ButtonDef
extends Resource
## One button pad. Scenes reference it by id and hold no numbers.

@export var id: StringName
@export var zone: StringName
@export var row: StringName
@export var row_index: int = 0
@export var cost_stat: StringName
@export var base_cost: float = 10.0
## Design record only. The game reads base_cost (docs/balance.md section 7).
@export var cost_growth: float = 10.0
@export var reward_stat: StringName
@export var reward: float = 1.0
