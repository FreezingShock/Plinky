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
## Zone reset uses (Blooms) of this attribute's currency needed before it can be bought (0 = from the start). Gifts open up as you Bloom.
@export var unlock_resets: int = 0
## Menu text, so a new gift needs no script table: what it does, its icon (assets/icons/<icon>.png), the unit shown after the
## number ("auto-presses"), and how the number reads: percent (+30%), flat (+50), rate (+0.4/s) or count (+1).
@export_multiline var blurb: String = ""
@export var icon: StringName = &""
@export var unit_text: String = ""
@export var value_kind: StringName = &"percent"
@export var order: int = 0
## Which stat pays for it: &"prestige" (the default) or &"rp" (Rebirth Points, a balance spent down on purchase).
@export var currency: StringName = &"prestige"
