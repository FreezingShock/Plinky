# Performance

**Target:** 60 fps (16.7 ms a frame) on integrated graphics at 1080p, on **High**. Low must hold 60 on older
integrated GPUs. The game is 2D canvas drawing plus one 642x362 post-process pass, so the budget is
mostly CPU: GDScript redraws and node count. Every number below is a budget to measure against, not a result.

## Tools
- **F3 overlay** (ui/perf_overlay.gd): fps, avg / p95 / worst frame over the last 240 frames, draw calls, nodes,
  script ms, VRAM, quality. Off by default, costs nothing while hidden.
- **Benchmark** (tools/bench.gd): runs the real main scene, meadow then Larkmoor, through idle at noon,
  sunset, night and rain, then presses (a pad press every 6 frames) and zoom 4x, at each quality. It forces vsync and
  the fps cap off after saved settings load, so the numbers are true cost. Writes shots/bench.json.
  ```
  godot --path . --script tools/bench.gd                        # real window: the numbers that count
  godot --path . --script tools/bench.gd -- --quality=low --frames=600
  godot --headless --path . --script tools/bench.gd             # scripts only; draws, objects, VRAM read 0
  ```
- Settings menu: Display > Graphics quality (ui/settings/settings_registry.gd).
- `PerfStats` (render/perf_stats.gd) is the shared sampler; `PerfStats.counters()` has the engine monitors.

## Graphics quality (render/graphics_quality.gd)
`GraphicsQuality.set_level(Level.LOW | MEDIUM | HIGH)`, saved in `user://graphics.cfg`; `GraphicsQuality.LABELS`
for the settings menu. Palettes, dither, outlines and lighting are identical at every level, so the look does
not fork; lower levels draw less and step slower.

| | Low | Medium | High |
|---|---|---|---|
| Fireflies / pollen drawn | 40% | 70% | 100% |
| World life redraw (LifeAir) | 8 fps | 10 fps | 12 fps |
| Grass sway redraw (LifeGround) | 4 fps, every 2nd tip | 5 fps | 6 fps |
| Particles per burst | 50% (min 2) | 75% | 100% |
| Ground relight height march (ground_light.gdshader) | 6 taps at 2x stride (same reach) | 9 taps at 1.34x | 12 taps |
| Ground occlusion taps | 2 | 4 | 4 |
| Full-frame light grade (reads the screen texture, a back-buffer copy) | skipped | on | on |
| Season air (SeasonParticles: petals, motes, leaves, snow) | 40% | 70% | 100% (at most 400 per kind, 12 fps, visible part only, none under Reduce motion) |

Systems that scale with content (new props, birds, grass, weather, lights) read their counts through
`GraphicsQuality.life_count()`, `particle_count()` or the step helpers, and cull with `visible_local_rect()`.
Add a row here when you add one.

## What changed in the first pass
- **PixelViewport** renders its 3D viewport once while `world_root` is empty (the meadow is baked 2D), and
  switches to per-frame as soon as a 3D node is added. Output is unchanged. Saves a full 642x362 Forward+ pass every frame.
- **Fx** uploads the ripple array only while a ripple is alive, and `shimmer_step` only when it ticks (10 per second),
  instead of a new array and two uniform writes every frame.
- **PixelViewport** writes `dither_origin` only when the camera crosses a texel.
- **LifeGround / LifeAir** skip grass tips, lights and fireflies outside the view (plus a 24 texel margin). The tip
  count is only 109 today; this is what keeps the bigger meadow flat.
- **main.gd** sets the pad glow multiplier only when it changes.

## Rules for new visual systems (bigger meadow, weather, day/night, birds)
1. Draw in a step (6 to 12 fps) with `queue_redraw()`, not per frame, unless the thing must move smoothly.
2. One `_draw()` per layer, not one node per object. Hundreds of Sprite2D props: cull by distance to the camera.
3. Cull with `GraphicsQuality.visible_local_rect(self)` once per redraw, not per element.
4. Counts come from `GraphicsQuality`; hash-seeded layouts (`MeadowLife.hash01`) so Low draws a prefix of High's set.
5. Shaders: no new full-screen pass. Add to post_dither.gdshader, keep loops constant and short, and
   write uniforms only on change.
