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
