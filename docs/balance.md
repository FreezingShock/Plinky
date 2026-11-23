# Plinky zone 1 starting balance (v0)

> **Which tables are live?** Sections 1 to 8 are the original v0 numbers (five meadow pads, r2 cost 30000) and are kept as history. Section 9 and 10 describe the v1 tuning. Section 11 (round 3) is the current balance for relics, attributes, Larkmoor pads and mastery. Meadow pads are now the six-tier flower ladder (v0.27.0, see decisions.md 2026-11-23); `content/*.tres` and `tools/sim.gd` are the truth over any table here.

Status: starting values from a quick simulation, 22 Nov 2026. Not tuned by play. `tools/sim.gd` replaces these numbers in M2 and should be the source of truth after that. Every value below belongs in `content/*.tres`, never in a script (SPEC section 5 rules).

## 1. Assumptions (v0, historical)
- Tick: 10 per second (dt = 0.1 s).
- Passive base cash: 0.25 per second.
- Press rate: 0.5 per second (the player walks between pads).
- Start: all stats at 0.
- Strategy used in the sim: at each press, buy the furthest affordable button.
- No relics, shrines, crits or attributes. Those come in M4.

## 2. Formulas (from SPEC section 3, with one correction) (v0, historical)
```
cash_per_second = base_cash × (1 + multiplier) × prestige_mult
button_gain (mult rewards) = reward × (1 + rebirths)
prestige_mult = 1 + prestige ^ 0.8
```
**Correction to the spec.** SPEC section 3 has two versions of the Rebirths effect. The stat table says Rebirths multiplies Multiplier gain. The formula also multiplies cash by (1 + rebirths). Using both would count rebirths twice. This table uses the stat-table version only. Confirm with Nathan before M2.

## 3. Stats (4) (v0, historical)
| id | Display | Start | Effect | Earned by |
|---|---|---|---|---|
| `cash` | Cash | 0 | Spent on Multiplier buttons. Income is passive. | Passive, 0.25 per second × (1 + mult) × prestige_mult |
| `mult` | Multiplier | 0 | Multiplies cash income: (1 + mult). | Multiplier buttons |
| `reb` | Rebirths | 0 | Multiplies Multiplier gain. Gate opens at 9. | Rebirth buttons |
| `prestige` | Prestige | 0 | prestige_mult = 1 + prestige^0.8 on tiers 0 to 2. | Rebirth action (see section 5) |

## 4. Buttons (5) (v0, historical)
| id | Row | Cost stat | Cost | Reward stat | Reward | Row index |
|---|---|---|---|---|---|---|
| `m1` | Multiplier | cash | 10 | mult | +1 | 0 |
| `m2` | Multiplier | cash | 100 | mult | +8 | 1 |
| `m3` | Multiplier | cash | 1000 | mult | +64 | 2 |
| `r1` | Rebirth | mult | 3000 | reb | +1 | 0 |
| `r2` | Rebirth | mult | 30000 | reb | +8 | 1 |

Each step in a row costs 10 times more and gives 8 times more (SPEC section 3). Between rows, the Rebirth costs are set high enough that the Multiplier row is always bought first.

## 5. Gate and rebirth (v0, historical)
- Zone 1 gate: opens when `reb` reaches 9 (r1 + r2 = 9).
- Rebirth action: available once `reb` is at least 1. It resets cash, mult and reb to 0, and adds `reb` (the value at reset) to `prestige`. Example: a reset at reb = 9 adds 9 prestige, so prestige_mult = 1 + 9^0.8 ≈ 6.1.
- Zone 2 is not balanced here. It starts in zone 2 values, which are not written yet.

## 6. Rough time to each button (simulation output) (v0, historical)
| Event | Time (min) |
|---|---|
| m1 first bought | 0.7 |
| m2 first bought | 3.1 |
| m3 first bought | 5.0 |
| r1 first bought | 7.2 |
| Gate opens (reb = 9) | 10.8 |

Read these against SPEC section 1: five buttons should be fun for ten minutes. The gate opens at about 11 minutes, inside the target. The Multiplier buttons arrive by 5 minutes, and the first Rebirth button at 7.2 minutes. Tuning history: base cash 0.1 per second gave a gate at 28 minutes, too slow. 0.25 per second is the chosen value.

## 7. .tres-ready values (v0, historical)
Each file uses the field names from SPEC section 5. Values are plain numbers. BigNum conversion happens at load.

