# Decisions: Balance, progression and resets

Economy numbers, Mastery, Momentum, Hold-to-buy, Rebirth and zone resets, relic stacks, the balance sims. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## 2026-11-23: Pad mastery and crits
- Every press gives the pad `xp_per_press` XP. Level n+1 needs `first_level_xp * xp_growth^n` XP; cap `max_level`. Each level adds `yield_per_level` to that pad's reward multiplier, `crit_chance_per_level` to its crit chance and `crit_damage_per_level` to its crit multiplier (added to `GameConfig.crit_multiplier`, then relic crit damage multiplies it). All numbers are in `content/config/mastery.tres`.
- Mastery is permanent: rebirth keeps it, `new_game` clears it. It sits on the pad, not the stat, so a stat index can still show the global crit chance (attribute only) and the per-pad value separately.
- Crit chance and crit damage already existed (Crit chance attribute, Crit Damage relic, `crit_multiplier` 5). Added `Sim.crit_chance(button_id)` and `Sim.crit_damage(button_id)`; no argument gives the global value.
- Data API for UI threads: `Sim.mastery` (`level`, `xp`, `xp_for_next`, `progress`, `yield_mult`, `crit_chance_bonus`, `crit_damage_bonus`), `Sim.area_mastery(zone)` -> `{pads, level_sum, level_cap, fraction, maxed}`, EventBus `mastery_changed(button_id, level, xp)` (every press) and `mastery_leveled(button_id, level)`.
- Save version 2 adds `game.mastery` as `{pad id: [level, xp_in_level]}`. The v1 migration adds an empty one. Unknown ids drop, levels clamp to the cap.
- Crit popup: a crit number ends in "!" and takes the crit gold (`PopupNumber.CRIT_COLOR`), on top of the existing 24 px size, hit-stop, burst and shake.
- Balance: the starting curve (12 XP, x1.35, cap 25, +1.5% yield per level) gives +15% yield, +3% crit chance and +0.4 crit damage on a pad after roughly 650 presses on it (level 10). Not yet measured against the 61 minute Larkmoor pacing; `tools/sim_larkmoor.gd` now prints the mastery reached by the far gate, to run on the PC.

## 2026-11-23: Mastery retuned after the PC sim
First numbers (+1.5% yield, +0.3% crit chance per level) put the Larkmoor far gate at 51.9 min instead of 61 (best pad level 10, 22 of 250 area levels). Crit chance counts too: at x5 damage, +3% chance is about +12% expected yield, so it pushed as hard as the yield did. Now +0.2% yield and +0.1% crit chance per level (best pad at level 10: about +6% expected on that pad). Estimate only, about 59 min; the PC sim still has to confirm.

## 2026-11-23: Mastery yield cut again
PC sim after the first retune put the Larkmoor far gate at 57.5 min (target about 61; 24 of 250 area levels, best pad level 11). `yield_per_level` 0.002 to 0.001, crit chance per level stays 0.001. Not re-run after this change.
- Dither wipe is drawn from tiled 4x4 textures (no shader) and is inked before the first frame; the shader version showed opaque on frame 1 on the PC.

## 2026-11-23 Momentum overhaul (v0.14.0)
- Nathan: "completely overhaul momentum and its bar". Momentum stays a 0..1 charge so the +40% ceiling and the balance sim are untouched, but it now has structure.
- Stages, named and data-driven (GameConfig.momentum_tier_*): Idle, Stride (20%), Rhythm (45%), Flow (70%), Surge (full). Income is 1 + 0.28 x charge + a kicker per stage reached (1/2/3/6%), so a full bar is still +40% and mid-bar is a touch lower, which makes crossing a stage feel like a step up.
- Hold, then drain: charging stops, the bar holds 1.2 s, then drains 0.1/s. At full the hold is 4 s (Surge), the payoff for reaching the top. Walking is still the main driver (0.55% per texel).
- Pressing and crits feed it: +1% per press, +5% on a crit, so pressing alone settles near Stride and walking is what reaches Flow and Surge. Fed from main.gd's press handler, not Sim.try_press, so the headless balance sim (which does not walk) is unchanged and the Larkmoor gate stays where it was (about 57 to 61 min).
- Not done, on purpose, to keep it light: relic or mastery hooks. Both can add to momentum_per_press later without new systems.
- Bar (ui/momentum_bar.gd, ui/momentum_meter.gd): 4 stage ticks that light below the bar as stages are passed, stage colour from palette roles (edge, good, accent, text), a dithered decay ghost that lingers 0.35 s then follows, a hold line under the bar, stage name on the title row, a flash and a one-size pop on a stage-up (off under Reduce flashing), Surge shimmer. Rising stages call Juice.momentum_tier (small shake, Surge pings). Tooltip is a shared Tip with exact numbers.
- Not run in-engine: no Godot in the cloud. CI runs the headless tests and sim; the PC pass should judge the bar at 1x and 3x, the flash and the tooltip.

