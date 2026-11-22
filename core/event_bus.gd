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
# Additions to the SPEC contract (logged in docs/decisions.md):
signal relic_equipped(relic_id: StringName)
signal relic_unequipped(relic_id: StringName)
signal attribute_bought(attribute_id: StringName, level: int)
signal offline_gained(seconds: float, gains: Dictionary)  # gains: StringName -> BigNum
signal bonus_gained(kind: StringName, gains: Dictionary)  # kind: &"streak" or &"critter"
signal critter_spawned()
signal critter_gone()
signal game_loaded()
signal game_saved()
signal onboarding_complete()  # the tutorial meadow's gate just opened; the main meadow can take over from here