6. Pool anything spawned per press (popups, particle bursts) once presses can come faster than 10 a second.
7. Check Low and High with the benchmark before merging a visual PR, and paste the table in the PR.

## Budgets (benchmarked on an RTX 3060 Ti, 1080p, vsync off; main at a4219f2)
Measured: meadow and Larkmoor both sit at about 2000 to 2150 fps (about 0.5 ms) in every sky state; Larkmoor costs
about the same as the meadow. Presses at High are about 1040 fps (about 1 ms). Rain had 4.9 to 5.3 ms spike frames.
A 3060 Ti hides integrated-GPU costs, so the budgets keep a wide margin. Integrated graphics is assumed 8 to 15 times
slower on the post pass and fill; that ratio is an estimate, not a measurement. Get one real integrated-GPU run when a
machine is available.

| Budget (3060 Ti, High, 1080p) | Limit | Why |
|---|---|---|
| Whole frame, idle, any sky state | avg 0.7 ms (about 1400 fps), p99 1.5 ms | 1 ms here is 8 to 15 ms on integrated, inside 16.7 |
| Whole frame, pad presses | avg 1.2 ms, p99 2.5 ms, worst 4 ms | a spike above 4 ms here is a visible hitch on a slow GPU |
| One new visual system (a layer, a shader pass) | at most 0.1 ms avg | there are about 8 such systems in flight |
| Whole frame on Low | at least 25% under High | Low exists for slow GPUs |
| Draw calls | under 250 (CI-enforced; the headless bench reads 0, so it bites on real-window runs) | High peaks near 160 on the CPU rasteriser |
| Nodes in the active zone | under 1350 (CI-enforced) | Larkmoor is about 1205 headless now: the Upgrades menu builds a row per gift, and the Bloom gifts added 10 rows (1065 before) |

A PR that adds a visual system pastes the `tools/bench.gd` table (Low and High) and states the delta against these.

## Rain spikes
SkyRain is stateless (no pooling to do): every drop is a pure function of time, redrawn at 12 fps. The 5 ms spikes
were that 12 fps redraw landing on one frame: about 150 drops times three `sin()` hashes plus the rects. Two of the
three hashes per drop are constant, so they are now cached once, and Low and Medium draw 40% and 70% of the drops.
Spike frames on a real GPU after this change: not yet measured.

## The Larkmoor transition stall (fixed in 0.26.2)
Found by profiling on the PC (RTX 3060 Ti, 2026-11-23): one 320 to 380 ms frame, once per run, in the first Larkmoor
row. It was not Low-specific, audio, shaders, Vulkan or a sky layer; it was the zone swap itself. `Transitions.cross_zone`
runs the swap at the wipe's peak (0.45 s after entry), and the swap did everything in one frame: `load()` of the scene
(about 36 ms), its `_ready` (about 22 ms) and `spawn_occluders` (about 170 ms: 400-odd synchronous texture loads, padded
copies of every swaying prop and a material per prop). The bench showed it in the "first Larkmoor row" only because its
frames are tiny, so the swap's frame landed inside that row (+771 ms after entry = 450 ms cover + the stalled frame).
Fix: `main.gd` prefetches the scene with `ResourceLoader.load_threaded_request`, and `spawn_occluders_sliced` builds the
props over several frames (8 ms each) under the fully covering wipe. `PerfStats.lap()` and the bench's `TRACE` lines time
each stage. After the fix the swap is a 99 ms first rendered frame plus 22 ms of `_ready`, under the fully covering wipe (330 ms to about 120 ms on the PC; props build over about 200 ms of 8 ms slices). CI runs `tools/check_frame_budget.py`: no frame over 150 ms in the headless bench, 300 ms for the covered swap frame.

## Open
- No GPU numbers yet. A real-hardware run of tools/bench.gd is needed to find the actual hot spot; the CPU
  side is cheap enough that the post shader and window fill rate at 4K may matter more.
- Popups and particle bursts are still one node each. Fine at hold-press rates; pool them if the bench shows spikes in `presses`.