- Fix (v0.14.1): the stage-up pop grew the stage name from 14 to 16 pt, which made the row taller and pushed the bar to the panel border. Removed; stage-ups are colour and frame flash only, and the stage label has a fixed minimum width.

## 2026-11-23 Hold-to-buy and Rebirth Points (v0.16.0)
- Hold-to-buy: holding an Upgrades Buy button (mouse, Enter/Space or pad confirm) keeps buying, after a 0.35 s delay, one level per 0.2 s speeding up to 0.04 s over a few seconds (`core/hold_repeat.gd`, pure and tested). It stops the moment the next level is unaffordable or maxed. Repeats play a light animation (pip pop and a quiet click; no squash, flying cost or number tick). The gallery detail page Buy is still click-only.
- Header: "Prestige to spend: N" became right-aligned balances on the title row, icon plus value in the stat colour (RP then Prestige), with stat tooltips. The gallery Attributes sub line reads "N Prestige   N RP".
- Rebirth Points (RP) are a new currency, `content/stats/rp.tres`. Each rebirth pays `rp_base + rp_growth x rebirths done` (1 + 0.1 per rebirth, rounded down, GameConfig). RP is a balance (spending lowers it), never resets, is not income, and does not touch the Multiplier: rebirths still only boost Multiplier gain. Shown in the HUD currency panel as "RP" once you have rebirthed, in the Stats gallery as Rebirth Points, and in the Rebirth tooltip.
- What RP buys (default pick, open to change): a "Rebirth perks" group at the bottom of Upgrades, three attributes with `currency = rp`: Pad lore (+5% pad XP per level, cap 10), Lucky streak (+5% luck, cap 10), Deep sleep (+0.5 h offline cap, cap 8). They use existing effects, so no new systems, and Prestige upgrades are untouched. The headless balance sim never buys them, so the Larkmoor gate stays at about 57.5 min.
- Save v4: a v3 save gets RP backfilled for the rebirths it already did (`rp_backfill` flag set by the migration, read by Sim.from_dict).
- World popups ("+93.3") used to draw over open menus because the popup overlay sits above the HUD. They are now hidden while their spawn point is under a centred menu panel (`PopupNumber.under_menu`, set by the HUD).
- Checked here with the real engine headless (tests, sim, boot) and a software-GL capture of the header. Not run: the PC pass should judge the hold feel with a real mouse and pad, and the RP row in the HUD at Wide.

