# Parked content

Not loaded by the game (ContentLoader only reads the live content folders). Kept for reuse.

- `stats/cash.tres` and `stats/mult.tres`: the original Cash and Multiplier stats. Nathan removed them from the Ember
  Quarry (v0.34.0) and plans to bring them back in a later "nostalgic, liminal" zone. In the quarry they became
  Embers (the passive trickle) and Cinder (the first forge row). The art is still at `assets/icons/cash.png` and
  `assets/icons/mult.png`, the colours (Cash `f2c94c`, Multiplier `55aaff`) are in the git history of `ui/stat_style.gd`,
  and the relic effects `CASH_MULT` and `MULT_GAIN` still exist in `data/relic_def.gd`.
- To revive: move the files back to `content/stats/`, give them a new `zones` list, add stat colour and tooltip text.
- `attributes/`: eleven attributes that could never be bought. Eight were paid in Prestige and three in Rebirth Points,
  and Rebirth is off (`rebirth_zones` is empty), so neither currency is ever earned. Their zone gifts replaced the
  rest. Three effects had no gift at all: Press rate (`press_rate`), Luck (`luck`) and Crit damage (`crit_power`).
  `tests/run.gd` revives these eleven into every test sim (`PARKED_FOR_TESTS`), so the mechanics stay covered.
  To revive one for play: move it back to `content/attributes/`, check its currency, and drop it from that list.