`content/stats/`
- `cash.tres`: id = &"cash", display_name = "Cash", start = 0, boosted_by = &"mult"
- `mult.tres`: id = &"mult", display_name = "Multiplier", start = 0, boosted_by = &"reb"
- `reb.tres`: id = &"reb", display_name = "Rebirths", start = 0, boosted_by = &"prestige"
- `prestige.tres`: id = &"prestige", display_name = "Prestige", start = 0, boosts_tiers = 0 to 2

`content/buttons/`
- `m1.tres`: id = &"m1", zone = &"zone1", row = &"multiplier", row_index = 0, cost_stat = &"cash", base_cost = 10, cost_growth = 10.0, reward_stat = &"mult", reward = 1
- `m2.tres`: id = &"m2", zone = &"zone1", row = &"multiplier", row_index = 1, cost_stat = &"cash", base_cost = 100, cost_growth = 10.0, reward_stat = &"mult", reward = 8
- `m3.tres`: id = &"m3", zone = &"zone1", row = &"multiplier", row_index = 2, cost_stat = &"cash", base_cost = 1000, cost_growth = 10.0, reward_stat = &"mult", reward = 64
- `r1.tres`: id = &"r1", zone = &"zone1", row = &"rebirth", row_index = 0, cost_stat = &"mult", base_cost = 3000, cost_growth = 10.0, reward_stat = &"reb", reward = 1
- `r2.tres`: id = &"r2", zone = &"zone1", row = &"rebirth", row_index = 1, cost_stat = &"mult", base_cost = 30000, cost_growth = 10.0, reward_stat = &"reb", reward = 8

`content/zones/`
- `zone1.tres`: id = &"zone1", gate_stat = &"reb", gate_threshold = 9, base_cash_per_second = 0.25, press_rate = 0.5, tick_rate = 10

`cost_growth` is recorded for the design. The explicit `base_cost` on each button is what the game reads, so changing growth alone does nothing until the formula is wired to it.

## 8. Open (v0, historical)
- Confirm the Rebirths correction in section 2.
- Gate threshold and base cash: 9 and 0.25 chosen for the 10 to 12 minute target. Confirm with the M2 simulator.
- Zone 2 starting values.

## 9. Round 2 audit (23 Nov 2026, v1 tuning)
The v1 sim that produced this table (`docs/balance-sim.py`) has been removed; its results are historical and the file is in git history before this change. Press rate was 1 per second; the gate time barely moved between 0.5 and 6 presses per second because cash income is passive.

| Finding (v0) | Number | v1 change | v1 result |
|---|---|---|---|
| First purchase waits for passive cash | 40 s of nothing | Cash starts at 10 (also the value after a rebirth) | First buy at 0 s |
| r2 (30000 mult) is never bought: greedy spends mult on r1 at 3000 | 0 of 9 gate rebirths come from r2 | r2 cost 12000 | Saver path (skip r1, wait for r2) opens the gate at 8.6 min; greedy at 10.5 min |
| Relic drops scale with click speed, not time | 2% per press: about 5 drops in 11 min standing, about 50 with hold-to-press | 1.5% per roll, one roll per second, guaranteed first drop at 60 s, pity at 150 s | About 1 relic per 70 s, whatever the click speed |
| Rebirth loop flattens | Run 1 is 11 min, run 2 is 3.2, then 2.9, 2.8, 2.7, 2.6 min | Not changed. Needs a design decision (Nathan). | See SPEC questions in the thread |
| Early rebirth is a pure loss | Rebirth at reb 1 gives 12.1 min total against 11.3 | Not changed | No decision exists before the gate |

## 10. Round 2 active-play layer (23 Nov 2026)
Run `python3 docs/balance-sim-active.py`. All values are in `content/config/game.tres`. Idle play still opens the gate at 10.5 min; active play is faster.

| Mechanic | Rule | Sim result (gate time) |
|---|---|---|
| Momentum | Walking fills it (about 180 texels), presses add 1% (crit +5%), holds 1.2 s (4 s at full) then drains 0.1 per second. Income x(1 + 0.28 x momentum + stage kickers 1/2/3/6%), full bar +40% as before. The headless sim does not walk or feed presses, so gate times are unchanged | Average +20% income: 10.5 to 9.0 min |
| Golden critter | Appears every 75 to 150 s, stays 12 s, click pays 30 s of income | Caught every time: 10.5 to 8.6 to 9.4 min |
| Pad streak | m1, m2, m3 in order, each within 10 s, pays 5 s of income, 20 s cooldown | Greedy play never does it. Deliberate play adds up to 25% income. |
| All three | | 7.6 to 7.8 min |
| Rebirth push | prestige gain = reb x (reb / 9) ^ 0.5 above 9 reb | Over 60 min: stopping at 9 reb gives 180 prestige, 54 reb gives 1455 (old rule: 594) |

