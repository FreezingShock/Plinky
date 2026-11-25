# Codebase map

Who owns what, where each system lives, and where the collisions happen. Read this before you start a task that touches more than one folder. Pair it with [pitfalls.md](pitfalls.md) (mistakes to avoid), [interfaces.md](interfaces.md) (signals and autoloads) and the topic file in [decisions/](decisions/README.md).

Checked against `main` at `1f9c5f2` (2026-11-25). Hot-file counts come from `git log -300` on `main`. Everything here was read from the code, not from memory of it. The game has not been run in-engine for this PR (cloud threads do not run Godot for docs-only work).

## How the layers fit

```
core/ (pure logic: Sim, BigNum, formulas, saves, calendar, achievements)
   ^ GameState (autoload) owns one Sim, runs the fixed tick, forwards Sim signals
   |
EventBus (autoload, signals only)  -->  world/ (zones, pads, walker, life)
   |                                 -->  ui/ (HUD, menus, tooltips, banners)
   |                                 -->  audio/ (Audio autoload)
   |                                 -->  render/fx_driver.gd (Fx, the only writer of gameplay shader uniforms)
   v
main.gd wires nodes together. It holds no balance numbers and owns no economy logic.
```

Rules that hold the layers apart (details in [pitfalls.md](pitfalls.md) and [SPEC.md](SPEC.md) section 5):

- `core/` never references nodes, scenes, or `render/`, `world/`, `ui/`. The autoload shells (`event_bus.gd`, `game_state.gd`, `calendar_service.gd`, `save.gd`) are the only Node scripts there.
- Gameplay emits EventBus signals. It does not set shader uniforms. Presentation scripts that own their own material (sky, shadows, screen light, toon, pixel viewport, window frame, transitions, boot and title backgrounds) set their own uniforms.
- Stats are `BigNum`. Every number shown to the player goes through `core/number_format.gd`.
- Balance lives in `content/*.tres`, loaded by `data/content_loader.gd`. Scripts hold no balance numbers.
- The HUD sits on its own layers (`z_index` 120 to 160 for HUD pieces such as `save_indicator.gd` and `welcome_card.gd`, CanvasLayers 127 and 128 for overlays). World lighting is z 5 to 10. Anything that must stay above the night tint goes on the HUD layer.

## Systems

Each section gives purpose, key files, entry points, the signals or interfaces it uses, and the gotchas. "Hot" files are listed in the table at the end.

### 1. Simulation and economy

- **Purpose.** All stats, pad presses, purchases, mastery, momentum, heat, critters, streaks, relics, attributes, resets, sealed caches, achievements and offline gains. Runs with no scene, so tests and `tools/sim.gd` can drive it.
- **Key files.** `core/sim.gd` (about 120 functions: `try_press`, `_press`, `press_gain`, `income_per_second`, `can_afford`, `step`, `auto_pick`, `check_achievements`, `new_game`). `core/bignum.gd`, `core/number_format.gd`, `core/formulas.gd`, `core/mastery.gd`, `core/pad_press_timer.gd`, `core/press_streak.gd`, `core/sealed_pulls.gd`, `core/achievements.gd`, `core/relic_inventory.gd`, `core/relic_query.gd`, `core/stat_sources.gd`, `core/stat_index.gd`, `core/hud_layout.gd`, `core/onboarding.gd`, `core/welcome_back.gd`, `core/seasonal_events.gd`, `core/tick.gd`.
- **Data.** `data/*_def.gd` resource classes (stat, button, zone, area, tier, relic, rarity, attribute, zone_reset, achievement, sealed_pull) and `data/*_config.gd` (game, mastery, calendar, sky, onboarding, relic, seasonal events, sim profiles). The `.tres` files are in `content/`.
- **Entry points.** `GameState.try_press`, `GameState.try_reset`, `GameState.buy_attribute`, `GameState.try_sealed_pull`, `GameState.enter_zone`, `Sim.step(dt)`.
- **Signals out.** Sim signals are relayed by `GameState` to EventBus: `stat_changed`, `button_pressed`, `button_denied`, `mastery_changed`, `mastery_leveled`, `zone_entered`, `gate_opened`, `reset_done`, `attribute_bought`, `relic_*`, `bonus_gained`, `critter_*`, `heat_hot_changed`, `momentum_tier_changed`, `achievement_unlocked`, `offline_gained`. Full list in [interfaces.md](interfaces.md).
- **Gotchas.**
  - A float in a stat path is a bug. `Sim.press_gain` takes a float `crit_mult`, so new multipliers need the same care: scale BigNum values, do not carry a float stat.
  - `GameState.try_rebirth` and the `rebirth_done` signal still exist in code. The memory notes say Prestige and Rebirth were removed from design, so check with the owner before adding anything that depends on them.
  - `tests/run.gd` runs with no autoloads. Anything a suite calls must not name `Audio`, `EventBus`, `GameState`, `Save`, `Fx`, `Juice`, `Calendar` or `Banner`.

