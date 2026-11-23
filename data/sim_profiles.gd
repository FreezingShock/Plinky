class_name SimProfiles
extends Resource
## Play profiles for tools/sim.gd: how often the player presses a pad, and how many seeded runs each one gets.
## These are harness assumptions for pacing checks, not game balance. Single file: content/config/sim_profiles.tres.

## Profile names, printed in the sim table.
@export var profile_names: PackedStringArray = PackedStringArray()
## Presses per second for each profile, same order as profile_names.
@export var presses_per_second: PackedFloat32Array = PackedFloat32Array()
## Seeded runs per profile. The table reports the median and the spread.
@export var seeds: int = 8
