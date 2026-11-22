# Onboarding: the first ten minutes

How a new player learns the loop. Systems appear one at a time as the player earns them, and a short tip card explains each one the moment it matters. Code: `core/onboarding.gd` (rules), `ui/tip_card.gd` (the card), `ui/hud.gd` (`gate()` hides and reveals HUD parts). Pacing numbers: `content/config/onboarding.tres`.

## The loop the player should understand
1. Stand on a pad to press it. Pressing spends Cash and gives Multiplier.
2. Multiplier raises Cash income, so Cash comes faster and buys the next pad.
3. Rebirth pads (r1, r2) turn Multiplier into Rebirths. Nine Rebirths open the gate.
4. The Rebirth action banks Rebirths as Prestige, a permanent boost, and Prestige buys Upgrades.
Side systems (momentum, streaks, golden critter, relics) come in after the core loop is clear.

## Pacing timeline (greedy play, 0.5 presses per second, no relic luck)
Source: `docs/balance-sim-active.py` logic, re-run for these reveals; `tests/test_onboarding.gd` plays the real Sim and keeps the order and rough minutes.

| Time | What appears | Tip shown |
|---|---|---|
| 0:00 | Cash row, Settings. Nothing else. | **Welcome** (at 1 s): click to walk, stand on a pad or hold click, you can afford Multiplier 1. |
| 0:00 to 0:05 | First press reveals the Multiplier row and the Pads list (blink on reveal). | **Multiplier**: it boosts income, Cash also trickles in, `*` in the Pads list means buyable. |
| 0:40 | none | **Momentum**: walking charges up to +40% income. |
| about 1:00 | First relic drop (by 60 s, pity at 150 s) shows the Relics button and equipped bar. | **Relic found**: open Relics [R]. |
| about 1:30 | none (12th press) | **Streaks**: press a row's pads 1, 2, 3 within 10 s. |
| 2:25 | Multiplier 2 first bought. | none |
| 3:40 | Multiplier reaches 200: Rebirths row and the gate panel appear. | **Rebirth pads**: collect 9 to open the gate. |
| 4:25 | Multiplier 3 first bought. | none |
| 6:35 | First Rebirth pad bought (1 Rebirth): the Rebirth action appears. | **Rebirth**: resets into Prestige, gate stays open, pushing past 9 pays more. |
| 10:05 | Gate opens. | **Gate open**: walk to it to enter Ember Quarry. |
| after the first Rebirth action | Prestige row and the Upgrades button. | **Prestige**: spend it in Upgrades [Tab]. |

Active play (momentum, streaks, critters) reaches each step 10 to 20% sooner. A golden critter shows an urgent **Golden critter** tip the first time it appears (from about 1 minute).

## Rules
- **One tip at a time.** Normal tips wait 15 s after the last. Tips that answer an event (first press, critter, relic, Rebirth action, gate, Prestige) wait 6 s and may replace an open card. A card closes itself after 20 s.
- **Each tip shows once** per save, and the list is saved with the save file (`ui_flags` in the Sim dict).
- **Skippable.** "Skip tips" on any card turns tips off for good and reveals every system. Settings has Tips on, Tips off and Replay tips. The on/off choice lives in `user://tips.cfg`, so a new game does not nag a player who skipped.
- **Unlocks never go away.** A system stays visible after the stat that revealed it falls (Rebirth resets Multiplier to 0).
- **Old saves** (no `ui_flags`) get no tips, and every system they have earned is visible at once.
- **Tuning knobs** (all in `content/config/onboarding.tres`): `rebirth_reveal_mult`, `streak_tip_presses`, `walk_tip_seconds`, `first_tip_delay`, `tip_gap_seconds`, `urgent_gap_seconds`, `tip_lifetime`.

## Hand-off to the main meadow
The small meadow is the onboarding area. Its gate opening completes the tutorial: `Onboarding.completed` fires once per save (latched as `ui_flags.complete`, so it survives saving) and `GameState` forwards it as `EventBus.onboarding_complete()`. The main meadow work should listen to that signal, or read `GameState.onboarding.is_complete()`, to open or load the way on. The existing `gate_opened` and `zone_entered` signals are unchanged.

## Not in this pass
- No pointer arrow or highlight on the world pad (the card is docked bottom right, away from pads). A pad highlight is a good next step once the PC run shows where players look.
- No tip for relic slots or attribute choices; add after the quarry work settles those.
- No momentum meter exists yet, so the momentum tip describes the effect only.
