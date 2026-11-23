# Plinky zone 1 starting balance (v0)

Status: starting values from a quick simulation, 22 Nov 2026. Not tuned by play. `tools/sim.gd` replaces these numbers in M2 and should be the source of truth after that. Every value below belongs in `content/*.tres`, never in a script (SPEC section 5 rules).

## 1. Assumptions
- Tick: 10 per second (dt = 0.1 s).
- Passive base cash: 0.25 per second.
- Press rate: 0.5 per second (the player walks between pads).
- Start: all stats at 0.
- Strategy used in the sim: at each press, buy the furthest affordable button.
- No relics, shrines, crits or attributes. Those come in M4.

## 2. Formulas (from SPEC section 3, with one correction)
```
cash_per_second = base_cash × (1 + multiplier) × prestige_mult
button_gain (mult rewards) = reward × (1 + rebirths)
prestige_mult = 1 + prestige ^ 0.8
```
**Correction to the spec.** SPEC section 3 has two versions of the Rebirths effect. The stat table says Rebirths multiplies Multiplier gain. The formula also multiplies cash by (1 + rebirths). Using both would count rebirths twice. This table uses the stat-table version only. Confirm with Nathan before M2.

## 3. Stats (4)
| id | Display | Start | Effect | Earned by |
|---|---|---|---|---|
| `cash` | Cash | 0 | Spent on Multiplier buttons. Income is passive. | Passive, 0.25 per second × (1 + mult) × prestige_mult |
| `mult` | Multiplier | 0 | Multiplies cash income: (1 + mult). | Multiplier buttons |
| `reb` | Rebirths | 0 | Multiplies Multiplier gain. Gate opens at 9. | Rebirth buttons |
| `prestige` | Prestige | 0 | prestige_mult = 1 + prestige^0.8 on tiers 0 to 2. | Rebirth action (see section 5) |

## 4. Buttons (5)
| id | Row | Cost stat | Cost | Reward stat | Reward | Row index |
|---|---|---|---|---|---|---|
| `m1` | Multiplier | cash | 10 | mult | +1 | 0 |
| `m2` | Multiplier | cash | 100 | mult | +8 | 1 |
| `m3` | Multiplier | cash | 1000 | mult | +64 | 2 |
| `r1` | Rebirth | mult | 3000 | reb | +1 | 0 |
| `r2` | Rebirth | mult | 30000 | reb | +8 | 1 |

Each step in a row costs 10 times more and gives 8 times more (SPEC section 3). Between rows, the Rebirth costs are set high enough that the Multiplier row is always bought first.

## 5. Gate and rebirth
- Zone 1 gate: opens when `reb` reaches 9 (r1 + r2 = 9).
- Rebirth action: available once `reb` is at least 1. It resets cash, mult and reb to 0, and adds `reb` (the value at reset) to `prestige`. Example: a reset at reb = 9 adds 9 prestige, so prestige_mult = 1 + 9^0.8 ≈ 6.1.
- Zone 2 is not balanced here. It starts in zone 2 values, which are not written yet.

## 6. Rough time to each button (simulation output)
| Event | Time (min) |
|---|---|
| m1 first bought | 0.7 |
| m2 first bought | 3.1 |
| m3 first bought | 5.0 |
| r1 first bought | 7.2 |
| Gate opens (reb = 9) | 10.8 |

Read these against SPEC section 1: five buttons should be fun for ten minutes. The gate opens at about 11 minutes, inside the target. The Multiplier buttons arrive by 5 minutes, and the first Rebirth button at 7.2 minutes. Tuning history: base cash 0.1 per second gave a gate at 28 minutes, too slow. 0.25 per second is the chosen value.

## 7. .tres-ready values
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

## 8. Open
- Confirm the Rebirths correction in section 2.
- Gate threshold and base cash: 9 and 0.25 chosen for the 10 to 12 minute target. Confirm with the M2 simulator.
- Zone 2 starting values.

## 9. Round 2 audit (23 Nov 2026, v1 tuning)
Run `python3 docs/balance-sim.py`. Press rate is 1 per second here; the gate time barely moves between 0.5 and 6 presses per second because cash income is passive.

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