## Weak-hardware stand-in (2026-11-23)
No integrated GPU was available, so `tools/bench_weak.sh` runs the real-window bench on **Mesa lavapipe** (software
Vulkan) under Xvfb, 4 CPU cores, 1280x720. That is a CPU rasteriser, not an iGPU: its absolute numbers mean nothing
(every phase sits near 20 ms), but it is stable enough to A/B two builds or two quality levels. Install: `apt install
mesa-vulkan-drivers xvfb`, then `GODOT=/path/to/godot tools/bench_weak.sh out.json 1280x720 --frames=120`.

Where a frame goes at Low in the meadow (wall time, hiding one group at a time; the empty window floor is 5.4 ms,
the HUD 1.7 ms, the world about 14 ms): sky passes about 7 ms, ground about 6 ms, walker, pads and props about 5 ms,
far layer 3.6 ms, screen light 3 ms, life layers 2.3 ms, tree and rock shadow sprites 1.5 ms. Frame time barely moves
with resolution here (640x360 21.7 ms, 1080p 27.3 ms), so the cost is per-layer work, not pixel count.

What Low changed (all measured with `bench_weak.sh`, 120 frames a phase, same machine, main at v0.33.0 vs this branch):

| Average frame, mean of the 5 non-zoom phases | before | after |
|---|---|---|
| Low, meadow | 21.5 ms | 18.8 ms (-13%) |
| Low, Larkmoor | 21.2 ms | 19.0 ms (-10%) |
| High, meadow | 20.9 ms | 20.1 ms (noise; High is unchanged except the shadow march now skips when no shadow applies) |
| High, Larkmoor | 21.1 ms | 21.2 ms (unchanged) |

Low is now about 10 to 15% under High on this rasteriser, short of the 25% budget above. The budget stays: a real iGPU
may respond more to the skipped screen-texture pass and the shader taps than lavapipe does, and the PC thread should
run `tools/bench.gd` at Low and High on the real machine and update this table.
Not done and why: rendering the world into a 642x362 target (would cut fill 9x at 1080p) touches every world shader's
texel maths and the zoom, so it needs its own change and an in-engine look check.

## Zone load, second pass (2026-11-24)
Measured with `tools/bench_weak.sh` (lavapipe, 1280x720, High, 4 cores) on the swap's `PerfStats` stages. The numbers
are CPU on the main thread and wall time, and the wall numbers include the software rasteriser, so only the CPU
rows are comparable to a GPU. Lavapipe shares the 4 cores with the workers, so each run varies by tens of milliseconds.

| Swap stage (main thread) | before | after |
|---|---|---|
| Ember Quarry props, built in one frame | 89.7 ms (synchronous `load()` of 366 textures, then the props) | 20 to 28 ms, built over 8 ms slices under the wipe |
| Ember Quarry `_ready` (add_child) | 13 ms | 17 to 23 ms |
| Larkmoor `_ready` (add_child), one run | 228 ms | 230 ms in the run without timers; about 25 ms in the run with timers (see note) |
| Larkmoor: life (`LifeAir.setup` reads the backdrop with `get_image()`) | 96 ms | decoded on a worker, 3 ms on the swap frame |
| Larkmoor: sky ground maps (`load()` of two 3040x1840 maps) | 163 ms | prefetched, 17 ms |
| First rendered frame after the swap (lavapipe, includes the render) | 114 to 198 ms | 59 to 150 ms |

What changed: `ZoneAssets` (world/zone_assets.gd) prefetches a zone's textures on the loader, caches each texture once, and
releases the zone's textures when it is left. `spawn_occluders_sliced` on the Ember Quarry spreads its props over frames.
The backdrop is decoded from its lossless source PNG on a `WorkerThreadPool` task. The four Ember Quarry shaders are warmed
at boot. Larkmoor's scene is requested on the loader before its textures.

Note: one run of Larkmoor's `_ready` still measured 230 ms, while a run with stage timers inside `_ready` measured about 25 ms.
The two runs had the same code apart from the timers, so the gap is probably thread contention on this 4-core software
renderer. Not settled. Needs a timed swap on the PC (RTX 3060 Ti) before the number is quoted.

Not done: the Ember Quarry still draws 183 props as one node each (one draw call each). Atlasing them is the next step for
batching. The first rendered frame after a swap is GPU work (texture upload, first draws), which only the PC can measure.

