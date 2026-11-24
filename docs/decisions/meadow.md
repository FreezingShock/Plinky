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

## 2026-11-24: Clover chip and gold rim
- **Why:** PC QA on v0.58.2: the "Needs Dewdrops" chip did not show at 1x, and the Clover rim read green at 3x. The Clover row is uncommon, so its rarity ring was the uncommon green, and its gems were the Clover reward green. Both drew over the one-texel gold rim.
- **What:** Clover pads take the gold `#f2c14e` on the rim, the lit rim, the dashed rarity ring and the corner gems. The chip is a cream box with an ink border and ink text, drawn under the plate. The buy-state green inside the plate is unchanged.
- Not run in-engine from the cloud. Please check the chip and the rim at 1x and 3x on a PC capture.

## 2026-11-24: Cost chip legible at 1x
- **Why:** PC QA on v0.58.4: the cream chip now shows, but its digits did not read at 1x. The chip was drawn with the 5x8 font at size 16, which doubles every glyph. The text filled the chip in ink and ran past its top and bottom edges.
- **What:** The chip uses the font's native size 8, so each glyph is one screen texel. The chip is 12 rows (ink border, 10 cream rows) with the 8-row text centred in it, and every origin and width is a whole texel.
- Not run in-engine from the cloud. Please check the chip at 1x on a PC capture.

## 2026-11-24: Cost chip redrawn, with a test
- **Why:** PC QA on v0.58.5: after the native-size change no chip showed on any Clover pad, at 1x or in a 4x crop.
- **What:** The chip's box and text placement are in `TexelPad.lock_chip_box` and `shows_lock_chip`, which `_draw` calls. The text is drawn with the same call shape as the 16 px version that drew, at the font's native size 8. `tests/test_pad_plate.gd` asserts the draw decision, the box size and the glyph coverage.
- **Not proven:** the headless suite can't see pixels, so the chip is still checked on a PC capture. The cause of the vanish has not been pinned down from code.

## 2026-11-24: Cost chip shows the cost and its icon
- **Why:** PC QA on v0.58.6: the chip read "Needs Dewdrops" with no number, and Nathan asked for a cost chip.
- **What:** The chip on a locked row's first pad shows the pad's cost (`Formulas.button_cost(...).format()`) and the cost stat's 8 px icon, in the same 8 px text on the cream chip. A pad's cost depends only on its definition, so the text is set once in `_ready`. The icon is an 8 px staged icon from `IconSet`, drawn as a texture on the chip, which is a UI label on the grass and not world geometry.
- The chip is only on each row's first pad, as before. Other pads in a locked row show no chip.
- Not run in-engine. The layout test checks the box and the glyph coverage with the real Clover cost.

## 2026-11-24: Cost chip beside the plate, digits spaced
- **Why:** PC QA on v0.58.7: at 1x the digits of "300" ran together, because the 5 px font has no spacing of its own. The chip also sat under the plate, where the walker stands, so the sprite covered part of it.
- **What:** The chip is beside the plate's right end, centred on the top face, so nothing stands on it. Digits are drawn one glyph at a time with one texel between them. The 6x12 body font would not fit the 12-row chip, so the chip keeps the 5x8 native font.
- Not run in-engine. The layout test checks the position and the spacing with the real Clover cost.

## 2026-11-24: Cost chip above the air layer
- **Why:** PC QA on v0.58.8: faint bluish speckles showed behind the last two digits. The chip was drawn in the pad's own `_draw`, and the air layer (`LifeAir`, z 10, fireflies, glow, sparkles and the pad shimmer) draws over every pad.
- **What:** The chip is a child node of its first pad, at `LOCK_CHIP_Z` 11, so it draws above the air layer. It stays opaque and is shown or hidden as the row's lock changes. `tests/test_pad_plate.gd` asserts the z order.
- Not run in-engine. Please check the chip on a PC capture for the speckles.

## 2026-11-24: Meadow water rework
- **Brief (Nathan, via coordinator):** the meadow map is nice but needs to be larger and more polished; rework the lake, shoreline and streams and keep the mountains' look (they grow with the map).
- **Changed:** the lake radius 46 to 54 texels (about 17 percent wider) (still a bowl with the same shore blend); the stream bed is cut 0.9 below its own downhill water surface, so the river is one continuous ribbon instead of a dry channel with gaps; white water only on the stream banks, not down the middle; 90 shore reeds (was 46) and 60 lily pads on the lake (was 42).
- **Why:** the old stream was dry for about half its length, so it never read as water, and the lake's rim was a flat dark bowl. Foam down the whole mountain stream read as a pale column, not water.
- **Side effects:** the bigger lake takes two oaks and a crystal cluster that stood on its edge; the walkable area is 10.2% (was 11.1%) and every pad and the gate are still reachable (generator check).
- **Not run in the cloud:** the in-engine look and the sound sites (`MeadowSites` shore loudness) on the PC. The headless tests were not run here (no Godot in this container).
## 2026-11-24: Clover stays green inside its gold rim; Dewdrop row moves in
- **Why:** Nathan asked why the Clover pads were yellow (screenshots from PC QA). The gold for the Clover rim was also set as the stat colour, so the gems and flowers went gold. Nathan also said the Dewdrop pads sat too close to the arrival gate.
- **Clover:** the gold is now only the rim, lit rim and rarity ring. The gems, pip and flowers keep the Clover reward green.
- **Dewdrops:** the Sprout row moved from (644,658), (688,680), (732,702) to (634,568), (678,590), (722,612), beside the main path north of the gatehouse tower. The nearest pad is 111 texels from the arrival gate, up from 31. Every footprint is on walkable ground, and all 18 pads are reachable from spawn on the walk mask.
- **Art:** `gen_larkmoor.py` regenerated the Larkmoor art, and the sway tips in `world/larkmoor_life.json` were regenerated with the recorded arguments. All 420 tips sit on the same backdrop colour.
- Not run in-engine from the cloud. Please check the pads on a PC capture.

## 2026-11-24: Meadow river fix (after PC QA of #272)
- **QA finding:** the upper two thirds of the stream read as a pale green checker with orange banks, so foam, not water. Bank spots 16 texels out were walkable in only about a third of cases.
- **Cause:** the foam test covered the outer 1.6 texels of a 9-texel channel, so about two thirds of it was white water. The bed was only 0.9 deep, which is a light water ramp.
- **Changed:** foam only at the outer 0.8 texels; bed 2.6 deep so the middle is dark water; bank blend over 4 texels; low meadow ground beside the stream eased toward the water (never the mountain itself).
- **Not fixed:** the east bank runs along the mountain foot and is rock. Walkable banks are on the meadow side only (about 11 of 30 samples at 16 texels). Making the mountain side walkable means reshaping the mountain foot, which is part of the bigger-map slice.