Limits: pushing further wins at every target in the sim, so there is no stop point yet. A cost wall on r1 and r2 would create one. Not decided.

## 11. Round 3 (23 Nov 2026): relics, attributes, pads, RP, mastery, Momentum

Scope: upgrade cost and effect curves, attributes, relic drops and effects, Rebirth Points perks, pad mastery, Momentum. Not touched: meadow pads (zone1), Bloom, Larkmoor pad costs.

### 11.1 What was checked and how
- **In-engine.** `tools/sim.gd` (meadow gate) and `tools/sim_larkmoor.gd` (Larkmoor far gate) run headless. Both use a random seed, so one run can move about 5 minutes. Every number below that comes from them is a mean or median over 8 to 12 runs.
- **Spreadsheet pass.** Pad payback, attribute cost to cap and relic drop shares were worked out from `content/*.tres`. Drop shares use the same roll rules as `core/sim.gd` (one roll per press, at most one per second, first drop by 60 s, pity at 150 s). Monte Carlo over 1 to 60 hours of play.
- **Probe.** A scratch copy of `sim_larkmoor.gd` that equips each relic into a free slot as it drops. It measures what relics do to pacing. Not committed; the same probe is easy to rebuild if needed.

### 11.2 Pads (Larkmoor, unchanged)
Payback = cost / (0.25 cash per second x reward). This is the time for a pad to pay for itself at the base income rate.

| Pad | Row | Cost | Reward | Payback |
|---|---|---|---|---|
| g1 | Multiplier | 8,000 cash | +24 mult | 22 min |
| g2 | Multiplier | 96,000 cash | +192 mult | 33 min |
| h1 | Multiplier | 1.15M cash | +1,536 mult | 50 min |
| h2 | Multiplier | 13.8M cash | +12,288 mult | 75 min |
| t1 | Multiplier | 166M cash | +98,304 mult | 112 min |
| t2 | Multiplier | 1.99B cash | +786,432 mult | 169 min |

Each step is about 1.5x slower to pay back. No pad dominates or is dead, so the Multiplier row stays as is.

Rebirth row: reb per mult falls about 4x per step (o1 5e-5, c1 1.25e-5, l1 3.1e-6, e1 7.8e-7). That is the cost of the big jumps toward the 1,500 gate, so it is left alone.

Found, not changed (other threads): zone 2 forge steps are x10 cost, x8 reward (Larkmoor uses x12 and x8). Meadow r2 gives 2x the reward per cost of r1, so the meadow pads keep the saver path issue from round 2.

### 11.3 Relic drops and stacking (changed)
Drops at 0.5 to 1 press per second: about 45 to 65 per hour, one relic each. Weight by rarity (60, 25, 9, 4, 1.5, 0.4) picks the rarity and then the relic.

**Problem.** The four linear relics had no cap and carry over between rebirths. Gold Purse is common, so it takes about 60% of drops.

| Stacks after | Gold Purse (+10% cash, linear) | Stopwatch (+8% press rate, linear) | Growth Crystal (+15% mult gain, linear) | Sharp Fang (+25% crit damage, linear) |
|---|---|---|---|---|
| 1 hour | +260% | +91% | +42% | +5% |
| 3 hours | +714% | +246% | +153% | +80% |
| 10 hours | +2,474% | +802% | +510% | +390% |

**Tried and rejected: hard caps.** A hard cap sends drops to the rarer relics once the common one is full. Everything capped in about 3 hours of play, so the relic system ended there.

**Chosen: diminishing stacks** (the existing `DIMINISHING` rule, the same one Twin Pads and Pulse Ring already use). Each stack adds a smaller step, the total stays under +100%, and drops keep coming.

| Relic | Rarity | Before | After (per stack) | Total at 1 h | 3 h | 10 h |
|---|---|---|---|---|---|---|
| Gold Purse | Common | linear 10% | diminishing 6% | +80% | +99% | +100% |
| Stopwatch | Uncommon | linear 8% | diminishing 8% | +59% | +92% | +100% |
| Growth Crystal | Rare | linear 15% | diminishing 10% | +25% | +66% | +97% |
| Sharp Fang | Epic | linear 25% | diminishing 25% | +5% | +58% | +98% |

Twin Pads (Legendary) and Pulse Ring (Mythic) were already diminishing, with caps of 10 and 12. Unchanged.

**Pacing effect (probe, Larkmoor far gate, relics equipped as they drop).**

