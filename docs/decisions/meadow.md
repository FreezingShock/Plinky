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

## 2026-11-24: Clover stays green inside its gold rim; Dewdrop row moves in
- **Why:** Nathan asked why the Clover pads were yellow (screenshots from PC QA). The gold for the Clover rim was also set as the stat colour, so the gems and flowers went gold. Nathan also said the Dewdrop pads sat too close to the arrival gate.
- **Clover:** the gold is now only the rim, lit rim and rarity ring. The gems, pip and flowers keep the Clover reward green.
- **Dewdrops:** the Sprout row moved from (644,658), (688,680), (732,702) to (534,600), (578,622), (622,644): open grass between the main path and the lake, with the nearest pad 156 texels from the arrival gate, up from 31. The first move, to (634,568) to (722,612), put two pads behind the oak and the gatehouse tower, so the walk mask alone is not enough. Placement now also checks sprite occlusion: no sprite standing in front of a pad may overlap its plate. Every footprint is on walkable ground, and all 18 pads are reachable from spawn on the walk mask.
- **Art:** `gen_larkmoor.py` regenerated the Larkmoor art, and the sway tips in `world/larkmoor_life.json` were regenerated with the recorded arguments. All 420 tips sit on the same backdrop colour.
- Not run in-engine from the cloud. Please check the pads on a PC capture.
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

## 2026-11-24: Meadow path stones (slice 3 of the meadow rework)
- **Brief (Nathan, via coordinator):** paths between areas should look better and fit the area they lead to.
- **Changed:** a small flat stone every ~11 texels along the meadow path, alternating either side of the centre line, placed last in `gen_meadow3d.py` so nothing earlier in the layout moves. Only on open ground near the path; never in water.
- **Why:** the path was a plain sand strip. Stones are the cheapest step that makes it read as made.
- **Not in this slice:** the path's edges are still plain grass, and the lake boardwalk and the Larkmoor path are untouched.
- **Not run in the cloud:** the look in-engine; PC QA should screenshot the path at 640x360.
## 2026-11-24: Meadow river fix (after PC QA of #272)
- **QA finding:** the upper two thirds of the stream read as a pale green checker with orange banks, so foam, not water. Bank spots 16 texels out were walkable in only about a third of cases.
- **Cause:** the foam test covered the outer 1.6 texels of a 9-texel channel, so about two thirds of it was white water. The bed was only 0.9 deep, which is a light water ramp.
- **Changed:** foam only at the outer 0.8 texels; bed 2.6 deep so the middle is dark water; bank blend over 4 texels; low meadow ground beside the stream eased toward the water (never the mountain itself).
- **Not fixed:** the east bank runs along the mountain foot and is rock. Walkable banks are on the meadow side only (about 11 of 30 samples at 16 texels). Making the mountain side walkable means reshaping the mountain foot, which is part of the bigger-map slice.
## 2026-11-24: Meadow gate arch (slice 2 of the meadow rework)
- **Brief (Nathan, via coordinator):** gates and paths between areas must look better and match the area they lead to; the quarry gate reads as ember and stone, so the meadow gate reads as timber and flowers.
- **Changed:** the meadow gate (zone1) takes `gate_art = &"meadow"` and draws its own arch in `world/texel_gate.gd`: timber posts with cream caps and vines, a flower-garlanded lintel with a keystone bloom, a wooden lattice that shows the green light of Larkmoor once open, and drifting petals while open. It uses the meadow palette, 8 indices like the forge arch.
- **Why:** the plain pulsing ring read as a placeholder, and the arch gives the gate the hover tooltip the forge gate already has.
- **Not in this slice:** the path to the gate is still baked sand (gen_meadow3d.py). Path edges (stepping stones, flowers) are the next gate-and-path step.
- **Not run in the cloud:** the look and the draw code in-engine (no Godot here). The PC QA thread should screenshot the gate closed and open.
## 2026-11-24: Meadow path pass (slice 4 of the meadow rework, after PC QA of v0.61.3)
- **QA finding:** the stepping stones read as spots at 640x360, the vine and petals on the gate were not visible, the foam was barely visible, and the gate tooltip did not show in captures.
- **Changed in `tools/art/gen_meadow3d.py`:** the path is wider (6.6 plus or minus 0.6 texels, was 5.4) with a dark rim on the grass just outside it and light pebbles on the surface. Flower verges run along both edges on the first part of the path. Five lantern posts are sprites (lantern is now an exported sprite kind), so they y-sort and add light entries in `world/meadow_life.json`. The last four path segments, the gate approach, get low timber rail fences on both sides instead of verges. A plank boardwalk on pilings runs from the path to the lake, 43 texels at its shortest crossing. The stepping stones stay. The foam band on the stream is the outer 1.8 texels of the channel (was 0.8).
- **Changed in `world/texel_gate.gd`:** the meadow gate's vines are a continuous leaf ribbon in two phases with a bloom at each tip, drawn over the lattice. Open petals are 2x2 and there are nine of them. `HIT` covers the whole arch including the keystone, so the tooltip can reach the top of it.
- **Test:** `tests/test_quarry.gd` checks that the meadow arch is hoverable from its keystone to its feet, and that the meadow gate has a tooltip spec.
- **Not done:** the walkable mask stays terrain-only, so the boardwalk, fences and lanterns do not block the walker. Fewer lanterns than slots: the placement checks reject spots near trees, so the path has five, not one per 40 texels.
- **Not run in the cloud:** Godot, the headless tests, and the look in-engine. The PC QA thread should screenshot the path, the verges, the boardwalk, the gate closed and open, and hover the gate to confirm the tooltip.

