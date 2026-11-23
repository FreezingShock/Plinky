# Ember Quarry stat ladder (pitch v1, 23 Nov 2026)

Status: pitch, not built. Builds on the meadow ladder (PR #164: TierDef, zone-scoped stats, gain_boost chain). Numbers are starting values; the quarry balance thread tunes after.

## Six tiers, forge order (revised: Cash and Multiplier are the base tiers)
| # | Tier | Stat | Rarity | Pad object | Pads cost |
|---|---|---|---|---|---|
| 1 | Cinder | Cash | Common | glowing coal pile | quarry passive trickle (0.25/s) |
| 2 | Ore | Multiplier | Uncommon | rock chunk with a vein | Cash |
| 3 | Slag | Slag | Rare | bubbling slag pool | Multiplier |
| 4 | Ingot | Ingots | Epic | stacked bar | Slag |
| 5 | Alloy | Alloys | Legendary | two-tone bar on an anvil | Ingots |
| 6 | Emberheart | Emberhearts | Mythic | heart shaped ember crystal | Alloys |

Tier names are the pad rows; stat names stay Cash and Multiplier. Rebirth, Prestige and RP are the reset layer, sourced from Ingots. Each row has three pads (+1/+8/+64); the last pad pressed once opens the next tier.

## Buff rule (shared mechanic, owned by the meadow thread)
From tier 3 up, every stat boosts the gains of all tiers below it: Slag x1.25, Ingots x1.25, Alloys x1.50, Emberhearts x1.50. Stacks multiplicatively down the ladder. Setting "Boosts shown as": Percent (+25%) or Factor (x1.25). Content only: factors live in content/*.tres.

## Existing quarry stats folded in
Slag becomes tier 3 (still the gate stat family). Heat keeps its Hot pad bonus. Multiplier, Rebirth, Prestige and RP keep running, sourced from Ingots (Rebirth cost) the way the meadow sources them from Clover Leaves. Zone gate: 9 Emberhearts (Zone 3 not built, banner stays).

## Art
Per-tier standing object 13 texels on the plate (like meadow flowers) plus icons at 8, 16 and 32 px, palette-indexed, rarity ring.

## Fixes the ladder must include (from the balance thread's code read)
- Arrival grant is a flat, small amount (enough for the first Cinder pad row, about 3 minutes of play), not scaled by Starbloom stock. Today's scaling gives ~1.2M Cash and buys Forge f3 in 2 s.
- Rebirth is zone-scoped: in the quarry it banks Ingots (quarry-earned), in Larkmoor it banks Clover Leaves, and it refuses when the zone's source stat is zero. No cross-zone soft lock; a rebirth in the quarry resets to the zone's flat arrival grant, never to Cash 10 / Mult 0.