| Setup | Mean far gate | Notes |
|---|---|---|
| No relics (any build) | 57 min | 12 runs each: base tree 57.5, final tree 57.1 |
| All four relics, old linear values | 26 min | Relics cut the pace by more than half |
| All four relics, Gold 10% diminishing, Growth 15% diminishing | 31 min | First try, too fast |
| All four relics, Gold 6%, Growth 10% (shipped) | 35 min | About a third off the unequipped pace |
| Gold alone, 6% | 36 min | |
| Growth alone, 10% | 49 min | |
| Stopwatch alone, or Sharp Fang alone | 57 to 59 min | Barely moves the gate |

Gold Purse and Growth Crystal carry the speed-up. Stopwatch and Sharp Fang are real but matter more later, in standing and crit play.

**Open for Nathan (taste).** Relics are worth a third off Larkmoor's pace (shipped) or half (old). Recommendation: keep a third, because that leaves Larkmoor near its one-hour target. Change `per_stack` in `content/relics/r_cash.tres` and `r_mult.tres` to move it.

### 11.4 Attributes (changed: caps only)
Costs are `base x 1.4^level`, paid in prestige unless the row says otherwise.

| Attribute | Before | After | Total cost to cap | Value at cap |
|---|---|---|---|---|
| Pad yield (unlocks at 10 Rebirths) | cap 25, total 224,944 prestige, last level 64,284 | cap 15, total 7,728, last level 2,222 | 29x cheaper | +50% to +30% press reward |
| Quick study (5 Rebirths) | cap 20, total 20,892 | cap 10, total 698 | 30x cheaper | +100% to +50% mastery XP |
| Press rate | cap 20, total 6,268 | cap 15, total 1,159 | 5x cheaper | +200% to +150% press rate |

Why pad yield: last level was 64k prestige for +2% press reward, about 13x worse per prestige than crit chance's last level (9.6k for +1% crit chance, worth about +4% expected press at the 5x crit). Now the last level is 2.2k for +2%.

Why quick study: mastery effects are small (see 11.6), so +100% mastery XP for 21k prestige is over-priced.

Why press rate: Stopwatch now doubles press rate at most, so the two together would reach about 6 presses per second while standing. Capping the attribute at 15 keeps the stack near 5x base (about 2.5 presses per second).

Left alone: crit chance (34k for +25% chance), crit power (17k for +1.0x crit), luck, walk speed, offline gain.

### 11.5 Rebirth Points perks (unchanged)
RP paid per rebirth: 1 at the start, 2 from rebirth 10, 3 from rebirth 20 (`rp_base 1 + 0.1 per rebirth done`, rounded down). Total after 50 rebirths: 150 RP. After 100: 550.
Costs to cap: Pad lore 227 RP, Lucky streak 340 RP, Deep sleep 69 RP. Total 636 RP, so the perks take about 100 rebirths. Nothing to fix.

### 11.6 Pad mastery (unchanged, flagged)
Level 10 takes about 650 presses on one pad. Level 25 takes about 62,000 presses, about 9 hours of pressing one pad. At max a pad gets +2.5% yield, +2.5% crit chance and +1.0 crit damage.

Mastery feeds press yield inside the sim, so changing it moves the Larkmoor far gate. It was tuned down to hit that pacing in the last round (decisions log, 23 Nov). I left it alone.
**Open for Nathan:** keep mastery as a long tail (current), or raise it and retarget Larkmoor's pacing. Recommendation: keep it, since it makes long runs feel different without touching the one-hour target.

### 11.7 Momentum (unchanged)
Stage bonuses (+1, +2, +3, +6%) match the four thresholds and five names. A full bar gives +28% charge plus +12% kickers, so +40% total. Presses add 1% each, so standing on a pad at about 2 presses per second fills the bar. That is intended, but it is why the press rate cap moved.

### 11.8 Number overflow
No risk found. `BigNum` keeps a float mantissa and an integer exponent, so there is no float overflow. `NumberFormat` gives suffixes up to 10^3003, then e-notation. Checked against the 10-hour relic and pad magnitudes, which stay well inside that range.

### 11.9 Flagged for other threads
- **Prestige formula** (`prestige_mult = 1 + prestige^0.8`, with prestige per rebirth growing roughly linearly): income multiplier grows as N^0.8 across rebirths. This belongs to the Bloom thread. Not changed.
- Zone 2 forge curve (x10 cost) and meadow r2 (see 11.2).

### 11.10 Verification
- Headless tests: 2612 checks, 0 failed (2600 before, plus 12 new regression checks, three per stacking relic: diminishes, first stack is its full step, at or under 100% after 1000 stacks; the Gold Purse assertion was updated to the new step).
- Not run here: the screenshot tool. It draws nothing under the cloud's software renderer, so the PC thread should check the relic and attribute panels in-engine.

