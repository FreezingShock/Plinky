# Relics: tooltip, rarity, inventory, equip

Source of truth is SPEC section 3 (Relics and buffs). This file is the build detail.

## Model
- `RelicInventory` (`core/relic_inventory.gd`) is pure logic: `owned` stacks, `equipped` ids, slot count from rebirths. No nodes.
- Equip slots: `RelicConfig` (`content/relics/_config.tres`): 3 base, +1 at 5 and at 20 rebirths.
- Equipped type applies all owned stacks. Unequipped applies none. Swap is free.
- Effects: `total_effect(kind)` sums linear stacks, combines chances as 1-(1-a)(1-b). `multiplier(kind)` is 1 + total, for formulas.

## Rarity (content/rarities/*.tres)
| Tier | MC | Hex | Drop weight |
|---|---|---|---|
| Common | &f | #FFFFFF | 60 |
| Uncommon | &a | #55FF55 | 25 |
| Rare | &9 | #5555FF | 9 |
| Epic | &5 | #AA00AA | 4 |
| Legendary | &6 | #FFAA00 | 1.5 |
| Mythic | &d | #FF55FF | 0.4 |
| Divine | &b | #55FFFF | 0 (never rolls) |
| Special | &c | #FF5555 | 0 (never rolls) |

Frames: `assets/ui/rarity/` (from art/icons/rarity, 20x20, 16x16 icon at offset 2,2).

## Hooks for the core thread (core, not edited here)
1. GameState owns `var relics: RelicInventory`, builds it from `content/relics/*.tres` + `_config.tres`.
2. Forward signals: `relic_gained` to EventBus.relic_gained; `relic_equipped` and `relic_unequipped` are new EventBus signals (added to SPEC interface list).
3. On rebirth call `relics.set_rebirths(n)`.
4. On each successful press: `var id := relics.roll_drop(rng, luck_level); if id != &"": relics.add_relic(id)`.
5. Formulas: `relic_mult` = `relics.multiplier(CASH_MULT)` for cash; MULT_GAIN for button gain; PRESS_RATE added to press rate; CRIT_DAMAGE added to the 5x crit; DOUBLE_CHANCE and PULSE_CHANCE rolled per press.
6. Save: `relics.to_dict()` / `from_dict()`.

## Drops, toast and flash (Nathan, 2026-11-22)
- Divine and Special come only from rebirths or achievements, never random drops (weight 0). Grant with `add_relic()`.
- Epic and above (`flash_min_rank`) show a rarity-coloured `RelicToast` and a pad flash. The pad flash is Fx's job: on `relic_gained`, flash the pressed pad with `RarityDef.color`.
- Equip slots stay a rebirth reward.
- Wiring to PR #2 (`Juice.relic_drop(pad_glow, rarity)`), once both are merged, in the HUD or world scene that owns the pad glow:
  `GameState.relics.relic_gained.connect(func(id, _s): Juice.relic_drop(pad_glow, GameState.relics.rarity_of(id)))`
  `rarity_of()` returns the lowercase id PadGlow expects. PadGlow already ignores Common to Rare.

## UI
`RelicPanel` (collection + slots + hints), `RelicBar` (HUD strip), `RelicSlot`, `RelicTooltip`, `RelicToast`. Colours from `RelicStyle`, which the theme calls `set_palette()` on at zone change. Fonts come from the theme. Demo: `godot --path . res://tools/relic_demo.tscn`.

## Test
`godot --headless --path . --script tests/run.gd`

## Stacking (2026-11-23)
- Four relics diminish: Gold Purse 6% cash per stack, Stopwatch 8% press rate, Growth Crystal 10% mult gain, Sharp Fang 25% crit damage. Each stack adds less than the last, so the total stays under +100% and drops keep coming. Twin Pads (cap 10) and Pulse Ring (cap 12) diminish too.
- Why not caps: a hard cap sends drops to the rarer relics once the common one is full. Everything capped by about 3 hours of play, so the relic system ended there.
- Drops only roll on a press (at most once per second). Rolls are not per second of wall time, so a player who is not pressing gets no relics.
- Numbers and the pacing effect are in `docs/balance.md` section 11.3.

## Abilities (2026-11-24)
Thirty-three relics now: the six originals plus 27 with their own mechanics. Each new effect is a `RelicDef.Effect` kind appended after the originals, so saved `.tres` values and save files keep their meaning.

| Effect | What it does | Where it hooks in |
|---|---|---|
| `DROP_CHANCE` | multiplies the relic drop roll (1 + total) | `RelicInventory.roll_drop` |
| `CRIT_CHANCE` | adds to crit chance (chance-combined) | `Sim.crit_chance` |
| `OFFLINE_RATE` | adds to the share of income that time away pays (base 0.5) | `Sim.apply_offline` |
| `SURGE` | every `period`th press of the run gains `value` (`RelicInventory.surge_mult`) | `Sim._press` |
| `ZONE_GAIN` | multiplies press reward on pads of the zone in `zone` | `Sim.press_gain` |
| `PRESS_REFUND` | chance a press costs nothing (stock still needed) | `Sim._press` |
| `MASTERY_XP` | adds to pad mastery XP per press | `Sim._press` |
| `HOT_GAIN` | multiplies press reward while Heat is hot (Ember Quarry) | `Sim.press_gain` |
| `PITY_SPEED` | shortens the relic pity timer, floored at a tenth | `RelicInventory.pity_due` |
| `REPEAT_GAIN` | multiplies a press that lands on the same pad as the last real press | `Sim._press` |
| `DROP_REWARD` | a relic drop also pays a share of that press's reward | `Sim._press` |

- `RelicDef.zone` (zone id such as `zone1`, `zone2`, `larkmoor`) and `RelicDef.period` are new fields. Both are empty or zero for other effects.
- Divine and Special are unchanged: weight 0, granted by rebirths and achievements. No new ones yet.
- Counts: Common 6, Uncommon 6, Rare 6, Epic 5, Legendary 5, Mythic 5 (Divine and Special not counted).
- Icons: `tools/art/gen_relic_icons.py` draws every relic at 8, 12, 16, 24 and 32 px. Mock sheet: `/mnt/project-files/plinky-relics/relic_icons_sheet.png`.
- Tooltips use `press_gain_preview`, which leaves out surges and repeats (they depend on the press itself). `press_gain_average` includes the average surge.
- Away income is capped at `GameConfig.offline_rate_cap` (0.75 of the awake rate, `content/config/game.tres`), so the three lanterns at max stop there. Idle stays well under active, per #221 and Nathan's idle-about-2x-as-long target. `Sim.offline_fraction()` applies the cap.
- Balance is not yet run through `tools/sim.gd` (Godot cannot run in the cloud). That run is the PC QA step before this is final.
