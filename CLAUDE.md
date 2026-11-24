# Plinky

Godot 4.7 isometric incremental button-presser. GDScript, Forward+, fixed isometric camera. The 3D scene renders at 640x360, then goes through dither, palette and outline post-process.

Read only what your task touches. Grep the big docs rather than reading them whole.

## Repo map (flat, no src/)
- `core/` pure logic: sim, bignum, formulas, mastery, codecs, number_format. Never references nodes, scenes, or render/ world/ ui/. Only the autoload shells (event_bus, game_state, save, calendar_service) may be Nodes, and they stay thin.
- `data/` resource definitions. `content/` all balance numbers as .tres (no balance numbers in scripts). `content/parked/` is kept on purpose.
- `world/` zone scenes, pads, walker, gates. `render/` Fx driver, camera, pixel viewport, toon material, shaders. `ui/` HUD, menus, panels; `ui/fx/` Juice popups and transitions.
- `boot/`, `audio/`, `theme/`, `fonts/`, `assets/` (art and audio, binary).
- `tools/` capture scenes, sim, bench, art generators (`tools/art/`). `tests/` has `run.gd` and `test_*.gd`; every suite must be listed in `run.gd`.
- Autoloads (project.godot): EventBus, GameState, Calendar, Save, Fx (`render/fx_driver.gd`), Juice (`ui/fx/fx_bus.gd`), Audio.

## Docs (grep for the section you need)
- `docs/SPEC.md` system spec and section 5 stream ownership. `docs/interfaces.md` signals and APIs. `docs/art-bible.md` art values.
- `docs/decisions/README.md` decision log index. Read the index, then only the topic file you need (`docs/decisions/<topic>.md`: core, world, meadow, quarry, art, audio, hud, balance, ci-workflow). Never read every topic file.
- `docs/workflow.md` process. `docs/versioning.md` version rules. `docs/ci.md` jobs, ruleset and release.
- The design library (specs, art, longer docs) lives outside the repo at `/mnt/project-files/plinky/`. Its README is the index.

## Rules
- Static typing everywhere.
- Gameplay emits EventBus signals and never sets shader uniforms. Fx owns gameplay-driven uniforms. Presentation scripts that own their own material (sky, shadows, screen light, toon material, pixel viewport, window frame, transitions, boot and title backgrounds) may set that material's uniforms.
- All stat values are BigNum, never float. Format numbers only through `core/number_format.gd`.
- Theme: Pixelify Sans titles, Spleen 6x12 body, palette-indexed colour roles, 4x4 Bayer dither, nearest filtering, integer scale, no blur. Title Case for stat names and menu labels.
- No image textures on world geometry. Colour is vertex colour or palette index.
- Do not copy assets, names or number tables from any existing game.
- Do not use the word "Plinko" in game text, store copy or file names. No literal "Button" in player-facing text.

## Commands
- Tests: `godot --headless --path . --import` once on a fresh checkout, then `godot --headless --path . --script tests/run.gd`. Exit 0 means pass.
- Visual check: `godot --path . tools/play_shots.tscn` (gameplay) or `tools/hud_shot.tscn` (HUD panel, `-- early|late`). Look at the PNG.
- Godot does not run in cloud sessions. Say in the PR which checks were not run in-engine.

## Workflow (summary; details in docs/workflow.md)
- Branch from main, open a PR, never push to main, never bypass the ruleset.
- Every PR that touches game folders adds one `changelog.d/<slug>.patch.md` or `.minor.md` (small = patch, feature = minor). Do not edit the version or `CHANGELOG.md`. MAJOR only when Nathan asks.
- CI (`test` check, see docs/ci.md) must be green. Draft or conflicting PRs do not run CI: merge main in, mark ready, merge promptly.
- Parallel work: stay inside your stream's folders. Only the main session edits project.godot, the main scene, this file and docs/interfaces.md. Cross-area changes go through the coordinator.
- Log decisions by appending to the matching topic file in `docs/decisions/`, as `## <date>: <title>` with one line of reasoning. Find the topic in the index.

## Working with Nathan
- Lead with the result, then the reasoning.
- Make reasonable calls and log them. For taste questions, give your own recommended pick.
- Stop and ask before anything hard to undo.
- Include screenshots in reports. Say clearly what has not been run in-engine.
- Finished-product quality: no placeholders or stubs in a merged milestone.
