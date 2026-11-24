# Decisions: World, calendar and player

Calendar, clock, seasons, seasonal events, zone entry cards, the walker and the travel map. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## 2026-11-23: Calendar, clock and seasons
- Structure (Nathan): a month is 5 days, a season 2 months (10 days), a year 4 seasons (40 days). One in-game day is 5 real minutes, 3 of daylight and 2 of night (`daylight_fraction` 0.6 in sky.tres), so a season is 50 minutes and a year about 3h20m. The clock is linear (sunrise 04:48, sunset 19:12); only the sun's phase is stretched (`SkyModel.phase_of_clock`), and daylight 0.5 stays the old cosine so old tests hold.
- Names (Nathan: plain defaults): seasons Spring, Summer, Autumn, Winter; months Early Spring, Late Spring, Early Summer, Late Summer, Early Autumn, Late Autumn, Early Winter, Late Winter. All in content/config/calendar.tres.
- `GameCalendar` (core/game_calendar.gd) lives in the Sim, ticks with it, advances through offline time, and saves as `calendar.elapsed_days`. Save version 3; v2 saves migrate to the first morning of Spring. A new game starts at 07:12, Day 1.
- The sky runs off the calendar clock (not session time), so the sky and the HUD clock agree. Rain, wind and mist keep the session clock.
- API: `Calendar` autoload (core/calendar_service.gd, one line in project.godot) with `now()`, `season_weights()`; EventBus `season_changed`, `month_changed`, `day_changed`, `year_changed`. The class is `GameCalendar` because an autoload cannot share a global class name.
- Seasons are outdoor only (meadow and Larkmoor, anything with a SkyCycle). Ground and props are recoloured in the existing relight shaders (render/shaders/season.gdshaderinc): green texels switch to the season colour by a per-texel Bayer plus patch threshold, so a change is a growing scatter, never a pop; winter lays snow on greens and highlights. The grade tint, haze colour and fog are multiplied by the season. The look turns over during the last day of a season, so the new one is complete when its first day starts. Spring and summer blossom and green, autumn amber and red, winter snow, in rain becomes snow in winter. Particles (petals, sun motes, leaves, snow) in world/season_particles.gd.
- Quarry and other themed areas have no SkyCycle, so they are unchanged. The clock still shows there.
- Dev console: `season [name]`, `day <n>`. tools/season_shots.gd renders each season at noon, golden hour and night.

## 2026-11-23: Walker overhaul, sprint, jump, slide
- **Look.** Walker redrawn (`tools/art/gen_walker.py`, atlas 4x5 cells, 20 poses): same hooded identity, terracotta cloak with a dark scarf that reads against the grass. The atlas no longer bakes a ground shadow; SkyShadows casts it and shrinks it as the walker rises.
- **Procedural animation.** `WalkerBody` draws the atlas cell one texel row at a time, so squash/stretch, lean and hop stay on the texel grid (no rotation, no blur). Walk cycles speed up with the speed factor; landings squash; takeoff stretches; sprint leans the head 3 texels; sprints, slides and landings kick dust (2x2 dither thin-out, no alpha).
- **Controls.** Shift (hold) sprints, Ctrl toggles a sprint lock, Space jumps, C crouches (hold) or slides when pressed while sprinting. Jump and Crouch are rebindable; Shift and Ctrl are fixed because the rebind capture ignores modifiers. Pad: A jumps.
- **Recentre moves off C (taste question for Nathan).** C was Recentre camera; Crouch/slide takes it. Recentre now defaults to Home (it was already bound there as a second key). Alternative: middle-click is taken by pan-drag, so Home is the only free pick that needs no new gesture. Old saves with Recentre on C fall back to Home and keep every other rebind.
- **Jump.** About 17 texels high, 0.45 s of air. Hold for full height, tap for a hop. A press just before landing chains the next jump (bunny hop). Each jump adds +0.30 speed that fades at 0.45/s and stacks to +0.60, so chained hops while sprinting reach about 2.1x walking speed. Jumping clears pads: standing pads count only a grounded walker, so landing on one presses at once. Click-to-walk keeps going while airborne.
- **Camera.** The view rises by about two thirds of the jump height (eased, never overshoots), a hard landing thumps it up to 2.5 texels, and sprinting leans the look-ahead up to about 2x further and tightens the follow rate. All of it is off under Calm camera.
- **Slide.** C pressed while sprinting (speed factor 1.25 or more): 2.2x burst easing to 0.6x over 0.7 s, direction locked, ends at a wall, 0.45 s cooldown. Jumping out of a slide gives +0.15 extra boost. Crouch walks at 0.5x and is silent.
- **Balance numbers** (`sprint_mult` 1.55, `crouch_mult`, slide and jump-boost values) live in `GameConfig` / `content/config/game.tres`. Gravity, jump velocity and ease rates are feel constants in `WalkerMotion`. Sprint and jumps raise momentum charge simply because it is fed by distance walked.
- **HUD.** SPRINTING HELD (Shift) or SPRINTING ENABLED (Ctrl lock) floats above the Momentum panel in the bold Pixelify title face; it sits outside the panel layout so it never resizes it. It shows only while the Momentum panel is visible.
- Not run in the cloud: the engine itself. CI runs the headless tests; the PC pass judges the feel, the label position and the new sprites.

