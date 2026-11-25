class_name GoalDef
extends Resource
## One mid-game goal. Content lives in content/goals/*.tres, one file per goal, in a chain by `order`.
## A goal is reached the first time `counter` reaches `target`, and it stays reached through resets (it is kept in a
## log, like the Ledger). Its reward is a permanent press bonus: `reward` 0.02 adds 2% to every pad's reward. The sum of
## all reached goals' rewards multiplies press gain (core/goals.gd).
## Counters are the ones Sim.achievement_counters() names, so a goal can use anything an achievement can.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## Counter name from Sim.achievement_counters(), e.g. presses, crits, zone_resets, play_hours, mastery_best.
@export var counter: StringName = &"presses"
@export var target: float = 1.0
## Position in the chain. The Next Goal shown on the HUD is the lowest order not yet reached.
@export var order: int = 0
## Permanent press bonus when reached (0.02 = +2%).
@export var reward: float = 0.0
