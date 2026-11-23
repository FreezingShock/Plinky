class_name AchievementDef
extends Resource
## One achievement. Content lives in content/achievements/*.tres, one file per achievement.
## It unlocks the first time `counter` reaches `target`. Counters are named in Sim.achievement_counters()
## (presses, crits, rebirths, ...), plus `peak_<stat id>` (highest value a stat has ever had), `tier_<tier id>`
## and `zone_<zone id>` (1 once opened or entered). Rewards are cosmetic only: an optional title.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## One of Achievements.CATEGORIES.
@export var category: StringName = &"presses"
@export var counter: StringName = &"presses"
@export var target: float = 1.0
## Sort position inside the category. Lower comes first.
@export var order: int = 0
## Cosmetic reward shown under "Title" in the Ledger. Empty for none.
@export var title: String = ""