## 2026-11-23 Balance round 3: relic stacks, attribute caps (0.26.7)
- **Relic stacks diminish.** Gold Purse, Stopwatch, Growth Crystal and Sharp Fang move from `LINEAR` to `DIMINISHING`, with per-stack 6%, 8%, 10% and 25%. Reason: linear and uncapped, Gold Purse reaches +2,474% cash after 10 hours of play, and relics carry over between rebirths. Hard caps tried first; they end the relic system in about 3 hours because drops re-weight onto the rarer relics.
- **Per-stack steps for Gold Purse and Growth Crystal were lowered** (10% to 6%, 15% to 10%). With all relics equipped as they drop, the Larkmoor far gate went from about 26 min (old linear) to 31 min (first try) to 35 min (shipped). Unequipped it stays at about 57 min. Chosen to keep relics at about a third off the pace. Taste call for Nathan (see balance.md 11.3).
- **Pad yield cap 25 to 15** (last level was 64k prestige for +2%, about 13x worse per prestige than crit chance). **Quick study cap 20 to 10** (21k prestige for mastery XP that barely matters). **Press rate cap 20 to 15** (so Stopwatch and the attribute together stay near 5x press rate).
- **Not changed:** meadow pads (other thread), Larkmoor pads (pacing holds, 57.5 min mean on both trees), Rebirth Points perks, mastery (pinned to Larkmoor pacing, open question), Momentum stages, prestige formula (Bloom thread).
- Verified: 2612 headless checks, 0 failed. Larkmoor far gate (no relics equipped, as the sim always runs): 57.5 min mean on the base tree, 57.1 on this tree, 12 runs each. Screenshot not verifiable in the cloud.

## Balance sim: three play profiles, meadow pacing checked (2026-11-23)
- **Why:** the sim had one greedy press rate, so it could not show how much the pacing depends on how often the player presses. Idle, active and hold now run over 8 seeded runs each, and the table shows the median and the range.
- **Profiles are content:** `content/config/sim_profiles.tres` (`data/sim_profiles.gd`) holds the presses per second (idle 0.2, active 0.5, hold 4.0) and the seed count. They are harness assumptions for pacing, not game balance. Active is the zone's `press_rate`, which already includes walking between pads.
- **Seeds:** each run sets `rng.seed` so a rerun gives the same numbers (checked: two runs identical).
- **Meadow kept as it is:** active gate 10.1 min (range 9.8 to 10.1), hold 9.8, idle 16.6. Clover opens at 4.4 min in every profile. The meadow meets the 10 minute target, so no meadow costs changed.
- **Larkmoor not edited here:** the far gate is 56.0 min median on active (range 33.7 to 58.8), just under the 57 to 61 target. Larkmoor costs belong to the flower tiers thread, which gets these numbers (see `docs/balance.md` section 11).
- **Open:** idle reaches the Larkmoor far gate at about 134 min, and the 57 to 61 target only holds for active play. Whether idle should be faster is a design question for Nathan. Not decided.

## Offline catch-up v2 
- Away time still caps at offline_base_cap_hours plus Deep Sleep levels. Within it: passive Sunlight at full rate; flower tending at `offline_tend_fraction` (0.1) of the press rate, one top unlocked pad per open tier, lowest tier first, paying real cost and reward and limited by stock (so it can never invent resources); mastery XP follows from those presses with Pad Lore applied; relic rolls at `offline_relic_roll_fraction` (0.25) of the awake rate with normal luck and pity, at most 3 drops per return. All numbers in content/config/game.tres. Zone 2 has no tiers yet, so it gets passive income only. Welcome Back lists tending and mastery in the mastery colour and found relics in their rarity colour. Untested in engine: no Godot in the cloud; CI runs the new tests. Balance threads may retune the three fractions.

## Tier buffs, multiplier display, clearer pad states (2026-11-23)
- **Decision (Nathan):** stats from the 3rd tier up buff several lower stats, not just the one below. `StatDef.buff_stats` and `buff_factor` (data, reusable by the Ember Quarry ladder): while a stat is held (>= 1), rewards into each listed stat are multiplied by the factor, and buffs from different stats stack. Meadow: Thistle Down and Heather Sprigs 1.25x, Foxglove Bells and Starbloom Petals 1.5x, each on every stat below it. This is flat, not per unit, so it stays predictable; the per-unit chain (`gain_boost_stat`) is unchanged.
- **Setting:** Settings > Gameplay > Multiplier display, Factor (x1.5) or Percent (150%), through `NumberFormat.mult()`. Used by the stat sources lists and the HUD prestige label.
- **Pacing:** with buffs the Larkmoor gate is 2000 Starbloom Petals; `tools/sim.gd` (now seeded) lands at 58 to 61 min, with a few minutes of swing from relic drops.
- **Pad states:** locked pads are dark with a dull bud and no buy colours; buyable pads get a green ground halo, plus the existing green inset and tick; unaffordable stays red with the X.

