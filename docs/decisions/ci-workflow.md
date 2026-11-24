# Decisions: CI, release and process

CI jobs, release stamping, changelog rules, performance passes, docs and repo hygiene. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## Performance pass (22 Nov)
| 2026-11-22 | Target 60 fps at 1080p on integrated graphics (16.7 ms), judged by tools/bench.gd on real hardware | A fixed budget for the bigger meadow and the lighting, weather and day/night work. See docs/perf.md. |
| 2026-11-22 | Graphics quality Low / Medium / High lives in render/graphics_quality.gd and saves to user://graphics.cfg | Its own file so display settings saves never overwrite it. Same palettes and dither at every level; only ambient density and step rates change, so the look does not fork. |
| 2026-11-22 | PixelViewport renders the empty 3D viewport once, not every frame, until a 3D node is added | The meadow is baked 2D, so the 642x362 pass produced the same blank frame 60 times a second. No visual change. |
| 2026-11-22 | World life culls to the visible rect plus 24 texels | Keeps cost flat as the main meadow grows. Margin keeps edges from popping. |
| 2026-11-22 | F3 toggles a frame-time overlay (PerfOverlay, attached from main.gd) | Debug only, hidden by default, no cost while hidden. |

## 2026-11-23: Game version and changelog
- Version is MAJOR.MINOR.PATCH in `core/build_info.gd` (already existed at 0.1.0). MINOR = features, PATCH = fixes and tweaks, MAJOR only when Nathan asks. Rules in docs/versioning.md; CHANGELOG.md has history backfilled from #3-#95 grouped into 0.1.0 to 0.4.0, and this change is 0.5.0.
- Shown small on the boot screen. Nathan wants it less tucked away than a Settings row, so the Update Log tile in the bottom-bar hamburger gallery will show it via `BuildInfo.string()` and `BuildInfo.changelog()`. No Settings About row.
- Not run in-engine: boot label placement, CHANGELOG.md in the export (include_filter added).

## 2026-11-23 Docs and rules hygiene (docs only)
- **CLAUDE.md and SPEC.md describe the real flat layout** (`core/`, `world/`, ...; no `src/`). `docs/interfaces.md` now exists (autoloads, EventBus signals, rules) instead of being a missing reference.
- **Shader uniform rule amended, not refactored.** Gameplay never sets uniforms; `Fx` owns gameplay-driven ones; presentation scripts that own a material (sky, shadows, screen light, toon material, pixel viewport, window frame, transitions, boot and title backgrounds) set their own. Reason: about 60 sky calls would otherwise move into `Fx` for no gain.
- **`core/` wording:** pure logic is node-free; the Node autoload shells (event_bus, game_state, save, calendar_service) are the named exception.
- **Stale docs refreshed:** `docs/features.md` rewritten for v0.27.0; `docs/balance.md` marks sections 1 to 8 as v0 history and adds a pointer to the flower and quarry ladders; `docs/zone2-ladder.md` copied into the repo.

## 2026-11-23 Weak-hardware pass: Low really scales down (0.37.1)
- **Measured first.** A software Vulkan rasteriser (lavapipe) in the cloud stands in for a weak GPU (`tools/bench_weak.sh`). Before this change Low was no faster than High there (about 21.5 vs 20.9 ms).
- **Low now:** ground relight march 6 taps at double stride (same reach) and 2 occlusion taps; the light grade pass, the only shader that reads the screen texture, is skipped. Medium sits between on the march. High is the full look.
- **No-cost wins at every level:** the ground shader skips its shadow march when no cast shadow applies and its occlusion taps when `ao_amt` is 0 (identical output). ShaderWarm also compiles ground_light, ground_fog and light_grade at start, so the first Larkmoor frames do not compile them.
- **Look tradeoff on Low (taste call):** no sun-side lift or highlight and shadow split from the light grade, slightly coarser cast shadows. Palettes, dither and outlines are unchanged.
- **CI ceilings:** `check_frame_budget.py` now also fails above 250 draw calls and 1200 nodes (Larkmoor is 1065 headless; the old 700 in perf.md was stale).
- **Result:** Low is 10 to 13% faster than before on the stand-in, High unchanged. Short of the 25% budget; real iGPU numbers still wanted from the PC thread. Not run on a real GPU.

## 2026-11-23 CI split and version stamping after merge
PRs add a `changelog.d/<slug>.patch|minor.md` fragment instead of bumping `core/build_info.gd`, `export_presets.cfg` and CHANGELOG.md, so the version files never conflict. `.github/workflows/release.yml` folds fragments into a release commit on main (serialised, biggest bump wins). Chosen over a merge queue (adds waiting per merge and needs ruleset setup) and over version-in-CI-only (the in-game version must exist in the repo). CI: engine jobs `unit`, `sim`, `play` run in parallel with a cached Godot binary and `.godot/imported`; docs-only PRs skip them; the aggregate check keeps the name `test`. The Release bot pushes to main, so a main ruleset must let GitHub Actions bypass the pull-request and status-check rules. Not run in-engine: the workflow changes are validated by CI itself.

## 2026-11-23 Repo trim for faster, cheaper threads
- Removed 10 unreferenced GDScript files (`world/player.gd`, `world/button_pad.gd`, `ui/district_banner.gd`, `ui/fx/counter_tick.gd`, and six tool scripts with no scene, test or doc reference). Reasoning: each had zero references (class names and paths checked); git history keeps them.
- Removed tracked `__pycache__` bytecode and ignored it. Added `.claudeignore` (bulk art, audio, captures, CHANGELOG.md) and `.gitattributes` (binary art and audio, generated JSON).
- `CLAUDE.md` is now a short map that points at the docs. It no longer tells agents to read SPEC, decisions and theme whole. `docs/theme.md` is not in the repo (it lives in the library), so the reference is dropped.
- Kept on purpose: `tools/size_shots.gd` (the audit plans to extend it), `tools/screenshot.gd` (SPEC names it), the art generators in `tools/art/`, and `content/parked/`.

## Restored after the #220 split (lost text from the pre-split log)

## 2026-11-23 Node budget 1300 to 1350 (Larkmoor pads, Nathan's call)
- **Why:** the Larkmoor Dewdrop and Clover rows add 61 nodes (six pads with their anchors and holds, and six props from the regenerated layout). Main's Larkmoor is 1266, so the scene reached 1327 and CI's `play` frame budget failed.
- **Chosen by Nathan (decision card):** raise the active-zone node ceiling to 1350 rather than trimming props or optimising pads first. Set in `.github/workflows/ci.yml` (frame budget 150/300/250/1350), `docs/ci.md` and `docs/perf.md`.

## CI uid guard (2026-11-23)
- **Why:** PR #224 added six missing Godot `.uid` sidecars, and a scan of main then showed `tests/test_nucleus.gd` had none either. Nothing stopped the next one.
- **What:** a `uid-guard` job in `.github/workflows/ci.yml` fails when any tracked `.gd` or `.gdshader` has no `.uid` next to it on a clean checkout. It is part of the `test` aggregate.
- **Scenes not covered:** Godot 4 keeps a scene's uid in the `[gd_scene]` header, not in a sidecar. Ten of the twenty `.tscn` files have no header uid, which is valid, so a sidecar rule for scenes would fail main. Add a header check later only if Nathan wants one.