## Seasonal events (2026-11-23)
- **Decision (Nathan approved the audit pick; picks are mine):** one small event per season, read off the calendar, all numbers in `content/config/seasonal_events.tres`. Spring **Petal Shower**: golden critter wait x0.7. Summer **Long Light**: passive income +8% while the sun is up (about +2% averaged over a year). Autumn **Seed Fall**: relic roll interval x0.75. Winter **Frost Pads**: momentum decays at half speed.
- **Why these:** each touches a system that already exists (critter, income, relic rolls, momentum), so nothing new to balance and no swing over a few percent. Plain names, no streak-tier words.
- **Surface:** `core/seasonal_events.gd` (pure), `Sim.events`, arrival banner on `season_changed` (`DistrictBanner.show_event`), event line in the clock tooltip. Water and recolour untouched; no new dither.
- **Visible:** each event thickens its own season's particles (x2.4 petals, x2.6 sun motes, x2.2 leaves and seeds, x1.8 snow, `particle_boost`). Not done: frosted pad meshes and a warmer summer grade (need the engine to tune). Not run in the cloud: the engine; CI runs tests, the PC pass checks the look.

## 2026-11-24: light pools at night, nearest the walker first
The shade shader has 48 light slots now (was 24). Larkmoor has about 50 pools (21 pads, gate, arch, 26 lanterns, walker), and the 24 slots were full before the lanterns were added, so no lantern got a pool. Pools are kept in memory (up to 256) and the shader gets the walker's pool first, then the rest nearest the walker on the 2:1 ground ellipse. Pad pools go from 0.45 to 0.9 strength. Lantern pools are added once per scene in `_begin`, so they do not depend on which chunks are loaded. Not run in-engine (the cloud cannot run Godot); PC night shots are the check.

## 2026-11-24: Larkmoor node headroom (chunks 160, rings 2 and 2)
- **Why:** #326 adds about 30 Larkmoor nodes, which would put the night count near 1367 against the 1350 ceiling. Each loaded prop is two nodes (its sprite and its shadow quad), so the prop chunks are the lever.
- **What:** `CHUNK` 320 to 160, `LOAD_RING` 1 to 2, `KEEP_RING` 2 (unchanged). Counted on `placements3d.json`, the worst walker spot loads 162 props, not 299, so the estimate is about 1060 nodes at that spot (about 1340 before). The guarantee is the same: at least 320 texels of props around the walker.
- **Also:** `_spawn_one` shares one padded texture per file and one prop material per file (`_padded`, `_prop_mat`). Before, each spawn duplicated the material and `SkyCycle.prop_material` kept every copy in `_prop_mats` for the per-frame relight, so the list grew with every load.
- **Not run in-engine** (the cloud cannot run Godot). The node count is an estimate from the placements, not a measured number; the PC pass should read the real count at night and at the worst spot, and check for pop-in at zoom 1 along a chunk edge (the view reaches about 340 texels from the walker at zoom 1, a little past the 320 guarantee).