## 2026-11-23 Bloom: the meadow's reset layer (0.31.0)
- **Bloom replaces Rebirth in the meadow.** It opens once Larkmoor's far gate has opened and Starbloom Petals reach the gate threshold (`Sim.bloom_ref()` reads it from the zone, so Bloom follows the gate). Nathan wanted a modest layer: one reset after Rebirth, no Transcendence or Infinity.
- **Currency is Seeds, not Petals** (Petals clashes with Starbloom Petal). Icon: a plump peach-gold seed with no sprout so it never reads as the RP gem (`tools/art/gen_seed_icon.py`, 8, 16, 24 and 32 px).
- **Pays** floor(2 x sqrt(Starbloom Petals / gate threshold)) Seeds, at least 2 (`bloom_seed_scale`, `bloom_min_seeds`). Every Bloom also adds 5% to every pad's reward for good (`bloom_reward_per_bloom`, via `pad_yield_mult`).
- **Resets** every stat flagged `resets_on_bloom`: Sunlight, Dewdrops, Clover Leaves, Thistle Down, Heather Sprigs, Foxglove Bells, Starbloom Petals. Keeps gates, open tiers, relics, mastery, Seeds, RP and old Prestige.
- **Buys four gifts** in Upgrades (BLOOM GIFTS): Head start (starting Sunlight), Deep soil (Sunlight income), Wide bloom (pad yield), Long dusk (offline hours). All in `content/attributes/bloom_*.tres`.
- **Rebirth, Prestige and RP are hidden outside `rebirth_zones` (Zone 2).** UI only: the button, stat rows, Upgrades groups and the Rebirth tip. Balances, levels and saves are untouched; they return with Zone 2. `Sim.try_rebirth` still works (dev console, tests).
- **Saves:** `bloom_count` is new and defaults to 0, so no save version bump. Seeds is a stat and loads as 0.
- **Open:** pacing is from `tools/sim_bloom.gd`, a greedy floor with no walking, relics or attributes. Taste call: Bloom may want to reset Sprout and Clover progress too (it does, as stats), and the first-time teach tip text.

- 2026-11-23: Golden-hour pass. 08:08 spring looked best because the grade, long shadows and tint were all at once; low_sun() ended at elevation 0.62. Added SkyModel.golden() (floor 0.35 at noon, reach 0.95) driving rim, ground relight, shadow length (elevation squared), light-pass side/split, new sat/contrast in light_grade, wider god rays (zero at noon) and a haze bump. All costs stay at one full-frame pass already present; rays skip at noon. Pond water untouched. Not run in-engine from the cloud.

## STANDING RULE: every zone has its own reset 
- 2026-11-23, Nathan: global Prestige is retired as the main loop. Every zone gets its own rebirth/ascension with its own currency and its own themed upgrade menu, in the same menu style as Upgrades. Meadow = Bloom (Seeds, Bloom Gifts). Ember Quarry = Reforge later. Keep layers modest.
- Built as `ZoneResetDef` (data/zone_reset_def.gd), one .tres per zone in content/resets/. A new zone needs: the def, a currency stat, an icon at 8/16/24/32 px, a colour in StatStyle.COLORS, and gift attributes with `currency` set to it.
- Bloom repeat pacing: resets only Sunlight and Larkmoor's flowers (not Dewdrops or Clover Leaves), +25% pad reward per use, requirement shrinks 15% per use down to 30%. Unmeasured in-engine; run tools/sim_bloom.gd on the PC.