## 2026-11-24: Thistle row clear of the oak
- **Why:** the two Thistle pads in Gatehouse Green, at (868,646) and (912,624), sat behind an oak on main. The walk mask does not catch a sprite standing in front of a pad.
- **What:** the Thistle row moved to centre (864,642), so its pads sit at (820,664), (864,642) and (908,620). Every Larkmoor pad now passes the sprite occlusion check on the regenerated placements, and every footprint is walkable.
- Not run in-engine. Please check the Thistle row on a PC capture.
## 2026-11-24: Larkmoor paths, gates, bridge and connectivity (Larkmoor slice 1)
- **Brief (Nathan, via coordinator):** no path may lead nowhere, structures need a purpose, bridges should be wider and easy to step onto.
- **Connectivity:** `tools/art/larkmoor_layout.py` `dead_ends()` checks that every path end reaches a gate, pad, landmark or another path within 30 texels. `gen_larkmoor.py` refuses to build while it fails. The north-east path ended in the open grass; it now ends at the Great Lantern.
- **Structures:** the seven standing stones are one height with no tilt, so the ring reads as built, and the cairn sits at its centre. The gatehouse tower stands beside the arrival gate. The Emberwatch tower stands beside the Ember gate, on its wall.
- **Gates:** `make_gateway(style)`. The arrival arch is timber with a flower garland on the lintel. The Ember gate is stone with ember bloom in the lintel. Both stay baked props, not the TexelGate art, because the way-back arch in zone 2 depends on the art key.
- **Bridge and jetty:** the stream bridge is 13 texels wide and the lake jetty 8 wide. Both walk strips are flared at the ends (`_deck_strip`) so the entry is easy to find. Open lake water stays unwalkable.
- **Pads:** unchanged. The anchors match main exactly.
- **Not run in the cloud:** the look in-engine, and the generator's output has not been seen in Godot.

- **2026-11-24, spacing and lanterns:** props are placed by their real footprint (`solid_radius` on the prop SDF, not the old guessed radii), so crowns touch but never stack. Per-kind gaps are in `MIN_GAP`. Pads and the spawn keep a wider keep-out. `check_layout()` fails the run on any prop-on-prop, prop-on-pad, prop-on-path or lantern-on-walk-line overlap. Lanterns sit a few texels past the rim, and the lamp is redrawn as a readable garden lantern. Their light pools come from the existing `life.lights` path.

## 2026-11-24: Larkmoor frame grows 1.5x (slice 1 of the bigger-map rework)
Larkmoor's world is now 2280 by 1380 texels (was 1520 by 920). `tools/art/larkmoor_layout.py` scales every authored position in one `_apply_scale()` step, so the 2:1 projection and the path and pad checks stay exact. Groves keep their density by scaling counts with S squared; prop sizes do not change. Sway tips are 945 (was 120 in the old frame) to keep grass density. `larkmoor_scene.gd` now sets its banner radius (165) and haze strip from the new size. Regenerate with `python3 tools/art/gen_larkmoor.py` (about 2 minutes) then `gen_life_anchors.py --bounds 285,165,2010,1088 --sway-count 945`. Not run in engine. The mask check at the bridge (main route through the stream) is walkable on the new mask; the coordinator's 1 of 41 reading needs the QA probe's exact A and B points to reproduce.
- **2026-11-24, pads beside the path:** every meadow pad is moved to the nearest open-land spot 24 to 34 texels from the path centre (`beside_path` in `gen_meadow3d.py`). `check_pads()` fails the run if a plate touches the path. Row order is kept. `tests/test_sites.gd` now uses the first Sprout pad at (194, 230). Trees sit at 10, the minimum `test_sites` allows.

## 2026-11-24: Larkmoor at 2x, lanterns in a rhythm, grove counts held
Larkmoor's frame is now 2x (3040 by 1840 texels), `S = 2.0` in `larkmoor_layout.py`. New land: a north lobe (`LOBES`), a bottom-right land, trails `PATH_SE1`, `PATH_SE2` and `PATH_NW2`, and three landmarks at their ends. Grove counts are not scaled, because every tall prop is a scene node and Larkmoor sits near the 1350 ceiling; the frame is bigger but emptier than the old one. Lanterns: one size, one spacing (150 texels, 70 texel ends), 15 texels off the path edge, facing set by a fixed quarter-turn order, not random. 29 lanterns and 30 lights. Still open: new districts (the zone has seven, and the areas and zone-menu test pin that count), and a chunked or lazy prop spawn if the new land needs trees.