## Camera pan sweep and Larkmoor entry (2026-11-24)
- **Probe:** `tools/larkmoor_pan_sweep.gd` pans the camera in a sine (free mode, the walker still) at 120, 300 and 600 texels a second, at zooms 1, 2 and 4, 360 frames each. It counts pop-in frames (an on-screen chunk with props not yet loaded), chunk loads and their cost, and the trace labels. `-- --still-sway` holds the flowers (Reduce Motion), so only pan-driven redraws remain.
- **Result (lavapipe, High, 1280x720):** 0 pop-in frames at every speed and zoom. Node peak 891 against the 1300 budget. Chunk loads cost 0.2 ms mean and 4.4 to 7.2 ms at worst, at zoom 1 and 600 texels a second.
- **Garden redraw, checked and not changed:** a 32-texel redraw pad (redraw once per pad of pan, not every 16 texels) did not cut redraws in a sway-frozen A/B (127 to 121 at zoom 1, 600 texels a second) and made each redraw about 25% dearer (0.97 to 1.25 ms mean). Dropped. Pan redraws are not the lever; the cost is per flower drawn.
- **Entry hitch:** see [decisions/world.md](decisions/world.md), "Larkmoor's farm builds over the wipe".
- **Not run on a real GPU:** every number above is a CPU measurement on a software rasteriser. PC QA should run the pan sweep at zoom 1 and 2 on the RTX 3060 Ti and check the wheat's entry under the wipe.

## Larkmoor and quarry entry: the theme recolour (2026-11-24)
- **Probe:** `tools/larkmoor_entry_probe.gd` enters a zone the way the CI bench does and prints each frame over `--slow=<ms>`, its PerfStats laps, and a split of the frame: the frame's process pass, then a hook that runs last in the pass, then the gap to the next frame. `--pre=larkmoor --zone=zone2` enters the quarry through Larkmoor.
- **The gap:** the swap frame spent 120 to 170 ms outside every lap and outside process (the process callbacks took about 6 ms). The lap that measures the swap itself (`add_child`, 30 to 45 ms) was not the cost.
- **Ruled out, each left the gap in place:** freeing the old zone at once (1.7 ms), not releasing the zone's textures, skipping the occluders or the pads, hiding the new zone's subtree, making the sky's screen add synchronous, and 900 sprites or large textures entering a frame (2 ms in a micro-benchmark).
- **Cause:** `PlinkyTheme.apply` (theme/theme_apply.gd) wrote about 25 colours and style fields one by one, and each write told every Control that uses the theme to restyle itself. Skipping the call removed the gap, so the cost was in those notifications. The writes now run with the signals held back, and the theme announces one change at the end.

| Swap frame | before | after |
|---|---|---|
| Probe, Larkmoor entry (headless, low), 2 runs | 124 to 224 ms | 50 to 62 ms |
| Bench `first frame after add_child`, Larkmoor | 4 to 7 ms | 4 to 5 ms (unchanged) |
| Bench `first frame after add_child`, quarry | 238 ms | 114 to 116 ms |

- **Still open:** the quarry swap's gap is still 110 to 160 ms in the probe, so the theme was one cause, not the only one. Not attributed yet. The next suspects are Control layout and HUD work queued by the zone change, which the probe cannot show.
- **Seen once:** `world/sky_cycle.gd:503` (`padded`) got a null image from `get_image()` in one bench run of 3 with this change, and none in the baseline run. Not investigated. It is not in this change.
- **Not run on a real GPU:** every number is headless. PC QA should time a zone entry on the RTX 3060 Ti.

## Walk mask on the return paths (2026-11-24)
- `WalkMask.image()` loaded the zone's walkable map on the main thread on its first use after a zone change. That was a synchronous `load()` of about 34 ms, and it fell on the first walk in the new zone, so the return to the meadow and the return from the Quarry showed it.
- Fix: `WalkMask.prefetch(path)` queues the map on `ZoneAssets` when the zone is entered, and `image()` takes it from there. Probe: the 34 ms load is gone from the return frames. Headless frame times are noisy, so the total gain on the PC is not measured yet.

