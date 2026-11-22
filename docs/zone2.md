# Zone 2: Ember Quarry (concept v1, blockout v1)

Status: concept 22 Nov 2026. Blockout built 23 Nov 2026 (section "Blockout v1" at the end). Not yet confirmed by Nathan; two alternatives are mocked in art/zone2/. Numbers are starting values for `content/*.tres` and will be tuned with `tools/sim.gd` in M5. Original design for Plinky. Nothing here is copied from another game.

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

## Blockout v1 (23 Nov 2026)
Playable, ready to swap. Verified by the PC thread only; the cloud thread could not run Godot.

**Layout.** One bowl of dark rock with three terraces rising away from the camera. A scorched path switchbacks up through three ramps, one per terrace edge, to a basalt gate at the far end. Pads f1, f2, f3 sit on terraces 0, 1 and 2. Lava pools and ember seams are decoration and block the walker. Tall basalt spires and the gate pillars are y-sorted sprites, so the walker passes behind them. Source: `tools/art/gen_zone2.py quarry` writes `assets/art/zone2/quarry/` (ground 840x480 with the same 100x60 bleed as the meadow, walkable.png, sprites, placements3d.json). The scene is `world/quarry_scene.tscn`; `ZoneDef.scene_path` and `walk_mask_path` select it, and main.gd swaps it in on zone entry.

**Props list.** Basalt spire clusters (tall, sprite), boulders, ember crystals, cut stone blocks, wooden posts along the path, two gate pillars with a lintel, three lava pools, ember seams, three vents.

**Forge costs Cash, not Rebirths (changes the table above).** Rebirths cannot be earned in zone 2 (zone 1 buttons are not pressable there), so a Rebirth price would strand the player at the 9 they arrive with. Forge buttons now cost Cash: f1 10000 for +1 Slag, f2 100000 for +8, f3 1000000 for +64 (provisional, retune with tools/sim.gd). Slag is not reset by rebirth, and Cash income gets a separate factor (1 + slag / 2) via `StatDef.income_factor_per_unit`.

**Heat is charged on vents, not by pressing (changes the Heat section above).** Forge presses are rare and expensive, so a press-built Heat could never reach the hot line. Instead, standing within a vent's radius charges Heat at 6 per second up to 10; Heat drains at 1.5 per second away from vents; at 5 or more every press pays 2x. A walker who charges on a vent and walks to a pad has about 3 seconds of Hot. Values are on `content/zones/zone2.tres`. Heat clears on zone entry and rebirth, and is not saved. The vents sit one terrace-walk from their pad, so the route matters.

**Feedback.** A pulsing ring marks each vent, and ten pips over the walker show Heat (base colour while charging, paper when Hot, a tick at the hot line). Hot payouts show as larger popups.

**Not done.** Zone 3 (the gate leads nowhere yet; the HUD says so), a Heat bar on the HUD (open question above, pips for now), a zone 2 shrine and life layer (sway, embers, critters), zone 2 audio, balance pass, the transition art between zones.
