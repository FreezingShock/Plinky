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
| Draw calls | under 250 | High peaks near 200 now |
| Nodes in the active zone | under 700 | Larkmoor is about 414 headless |

A PR that adds a visual system pastes the `tools/bench.gd` table (Low and High) and states the delta against these.

## Rain spikes
SkyRain is stateless (no pooling to do): every drop is a pure function of time, redrawn at 12 fps. The 5 ms spikes
were that 12 fps redraw landing on one frame: about 150 drops times three `sin()` hashes plus the rects. Two of the
three hashes per drop are constant, so they are now cached once, and Low and Medium draw 40% and 70% of the drops.
Spike frames on a real GPU after this change: not yet measured.

## The Larkmoor transition stall (fixed in 0.26.1)
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