## 2026-11-24: Westmere, the west subarea (Starbloom row extended)
Larkmoor gets a west subarea on the lake's west bank, reached by a trail off the west road, north of the lake. It has no gate. Its three pads extend the Starbloom row (starbloom_4 to 6, row indexes 3 to 5) rather than adding a tier, so the locked eight-tier ladder and its test stay as they are. Rewards are 8 times the last pad each step (512, 4096, 32768), costs 5, 5 and 5 times the last (5000, 25000, 125000). Those numbers are not pacing-checked. The zone's pad list grows to 21 and the area count to 8.

## 2026-11-24: Critters react to the walker (rabbits, ducks, frogs, butterflies on beds)
Rabbits, ducks, frogs and butterflies live in `world/life_critters.gd` and `world/life_butterflies.gd`, both `RefCounted` helpers that `LifeAir` owns and draws from its own `_draw`. Reason: Larkmoor sits near the 1350 node ceiling, so the critters add no nodes at all. Burrows, duck spots and frog perches come from the existing grass-tip list and water ellipses, never from a pad or inside the water. Butterflies use new `flowers` spots that `tools/art/gen_life_anchors.py` reads from the backdrop's blossom beds (`--add-keys` writes only the new keys, so the sway list is untouched). Birds roost by night, in rain and in winter (`LifeReact.bird_share`), and every critter fades in and out by dither (`MeadowLife.dissolved`). Reduce Motion keeps everything in place: a rabbit still sits up and watches, butterflies flap on their bed. Not verified in the PC editor: the screenshots come from the cloud's software renderer, and the butterflies are only 7 by 4 texels, hard to pick out at 3x.
## 2026-11-24: Wider paths, one lantern size, lamp glows, windmill branch ends at the mill
Paths: the half-width goes from 6.6 to about 10.5 to 12.7 texels, one ground material, with a noise-wobbled edge and no rim band or pebbles. Rocks keep 11 texels back from a path (`path_clear`), so no rock border. Flowers no longer sit on a fixed verge line: they go in patches 13 to 24 texels off the path.
Lanterns: every ordinary lantern is cut to one 19 by 29 window around its foot (measured on every lamp at every facing), so the size and lamp height match. The great lantern landmark is unchanged. 24 lanterns are placed now (25 before), because the wider path and the 19-texel offset reject one spot. Pools: radius 62 and strength 1.0, and each lamp head has a small dithered bloom that fades in with the night.
Light slots: 56 in the shader, enough for Larkmoor's 50 pools. The nearest-to-walker packing still applies beyond that.
Windmill: the east branch was a fold whose tip stopped in open grass beside the mill. The tip now ends at the mill's south door. The sails are still baked into the windmill sprite; splitting them out for the farm is the next slice.
Not run in-engine: the headless test suite passes (5335 checks), but the night look and the path width need a PC screenshot.
## 2026-11-24: Five pads per statistic, five art stages, pads on curves (Larkmoor)
- **Brief (Nathan, via coordinator):** five pads (stages) per statistic, refine the stage art so the family reads as one, and lay each row on a clean line or organic curve beside the paths, closer together, with no overlaps. The Starting Clearing stays at three pads per row: it is the tutorial and its Clover gate (9) and onboarding tests depend on it.
- **Content:** ten new pads, `lark_sprout`, `lark_clover`, `thistle`, `heather`, `foxglove` pads 4 and 5. Costs continue each ladder at 4x per step (Thistle 4.608M and 18.432M Sunlight, Heather 4M and 16M Thistle, Foxglove 4,000 and 16,000 Heather, Dewdrop row 4,000 and 16,000 Sunlight, Clover row 19,200 and 76,800 Dewdrops), rewards at 8x per step (512 and 4,096; Thistle 12,288 and 98,304). The next tier now opens on the fifth pad, so every unlock is later than before. **Pacing is not tuned**: handed to the pacing thread. Starbloom keeps six pads (the last three on the Westmere bank); pad 6 wears the stage 5 art.
- **Art (`TexelPad`, procedural, no new PNGs):** stage 1 one flower, 2 two buds, 3 two half flowers and glints, 4 a bud at each outer edge plus two taller blooms behind, 5 the outer buds become half flowers and a gold crown sits over the flower, with more glints (still off under Reduce Motion). `TexelPad.stage_of()` maps row index to stage; the quarry forge art still has three stages. `tools/pad_sheet.tscn` now shows stages 1 to 5 of the six Larkmoor tiers.
- **Layout (`larkmoor_layout.py`):** `curve_row(ctrl, n)` lays pads on a Catmull-Rom curve, 21 authored units (42 texels) apart, down from 44 (88 texels). Plates are 28 wide, so the gap is 14. Each row hugs the ground beside a path (path gap 56 to 150 uv texels, never under the 41 texel plate clearance). District-to-row mapping is unchanged this PR; per-statistic districts and flower gardens follow, one statistic per PR.
- **Regenerated:** `gen_larkmoor.py` (full, not `--fast`) and `gen_life_anchors.py --bounds 380,220,2680,1450 --sway-count 1680` (this reproduces the committed JSON byte for byte on the old art).

