# Plinky

Godot 4.7 isometric incremental game. GDScript, Forward+, fixed isometric camera. 3D renders at 640x360, then dither, palette and outline post-process.

**Before your first change, read [docs/pitfalls.md](docs/pitfalls.md).** Then open only the docs your task touches. Grep big docs; don't read them whole.

## Repo map
- `core/` pure logic (sim, bignum, formulas, number_format). No nodes, scenes, or `render/` `world/` `ui/` references. Autoload shells may be Nodes and stay thin.
- `data/` resources, `content/` balance as `.tres` (no balance numbers in scripts). `content/parked/` is kept on purpose.
- `world/` zones, pads, walker. `render/` Fx, camera, shaders. `ui/` HUD and menus; `ui/fx/` Juice popups.
- `tools/` capture scenes, sims, bench, art generators. `tests/run.gd` plus `test_*.gd`; every suite must be listed in `run.gd`.
- Autoloads (`project.godot`): EventBus, GameState, Calendar, Save, Fx, Juice, Audio, Banner.

## Docs (open only what you need)
- `docs/pitfalls.md` mistakes to avoid. Read first.
- `docs/decisions/README.md` index. Then only the matching topic file (core, world, meadow, quarry, art, audio, hud, balance, ci-workflow). Log your decisions there.
- `docs/SPEC.md` system spec (section 5 is stream ownership). `docs/interfaces.md` signals and APIs. `docs/art-bible.md` art values.
- `docs/workflow.md` process. `docs/versioning.md` versions. `docs/ci.md` jobs, ruleset, red-check causes, release.
- Design library: `/mnt/project-files/plinky/` (README is the index).

## Rules
- Static typing everywhere.
- Gameplay emits EventBus signals and never sets shader uniforms. Fx owns gameplay uniforms. Presentation scripts that own their material may set it.
- Stats are BigNum, never float. Format numbers only through `core/number_format.gd`.
- Theme: Pixelify Sans titles, Spleen 6x12 body, palette-indexed colours (8 roles, each a 4-step hue-shifted ramp, art-bible s.3), 4x4 Bayer dither, nearest filtering, integer scale, no blur. Title Case for stat names and menu labels.
- No image textures on world geometry. Colour is vertex colour or palette index.
- Don't copy assets, names or number tables from other games.
- Never use "Plinko" in game text, store copy or file names. "Button" is fine anywhere, in game text too (Nathan, 2026-11-25).

## Commands
- Tests: `godot --headless --path . --import` once on a fresh checkout, then `godot --headless --path . --script tests/run.gd`. Exit 0 is a pass.
- Visual check: `godot --path . tools/play_shots.tscn`, or `tools/hud_shot.tscn` (`-- early|late`). Look at the PNG.
- Cloud sessions can't run Godot. Say in the PR which checks were not run in-engine.

## Workflow
- Branch from `main`. Open a PR. Never push to `main` or bypass the ruleset. Create PRs as drafts, then mark ready and enable auto-merge (squash).
- Game-folder changes need one `changelog.d/<slug>.patch.md` or `.minor.md` fragment. Never edit the version, `CHANGELOG.md`, `core/build_info.gd` or `export_presets.cfg`. MAJOR only when Nathan asks.
- `test` check must be green. Keep watching your PR until it merges. Fix red checks and conflicts yourself.
- New `.gd` and `.gdshader` files need a committed `.uid`.
- Stay inside your stream's folders. Only the main session edits `project.godot`, the main scene, this file and `docs/interfaces.md`. Cross-area changes go through the coordinator.

## Working with Nathan
- Lead with the result, then the reasoning.
- Make reasonable calls and log them. For taste questions, give your recommended pick.
- Stop and ask before anything hard to undo.
- Include screenshots in reports. Say what has not been run in-engine.
- No placeholders or stubs in a merged milestone.
