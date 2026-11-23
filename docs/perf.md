# Performance

**Target:** 60 fps (16.7 ms a frame) on integrated graphics at 1080p, on **High**. Low must hold 60 on older
integrated GPUs. The game is 2D canvas drawing plus one 642x362 post-process pass, so the budget is
mostly CPU: GDScript redraws and node count. Every number below is a budget to measure against, not a result.

## Tools
- **F3 overlay** (ui/perf_overlay.gd): fps, avg / p95 / worst frame over the last 240 frames, draw calls, nodes,
  script ms, VRAM, quality. Off by default, costs nothing while hidden.
- **Benchmark** (tools/bench.gd): runs the real main scene through idle, presses (a pad press every 6 frames),
  and zoom 4x at each quality, vsync off so the numbers are true cost. Writes shots/bench.json.
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

## Open
- No GPU numbers yet. A real-hardware run of tools/bench.gd is needed to find the actual hot spot; the CPU
  side is cheap enough that the post shader and window fill rate at 4K may matter more.
- Popups and particle bursts are still one node each. Fine at hold-press rates; pool them if the bench shows spikes in `presses`.
