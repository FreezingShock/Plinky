# Zone 2: Ember Quarry (concept, v1)

Status: design concept, 22 Nov 2026. Text only. Numbers are starting values for `content/*.tres` and will be tuned with `tools/sim.gd` in M5. Original design for Plinky. Nothing here is copied from another game.

## Theme
A quarry where the stone is still warm. The diorama is cut from dark rock with ember seams. Pads sit on cooling slag. The walker passes spires of basalt, and the light comes from below. The mood is hot, dusty, and busy.

## Palette
Same eight role indices as zone 1 (0 ink/outline, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper/UI). Hex values are the Ember Quarry palette from docs/art-bible.md:

| Index | Role | Hex |
|---|---|---|
| 0 | Ink / outline | #1a1116 |
| 1 | Shadow | #4a1f2a |
| 2 | Deep | #8a3a2e |
| 3 | Base | #d0602f |
| 4 | Light | #e9a845 |
| 5 | Accent | #b77a7a |
| 6 | Earth | #5b3d5c |
| 7 | Paper / UI | #f1d9b5 |

Palette shift on entry: 1.5 seconds, blended from zone 1 (SPEC section 4).

## New stat tier: Slag
- Tier 3 in the stat chain, on top of Cash, Multiplier, Rebirths, and Prestige. Start 0.
- Earned by the Forge buttons (below), which cost Rebirths.
- Effect: multiplies Cash income by (1 + slag / 2). This is a separate factor from Multiplier, so the two stack.
- Slag does not change the Rebirths rule. Rebirths still boost Multiplier gain only.

## New mechanic: Heat
- Every press adds 1 Heat. Heat caps at 10 and falls by 1 per second.
- At Heat 5 or more, a pad is Hot. A press on a Hot pad pays double.
- Hot pads glow in palette 4 with a dithered ember trail (2 to 3 texels, palette 3).
- Heat resets to 0 on zone entry and on rebirth.
- The mechanic rewards steady pressing over one burst of pressing, and it works with the walker's route.

## Button row: Forge
| id | Cost stat | Cost | Reward stat | Reward | Row index |
|---|---|---|---|---|---|
| `f1` | reb | 25 | slag | +1 | 0 |
| `f2` | reb | 250 | slag | +8 | 1 |
| `f3` | reb | 2500 | slag | +64 | 2 |

Each step costs 10 times more and gives 8 times more, as in zone 1.

## Gate
- Zone 2 gate opens at Slag 9. This matches zone 1's gate rule, so one gate shape and script serve both zones.
- Zone 3 is not designed yet.

## Open
- Whether Heat should be shown on the HUD as a bar or only as pad colour. Decide at the M5 look review.
- Whether the Forge row should be unlocked by the zone 1 gate or by buying one Rebirth button first.
- Confirm the zone 2 numbers after the M2 simulator is built.