## 13. Flower ladder pacing check (23 Nov 2026, before #171, main at 5f4ab24, v0.27.0)
Run `godot --headless --path . --script tools/sim.gd`. Greedy buys (highest row first), no walking, attributes or relics. Each profile runs 8 seeded games. Times are minutes from the start of the meadow. Larkmoor's first tier (Thistle) opens on arrival, so it has no unlock time.

| Profile | Presses/s | Clover opens | Heather opens | Foxglove opens | Starbloom opens | Meadow gate median (range) | Larkmoor gate median (range) |
|---|---|---|---|---|---|---|---|
| idle | 0.2 | 4.4 | 17.1 | 67.0 | 124.1 | 16.6 (16.2 to 16.6) | 134.4 (71.6 to 136.9) |
| active | 0.5 | 4.4 | 11.4 | 30.9 | 52.9 | 10.1 (9.8 to 10.1) | 56.0 (33.7 to 58.8) |
| hold | 4.0 | 5.1 | 24.1 | 31.0 | 34.0 | 9.8 (9.6 to 9.8) | 34.5 (17.0 to 95.0) |

- **Meadow:** active sits on the 10 minute target. Nothing changed in the meadow.
- **Sunlight carried into Larkmoor (seed 1, active):** 4.49K. Thistle 1 costs 8K, and the Thistle row is bought within about a minute of arriving. The Thistle tier does not pace Larkmoor: Heather opens 1.3 minutes after arrival.
- **Larkmoor far gate:** 56.0 median on active, under the 57 to 61 target. The spread between seeds is large (33.7 to 58.8). The median is the number to read; a single run can move by 20 minutes. Hold is faster, so a press-rate change moves the gate more than any single cost.
- **Handed to the flower tiers thread (not edited here):** the Thistle row costs too little to pace Larkmoor, so Heather opens almost on arrival. Raising the Thistle costs would move Heather and everything after it.
- **Idle:** at one press every 5 seconds the far gate is about 2 h 15 min. Decide with Nathan whether that is acceptable.
## 12. Meadow flower ladder and quarry ladder (23 Nov 2026, pointer)
- **Meadow (v0.27.0):** six flower tiers replace the old Cash, Multiplier and Rebirth pads. Costs and rewards are in `content/buttons/*.tres` and `content/tiers/*.tres`; the table is in decisions.md under the 2026-11-23 flower ladder entry. Sim result: meadow gate at 10.1 min, Larkmoor far gate at 59.2 min.
- **Bloom:** the meadow's reset layer is decided but not built, so rebirth-loop findings in sections 9 and 10 stay open until it lands.
- **Ember Quarry:** the ladder pitch (Cinder to Emberhearts, rebirth sourced from Ingots, flat arrival grant) is in docs/zone2-ladder.md. Numbers there are starting values for the quarry balance thread.


### Cost pass after #171 (23 Nov 2026, v0.28.1)
Brief from Nathan: fast and satisfying progression, short gaps between unlocks, idle about 2x active, Larkmoor near 57 to 61 min on active. Changed data only: Heather 3 2.3M to 1M Thistle, Foxglove 3 1800 to 1000 Heather, Starbloom 3 2000 to 1000 Foxglove, Larkmoor gate 2000 to 2600 Starbloom. Meadow and Thistle unchanged.

| Profile | Heather opens | Foxglove opens | Starbloom opens | Far gate median (range) |
|---|---|---|---|---|
| active, before (v0.28.0) | 11.4 | 27.4 | 40.7 | 58.4 (43.0 to 60.8) |
| active, after (v0.28.1) | 11.4 | 22.5 | 33.9 | 51.6 (38.6 to 64.2) |
| idle, after | 17.1 | 45.0 | 73.0 | 114.8 (85.5 to 120.7), 2.2x active |
| hold, after | 24.1 | 28.5 | 29.9 | 30.1 (16.0 to 91.1) |

- **Gaps (active, after):** Heather to Foxglove 11.1 min, Foxglove to Starbloom 11.4 min, Starbloom 3 bought at 46.5 min, 12.5 min after Starbloom 2. Before, the Foxglove and Starbloom gaps were 16.0 and 13.3 min.
- **Not met:** the far gate at 51.6 is about 5 min short of 57 to 61. The gate barely responds to its own levers: threshold 5000 gave +3 min, Starbloom 3 costs from 3000 to 12000 gave the same 51 to 52 min. The next lever is Foxglove income. Decision for Nathan.
- **Thistle:** unchanged. Heather still opens about 1 min after arrival, because the Sunlight carried in buys Thistle quickly.
