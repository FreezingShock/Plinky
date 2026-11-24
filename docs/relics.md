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
5. Formulas: `relic_mult` = `relics.multiplier(CASH_MULT)` for cash; MULT_GAIN for button gain; PRESS_RATE multiplies press rate (1 + total), like MULT_GAIN; CRIT_DAMAGE added to the 5x crit; DOUBLE_CHANCE and PULSE_CHANCE rolled per press.
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

## Walker aura (2026-11-24)
`WalkerRelics` (`world/walker_relics.gd`) is a child of the walker. Each equipped relic gets one mote that circles the head in its rarity colour, with a short trail. The highest equipped rarity lights a pool under the feet, and Epic and up sparkle. It reads `RelicInventory` only. Held items are not done yet: each would need its own sprite on the walker atlas.

## Gallery (2026-11-24)
`RelicPanel` is a gallery, sized to its content. Rarity chips show found counts in each tier's colour, and the open one is filled. Cards are 40 px squares, six across, with the tier's initial in the corner so the tier reads without colour. Relics you have not found show as dark silhouettes. The hover or focus tooltip holds the detail: the ability (`describe()`), the owned state, how to find it (`RelicInventory.acquire_text()`, from the rarity weights, or 'granted by rebirths or achievements' for weight 0), and what a click does. A click equips an owned relic into a free slot. With every slot full, the relic waits and the slots light up; click one to swap. Clicking an equipped relic or slot unequips it. Keyboard and pad: Enter or A acts, Esc cancels a waiting swap. Buffs sit beside the slots as chips with the stat's icon, packed to the right. The header's eye button toggles between showing every relic (on) and owned relics only (off), with a tooltip for each state. Tooltips use the shared `Tip` system.


## Sealed caches (2026-11-24)
A late-game sink and a pull moment. Two caches sit at the foot of the relic gallery under a "Sealed Caches" heading. Files: `content/sealed/*.tres` (`SealedPullDef`, data only), `core/sealed_pulls.gd` (pure: price, cap, pool, roll), `ui/sealed_pull_strip.gd` (the cards), `ui/sealed_pull_overlay.gd` (the opening), `ui/sealed_art.gd` (the pouch, drawn in code per zone palette).

- **Bloom Cache** spends Seeds and **Nucleus Cache** spends Core Shards. Each is unlocked by its reset's first use, so the card is dimmed until then.
- **Price** is `base_cost x growth ^ pulls this reset`, floored. Base 40, growth 1.5, so a full reset costs 40, 60, 90, 135, 202 (527 in total). Cap is five pulls a reset. A reset clears that reset's count (`SealedPulls.on_reset`, called from `Sim.try_reset`).
- **Pool** is every relic at Rare (rank 2) or above with a drop weight, and not at its stack cap. Rarity is chosen by weight, then a relic, the same as `RelicInventory.roll_drop`. Rare is about 60 percent, Epic 27, Legendary 10 and Mythic 3. Divine and Special never come out. The tooltip shows the odds.
- **Flow**: `Sim.try_sealed_pull` checks the reset, the cap, the price and a non-empty pool, then spends the currency and grants the relic through `RelicInventory.add_relic`. Nothing is granted if any check fails. The grant fires `relic_gained` as usual, so the relic sound plays at the click.
- **Reveal**: the pouch shakes (0.6 s), cracks with sparks and a thump (0.35 s), then shows the relic in its rarity colour with its ability and "New!" or the new count. A click or Enter skips the animation, and Continue, a click outside or Esc closes it. Reduce Motion skips the shake and sparks, and the sparks never blink.
- **Save**: `sim.to_dict()["sealed_pulls"]` holds the pulls per reset. Older saves load with none.
- **Tuning** is only in the `.tres` files. The numbers above are unverified in the sim and need a pass with `tools/sim.gd` on PC.