### 2. Save, slots and offline progress

- **Key files.** `core/save.gd` (autoload `Save`: autosave, load on start, offline progress, slot choice), `core/save_codec.gd` (pure encode, decode, migration, `.bak` fallback, never throws), `core/save_slots.gd` (slot list).
- **Format.** JSON with a `version` field. Slot 1 is `user://save.json`. Each slot keeps a `.bak` copy of the previous save. A missing or corrupt save falls back to the backup, then to a new game.
- **Timing.** Autosave every `autosave_seconds` (30 s in `content/config/game.tres`), plus zone change, rebirth or reset, and quit. `Save` writes nothing on the title screen.
- **Signals.** `game_loaded`, `game_saved`, `save_failed`, `offline_gained`.
- **Gotchas.**
  - The `Save` autoload and `save_codec.gd` both write files. Add migrations to `SaveCodec` (one branch per version), not to call sites.
  - Benchmarks set `Save` to not write, so `tools/bench.gd` never overwrites a player save. Keep that switch when you add a new tool that writes saves.
  - [SPEC.md](SPEC.md) still describes one save file. Slots exist now, and slot 1 is the original file.

### 3. Zones, scenes and streaming

- **Purpose.** Each zone has a scene, a walk mask, a palette and a set of areas and pads. Zone changes swap the scene under a transition and warm the next scene's textures before the swap.
- **Zone data.** `content/zones/zone1.tres` (Starting Clearing, meadow palette, no own scene, so it uses the default `MEADOW_PATH`), `content/zones/larkmoor.tres` (`world/larkmoor_scene.tscn`, meadow palette, walk mask in `assets/art/zone1b/larkmoor/`), `content/zones/zone2.tres` (`world/quarry_scene.tscn`, `ember_quarry` palette, walk mask in `assets/art/zone2/quarry/`). Areas are in `content/areas/`, resets in `content/resets/`.
- **Key files.** `main.gd` (`_swap_zone_scene`, `_zone_scene_path`, `_prefetch_scene`, `_take_prefetched`, `_build_entry_occluders`, `_on_zone_entered`). `world/zone_assets.gd` (`ZoneAssets`: static cache, worker-thread prefetch of prop textures during the wipe). `world/walk_mask.gd`. `world/meadow3d_scene.gd`, `world/larkmoor_scene.gd`, `world/quarry_scene.gd`, `world/gate.gd`, `world/ember_entrance.gd`. `boot/scene_swap.gd` (captures the old frame, swaps the next scene underneath the cover).
- **ZoneAssets API.** `prefetch_scene`, `prefetch`, `take`, `texture`, `ready`, `release`, `backdrop_image`, `paths_for_manifest`.
- **Signals.** `zone_entered`, `gate_opened`, `onboarding_complete`.
- **Gotchas.**
  - Node ceiling: a zone must stay at or under **1350** nodes. CI enforces it in the `play` job (`tools/check_frame_budget.py`, `.github/workflows/ci.yml`). Larkmoor was about 1205 headless at the last measurement ([perf.md](perf.md)). Build long lists lazily, and batch decor into one node (MultiMesh, custom draw, or a RenderingServer canvas item as `world/farm/farm_wheat.gd` does).
  - `Image.load_from_file` on a `res://` path fails in exported builds. `world/sky_cycle.gd` (`padded`) uses it as a fallback when a texture has no pixels yet, and it then warns and leaves the sprite unpadded. Use `ZoneAssets.texture` or `ZoneAssets.backdrop_image` for anything that must work in an export.
  - Loading a zone's textures on the main thread during the swap causes the stall that `ZoneAssets` was written to remove. Prefetch first.