## 2026-11-24: Larkmoor flower gardens draw from one atlas
- **Why:** the first frame a garden flower variant came into view baked its sprite (`GardenArt.frame`: an Image built pixel by pixel, then a new texture), so zooming out or walking into a new field hitched, and each flower was its own draw call (about 300 at zoom 1, the largest count Larkmoor draws).
- **What:** every frame of every statistic is one atlas texture, built once on first use (`GardenArt.atlas()`, `atlas_rect()`, `frame_index()`). `GardenLayer` draws with `draw_texture_rect_region` from that atlas, so the canvas batches the whole garden, and it finds the flowers in view by a binary search on the y-sorted list. Sprites are the same pixels: `test_gardens` checks every atlas frame against its own sprite.
- **Not run in-engine** (the cloud renders with lavapipe). Measured on lavapipe with `tools/larkmoor_stream_bench.gd` (A/B on one machine, numbers in the PR).
## 2026-11-24: Larkmoor prop chunks load through a queue, textures warm ahead
- **Why:** a walker crossing into new chunks spawned up to five chunks in one frame, and each first use of a sway texture was padded on the spot. Measured on lavapipe: chunk loads averaged 1.44 ms and peaked at 19 ms on the walk.
- **What:** `_refresh_center` queues the chunks the walker now needs, nearest first, and `_drain_spawns` spawns them at 2 ms a frame (at least one). `_drain_warm` readies the textures of every prop chunk nearest the start, 1 ms a frame, only while nothing waits to spawn (`_warm_prop`). Zone entry still spawns the first ring at once, under the wipe.
- **Measured:** the walk now averages 0.65 ms a chunk, peaking at 11.5 ms. The loaded area still keeps 320 texels around the walker, because the walker moves about 3 texels a frame and a crossing takes a few frames to spawn.
- **Found, not fixed:** the worst walker spot (1460, 800) loads 159 props and reads 1392 nodes, over the 1350 ceiling. Each prop is two nodes (its sprite and its shadow quad). Streaming by camera view, so panning does not show pop-in, needs fewer nodes per prop first.

## 2026-11-24: shadows batched into three MultiMesh layers, not a quad per caster
- **Why:** each loaded prop was two nodes (its sprite and its shadow quad), so the worst walker spot read 1392 nodes against the 1350 ceiling, and view-based streaming needs headroom.
- **What:** `SkyShadows` draws every caster shadow in one `MultiMeshInstance2D` ("Casters", z 0), the pad overlay in a second ("PadOverlay", z 1, hidden without pads), and the walker's shadow in a third ("WalkerShadow"). Each instance carries its soft, strength and pad-overlay flag in `INSTANCE_CUSTOM`, read by `cast_shadow.gdshader` as varyings. The transform math is the same as the old per-quad placement (`_xf`), and the shader's softness and density are unchanged.
- **Measured (lavapipe, headless):** the worst walker spot reads 1095 nodes (was 1392). Walk and zoom scenarios all stay between 991 and 1057 nodes.
- **Look:** settled shots at noon, sunset and midnight match the chunk-queue build by eye in a crop under a tree and the walker. Pixel diffs are not zero, because particles, fireflies and the sky flicker draw from time, so two runs of the same build also differ. Not run in-engine: the PC pass should compare the sunset shadows under the trees and the pad row.
- **Also:** `LarkmoorScene` emits `chunk_loaded(key)` and `chunk_unloaded(key)` from `_load_chunk` and `_unload_chunk`, for per-chunk effects such as the grass quads.

