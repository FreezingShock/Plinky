# Achievements and the Ledger

40 achievements in eight categories, shown in the **Achievements** window (hamburger tile after History; called Ledger until 2026-11-24). Content is one file per
achievement in `content/achievements/`; logic is `core/achievements.gd`; the window is `ui/ledger_panel.gd`; the unlock
banner is `ui/achievement_toast.gd`, with each section's look in `ui/achievement_style.gd` and particles in `ui/fx/achievement_sparks.gd`; icons come from `tools/art/gen_ledger.py`.

## How it works
- An achievement unlocks the first time its **counter** reaches its **target**. Counters are named in `Sim.achievement_counters()`:
  plain totals (`presses`, `crits`, `streaks_done`, `best_momentum`, `rebirths`, `relic_drops`, `relic_kinds`, `best_relic_rank`,
  `attributes_bought`, `mastery_best`, `play_hours`, `gates_open`), `tier_<id>` and `zone_<id>` flags, and `peak_<stat>`.
- **Peaks** are the highest value a stat has ever had, so spending or rebirthing never costs you an unlock. They are saved.
- The Sim checks once a second and right after a rebirth, then emits `Sim.achievement_unlocked`, forwarded on `EventBus`.
- **Saves:** the unlocked list and peaks live under `achievements` in the save. A save from before the Ledger is credited with
  what it has already done, silently, so an old save never gets a wall of pop-ups. Loading never replays unlocks.
- The toast is held back until the first Dewdrops unlock (the tutorial), but the achievement still counts.
- `Sim.validate()` rejects an achievement with an unknown category, an unknown counter or a target of zero.

## Rewards: cosmetic only
The only reward is a **title**, shown in the Ledger header. The newest unlocked achievement that has a title sets it. Nothing
here touches income, drops or any balance number, so the Ledger can be tuned freely. Ten achievements carry a title.

## Adding one
Copy any `.tres` in `content/achievements/`, change `id`, `display_name`, `description`, `category`, `counter`, `target`,
`order` (position inside its category) and optionally `title`. No code changes. For a new counter, add it to
`Sim.achievement_counters()` and the validator picks it up.

## Not built yet
- **Bloom.** The Bloom layer is not in the game, so there are no Bloom achievements. When it lands, add a `blooms` counter and
  three or four entries (first Bloom, 5, 25, a Bloom Gift bought) to the Rebirth category.
- **Quarry depth.** Quarry has four entries on what exists today (entering, Ingots, Emberhearts, Slag). Heat and Alloys want entries once they have a feel pass.
- **Divine and Special relics** (see below).

## Proposal: Divine and Special relics from achievements
`docs/relics.md` says Divine and Special never roll and come from rebirths or achievements, but no Divine or Special relic exists yet,
so nothing is granted. Proposal, for Nathan to accept or change:
1. **Divine relics come from Rebirth milestones, not from the Ledger.** (Rebirth 10, 25, 50 each grant one.) Keeps relics a rebirth reward.
2. **Special relics come from the Ledger, and only for finishing a whole category**: eight Specials, one per category, each named for
   its category. Awarded on the unlock of that category's last entry, and shown in the toast.
3. Special relics are **cosmetic-leaning**: a small fixed effect (a few percent, no stacking), in the same slot system, so a full Ledger
   is a collector's goal and not a power spike.
This needs relic defs, a grant hook in `Sim.check_achievements`, and a balance pass, so it is a follow-up and not in this change.

## Unlock banner (2026-11-24)
- A wide banner centred across the screen, its middle at 38% of the height. It unfurls from a sliver in eight whole steps, holds for 2.4 s, and closes the same way.
- **Never over a menu.** While any menu is open, or the Bloom ritual runs, unlocks wait in the queue. A banner already up when a menu opens closes and goes back to the front of the queue.
- **Per section:** colour and icon from `LedgerPanel`; particle style (gold sparks, drifting petals, rising flame, glints, rings, bubbles, embers, dust) and a quiet chime from `AchievementStyle`.
- A titled achievement adds more particles, a second quieter chime and a small screen shake (`Juice.shake`, which respects Reduce Shake).
- Reduce Motion shows it whole, with no unfurl, particles or shake. Reduce Flashing drops the dither ink.