### 4. Pads, gardens and the walker

- **Purpose.** The pressable pads on the baked art, the flower gardens around each statistic's row, the walker and its pose, and what the walker carries.
- **Key files.** `world/texel_pad.gd` (`TexelPad`: pad press logic and live ring, drawn on the baked art). `world/garden_layer.gd` and `world/garden_art.gd` (flower gardens from `world/larkmoor_gardens.json`, generated by `tools/art/gen_gardens.py`). `world/flower_glow.gd` (night glow per field). `world/texel_walker.gd` (movement entry point), `world/walker_motion.gd` (sprint, jump, crouch, slide; pure), `world/walker_body.gd` and `world/walker_pose.gd` (drawing), `world/walker_relics.gd` (equipped relic motes). `render/world_camera.gd` (2D camera for the baked world, integer zoom). `world/farm/farm_wheat.gd`, `world/farm/wheat_clump.gd` and `world/farm/farm_props.gd` (farm wheat as canvas items).
- **Entry points.** `TexelPad` reads the walker's position and calls `GameState.try_press`. `Hud` and `PadTooltip` read the pad's cost and reward. `main.gd` builds pads in `_build_pads`.
- **Gotchas.**
  - Pads and gates read `TexelWalker.position`. A jump only changes `lift`, so the ground position stays put.
  - Gardens are drawn by one node (`GardenLayer`). Do not give each flower its own node.
  - Pad signs: the detailed sign goes only on each row's first pad (`_1`), and later pads show their price in the tooltip. See `tests/test_pad_signs.gd`.

### 5. Lighting, weather and shaders