## 2026-11-24: Larkmoor props stream by camera view, under a node budget
- **Why:** the walker ring alone (LOAD_RING 2) leaves the screen edges empty when the camera is panned away from the walker, so props pop in at the edge. The on-screen area is also larger than the ring at some zooms.
- **What:** `_set_view` reads `GraphicsQuality.visible_local_rect(self)` once per sync. A chunk is wanted when it is in the walker ring or on screen plus `VIEW_MARGIN_LOAD` (1 chunk). A loaded chunk stays while it is in the walker's keep ring or within `VIEW_MARGIN_KEEP` (2 chunks) of the screen, so an edge does not churn. Both are clamped to the map (`_map_chunks`). The queue is ranked walker ring, then on screen, then the margin (`_queue_rank`).
- **Budget:** chunks outside the walker ring load only while the scene's node count plus the chunk's props stays under `VIEW_NODE_BUDGET` (1300), so the view never takes a zone past the 1350 ceiling. The walker ring always loads, so tour stops near the ceiling lose view margin first, not walker props.
- **Bush list:** an unload now rebuilds the rustle list (`_rebuild_bushes`). Before, a view-only unload left freed sprites in `LifeReact`, which cast-errored every frame.
- **Measured (headless, no renderer, Godot 4.7.2, `tools/larkmoor_view_probe.gd`):** at zoom 1, 2 and 4, five pans each (the walker spot plus 900 and 600 texels away, and a diagonal), every frame checked: 0 frames with an on-screen chunk unloaded. Max node count 1154 at zoom 1 and 1121 at zoom 2, both on the diagonal pan; 1105 at zoom 4. Baseline idle at the spawn was 995 nodes, now 1005.
- **Not run in-engine:** frame time, pan feel and the edge look. The PC pass should pan at zoom 1 and 2 and watch the edges.

