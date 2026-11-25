# Onboarding: the first ten minutes

How a new player learns the loop. Systems appear one at a time as the player earns them, and a short tip card explains each one the moment it matters. Code: `core/onboarding.gd` (rules and tip text), `ui/tip_card.gd` (the card), `ui/hud.gd` (`gate()` hides and reveals HUD parts, `_poll_tips()` picks the card), `ui/tip.gd` (`Tip.hud_showing()`). Pacing numbers: `content/config/onboarding.tres`. The Meadow's own content is in `content/buttons/sprout_*.tres`, `clover_*.tres` and `content/zones/zone1.tres`.

## The loop the player should understand (Meadow)
1. Stand on a Sprout pad, or hold click on it, to press it. Each press spends Sunlight and gives Dewdrops.
2. Dewdrops make Sunlight flow faster, and Sunlight also trickles in on its own. Sunlight buys the next Sprout pad.
3. At 200 Dewdrops the Clover row appears. Clover pads cost Dewdrops and pay Clover Leaves.
4. Nine Clover Leaves open the Meadow gate. The gate leads to Larkmoor.

Side systems (momentum, streaks, golden critter, relics, mastery) come in beside the loop. Seeds and Bloom come later: the first Bloom needs the Larkmoor gate, so it is well past the first ten minutes. Its tip is the zone-reset tip, which uses the Bloom definition's own `teach_text`.

## Pacing timeline (greedy play in `tests/test_onboarding.gd`)
The test plays the real Sim, presses the most expensive affordable pad at the press rate, and checks the order and rough minutes. The numbers move by about 10 s between runs, so these are rounded.

| Time | What appears | Tip shown |
|---|---|---|
| 0:01 | Sunlight, Settings. Nothing else. | **Welcome**: click to walk, stand on a pad or hold click, you can afford Sprout 1. |
| 0:07 | First press reveals the Dewdrops row, the zone card and the Pads list. | **Dewdrops**: Dewdrops boost Sunlight, Sunlight trickles in, `*` in the Pads list means buyable. |
| 0:34 | none (12th press) | **Streaks**: press a row's pads 1, 2, 3 within 10 s. |
| 0:49 | none | **Momentum**: walking charges up to +40% income. |
| about 1:00 | First relic drop shows the Relics button and equipped bar. | **Relic found**: open Relics [R]. |
| about 1:10 | A golden critter, once one is out. | **Golden critter**: click it before it leaves. |
| 3:54 | Clover row appears at 200 Dewdrops. | **Clover pads**: the first costs its price in Dewdrops, pays Clover Leaves, and nine open the gate. |
| 10:19 | Gate opens. | **Gate open**: walk to it to enter Larkmoor. |

Measured in the first-hour playtest (a bot that presses at the standing rate and never leaves the pad): the gate opens at about 10.3 minutes, which matches the Meadow target of about 10 minutes.

## Rules
- **One tip at a time.** Normal tips wait 15 s after the last. Tips that answer an event (first press, critter, relic, gate, zone reset, Upgrades) wait 6 s and may replace an open card. A card closes itself after 20 s.
- **Tips wait for menus and banners, not for world tooltips.** A tip card steps aside for an open menu, a confirm card, a banner, an achievement toast or a HUD tooltip (`Tip.hud_showing()`). A pad tooltip under the pointer does not hold it: the pointer often rests on the pad the player is pressing, and the card would never show. The card is docked bottom right, and the tooltip draws above it.
- **Each tip shows once** per save, and the list is saved with the save file (`ui_flags` in the Sim dict).
- **Skippable.** "Skip tips" on any card turns tips off for good and reveals every system. Settings has Tips on, Tips off and Replay tips. The on/off choice lives in `user://tips.cfg`, so a new game does not nag a player who skipped.
- **Unlocks never go away.** A system stays visible after the stat that revealed it falls.
- **Old saves** (no `ui_flags`) get no tips, and every system they have earned is visible at once.
- **Tuning knobs** (all in `content/config/onboarding.tres`): `clover_reveal_dewdrops`, `streak_tip_presses`, `walk_tip_seconds`, `first_tip_delay`, `tip_gap_seconds`, `urgent_gap_seconds`, `tip_lifetime`.
- **Dead code to know about.** `F_REBIRTH_BUTTON` and the `rebirth_button` tip were written for an older Rebirth loop. `config.rebirth_zones` is empty, so that tip never shows, and no HUD element is gated on `F_REBIRTH_BUTTON`. Leave them until the Rebirth code is removed.

## Hand-off to the main meadow
The small meadow is the onboarding area. Its gate opening completes the tutorial: `Onboarding.completed` fires once per save (latched as `ui_flags.complete`, so it survives saving) and `GameState` forwards it as `EventBus.onboarding_complete()`. The main meadow work should listen to that signal, or read `GameState.onboarding.is_complete()`, to open or load the way on. The existing `gate_opened` and `zone_entered` signals are unchanged.

## Not in this pass
- The first-pad arrow (`ui/fx/pad_pointer.gd`) already points at the first pad. There is no arrow or highlight for the gate. A gate pointer is a visual change, so it needs mockups first.
- No tip for relic slots or attribute choices; add after the quarry work settles those.
- No tip for Mastery. The Mastery row has a tooltip that explains it, and it is visible from the first press.
- The momentum meter (a setting, off by default) is not gated by onboarding; the momentum tip describes the effect only.