## 2026-11-24: Pad rows hug the paths, flower fields round every row, tap-to-move routes (Larkmoor)
- **What was wrong (Nathan's review, and mine):** the five-pad rows from #326 were hand-picked curves 56 to 150 texels from the nearest path, so they sat stranded in open grass, not parallel to anything and not easy to press as you walk by. The first garden pass drew tiny flowers as sparse dots, kept them only 3 to 6 texels off the path edge, and tap-to-move could not reach about a fifth of the pads (a straight line stops at the first lake or trunk; 6 of 31 stopped short from the spawn, one by 240 texels).
- **Rows (`larkmoor_layout.py`, `tools/art/plan_rows.py`):** a row is now an offset curve of a path: plates `ROW_OFFSET` (28) texels from its centre line on one side, `ROW_GAP` (32 uv) apart along the offset curve, so it follows the path's bends and stays parallel. `plan_rows.py` searches every path, both sides, for the stretch with the most open grass, keeping rows 100 texels apart, out of the farm box, off the gates and landmarks, and each near its district. Its answer is the `ROWS` table. Pad 1 is still the plate nearest the spawn. `rows_off()` joins `pads_on_path()` and `dead_ends()` as a build guard in `gen_larkmoor.py`. `PAD_CLEAR` is a texel quantity (24, path half-width up to 13 plus the plate), not scaled with the world as before. District centres follow their rows. The Westmere trail now ends at its last plate.
- **Fields (`gen_gardens.py`, `world/garden_art.gd`):** each row sits in a field of its own statistic. Big flowers are the pad's own flower table (`TexelPad.FLOWERS`) at 1x, 2x or 3x with a one texel ink outline, in four tints (the last mirrored). Small hand-drawn flowers fill between them, and shrubs hang on the side away from the path. Density follows a slow noise (drifts and gaps, never a carpet), is densest at the plates, and nothing is placed within 17 uv texels of a path, thinning up to 36, so the path blends into plain grass before the field starts. A flower belongs to the row whose plate is nearest, so fields never run into each other. Bigger flowers keep further from the plates so the plates always read. Foxglove gets the most 3x flowers (tall spires), Clover the fewest big ones. Still one node: `GardenLayer`. It now redraws when the camera moves (it used to cull to a stale view after a jump) and culls 20 texels wide so a tall head is not clipped.
- **Tap-to-move (`world/walk_mask.gd`, `texel_walker.gd`):** `WalkMask.route(from, to)` returns waypoints: a clear straight walk is just the target (nothing changes in the open); otherwise an A* over a 4 texel grid of the mask (a cell is open only if its corners and centre are walkable), pulled tight with exact line checks. The walker follows the waypoints, replans up to three times if it is blocked, and now walks tap targets in a straight line in ground space (it used to curve). `tests/test_route.gd` and `tools/route_probe.tscn` (the real walker, spawn to every pad and pad to pad) pass 31 of 31 and 62 of 62.
- **Checks run in the cloud:** `tests/run.gd` 6445 checks, 0 failed; High bench Larkmoor 1172 nodes at spawn; garden tour rendered for every row. Not run: a real GPU, night, the PC's window.
- **Still open:** the verge flowers along every path are baked into the ground by `gen_larkmoor.py` (the map thread's); they still ring the path edge. Dewdrop's and Clover's district names (Heronmere, Cairnfold) no longer describe where their rows are.
## 2026-11-24: Larkmoor wildlife (dragonflies, fish, forest-edge deer, owls)
- **Build:** `world/life_wild.gd` (`LifeWild`, RefCounted) is owned by `LifeCritters` and drawn from LifeAir's `_draw`, so it adds no nodes. Sprites go through the shared `MeadowLife.blit`, which the critters now use too.
- **Data:** `tools/art/gen_life_anchors.py --add-keys` writes `perches` (six tall-pine crowns, fixed seed) and `forest_edge` (sway tips with a dense stand of trees within 70 texels and the nearest tree 14 to 34 away, kept 24 off every pad). It also writes `farm` and `farm_items` when given `--farm`. Command: `--backdrop assets/art/zone1b/larkmoor/ground.png --placements assets/art/zone1b/larkmoor/placements3d.json --out world/larkmoor_life.json --add-keys --farm assets/art/zone1b/farm/farm.json`.
- **Seasons and light:** dragonflies out by day in spring and summer (none in winter or rain); fish leap by day, fewer in winter; the deer comes out at golden hour (`low_sun`), fewer in winter; owls come out at night. Each creature is out when its hash is under the share, so the crowd thins smoothly.
- **Behaviour:** a walker close by sends a dragonfly darting over the water, the deer into the trees along the edge, and an owl to another perch. Reduce Motion keeps the dragonflies hovering in place and the fish, deer and owls still.
- **Not run in engine:** the look of the dragonflies at 1x (small sprite, hard to spot in a still); the fish leap; the deer and owl at the real scale on PC.
## 2026-11-24: windmill sails as their own sprite
- The mill is two sprites. `windmill` (id 14) is the tower only. `windmill_sails` (id 900001) is the four arms, sails and hub, rendered alone so the parts behind the tower are kept. Its foot is the hub, so the scene can turn it around that point. Sprite entries are in `placements3d.json`.
- The sails get their own id, far above the instance counter, and are voxelized directly, not through `put()`, so the placement random stream and every later prop stay where they were.
- Loose pixels on the tower sprite are dropped (largest connected part only). They were stray sail-edge pixels that the full render had tagged with the tower's id.
- Not run in-engine (the cloud cannot run Godot). The sprites were checked as images: tower one solid piece, sails four whole blades around the hub.

## 2026-11-24: Larkmoor wildlife presence (PC QA on v0.83.3)
- **QA:** dragonflies at most one by day, no fish or deer seen, nothing at dusk.
- **Counts follow the light by rank:** the first ceil(share * count) of each kind are out (`LifeWild._rank_out`). Before, one hash decided whether the single deer and each dragonfly was out, so a bad seed hid the whole kind.
- **More of each:** six dragonflies (was three), three deer (was one), three owls (was two), fish leap every 2.5 to 6 s (was 5 to 16).
- **Near the walker:** dragonflies, fish and deer pick their next spot near the walker when one exists (`NEAR_WALKER` = 160 iso texels), so they show where the player walks. Scared creatures still go away from the walker.
- **Readable sprites:** dragonfly with paper wings and a gold head (9 x 3), gold fish with a paper eye (8 x 3), earth-brown deer with a paper belly (10 x 8).
- **Not run in engine:** the dusk deer on PC. The deer is visible in the cloud render at 1x, but its colour on PC is unchecked.
## 2026-11-24: Larkmoor river, jumpable water, bridges and the south-west rim
- **Water:** one river now runs from Heronmere's north-east shore, through the bridge at (762, 456), into the mere. It is about 14 texels wide with a 3 texel depth. The lake-rim carve no longer leaves a dry gap, so the river and lakes join. The walk mask marks water in green and walkable ground in red and blue, so `WalkMask.is_water()` is one channel read.
- **Walker:** `texel_walker.gd` lets an airborne step cross water (`_try_step(step, airborne)`). On landing in water, `WalkMask.landing()` returns the nearest walkable texel within 60, and the walker splashes. Reason: a jumpable stream instead of a wall, with no drowning state.
- **Bridges:** the main bridge is a planked deck with rails, posts and stone abutments (`BRIDGE_HX/HY/DZ` = 17.5, 10.5, 4.0). The footbridge is smaller (13, 3.8, 2.6). Both are tall kinds with `BLOCK_R` 0 and their foot is drawn 40 texels higher, so the walker draws over the deck. Deck texels stay walkable.
- **Rim:** the south and west edges get a raised ridge (`env_ang` floor of 0.8 from the map edge angle). This is a first pass, not full mountain ranges. Higher ridges with ridged noise are the next pass.
- **Life data:** `--add-keys` keeps the existing `sway` list and writes only the other keys. After a backdrop change, run the full `gen_life_anchors.py` (no `--add-keys`) first, then the same command again with `--add-keys --farm ...`. Skipping the first run left 430 sway tips off palette 4 (fixed on this PR).
- **Not run in engine:** the cloud has no PC Godot. The headless suite passes (6149 checks). Walking the bridge and jumping the river still needs a PC walk check from each bank.
## 2026-11-24: Larkmoor tree spacing (review slice 1)
- Trees now keep a real gap between crowns: `TREE_GAP` oak 6 and pine 8 texels in `gen_larkmoor.py` (the old gap was 1.5, so trees stood in walls). The north-east pine groves go from 14 and 8 down to 10 and 6 (the two groves at (1040, 330) and (1120, 330)). Thinner than that dropped the forest-edge count under the test floor (`forest_edge` >= 6, `tests/test_wild.gd`), so the groves stay at 10 and 6.
- Regen order after the grove change: `gen_larkmoor.py`, then `gen_life_anchors.py` (base run), then `gen_life_anchors.py --add-keys --farm assets/art/zone1b/farm/farm.json` (writes `perches`, `forest_edge` and `farm_items`), then `gen_gardens.py` (its flowers test checks the ground pixels).
- Read from the zone 1 noon tour: the north-east pine stand reads as a thinner group with gaps. The other clusters are still tight, and the grove by the watchtower is the density to match. Not checked in-engine at zoom 3; the walk test is still to do.
- Tour: `tools/larkmoor_review.gd` (not committed) pins the sky at noon, hides the HUD, and walks a grid of spots at zoom 1.
## 2026-11-24: Larkmoor lanterns by path tier, evenly spaced
- **Tiers:** `PATH_TIER` in `larkmoor_layout.py` names each path: the main road (`road`), the two forks to the districts (`lane`), the windmill track (`trail`). `gen_larkmoor.py` spaces the lamps by tier: a road about every 110 texels, a lane every 200, a trail two (one at each end of its span). Spacing is even along each path, with the same 70-texel margin at both ends, so no lamp sits on a junction or a gate.
- **Why:** the old rhythm restarted on every path and dropped a lamp wherever the first side was blocked, so the gaps were uneven. Now a blocked spot slides the lamp along its path (up to a third of a step), and no two lamps are closer than 80 texels.
- **Sides:** the side alternates along a path, so a row reads as a rhythm, not a line on one edge.
- **Count:** 23 ordinary lamps and the great lantern (the old rhythm placed 25 on main after the districts moved, #352). Every lamp still takes the one size (19 by 29 window).
- **Random stream:** the props after the lanterns draw from the same random stream and take the same sprite ids as before (`LANTERN_STREAM_DRAWS`, 25 on main), so only the lamps and the ground and bush texels right beside them changed. Regenerating from `origin/main` first reproduced the committed placements, ground and bush sprites byte for byte, so the baseline is exact.
- **Life data:** the lamp glow centres in `world/larkmoor_life.json` now sit on the lit window, 17 texels above the foot. They were 38 above it, so the glow sat in the sky over each lamp. `gen_life_anchors.py` writes them that way now. Ten sway tips that the new ground had covered were nudged a few texels onto light grass (`tests/test_life.gd` checks every tip). Drift and flowers are unchanged.
- **Not verified in-engine on the PC:** the placement reads well from the map (checked on the preview), and the night, dusk and noon close-ups were checked on the cloud render. The full-map feel at zoom 1 is for the PC QA pass.
## 2026-11-24: Districts follow the rows (Larkmoor)
| Decision | Why |
|---|---|
| The Sprout row's district is **Reedgate** (new, `reedgate`), the Clover row's district is **Heronmere** (the lake, south shore). **Cairnfold** (stones and crystals, no pads) is a district marker of its own again at the stones, not at the Clover row. | The rows moved beside the paths, so the old names (Sprout at Heronmere, Clover at Cairnfold) named places they no longer sit in. The Cairnfold banner was showing over the Clover road. |
| Area defs split the same way: `larkmoor_reedgate.tres` lists the Sprout pads, `larkmoor_heronmere.tres` the Clover pads; orders shifted by one. Ids of existing areas are unchanged. | One row per district matches the other districts. |

## 2026-11-24: Stage plates and a thicker Thistle field
| Decision | Why |
|---|---|
| Flower pads change the slab itself from stage 3: a one texel tier-colour stripe on the side faces (stage 3), a second lighter one (stage 4), gold stripes on rows 1 and 3 (stage 5). The stage 5 crown is now an outlined gold band with five points and a white jewel, one texel above the flower. Stripes and crown are skipped on locked pads. | Stages 3 to 5 differed only by flower count and a one texel crown line, so they blurred together at 1x. Reviewed in `tools/pad_sheet.tscn`. |
| The Thistle garden reaches 100 uv (was 82) with 100 big flowers per plate (was 66). | The row's field was a thin strip beside the road. |
| `tools/garden_shots.gd` takes `-- phase=0.95` to shoot a row at night. | Night review of the rows. Software Vulkan hits the shader-instance limit after about six night shots; shoot the later rows by themselves. |
## 2026-11-24: Larkmoor path hierarchy (review slice 2)
- **Tiers, in widths:** `HALF` in `gen_larkmoor.py` gives each tier its own half-width: road 12, lane 7.5, trail 4 texels (before: one 10.5 for every path). The tiers are the existing `PATH_TIER` in `larkmoor_layout.py` (main route road; west and east forks lanes; windmill track trail).
- **Materials:** roads and lanes keep the trodden path material (`T_PATH`). Trails get their own worn ground, `T_TRAIL` (109), a darker ramp, so a narrow track reads as used but not paved. Grass texture never lands on either.
- **Edges:** each tier's edge keeps the ragged noise and the rock cut. Shade falls off at each tier's own edge.
- **Decor clearance:** `ok_spot` now measures from the nearest path EDGE (`dedge`), not the centre line, so trees and bushes keep clear of a wide road without the trail's narrow edge pushing them out. Expect fewer props right beside the main road.
- **Lamps:** the lamp check drops the path-edge test (`path=False`): the 19-texel offset already clears a lane or trail, and the edge test had removed every road lamp (15 lamps against 23; now 23, none closer than 80).
- **Forest edge:** `EDGE_SPACING` 60 to 50 in `gen_life_anchors.py`. The tighter tree clearance cost one deer-edge tip (5 against the test floor of 6); the spacing change brings it back to 6.
- **Tests:** `tests/run.gd` 6418 checks, 0 failed (Godot 4.7 headless, lavapipe).
- **Not yet:** the verge flower ring still follows the centre line (slice 3 replaces it), so it sits closer to the road edge than before. The bridge and water are the water thread's; the road is now 24 texels wide, so the bridge needs to span at least that.

## 2026-11-24: Starting Clearing flower fields
| Decision | Why |
|---|---|
| `tools/art/gen_clearing_gardens.py` writes `world/clearing_gardens.json` (format 2, 163 flowers) for the Sprout row (dewdrop) and the Clover row (clover). `world/meadow3d_scene.gd` draws it with one `GardenLayer` node, the same as Larkmoor. The meadow's ground and placements are read as they are, so no art regen was needed. | The Starting Clearing pads were the only ones without a field. The 3-pad rows keep their count (the tutorial). |
| Field distances use the ground's own path, water and dirt colours (the Larkmoor palette, which the meadow shares), so no flowers sit on the path. | Nothing new to tune by hand. |
| Checks: `tests/run.gd` 6429 checks, 0 failed. Screenshots in the cloud (xvfb, lavapipe): `tools/clearing_shots.tscn`. | The fields are in, but the meadow already has many baked flower beds and a gate banner covers part of the view. PC QA should judge the read at 1x and 2x, and night. |

## 2026-11-24: Foxglove and Starbloom fields thicker
| Decision | Why |
|---|---|
| `gen_gardens.py` raises `n` and `small` for the Foxglove row (66/30 to 96/46) and both Starbloom rows (64/28 to 100/46 and 66/28 to 74/33 for Westmere). Result: Foxglove 315 flowers, Starbloom north 291, Westmere 301 (was 267, 252, 292 on the same generator). Clover and Thistle are unchanged. | Nathan's pick from the handoff: the thin rows were about 1.6x thinner than Clover and Thistle. Target was about 300 per row, and Nathan likes the current density, so only the thin rows grow. |
| Still one `world/larkmoor_gardens.json` format 2 and one garden layer node, so the node count does not change. | Larkmoor sits near the 1350 ceiling. |
| Not run in-engine: night shots of these rows, and the look on a real GPU. | The cloud renderer stops after about six night shots. |

## 2026-11-24: Less clumped fields
| Decision | Why |
|---|---|
| `gen_gardens.py` draws distances half evenly over the field and half bunched to the plates (was all bunched), thins by gentle drifts (0.5 to 1.0, was 0.3 to 1.2), and spaces flowers 1.4x their footprint with a random 0.75 to 1.6 jitter. Attempts rose so the total stays about the same (2429 flowers, was 2410). | Nathan asked for fields that are less clumped but liked the density, so spacing varies and the heaps go, not the flower count. |
| `tools/qa_probe.tscn` walks the real main scene from a chosen start to a pad (`-- x=2127 y=1039 pad=lark_clover_1 rich`); `route_probe` also routes every pad from every other pad and a scatter of open spots. | For the lark_clover_1 farm-side report, which does not reproduce here. |
## 2026-11-24: Meadow lanterns one size, lit after dark
| Decision | Why |
|---|---|
| Every meadow lantern faces the same way (`rot=0`), and the export crops each one to one window around its foot: 8 texels left, 9 right, 27 above, 3 below (18 by 31). The generator asserts that every lantern voxel lands inside it. The sprites are 18 by 31 instead of 11 to 13 by 26 to 28. | The lanterns got a random quarter-turn from their seed, so the bounding boxes came out in four sizes. The PC QA saw four scale groups. Larkmoor's lamps already use the fixed-window method. |
| The placement stream is unchanged: the seed is still drawn for every candidate, so no other prop moves. Only the five lantern sprites, `rock_038_n` (its normals read the lantern beside it) and the lantern entries of `placements3d.json` changed in `assets/art/zone1/meadow3d/`. | Keeps the diff to the lanterns. |
| `_add_lights` gives lantern life lights kind `lantern`, the same kind Larkmoor uses, so their pools scale with the night (`SkyCycle.lamp_light_k`). They were kind `fixed` and burned at full strength by day. | The meadow lanterns were lit at noon. Larkmoor's were not. |
| `tests/test_lighting.gd` checks that each meadow lantern life light is a night pool and that the lantern sprites share one size. `tools/lantern_shots.tscn -- meadow` shoots the meadow lanterns at night, dusk and noon. | Regression guard, and the shot tool for the PC check. |
| A fresh bake on main matches the committed placements except `bush_027`'s width. Some committed sprite and ground files already differed from a fresh bake before this change (`oak_018_n`, `crystals_039_n`, `bush_027`'s width, the ground images and the preview). They were left alone. | Keeps this PR to the lanterns. |
| Not verified on the PC. Cloud shots (xvfb, software Vulkan) only. In the four cloud shots the meadow's night is much brighter than Larkmoor's (mean luminance about 84 against 62), so the lamp glow reads less there. | Lighting is for the sky owner to tune, not this change. |

## 2026-11-24: Larkmoor wildlife in reach of the walker
| Decision | Why |
|---|---|
| Dragonflies, fish, deer and owls only come out within `REACH` (200 iso texels) of the walker. A creature the walker has left more than `GONE` (300) behind fades out and re-forms inside `REACH` at the next fade-in. Nothing is placed where no one can see it, and nothing is hidden behind a far spot. | PC QA on v0.85.36 saw no creatures. The probe in the real Larkmoor scene showed the dragonflies, deer and fish drifting over the lake and the forest edge about 650 texels from the start, outside the on-screen rect (about 225 by 148 at zoom 2). |
| Owls pick a perch in reach (`_perch_within`) when the old one is out of reach. Fish leap only at water in reach. Deer graze only edge spots in reach. A dragonfly that is scared darts to water between `DRAGON_SHY * 2` and `REACH`. | Keeps every visible creature near the walker, with no new nodes. |
| `tests/test_wild.gd` moves the walker to the lake, the forest edge and the perch for the tests that need to see a creature, and checks that far from the water none is out. | The old tests put the walker far away, which now hides everything by design. |
| Verified in-game with a temporary probe in the real Larkmoor scene (xvfb, software Vulkan, removed after). At the start nothing is in reach. At the lake shore four dragonflies are out and on screen. Not verified on the PC. | The lake is about 650 texels from the start, so the start view shows no wildlife by design. |
## 2026-11-24: Larkmoor path drifts, darker trail, north-east groves (review slice 3)
- **Why:** review items 3 to 5 of the Larkmoor environment handoff. The verge flowers ringed every path edge, the trail tint sat too close to the lane, and the forest-edge tip count sat exactly on its test floor (6).
- **Drifts:** the verge ring is now patches. Candidates sit 9 to 30 texels from the path edge (`dedge`, so a road, a lane and a trail all keep the same clearance), and a slow noise field (`vn2(u/9, v/9)`, above .5) decides where the drifts are. Nothing hugs an edge, and bare grass shows between drifts.
- **Trail:** the trail ramp is `[6, 6, 6, 1]`: earth brown in the light, with the dark tone kept for the brightest spots. The old ramp `[6, 5, 5, 1]` read as the lane's cream. Road stays 24 texels wide (half-width 12), so the water thread's bridge must span 24 texels.
- **Groves:** three north-east candidates (pine at 1190,380; oak at 1010,240; bush at 1150,470). The forest-edge count goes 6 to 7. The density bar is the lighthouse grove at 640,590 (oak, 4 per group, radius 60).
- **Regen:** `gen_larkmoor.py`, then `gen_life_anchors.py --bounds 380,220,2680,1450 --sway-count 1680`, then `--add-keys --farm assets/art/zone1b/farm/farm.json`, then `gen_gardens.py`. Lamps 23, flowers 240 (life), gardens 2238.
- Not run in-engine yet: the zoom 1 and zoom 3 captures, and the walk test.

## 2026-11-24: Larkmoor dragonflies larger at 1x
| Decision | Why |
|---|---|
| Dragonfly sprites go from 9 by 3 to 11 by 5 texels (wings up and down), with a wider gold body. The draw origin moves to match (`-5, -2`). Fish and owls are unchanged. | PC QA said the wildlife reads thin at 1x. At 9 texels the dragonflies were specks over the lake. |
| Not in this change: ambient creatures near the Larkmoor start position. The nearest water and forest edge are about 650 texels from the start, and rabbits and other ground critters are placed from the anchor data. Adding start-area creatures needs an anchor placement decision. | Kept this PR to what can be checked here. |

## 2026-11-24: Larkmoor start view has rabbits and butterflies; deer at dusk
| Decision | Why |
|---|---|
| `larkmoor_life.json` gets a `start` key, the Larkmoor `player_spawn` anchor from `assets/art/zone1b/larkmoor/placements3d.json` (1520, 1349.5). The generator's `--add-keys` path does not write it, so it survives a regenerate. | The start view had no wildlife within reach. The start is the one place every player sees first. |
| Two rabbits are placed at the grass tips nearest the start, within 260 iso texels and 30 texels apart (`START_RABBITS`, `START_REACH`). Other rabbits keep their random spots. | Rabbits stay near their burrow (wander 30), so they stay in the start view. |
| The first two butterflies start on the flower beds within 260 iso texels of the start. Their flits stay local, so they stay in that area. They are out in any season with butterfly share 0.2 or more, so they show in autumn too. | Autumn share is 0.35, and the usual hash gate hid both start butterflies in the probe. |
| Deer share now also rises in the dusk light (`sin(PI * night)`, at most 0.9), and not at full night. Golden hour (low sun) still brings them out too. | Probe at 19.2 h and 19.6 h (night 0.2 to 0.5): no deer, though owls and dragonflies were out. The deer followed low sun only. |
| Verified in the real Larkmoor scene (temporary probes, removed): at the start, 2 rabbits and 2 butterflies on screen over three checks. At noon, golden hour, dusk and night, dragonflies, deer and owls appear at the lake, forest edge and perch as their share says. Not verified on PC. | Coordinator asked for the start view and the golden-hour and dusk check. |