## Boot, title to game, and the loading screen (2026-11-24)
- **Probe:** `tools/loading_probe.gd` runs the boot screen, waits for the title, presses Play (which goes through the loading screen into the game) and prints each slow frame with its phase and laps. It needs a real window: under `--headless` the swap never draws, so run it with `xvfb-run` (this run used OpenGL, not Vulkan, because Xvfb has no VK_KHR_surface).
- **Found:** `GardenArt.atlas()` baked the flower atlas on the game's first frame, about 750 ms on the software renderer. `GardenArt.prepare()` plans the atlas and `GardenArt.prepare_slice()` bakes it three milliseconds a frame from the boot screen; the sheet is packed and uploaded on the main thread. The game's first frame drops to about 7 ms.
- **Not on a worker:** a first version composed the atlas on a `WorkerThreadPool` task. Its boot smoke test then failed on parse errors (preloads of walker_atlas.png, PixelifySans.ttf and bloom_veil.gdshader). With the composition run synchronously the errors went away, so the worker is not safe to use here. Do not move script-adjacent work onto the pool without running `tools/bench.gd`/the boot smoke test.
- **Numbers (xvfb, OpenGL, software renderer; not the PC):** boot to title 1.8 to 2.5 s. Play to game 2.6 to 2.9 s, down from 3.8 to 5.4 s before the atlas change. The worst frame in the loading phase is 340 to 530 ms; it still holds about 300 ms the probe does not label, probably the deferred scene change (freeing the boot screen and instantiating the game).
- **Not measured:** on the PC GPU. Shader compile on the first frames is driver-side and only the PC can show it.

## Atlas bake on the title, and loading holds for it (2026-11-24)
- **Found:** the boot screen baked the flower atlas 3 ms a frame, but the loading phase is short (about 1.5 s on the software renderer) and the atlas needs about 750 ms of baking. The rest, about 290 ms, landed on the game's first frame in `GardenArt.atlas()` (called from `main.gd` `_ready`).
- **Fix:** the title screen bakes a slice a frame while it is idle (`GardenArt.BAKE_SLICE_MS`, 3 ms). Once the loader is done, the boot screen uses a bigger slice (`BAKE_CATCHUP_MS`, 10 ms), and its leave waits for `GardenArt.is_ready()`. The game's first frame no longer bakes anything.
- **Probe:** `tools/loading_probe.gd --dwell=<frames>` sets how long the title stays up before Play (default 60, about a second). Same dwell, same machine (xvfb, OpenGL, software renderer), single runs: worst loading frame 562 ms before, 294 ms after. Play to game 2135 ms before, 1884 ms after. Headless numbers are noisy, so treat these as direction, not the PC figure.
- **Still in that frame (labelled with temporary laps):** occluders and the zone frame about 52 ms, `DevConsole.attach` about 36 ms, meadow load about 35 ms, HUD about 25 ms, and the camera snap and audio start about 27 ms. The rest of the 280 ms frame is the swap frame's draw and end-of-frame work, which the software renderer makes slow. Not changed here.

## The game-entry frame, labelled (2026-11-24)
- **Batch 152 (PC, RTX 3060 Ti):** each boot had one loading hitch of 421 to 436 ms, with laps that did not add up to it. The swap draw was 4 ms at worst, so it was CPU work in the entry frame, not the GPU.
- **Labels:** `main.gd` `_ready` now puts a `PerfStats.lap` after each step (`entry: ...`), and the boot screen labels its atlas slice. `PerfStats.lap` does nothing unless tracing is on, so this costs nothing in play.
- **Dev console:** built on its first open, not on the entry frame (about 36 ms of CPU). Lavapipe could not show it, since the run-to-run spread is larger than the change.
- **Lavapipe, one run, after the change (software renderer):** the entry frame is about 267 ms. Labelled: meadow load 29 ms, HUD 23 ms, audio and camera start 26 ms, menus 11 ms, occluders and zone frame 12 ms, pixel view 5 ms. About 150 ms is unlabelled: draw and the end-of-frame flush, plus the frame before `main._ready`.
- **Not done:** the entry frame still has about 115 ms of labelled CPU work. Getting every frame under 33 ms needs the game's build spread across frames under the swap cover, which waits on a ready signal. That is a separate change.