## 2026-11-24: A pinned season moves the calendar (winter pin now reaches the clock and the flowers)
- **Cause:** `SkyCycle.debug_season` (tools and screenshots) only changed the sky's season weights. The HUD clock, the flower gardens (frost comes from `Calendar.now()`) and the sim's season bonuses all read the real calendar, so a winter pin showed snow on the ground but still read Early Spring and drew no frost.
- **Fix:** `SkyCycle._update_season` jumps the calendar to the pin (`GameCalendar.jump_to_season`) whenever the calendar is in another season. Pure rule: `SkyCycle.pin_jump_needed(pin, current)`.
- **Scope:** only when the pin is set, which is tools and tests. Normal play never sets it.
- **Not verified on the PC:** whether frost reads clearly at zoom 1 and 4 once the flowers switch.
## 2026-11-24: Walk grid cells are open only when every pixel is walkable
- **Why:** the Larkmoor path-tier PR (#406) changed trees, and its route test failed on one Westmere route: a waypoint step crossed a 3-cell hole in the walk mask. The hole was on main too. `WalkMask._build_grid` sampled only a cell's corners and centre, so a hole smaller than a cell could sit inside an open cell and a route could cut across it.
- **What:** `world/walk_mask.gd` checks every pixel of each 4x4 cell and closes the cell on any blocked pixel. The old centre check is gone, since the full check covers it.
- **Measured:** `tests/run.gd` 6651 checks, 0 failed. `tools/route_probe.tscn` (real walker, Larkmoor pads): main had 5 misses, this change has 3 (pads 5 and 9 now route). The other 3 are the same on main. Time 93 s with the change, 106 s on main, within run noise.
- Not run in-engine: the play-through of the Westmere and Heronmere routes on a PC.

## 2026-11-24: A pinned time of day moves the calendar clock (dusk pins no longer show daylight on the HUD)
- **Cause:** `SkyCycle.debug_phase` (tools and screenshots) pinned only the sky, so the HUD clock stayed on the real time. The golden tool also set the calendar to the sun phase, which is a different scale from the clock (a sun phase of 0.73 is not clock 0.73), so its labels did not match the sky.
- **Fix:** `SkyCycle._pin_clock` sets the calendar to `SkyModel.clock_of_phase(debug_phase)` whenever it is off by more than 0.005 of a day. The sky still takes the exact pin in `_model_time`, and the sky and calendar agree because `phase_of_clock` inverts `clock_of_phase`. Pure rule: `SkyCycle.clock_pin_needed`.
- **Tools:** `tools/golden_shots.gd` no longer sets the calendar itself.
- **Checked in the cloud:** the golden shot set prints HUD clocks 16:38 (golden), 18:38 (sunset), 20:13 (dusk) and 22:08 (night) for the matching pins.
- **Not verified on the PC:** the batch 85 captures themselves.

## 2026-11-24: Golden shot tool pins match the golden and sunset look (batch 87)
- **Cause:** QA read the tool's pins as wrong. Sun phase 0.75 reads 19:12 on the clock and 0.76 reads 19:26, both evening and fairly bright. The labels were also off: 0.66 was named 16:30 but reads 16:36 (cloud run: 16:38).
- **Fix:** `tools/golden_shots.gd` PHASES now uses 0.69 as golden (17:28, sun 0.37 up, full golden look) and 0.73 as sunset (18:37, sun still above the horizon). The other labels are recomputed from `SkyModel.clock_of_phase` at daylight 0.6. Labels are within about 2 minutes of the HUD clock.
- **Wildlife window, checked:** `MeadowLife.low_sun` (life_wild, life_critters, life_air, cozy_swarm) uses `SkyModel.low_sun`, which is 0.41 at phase 0.69 and 0.95 at 0.73, so the golden and sunset pins both sit inside it. It differs from `SkyModel.golden()` in the morning and afternoon: `low_sun` is 0 at noon, `golden()` keeps 0.35. Wildlife was left as it is, because changing it would alter spawn and behaviour, not only the tool.
- **Not run in-engine:** the cloud cannot run Godot, so the new captures and clock labels are not checked here. Tool-only change, so no changelog fragment.

## 2026-11-24: Pad costs show on wooden signs, on every row's first pad, open or locked
- **Cause:** the cost chip showed only on a locked row's first pad. The Starting Clearing sprout rows are open from the start, so their first prices (10 Sunlight) showed only in the hover tooltip.
- **Fix:** `TexelPad._draw_cost_sign` draws a terracotta plank on a post beside the row's first pad: the cost (currency icon and amount) over the reward (stat icon and gain). Its top band is green when the cost is held and red when not. The plank widens only for a long cost or reward (`TexelPad.sign_box`).
- **Node cost:** still one child node per row head (the old chip node), redrawn only when the held state flips. No new nodes, so the zone node counts are unchanged.
- **Checked in the cloud:** `tests/run.gd` 6759 checks, 0 failed. Headless captures of the real `TexelPad` (open and locked) and of the real `main.tscn` opening pads show the signs.
- **Not verified on the PC:** the Vulkan render of the signs. The cloud renders with OpenGL 3 under xvfb.

## 2026-11-24: Pad cost signs show the live tooltip values and sit under the night shade
- **Cause:** the sign showed "+1" from the button definition, while the tooltip shows the live gain (`Sim.press_gain_preview`, e.g. +439B). The sign also drew at z 11, above the night shade (z 5), so it stayed fully lit at night.
- **Fix:** `TexelPad._refresh_sign` reads the cost (`Formulas.button_cost`) and the gain (`press_gain_preview`) with the same `format()` the tooltip uses, every 0.2 s, and redraws only when a value changes. The plank is a fixed 50 texels wide, so it never resizes. A value that is too wide drops its fraction first (`fit_sign_text`). The sign's z is now `LOCK_CHIP_Z` 4, between the plate (0) and the shade (5).
- **Checked in the cloud:** `tests/run.gd` 6841 checks, 0 failed. Midnight and noon captures of the real `main.tscn`.
- **Not verified on the PC:** the night look. In the cloud capture a sign inside a pad's glow still reads brighter than the dark ground, as the pad and the ground beside it do. The PC night shot is the check.

## 2026-11-24: Quarry scene prefetch warms its script (gate walk parse error)
- **QA finding:** walking onto the Larkmoor Ember gate logged `Parse Error: Failed` at `res://world/quarry_scene.tscn:7` (the script line) on every head tested, including before the entrance art. Direct zone-2 boots, which load on the main thread, were clean.
- **Likely cause:** `main.gd` `_prefetch_scene` loads the scene on a worker thread, and the quarry script uses several game classes. The threaded load failed and `_take_prefetched` fell back to a plain synchronous `load`, so the quarry still opened (log error and a small stall).
- **Changed:** `_prefetch_scene` first loads the scene's script on the main thread for scenes in `WARM_SCRIPTS` (the quarry only; Larkmoor's script preloads large textures, so warming it would bring the stall back). The threaded request then reuses the compiled script.
- **Not run in-engine:** this is a read-the-code fix. PC QA should walk onto the gate and confirm the error is gone.