- **Purpose.** The day and night cycle, cast shadows, rain, wind, the season mix, the edge shade, and the Ember Quarry's own light.
- **Key files.** `world/sky_cycle.gd` (`SkyCycle`: the day and night overlay, wind, sway, feeds the sun to shadows and the season mix). `core/sky_model.gd` (time of day as pure functions of session time). `core/season_look.gd` (season values blended by weight). `world/sky_shadows.gd` (soft oval cast shadows). `world/sky_rain.gd`. `world/season_particles.gd`. `world/screen_light.gd` (vignette, a child of the main Control above the world and below the HUD). `world/quarry_light.gd` and `world/lava_flow.gd` (Ember Quarry glow and lava). `world/water_night_glow.gd`, `world/lava_flow.gd`, `world/heat_vents.gd`. `render/shader_warm.gd` (draws every world shader once at start so the first real draw doesn't stall).
- **Shaders** (`render/shaders/`): `day_night`, `ground_light`, `cast_shadow`, `ground_fog`, `sky_haze`, `light_grade`, `god_rays`, `heat_shimmer`, `pad_shadow`, `post_dither`, `quarry_glow`, `quarry_haze`, `quarry_prop`, `toon`, `vignette`, `water_night`, `wind_sway`, `cross_wipe`, plus `prop_ramps.gdshaderinc` and `season.gdshaderinc`. Grass is `world/grass_blades.gdshader`.
- **Layering.** `SkyCycle` puts the shade overlay at z 5, above the walker and pads, and below `LifeAir` (z 10), so fireflies and lantern glow stay bright at night.
- **Gotchas.**
  - The Ember Quarry is lit by lava and stays bright at every hour. It has no day and night cycle.
  - A new shader needs a committed `.uid` (the `uid-guard` job). In shader code, declare functions before use, and do not put `return` in `fragment()` or `vertex()`.
  - Cast shadows have a strength per object: trees are large and strong, flowers and bushes are faint, as the taste notes ask.

### 6. Life, props and farms

- **Purpose.** Ambient life: butterflies, critters, fireflies, wild animals, embers, ground reactions, and the wheat and flowers that react to the walker.
- **Key files.** `world/life_air.gd`, `world/life_ground.gd`, `world/life_critters.gd`, `world/life_butterflies.gd`, `world/life_embers.gd`, `world/life_react.gd`, `world/life_wild.gd` (wildlife; `LifeCritters` owns it and draws it from `LifeAir`'s `_draw`), `world/meadow_life.gd` and `world/meadow_life.json`, `world/larkmoor_life.json`. `world/cozy/` (cozy props, brook, swarm fireflies, wheat clumps, animator, layout). `world/grass_blades.gd` (grass shader driven by walker and critters). `world/meadow_sites.gd` (surfaces and water distance for sound).
- **Gotchas.**
  - `LifeAir` is z 10. Life that should sit under the walker needs a lower z, not a new layer.
  - Under Reduce Motion the drift stops but the blinks stay (`world/cozy/cozy_swarm.gd`). Check that flag in every new life system.

### 7. Render pipeline and camera

- **Key files.** `render/pixel_viewport.gd` (the 640x360 texel SubViewport, integer scale, the post ColorRect that transitions drive), `render/iso_camera.gd` (fixed isometric camera, 1 unit = 16 texels), `render/world_camera.gd` (2D world camera), `render/palettes.gd` (8-colour palettes; index roles are the same in every zone), `render/graphics_quality.gd` (Low, Medium and High, which change density and rates but never colours), `render/toon_material.gd` (builders for the shared toon material), `render/perf_stats.gd`, `render/fx_driver.gd` (Fx: global time, wind, shimmer, press ripples, palette targets; UI Transitions tweens its own `shift`, `invert` and `ascii`).
- **Gotchas.**
  - Palette and dither changes go through `Palettes` and `post_dither`. Do not add colour to a prop's material by hand.
  - `Fx` owns gameplay uniforms. Presentation scripts set the uniforms of the material they own.

### 8. HUD, menus and tooltips

- **Purpose.** The stat strip, the hamburger gallery and its sections, zone panel, tooltips, banners, the settings menus and window chrome.
- **Key files.** `ui/hud.gd` (about 1800 lines, reads the Sim at 10 Hz). `ui/hud_gain_label.gd`, `ui/hud_gain_tally.gd`, `ui/pad_tooltip.gd`. `ui/menu_router.gd` (`MenuRouter`: the only place that decides which menu is open). `ui/gallery_menu.gd` (the hamburger, also the Esc menu). `ui/index_panel.gd` (Stats and Attributes), `ui/upgrade_card.gd`, `ui/relic_panel.gd`, `ui/ledger_panel.gd` (Achievements), `ui/zone_panel.gd`, `ui/history_panel.gd`, `ui/update_log_panel.gd`, `ui/display_settings.gd`, `ui/window_frame.gd`, `ui/dev_console.gd`, `ui/modal_card.gd`, `ui/feedback_panel.gd`. Tooltips: `ui/tip.gd`, `ui/tip_host.gd` (the one tooltip panel), `ui/tip_text.gd`, `ui/tip_card.gd`. Banners: `ui/banner.gd` (autoload `Banner`), `core/banner_queue.gd`, `ui/subtitle_bar.gd`.
- **Entry points.** `Hud` calls the `GameState` API. Menus open through `MenuRouter`, and the hamburger routes through it too.
- **Gotchas.**
  - The hamburger tile is called **Achievements**. The file and the menu id are still `ledger` (`ui/gallery_menu.gd`, `ui/ledger_panel.gd`). A test asserts the label, so keep the label and not the file name in player-facing text.
  - Shared tooltips are `Tip` and `TipHost`. Never hand-roll one.
  - Toasts, banners and tips wait on `FxConfig.bloom_running` while a ritual plays.
  - UI is never affected by world lighting or weather. It sits above `ScreenLight`.
  - `ui/hud.gd` has the most commits of any UI file. Keep changes small and say in the PR which HUD section you touched.

### 9. Juice, transitions and popups

- **Key files.** `ui/fx/fx_bus.gd` (autoload `Juice`, the one entry point gameplay calls: `Juice.press`, `Juice.milestone`, `Juice.zone_enter`). `ui/fx/press_popups.gd` (one pooled node for every press popup). `ui/fx/popup_number.gd`, `ui/fx/fx_config.gd` (all Juice constants, tuned here only), `ui/fx/transitions.gd` (ColorRect shader tweens: `shift`, `invert`, `ascii`, plus cross wipe), `ui/fx/walk_marker.gd`.
- **Gotchas.**
  - Popups draw from one node and do not allocate per press. Keep it that way.
  - Respect Reduce Motion and Reduce Flashing in every new effect (`FxConfig` and `GraphicsQuality`).

### 10. Boot, title and loading

- **Key files.** `boot/boot.tscn` (the main scene), `boot/boot_screen.gd` (boot scene, rotating tips, progress bar), `boot/boot_loader.gd` (threaded `ResourceLoader` tasks with weights), `boot/boot_progress_bar.gd`, `boot/title_screen.gd`, `boot/title_background.gd` and `title_scenery.gd`, `core/title_mood.gd` (time of day for the title, the same sun arc as the meadow), `boot/slot_panel.gd`, `boot/credits_panel.gd`, `boot/version_link.gd`, `boot/scene_swap.gd`.
- **Flow.** Boot scene, then title, then game through `SceneSwap`. Boot hands over once loading is done and the minimum time has passed.
- **Gotchas.** The title's time of day must come from `TitleMood`, not a copy of the palette. Pre-game screens fill any window. The game keeps its letterbox.

### 11. Audio

- **Key files.** `audio/audio.gd` (autoload `Audio`: buses, volumes, pitch variation, music and ambience per zone, subtitles). `audio/ambient_scape.gd` (crickets, rain, water and tree beds), `core/ambient_mix.gd` (pure mix rules), `world/meadow_sites.gd` (surface lookups for footsteps).
- **Entry points.** `Audio.pad_press`, `Audio.relic`, `Audio.footstep(surface)`, `Audio.set_surroundings(water, trees)`, `Audio.ui(id)`, `Audio.start_loading` and `stop_loading`.
- **Gotchas.** Gameplay never plays a sound directly. It emits a signal or calls `Juice`, and `Audio` decides. Ambient loops should stay subtle and repetitive, per the project's taste notes.

### 12. Tests, sims and tools

- **Tests.** `tests/run.gd` runs every `tests/test_*.gd` suite. Each suite must be listed in `run.gd`. As of this map, all 87 suites are listed. Run `godot --headless --path . --import` once on a fresh checkout, then `godot --headless --path . --script tests/run.gd`. Exit code 0 is a pass. `tests/test_bump_version.py` is a Python test that `run.gd` does not run.
- **Balance sims.** `tools/sim.gd` (greedy pacing sim over `content/config/sim_profiles.tres`, prints median minutes to each tier and gate). `tools/sim_bloom.gd`. `docs/balance-sim-active.py`.
- **Playtest.** `tools/first_hour_playtest.gd` already plays a scripted first hour: starts a fresh game, presses the best affordable pad, opens the gate, walks into Larkmoor, saves a PNG at each milestone. Use it before writing a new one.
- **Benchmarks and captures.** `tools/bench.gd` (frame times per quality level, writes `shots/bench.json`), `tools/check_frame_budget.py` (fails on a frame over budget or over the node ceiling), `tools/memory_probe.gd`, `tools/loading_probe.gd`, `tools/qa_probe.gd`, `tools/route_probe.gd`, plus screenshot capture scenes (`tools/*_shots.tscn`, `tools/play_shots.tscn`, `tools/hud_shot.tscn`).
- **Art generators.** `tools/art/gen_*.py` produce the baked art, the placements JSON and the gardens. Re-run the generator rather than editing its output by hand.

### 13. CI and release

- **Jobs** (`.github/workflows/ci.yml`): `changes` (decides which engine jobs run; docs, changelog and markdown PRs skip them), `unit`, `sim`, `play` (screenshots and the frame budget), `changelog-guard`, `uid-guard`, and `test` (the required check). `build.yml` and `release.yml` build and stamp versions. `stuck-pr-watch.yml` flags stalled PRs. `token-expiry-reminder.yml` reminds about the release token.
- **Rules.** A game-folder PR needs a `changelog.d/<slug>.patch.md` or `.minor.md` fragment, or the `no-changelog` label. Never edit `CHANGELOG.md`, `core/build_info.gd` or `export_presets.cfg`. Commit a `.uid` for every new `.gd` and `.gdshader`. Details in [ci.md](ci.md) and [versioning.md](versioning.md).

## Hot shared files

These files had the most commits in the last 300 commits on `main`. Two threads touching one of them is the usual source of conflicts. Name the owner in the brief, and tell the other thread.

| Commits | File | Area | Why it is hot |
| --- | --- | --- | --- |
| 5 | `main.gd` | Integrator | Wires every system. Only the main session edits it per CLAUDE.md. Keep new logic in the owning system. |
| 5 | `docs/perf.md` | Docs | Every perf pass appends a section. Append at the bottom. |
| 4 | `world/zone_assets.gd` | Zones | Streaming and prefetch. |
| 4 | `world/texel_pad.gd` | Pads | Press logic and ring. |
| 4 | `world/sky_cycle.gd` | Lighting | Day, night, wind, season feed. |
| 4 | `world/garden_art.gd` | Gardens | Flower sprites. |
| 4 | `docs/decisions/hud.md` | Docs | HUD decisions. Keep both sides on merge. |
| 4 | `boot/boot_screen.gd` | Boot | Loading and hand-over. |
| 3 | `ui/hud.gd` | HUD | About 1800 lines, reads the Sim at 10 Hz. |
| 3 | `ui/index_panel.gd`, `ui/tip_text.gd` | UI | Stat and attribute rows and tooltip text. |
| 3 | `render/shaders/day_night.gdshader`, `ground_light.gdshader` | Lighting | Shared by every outdoor scene. |
| 3 | `world/walk_mask.gd` | Walker | Walkable areas. |

## Stale doc lines and drift

Found while writing this map. Status says what this PR did.

| Where | What is stale | Status |
| --- | --- | --- |
| [SPEC.md](SPEC.md) section 5, folder layout | Lists `world/player.gd`, `world/button_pad.gd` and `render/palettes/`. The files are `texel_walker.gd`, `texel_pad.gd` and `palettes.gd`. | Fixed in this PR. |
| [SPEC.md](SPEC.md) section 5, autoloads table | Missing `Banner` (`ui/banner.gd`). | Fixed in this PR. |
| [SPEC.md](SPEC.md) section 7, workstreams | Names `src/` folders. The repo is flat. Stream ownership is section 7, not section 5 as CLAUDE.md says. | Pointer added in this PR. |
| [pitfalls.md](pitfalls.md) | No entry for `Image.load_from_file` on `res://`. | Added in this PR. |
| [interfaces.md](interfaces.md) | EventBus list is missing `reset_done` and `achievement_unlocked`. Autoload table is missing `Banner`. | **Not edited.** Only the main session edits this file (CLAUDE.md). Flagged to the coordinator. |
| CLAUDE.md | Says "section 5 is stream ownership". It is section 7. | **Not edited.** Main session only. Flagged to the coordinator. |
| `core/event_bus.gd` header | Points to `godot/README.md`, which does not exist. | **Not edited.** This PR is docs-only. Fix in a code PR. |
| `ui/ledger_panel.gd` header and file name | Says "The Ledger". The label is Achievements. | Noted here. Rename is a code change and not in this PR. |
| `core/game_state.gd` | `try_rebirth` and `rebirth_done` still exist, though design notes say Rebirth is removed. | Noted here. Check with the owner before removing. |

## Quick rules for a new task

1. Read [pitfalls.md](pitfalls.md), then the one [decisions](decisions/README.md) topic file that matches.
2. Find the system above. Stay in its folders. If the change crosses into another system, send the signal through EventBus or ask the owner.
3. If you touch a hot file, say so in the PR and check the table above for the other thread.
4. Keep new balance in `content/`, new stats in `BigNum`, and new zone nodes under 1350.