## Relic abilities expansion (2026-11-24)
- **Why:** Nathan asked for many more relics, each with a unique ability rather than a stat bump. Six relics were not enough variety.
- **What:** 27 relics across Common to Mythic (4 to 6 each), using 11 new effect kinds appended to `RelicDef.Effect` so existing `.tres` values keep their meaning. Divine and Special are unchanged (weight 0, granted by rebirths and achievements).
- **Chosen:** each relic gets a distinct trigger (zone, period, heat, repeat, drop, refund, offline rate, pity timer) so a relic reads as its own ability. Some effect kinds appear at two or three rarities with different numbers and triggers; that is a deliberate tier ladder.
- **Random sequence:** a new roll (free presses) only runs when a Free Presses relic is equipped, so runs without one keep the same random sequence.
- **Offline cap:** away income is capped at 0.75 of the awake rate (`offline_rate_cap`). Without the cap, three max lanterns reached 1.12, which broke the rule that idle takes about 2x as long as active (#221). Set by the coordinator on 2026-11-24. `tools/sim.gd` has not been run on the new relics yet; that is the PC QA step.
- **Not verified in-engine:** the new scripts were written and read but not run in Godot here. CI's unit and sim jobs run the new relic tests and the sim paths.

## 2026-11-24 Bigger Bloom and Nucleus gifts (minor)
- **Why:** most gifts were small nudges (+6% pad reward per level, +50 starting Sunlight). Nathan asked for gifts that matter more, and for existing ones to be improved before new ones are added.
- **Chosen:** keep the gift list and the tiers (unlock by Blooms or Nucleus count). Raise the per-level value of the gifts that already move the game most, in data only (`content/attributes/bloom_*.tres`, `nucleus_*.tres`). No script change, so the Upgrades layout (#232) is untouched and the menu text reads the new numbers itself.
- **Changed (per level, cap 10 unless noted):**

| Gift | Before | After | At cap |
|---|---|---|---|
| Head Start (starting Sunlight) | 50 | 120 | 510 to 1,210 start; sprout 3 (1,000) now affordable at once |
| Deep Soil (Sunlight income) | 10% | 15% | +100% to +150% |
| Wide Bloom (pad reward) | 6% | 12% | +60% to +120% |
| Seed Pods (Seeds per Bloom) | 15% | 30% | +150% to +300% |
| Twin Petals (double press) | 4% | 6% | +40% to +60% |
| Bramble (crit chance) | 2% | 3% | +20% to +30% |
| Rooted Study (pad XP) | 15% | 25% | +75% to +125% |
| Anvil Plates (pad reward) | 6% | 12% | +60% to +120% |
| Shard Veins (Core Shards per Nucleus) | 15% | 30% | +150% to +300% |
| Stoked Fire (Embers income) | 10% | 15% | +100% to +150% |
| Flint Edge (crit chance) | 2% | 3% | +20% to +30% |
| Anvil Study (pad XP) | 15% | 25% | +75% to +125% |
| Twin Strike (double press) | 4% | 6% | +40% to +60% |

- **Left alone, on purpose:** Warm Start already opens cinder 3 (600 Embers) at its cap of 1,010, so it does not need more. Wildflower, Dew Sprites, Forge Hands and Heart Strike already press or pay for free at up to 1 to 1.6 a second, and raising them would push idle past the 2x target. Bloom Echo and Core Echo already add 0.25 per Bloom before their own bonus. Roots and Banked Rows keep flowers and rows, which is already the strongest effect in each list. Long Dusk and Slow Burn stay at +4 hours of offline cap, since offline is already 0.5x.
- **Pacing:** not checked. `tools/sim.gd` (the CI sim gate) plays without attributes, so it cannot see these changes. `tools/sim_bloom.gd` plays with the meadow gifts, but Godot does not run in the cloud. Before this ships, the PC QA run should run `tools/sim_bloom.gd` and report minutes per Bloom and the idle:active ratio. Head Start is the one most likely to shift the first cycle.
- **Tests:** `tests/test_nucleus.gd` had the old values (0.10 and 0.15) written in. It now reads them from the gift, so the test follows the data.
- Not run in the engine: the tests and both sims. The menu text and the gift cards are data-driven, so they read the new numbers without a screenshot change, but PC QA should still check a Bloom and a Nucleus card for text width.

## 2026-11-24 Gift second effects and the press proc (minor)
- **Why:** #237 raised the numbers, but each gift still did one thing. Nathan asked for gifts that matter more, so four gifts now carry a second effect that changes how the game plays.
- **Schema:** `AttributeDef` gains `effect2` and `per_level2` (default empty and 0). `Sim.effect_total` sums both, so the rest of the game reads a second effect like any other. Existing gifts are unchanged.
- **Press proc (new effect `press_proc`):** each press has a chance of `per_level2` a level to pay `GameConfig.press_proc_mult` (5) times its reward. Twin Petals and Twin Strike carry it at 0.5% a level, so the cap of 10 gives a 5% chance, about +20% expected press reward. The roll is `Formulas.proc_mult`, which is pure and tested. The roll only draws from the RNG when the effect is owned, so runs without it keep the same random sequence.
- **Reward-bonus synergy:** Wide Bloom adds 1% a level to `bloom_bonus` and Anvil Plates adds 1% a level to `nucleus_bonus`. Each Bloom or Nucleus then pays that much more on every pad, stacking with the base 25% and with Echo. At cap that is +10% a Bloom, so ten Blooms add 100% on top.
- **Idle:** the proc runs on presses only, so it raises active play and slightly lengthens the idle ratio. The Bloom bonus applies to pad rewards, and offline tending pays pad rewards too, so it lifts both sides. Neither was measured.
- **Not done:** no new Bloom-count tier. The existing `unlock_resets` tiers already do the job.
- **Shown:** the gift card puts the second effect on its line 2, after "now -> next" ("+12% -> +14%  +10%/Bloom"), so the card stays at 52 px and the 180 px list cap holds (per the coordinator, after #242's compact cards). The Upgrades tooltip and the Stats index say "Also now X, next Y". `UpgradeText.second_short` and `second_value` do the text. Line 2 may be too wide for a 150 px card with a long second value, so PC QA should check it at 640x360.
- **Not shown:** the stat breakdown (`StatSources`) and `TipText.attribute` (no caller in the game, only tests) still show only the primary effect.
- **Not run in the engine:** the new unit tests run in CI. The idle ratio and pacing still need `tools/sim_bloom.gd` on the PC.

## 2026-11-24: Holding a pad presses at the standing rate
- **Why:** Nathan: "holding down on a button and standing on it should be the same speed." Hold-to-press repeated on its own clock (0.16 s, speeding to 0.07 s, about 6 to 14 presses a second), and a standing walker used the zone's press rate (0.5 a second at base). Two rates for one pad.
- **Call:** the standing rate wins (`Sim.press_interval()`: zone press rate, times attributes and relics). The faster hold rate was not kept because every pacing number (gate times, costs, the 2x idle rule in docs/balance.md) is tuned on the standing rate. Speeding standing up to hold would be about 15 times faster progression.
- **How:** one clock per pad, `core/pad_press_timer.gd`. Standing or holding both step it, so they cannot stack into a double rate. The click is the first press, and the repeat comes one interval later. `HoldPress` (ui/fx/hold_press.gd) is removed; `TexelPad.hold_release()` replaces its release.
- **Taste call to confirm with Nathan:** holding is now slow (zone 1: one press every 2 s). If he wants a fast hold back, it needs a separate hold rate, which breaks "same speed" on purpose.
- **Stale figure:** `content/config/sim_profiles.tres` still has a "hold" profile at 4.0 presses a second. It is a harness assumption, so it was not changed here; it should be set to the active rate (0.5) if the hold profile is kept.
- Not verified in-engine. PC QA should hold a pad and stand on one in zone 1 and Larkmoor, and check that the stacked popup still builds while held and folds on release.

## 2026-11-24: Fast pad presses scale the whole press
- **Why:** a standing press came once every 2 s in zone 1 (press rate 0.5). Nathan wanted a held click and a standing walker at one speed, and a faster rate. Chose "Scale the whole press" on the card "How should fast pad presses keep progression pace?" (option A). Changing only the rate would make progression 8 times faster, and changing only the reward would leave the pad cost out of step with it.
- **Call:** a player press costs and pays `GameConfig.press_scale` (0.125) of its old amount. Presses come 8 times as often, so the stock spent and earned per second match the old tuning.
- **Where:** `press_scale` is in `content/config/game.tres`. `Sim.press_gain` scales the reward, `Sim.press_cost` scales the cost, and `can_press` and `_press` use the same rule. Momentum (`feed_press_momentum`) and mastery XP scale too.
- **Auto presses and pulses** (`allow_pulse` false) pay the full cost and full reward. Offline tending does too, and its rate is `offline_tend_fraction` 0.0125 (was 0.1, divided by 8).
- **Rates:** `press_rate` is 4 in zones 1 to 3 (was 0.5). `sim_profiles.tres` presses per second: idle 1.6, active 4.0, hold 4.0 (was 0.2, 0.5, 4.0). The idle to active ratio stays at 0.4.
- **Tests:** `t.make_sim()` pins `press_scale` to 1 on a private copy of the config, so mechanics suites test the raw formulas. `t.make_sim(true)` gives the shipped config, used by the greedy timeline and the press-scale tests in `test_pad_press.gd`.
- **Not verified:** the balance gates from `tools/sim.gd` on the PC, and in-engine pace. The cloud can't run Godot.
## 2026-11-24: Sealed caches as the late-game sink
Seeds and Core Shards had only gift sinks, about 2,250 Seeds in total, so late stock went unspent (gameplay audit 2026-11-24, 5.5). The caches roll Rare-or-better relics with a price that climbs 1.5x per pull and a cap of five a reset. Reason: the cost resets each reset, so a cache is a steady sink, not a one-off, and the cap keeps it from becoming the only spend. Numbers are in `content/sealed/*.tres` and are unverified in the sim.
## 2026-11-24: Capstone gifts, the Bloom Crown and Nucleus Crown (minor)
- **Why:** the gameplay audit (`plinky/audits/gameplay-loop-audit-2026-11-24.md`, section 5.5) found the largest gift per level was +2%, and Nathan said go on a capstone for each tree, with gifts that change the game.
- **Chosen:** a sixth gift in each tree. `bloom_crown` (Seeds) and `nucleus_crown` (Core Shards): one level (cap 1), 150 of its currency, unlocked after 5 resets of its zone (the same gate scheme as the rest, so it heads its own tier). One level doubles every press on the zones its reset lists.
- **How:** data plus one generic hook. `ZoneResetDef.crown_effect` names the capstone. `Sim.zone_pad_mult(zone)` returns 1 + that gift's total for each reset that lists the zone, and `press_gain` multiplies by it. A Bloom Crown therefore doubles the meadow and Larkmoor and nothing in the quarry, and the reverse for the Nucleus Crown.
- **Why not scale it by level:** one level at x2 is the jump Nathan asked for. A cap of 1 makes it a goal to save for, not a grind.
- **Price (unverified):** 150 is the audit's proposal. It has not been checked against Bloom payouts (2 to 10 Seeds at the usual levels), so it may land late or early. `tools/sim_bloom.gd` buys the cheapest gifts first, so the crown lands last; PC QA should read the Bloom count at which it is bought.
- **Not run in the engine:** the new tests in `test_bloom_gifts.gd` and `test_nucleus.gd` run in CI only. The icons were drawn from one outline at each staged size (see hud.md).

## 2026-11-24: Mastery matters (yield 0.008, crit 0.003, XP growth 1.25)
- Nathan's audit pick: a maxed pad now pays +20% (was +2.5%) and reaches level 25 in about 12,700 XP, about 7 hours on one pad at 0.5 XP/s. Crit chance per level 0.003 (+7.5% at level 25).
- The audit's idle note was wrong: idle is 0.4 of active press rate (1.6 of 4.0 on #287), so the idle rule did not change. Idle's gate time is still about 2.4× active on main (CI sim, 93b063fe), so the gate-time ratio is set by the gate, not the press rate.
- Larkmoor gate on main (93b063fe) is 106 min active, not the 51.6 min in the audit (v0.28.1). The gate change is pending a decision, not part of this entry.
- Not run in-engine. CI `sim` on this PR is the check.
