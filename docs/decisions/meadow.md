# Decisions: Meadow and Larkmoor

Zone 1 and Larkmoor: the meadow map, the flower ladder, its Bloom reset, and its pacing. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## Larkmoor, the big meadow (23 Nov)
- The small meadow (`zone1`) is now the onboarding area. Its gate (9 Rebirths, unchanged) leads to a new zone, **Larkmoor** (`larkmoor`, order 1). Zone 2 (Ember Quarry) moves to order 2 and sits behind Larkmoor's far gate. `zone1.next_zone = larkmoor`, `larkmoor.next_zone = zone2`.
- Larkmoor is one 1520x920 canvas (about 4x the area of the onboarding island), rendered by `tools/art/gen_larkmoor.py` from the same 3D pipeline, palette and props as zone 1. Layout data is in `tools/art/larkmoor_layout.py`; `larkmoor_map.py` draws the layout mockup. Texel coordinates are canvas pixels (no 640x360 bleed offset).
- Seven districts (Gatehouse Green, Heronmere, Thistle Rise, Old Oak Crossing, Cairnfold, Lanternwood, Emberwatch), a main road with a west and an east loop, a footbridge over the stream, a windmill, a jetty, a ring of standing stones, an elder oak, and two stone gateways (onboarding arch in the south, far gate in the north). A banner names the district on entry.
- Ten pads: Multiplier row g1..t2 (6 pads, cost Cash 2e4 x12 per step, +24 x8 per step) and Rebirth row o1..e1 (4 pads, cost Multiplier 3e5 x40 per step, +6 x10 per step). Far gate opens at 1500 Rebirths. **Provisional.** `tools/sim_larkmoor.gd` (greedy, no rebirths) reaches the gate about 3 hours after arriving. It is a rough check, not tuning.
- Scenes can say how big they are: `world_rect` (camera and walker bounds), `mask_offset`, `placements_path`, `ground_path`. main.gd reads them on zone entry; `WalkMask.use(path, offset)`, `MeadowSites.use(...)` and `TexelWalker.bounds` follow the active zone. Scenes that say nothing keep the 640x360 frame with bleed.
- Crossing zones uses the existing transitions layer: `Transitions.cross_zone()` runs the dither wipe to ASCII, swaps the scene while covered, then clears. The camera snaps to the walker. Going forward you arrive at the new zone's Walker anchor; going back (Arch in Larkmoor leads to the meadow) you appear just inside the Gate anchor.
- Save migration: a save that was already in zone 2 stays there, and Larkmoor's gate (and the onboarding gate) are latched open for it. A save in the onboarding meadow with its gate open now walks into Larkmoor.
- Larkmoor reuses `meadow` palette and the meadow life layers (grass sway, fireflies) with its own anchors from `gen_life_anchors.py --bounds ... --sway-count ...`.
- Open: day/night and weather (PR #41) and walker reactions (PR #34) are not wired to the Larkmoor scene yet; both read the scene's ground, so they should work once merged. Pad colours, names and numbers are Nathan's call.
| 2026-11-23 | Window placement (core/window_place.gd, DisplaySettings.place_window): first launch centres the window on the screen under the cursor (else primary), 90% of that screen at most. Every later start, and every return from fullscreen, clamps the window wholly onto the one screen that holds most of it, shrinking if needed. Dead zones between monitors of different sizes pull it to the nearest screen | The exe opened across the gap on a 3840x1483 two-monitor desktop. Pure Rect2i math with tests: straddling, dead zone, off-screen, oversized, negative coordinates, tiny screens. |
| 2026-11-23 | Prop cast shadows made solid: oval body fully shadowed, dither only on the rim and tip; darker shade, wider ovals, dusk length 1.7 heights (noon 0.3). Dusk grade density 0.4, god rays 0.7 | The PC grab at 1080p could not make out the prop shadows; the heavy dither also swallowed them at dusk. |
| 2026-11-23 | bench.gd forces vsync and the fps cap off after settings load, and runs the meadow and Larkmoor through noon, sunset, night and rain | Vsync now defaults on from saved settings, which capped earlier runs at 180 Hz. Budgets are in docs/perf.md. |
| 2026-11-23 | SkyRain caches two of its three per-drop hashes and scales drop count with quality | Rain had 5 ms spike frames on its 12 fps redraw. Stateless, so nothing to pool. |
| 2026-11-23 | Bench starts a fresh in-memory game and turns Save off (Save.enabled) | The PC bench found no Larkmoor rows, most likely because Nathan's save was already in Larkmoor, so enter_zone returned false. Starting fresh also makes the "meadow" rows really the meadow, and the bench no longer overwrites the save. A failed entry now prints why. |
| 2026-11-23 | The god rays rect and cast shadows hide while their strength is about 0 | Rays are 0 at noon and night, but their atan/sin pass over the 860x500 area still ran. Noon at High was about 0.2 ms heavier than night; this is a hypothesis, to be confirmed by the next PC bench. |
| 2026-11-23 | God rays and cast shadows stay drawn for their first 4 frames after a scene loads | Hiding them while idle (previous entry) meant their shaders first compiled at the first sunset, which is the likely cause of the 195 ms hitch on Low in Larkmoor. Compiling at load moves the stall behind the loading screen. |
| 2026-11-23 | bench.gd times each sky and life layer at noon on High (layers/-Name rows) | Noon on Medium and High did not get cheaper after the ray and shadow hide, so the cost needs to be found per layer, not guessed. |

## Meadow flower ladder (2026-11-23)
- **Decision (Nathan):** the meadow is six tiers, each a line of three pads that pay one statistic: Sprout (Dewdrops, Common), Clover (Clover Leaves, Uncommon), Thistle (Thistle Down, Rare), Heather (Heather Sprigs, Epic), Foxglove (Foxglove Bells, Legendary), Starbloom (Starbloom Petals, Mythic). Cash, Multiplier and Rebirth are replaced here and return in Zone 2. Passive income is a new stat, Sunlight.
- **Unlock:** a zone's first tier is open; pressing the last pad of a tier once opens the next (latched in `tiers_open`). Locked pads show a dull bud and cannot be bought, even in god mode. Data: `content/tiers/*.tres` (`TierDef`).
- **Chain:** each stat boosts the one before it as `gain_boost_stat` (Clover Leaves boost Dewdrop rewards, and so on up to Starbloom). Costs are zone-local: Larkmoor pads cost Larkmoor stats (Thistle costs Sunlight), so a Larkmoor pad never needs a stat earned only in the meadow. Boosts, not costs, link zones. Stats carry a `zones` list; out of zone they earn and show nothing.
- **Economy:** Sprout 10/100/1000 Sunlight for +1/+8/+64 Dewdrops; Clover 3K/12K/48K Dewdrops; Thistle 8K/96K/1.15M Sunlight; Heather 23K/230K/2.3M Thistle; Foxglove 18/180/1800 Heather; Starbloom 20/200/2000 Foxglove. `tools/sim.gd` (replaces `sim_larkmoor.gd`): meadow gate at 10.1 min (9 Clover Leaves), Larkmoor gate at 59.2 min (120 Starbloom Petals), tiers opening at 11.4 (Heather), 31.7 (Foxglove) and 54.5 min (Starbloom), inside the 57 to 61 min Larkmoor target; a PC feel pass is still wanted.
- **Zone 2 arrival:** `entry_source_stat` Starbloom with `entry_grants` Cash 10000 and Multiplier 1000. Not calibrated.
- **Saves:** `ladder = 1`. Old saves keep mastery (pad ids mapped), Cash becomes Sunlight, Multiplier and Rebirths become Dewdrops and Clover Leaves, tiers open from practised pads and open gates. Saves still in Zone 2 are left as they were.
- **Layout:** Larkmoor rows are straight 2:1 lines stepping (44, -22) or (44, +22), four rows in Green, Oak, Thistle Rise and Emberwatch; Heronmere, Cairnfold and Lanternwood have no pads for now. Trees and bushes were pushed off the rows and the generators keep a clear radius around every pad.
- **Open:** Rebirth, Prestige, Rebirth Points and relics still run from Clover Leaves (`prestige_source_stat`). Tiers 3 to 6 and the meta layer want a feel pass; each tier has a 13 texel standing flower on its pad (Sprout dewdrop, Clover four-leaf, Thistle, Heather sprig, Foxglove spire, Starbloom star); opening a tier raises the flower row by row with a petal burst (`TexelPad._bloom_t`). The Bloom layer is meant to replace Prestige and Rebirth in the meadow; `prestige_source_stat` (Clover Leaves) and `tier_opened` are the hooks.
- Not run in the cloud: the engine on real hardware. CI and the PC pass confirm the look.

## Larkmoor cost pass: smoother unlocks, gate still short (2026-11-23)
- **Brief (Nathan, via coordinator):** progression should feel fast and satisfying; short gaps between unlocks, no long dead stretches; idle about 2x active is fine; Larkmoor near 57 to 61 min on active.
- **Changed (data only):** Heather 3 base cost 2.3M to 1M Thistle; Foxglove 3 1800 to 1000 Heather; Starbloom 3 2000 to 1000 Foxglove; Larkmoor `gate_threshold` 2000 to 2600 Starbloom. Meadow and Thistle costs unchanged.
- **Result (active, median of 8 seeds):** Heather opens 11.4 min, Foxglove 22.5, Starbloom 33.9, far gate 51.6 (range 38.6 to 64.2). Before: 11.4, 27.4, 40.7, 58.4. Idle gate 114.8 (2.2x active). Hold 30.1.
- **Still open:** the far gate is about 5 min short of the 57 to 61 target. The gate is a weak lever: raising the threshold to 5000 moved it about 3 min, and Starbloom 3 costs from 3000 to 12000 changed nothing. The next lever is Foxglove income (its rewards or the Heather costs), which slows the middle tiers too. Nathan to choose: accept about 52 min as faster progression, or slow the Foxglove economy to hit 57 to 61.
- **HUD currency panel is a compact strip (v0.29.0).** Names removed (instant tooltips carry them); value takes the stat colour; gain is 8 px dim text left of the value; rows show only once the stat has been held (latched per session) and only in the current zone. Chosen over a "headline + fold" panel because every earned currency stays glanceable and it needs no extra click. Collapse toggle left for later.
- **HUD currency panel is a compact strip .** Names removed (instant tooltips carry them); value takes the stat colour; gain is 8 px dim text left of the value; rows show only once the stat has been held (latched per session) and only in the current zone. Chosen over a "headline + fold" panel because every earned currency stays glanceable and it needs no extra click. Collapse toggle left for later.

## Larkmoor Clover row by the Heronmere lake (2026-11-24)
- **Why:** Nathan's feedback on the Clover pads from #223. The row stood in Cairnfold's north, far from spawn, and it looked locked, so he asked why it stayed shut until a Dewdrop pad was pressed.
- **Layout:** the Clover row now stands on the lake shore below the Sprout row, pad 1 nearest the road, at (504,652), (460,630), (416,608). It keeps its fifth slot in `DISTRICTS`, so the pad order still matches `pad_buttons`. The Cairnfold area now lists no pads, and Heronmere lists Sprout then Clover. Cairnfold's own district centre is unchanged.
- **Unlock kept:** Clover opens when the last Sprout pad is pressed, as before. The cost is Dewdrops. The tooltip says so, and the first pad of a locked row now draws "Needs <cost>" under its plate.
- **Budget:** the regenerated layout has 100 props against 96 before. All 18 pads are reachable from spawn on the walk mask. The CI play job checks the node ceiling.
- Not run in-engine from the cloud.
- **Sway tips:** `world/larkmoor_life.json` was regenerated from the new backdrop with the command in the 2026-11-23 Larkmoor entry (`--bounds 190,110,1340,725 --sway-count 420`). The old tips sat on the old ground, so `tests/test_life.gd` failed in CI. Checked here: all 420 tips sit on the palette colour the old tips used. Not run in engine.

## Restored after the #220 split (lost text from the pre-split log)

## 2026-11-23 Larkmoor Dewdrop and Clover rows (minor)
- **Why the pads were tutorial-only:** the flower ladder (v0.27.0) made Sprout (Dewdrops) and Clover Leaves the meadow's first two tiers. Clover Leaves is the meadow gate stat (9 to open Larkmoor), and Larkmoor was built as Thistle, Heather, Foxglove and Starbloom. The hand-off was intended, not a bug.
- **Added (Nathan's call):** two rows in Larkmoor, each its own tier so meadow unlocks stay apart. `lark_sprout` (Dewdrops, common) at Heronmere beside the lake path, paid in Sunlight at 10, 100, 1000 for 1, 8, 64 Dewdrops. `lark_clover` (Clover Leaves, uncommon) at Cairnfold beside the north path, paid in Dewdrops at 300, 1200, 4800 for 1, 8, 64 Clover Leaves. Larkmoor now opens on Sprout, then Clover, then Thistle, matching rarity order.
- **Art:** pads reuse the meadow flower art through `TexelPad.FLOWER_OF`, so pad 1 is plain, pad 2 adds sprouts and pad 3 is the flower bed with glints (the #212 stages). Pad 1 is the end nearest the road.
- **Layout:** rows placed in `tools/art/larkmoor_layout.py`, art regenerated with `gen_larkmoor.py`. Every pad passes the generator's walk-reach check. `world/larkmoor_life.json` regenerated with the arguments recorded above.
- **Pacing (`tools/sim.gd`, median of 8 seeds, active profile):** far gate 51.6 to 51.8 min; idle 114.8 to 117.7 min (idle about 2.3x active). Rejected: meadow-scale Clover costs (3000/12000/48000 Dewdrops) gave 62.8 min, and Sunlight costs of 100/1000/10000 with Dewdrops 1000/3000/9000 gave 79.5 min.
- **Flag:** the hold profile (4 presses/s, a fast clicker) falls from 30.1 to 16.2 min to the Larkmoor gate. Left as is; a taste call for Nathan whether to raise the new costs.
- Not run in the engine: the pad art and placement (screenshots need a GPU; the headless sim and tests did run).

## 2026-11-24: Heronmere rows on walkable ground
- **Why:** Nathan's marked-up screenshot of v0.51.1 (PC QA): the Dewdrop (Sprout) row should sit on the open grass below the main path, and the Clover row on the south lake shore. The Clover pads had most of their footprint off the walk mask, so they sat on the shore edge rather than on walkable ground.
- **Sprout (dewdrops):** `(644,658)`, `(688,680)`, `(732,702)`, pad 1 nearest the road. Every footprint pixel is walkable and the row clears the path and landmarks by at least 16 texels.
- **Clover (clover leaves):** `(546,648)`, `(502,626)`, `(458,604)`, pad 1 nearest the road. The walk mask only covers a narrow band along the lake shore, so the row sits on that band, a few texels inward from where the pads sat before.
- **Cost chip:** the first pad of a locked row draws "Needs <cost>" on a dark backing box. The chip was not visible in PC QA. The code path checks out (button_id is set before `_ready`), so the backing box is the fix to confirm on a capture.
- **Colour:** Clover pads have a gold rim (`#f2c14e`) in place of the grass green. A buyable Clover pad keeps the buy-state green.
- **Props and lights:** props went from 100 to 90 and glow lights from 5 to 3, because the generator cleared props around the moved pads.
- **Sway tips:** regenerated with the 2026-11-23 command. All 420 sit on the palette colour.
- Not run in-engine from the cloud.
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
## Upgrades menu fit and menu layer (2026-11-24)
- **Cards:** stacked to three lines (name and level; now to next; pips and cost). The Buy button is gone: the whole card buys, and Enter or Space buys while the card has focus. Two across at 150 px, so the panel is about a third narrower.
- **Outline and dim:** affordable is a bright green frame; unaffordable is a red frame with the contents dimmed to 55%, so the two read apart. Maxed is gold, locked is dim.
- **Uniform tiers:** each tier's grid has a fixed width, so tier 2 matches tier 1.
- **Height:** the list takes what its tab needs, up to 180 px, then scrolls.
- **Menu layer:** a shown menu moves to the end of its parent (`MenuAnim.bring_front`), so the relic bar, momentum meter, sprint trail and HUD chips all draw under it. No HUD piece draws over an open menu. Every menu is covered: animated ones through `MenuAnim.attach`, the rest through `MenuAnim.front_on_show`.
- **Tab highlight:** one function (`Hud._apply_upgrade_tab`) sets the page and the highlight together, and runs on every select and refresh. Opening the menu picks the current zone's tab.
- Not verified in-engine: the new size at 640x360, the z order against each HUD piece, the dim levels. PC QA should check both zones and a click, a hold and a Enter buy.


## Menus clear of the meter, zone gifts only in Upgrades (2026-11-24)
- **Meter:** a centred menu whose column reaches the momentum meter's column stops 6 px above the meter, so the meter's corner is never covered. Menus that do not reach the meter's column stay centred on the frame. Chosen over hiding the meter while a menu is open, because the meter's state stays visible during a menu.
- **Attributes:** the Stats and Attributes page lists only Prestige and Rebirth Perk attributes. Zone gifts (Bloom, Nucleus) appear only in the Upgrades gallery, which already groups them. Chosen over filtering by zone, because a gift has one home and two places showing it would drift.
- Not verified in-engine: the panel's new height above the meter at 640x360, and the Attributes page with a Nucleus save. PC QA should check both.

## Every zone's gifts get a tab in Upgrades (2026-11-24)
- **Why:** #228 showed only the zone you stand in, so the quarry's Upgrades gallery was one lone "Nucleus Gifts" header. It read as empty.
- **Tabs:** every zone reset's gifts have a tab, locked or not. The zone you stand in comes first in the strip, then the others in reset order. Each tier already says what gates it.
- **Kept as is:** `group_shown` still hides a zone's contents until that zone opens. The HUD currency chips and the Stats index use it, so their behaviour does not change. The gallery uses the new `UpgradeText.tab_shown`.
- **Tab look:** the active tab is drawn in its accent colour with a solid underline, not a dotted focus box. The tab keeps the ">" marker and sweep on hover or focus. The title and pause menus keep their focus box.
- Not verified in-engine: the strip at 640x360 with two zones, and the tab order after a zone change. PC QA should check the meadow and the quarry.

## Upgrade tabs follow keyboard focus (2026-11-24)
- **Why:** PC QA found that Left and Right moved the tab highlight in the quarry but left the cards on Nucleus. The tab only selected on press, so focus and selection drifted apart.
- **Fix:** a tab that gains focus selects its page, the same as a press. Mouse, Enter and pad all still work. Focus and selection now always agree.
- Not verified in-engine. PC QA should check Left and Right across both zones' tabs.

## WASD walks while a menu is open (2026-11-24)
- **Why:** opening any menu froze the walker, so a player could not walk while a panel was up. The ask was WASD only, with GUI clicks still blocked.
- **Rule:** `PadInput.move_vector` reads WASD by physical key while `menu_open` (`menu_walk_vector`, `walk_from_keys`). Arrows, d-pad and the left stick do not walk in a menu, because Godot's ui_* actions use them for menu focus. Pad users still cannot walk in a menu. That is a choice, not a gap.
- **Still blocked:** Space (jump) while a menu is open, because Space presses buttons. Typing in any LineEdit or TextEdit (Feedback, dev console) stops all walking. A Settings key rebind (`PadInput.key_capture`, set by the display panel) stops walking too, so W can be bound without moving.
- **Sprint and crouch** still work while walking in a menu. They are modifiers, and no menu uses Shift or C.
- **Tap-to-move:** a pending walk target is dropped when a menu opens or a field takes keys, so the walker does not keep walking after the menu is up.
- Not verified in-engine: walking with WASD under the Upgrades, Relics and Settings panels, typing in Feedback with W/A/S/D, and rebinding W in Settings. PC QA should check those four.
