extends Node
## Signals only, no state. The contract is in docs/interfaces.md and godot/README.md.
## Gameplay emits here. Fx and UI listen here.

signal stat_changed(stat_id: StringName, value: BigNum)
signal button_pressed(button_id: StringName, world_pos: Vector3, gain: BigNum, crit: bool)
signal button_denied(button_id: StringName)
signal zone_entered(zone_id: StringName)
signal gate_opened(gate_id: StringName)
signal relic_gained(relic_id: StringName, stacks: int)
signal buff_started(buff_id: StringName, seconds: float)
signal rebirth_done(prestige_gained: BigNum)
signal reset_done(reset_id: StringName, gained: BigNum)
# Additions to the SPEC contract (logged in docs/decisions.md):
signal relic_equipped(relic_id: StringName)
signal relic_unequipped(relic_id: StringName)
signal attribute_bought(attribute_id: StringName, level: int)
signal offline_gained(seconds: float, gains: Dictionary)  # gains: StringName -> BigNum
signal bonus_gained(kind: StringName, gains: Dictionary)  # kind: &"streak" or &"critter"
signal critter_spawned()
signal critter_gone()
signal heat_hot_changed(hot: bool)
signal momentum_tier_changed(tier: int, rising: bool)
signal mastery_changed(button_id: StringName, level: int, xp: float)  # every press; level and xp are the pad's after it
signal mastery_leveled(button_id: StringName, level: int)
signal achievement_unlocked(achievement_id: StringName)  # a Ledger entry just unlocked (core/achievements.gd)
signal goal_reached(goal_id: StringName)  # a mid-game goal was just reached (core/goals.gd)
signal game_loaded()
signal game_saved()
signal save_failed()  # a save could not be written (full disk, locked file)
signal onboarding_complete()  # the tutorial meadow's gate just opened; the main meadow can take over from here
# Calendar (core/game_calendar.gd). Indices are 0-based within the year; season 0 spring, 1 summer, 2 autumn, 3 winter.
signal day_changed(day_of_year: int)
signal month_changed(month_index: int)
signal season_changed(season_index: int)
signal year_changed(year: int)
