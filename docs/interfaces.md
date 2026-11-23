# Interfaces

The contract between core, world, render and ui. Replaces the "write this before parallel work" stub in SPEC section 5. Only the main session changes it; a new signal needs a line in docs/decisions.md.

## Autoloads (project.godot)
| Name | File | Job |
| --- | --- | --- |
| `EventBus` | `core/event_bus.gd` | Signals only, no state |
| `GameState` | `core/game_state.gd` | Owns the `Sim`, relays its signals to EventBus, runs the tick |
| `Calendar` | `core/calendar_service.gd` | Day, season and year clock; emits calendar signals |
| `Save` | `core/save.gd` | Load, save, migrate, export and import, offline progress |
| `Fx` | `render/fx_driver.gd` | Turns gameplay events into global shader uniforms |
| `Juice` | `ui/fx/fx_bus.gd` | UI effects: popups, counters, banners |
| `Audio` | `audio/audio.gd` | Music, SFX, subtitles |

## Rules
- Gameplay emits EventBus signals. World and ui listen to them; they do not call each other across folders.
- Pure logic in `core/` (sim, bignum, formulas, mastery, codecs) has no node or scene references, so `tests/` and `tools/sim.gd` run it headless. The autoload shells above are the only Node scripts in `core/`.
- Only `Fx` turns gameplay events into uniforms. Presentation scripts that own a material (sky, shadows, screen light, toon material, pixel viewport, window frame, transitions, boot and title backgrounds) set their own material's uniforms.
- Stats are `BigNum`. Numbers shown to the player go through `core/number_format.gd`.
- Balance values live in `content/*.tres` (loaded by `data/content_loader.gd`), never in scripts.

## EventBus signals (copied from `core/event_bus.gd`; the file is the truth)
```
signal stat_changed(stat_id: StringName, value: BigNum)
signal button_pressed(button_id: StringName, world_pos: Vector3, gain: BigNum, crit: bool)
signal button_denied(button_id: StringName)
signal zone_entered(zone_id: StringName)
signal gate_opened(gate_id: StringName)
signal relic_gained(relic_id: StringName, stacks: int)
signal buff_started(buff_id: StringName, seconds: float)
signal rebirth_done(prestige_gained: BigNum)
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
signal game_loaded()
signal game_saved()
signal save_failed()  # a save could not be written (full disk, locked file)
signal onboarding_complete()  # the tutorial meadow's gate just opened; the main meadow can take over from here
signal day_changed(day_of_year: int)
signal month_changed(month_index: int)
signal season_changed(season_index: int)
signal year_changed(year: int)
```

## Content folders
`content/` holds `stats`, `buttons` (pads), `tiers` (flower or forge ladder rows), `zones`, `areas`, `relics`, `rarities`, `attributes` and `config` (game, mastery, calendar, sky, onboarding). Each type has a `data/*_def.gd` or `*_config.gd` resource class.
