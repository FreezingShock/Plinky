# README screenshot slots

The README points each slot at `docs/readme/screens/placeholder.svg` until a real capture exists. To fill a slot, save the PNG under `docs/readme/screens/` with the name below and change that slot's `src` in README.md to the new file. Keep captures at 640 px wide or larger, and use the integer scale the game uses.

| Slot in README | File name | How to capture |
| --- | --- | --- |
| Pads and the Walker | `pads.png` | `tools/play_shots.tscn`, meadow, walker on a pad with the momentum meter visible |
| Upgrades Gallery | `upgrades-gallery.png` | Upgrades menu, zone tab, a row of cards |
| Relics | `relics-panel.png` | Relic panel with at least two equipped slots |
| Achievements | `achievements.png` | Achievements panel, mix of unlocked and locked rows |
| Bloom Ascension | `bloom-ascension.png` | Bloom reset moment, mid-animation |
| Nucleus Ascension | `nucleus-ascension.png` | Nucleus reset moment, mid-animation |
| Seasons (4 slots) | `season-spring.png`, `season-summer.png`, `season-autumn.png`, `season-winter.png` | Same meadow view at each season, from `tools/golden_shots.tscn` or the calendar debug |
| Offline Income | `welcome-back.png` | Welcome Back card after a simulated absence |

Zone captures already exist as baked previews in `docs/readme/zones/`. Replace them if a fresher in-engine capture is taken.
