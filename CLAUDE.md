# Plinky

Incremental button-presser in Godot 4.7, GDScript, Forward+. Fixed isometric
camera, 3D rendered at 640x360 with dither, palette, and outline post-process.
Full spec: docs/SPEC.md. Art values: docs/art-bible.md. Theme: docs/theme.md. Interfaces: docs/interfaces.md. Log: docs/decisions.md.
main is the source of truth. The design library (specs, art, longer docs) lives outside the repo in the project's shared files.

## Layout (flat, there is no src/)
core/ data/ world/ render/ ui/ ui/fx/ boot/ audio/ theme/ fonts/ content/ assets/ tests/ tools/ docs/ .github/workflows/
Autoloads (project.godot): EventBus, GameState, Calendar, Save, Fx (render/fx_driver.gd), Juice (ui/fx/fx_bus.gd), Audio.

Process: docs/workflow.md (cloud PR per task, one PC QA thread, QA findings routed by the coordinator).

## Rules
- Read docs/SPEC.md, docs/art-bible.md, docs/theme.md and docs/decisions.md before starting work.
- Static typing everywhere.
- Pure logic in core/ (sim, bignum, formulas, mastery, codecs) never references nodes, scenes, or render/, world/, ui/. The Node autoload shells in core/ (event_bus, game_state, save, calendar_service) are the only exceptions and stay thin.
- Gameplay emits EventBus signals and never sets shader uniforms. Fx owns gameplay-driven uniforms. Presentation scripts that own their own material (sky, shadows, screen light, toon material, pixel viewport, window frame, transitions, boot and title backgrounds) may set that material's uniforms.
- No balance numbers in scripts. They live in content/*.tres.
- All stat values are BigNum, never float. Format numbers only through core/number_format.gd.
- Theme: Pixelify Sans titles, Spleen 6x12 body, palette-indexed colour roles, 4x4 Bayer dither, nearest filtering, integer scale, no blur. Title Case for stat names and menu labels.
- No image textures on world geometry. Colour is vertex colour or palette index.
- Do not copy assets, names, or number tables from any existing game.
- Do not use the word "Plinko" in game text, store copy, or file names. No literal "Button" in player-facing text.

## Versioning
Every code PR adds a CHANGELOG.md line and bumps the version with `python3 tools/bump_version.py patch|minor` (small = patch, feature = minor). MAJOR only when Nathan asks. See docs/versioning.md.

## Git and CI
- Branch from main, open a PR, never push to main. CI (.github/workflows/ci.yml) runs the headless Godot tests and the sim on every PR; keep it green. Draft or conflicting PRs do not run CI: merge main in and mark ready.

## After every change
1. godot --headless --path . --script tests/run.gd (run `godot --headless --import` once on a fresh checkout)
2. godot --path . tools/play_shots.tscn (gameplay) or tools/hud_shot.tscn (HUD panel, `-- early|late`), then look at the PNG
3. Commit only when tests pass

## Parallel work
- Streams own the folders listed in SPEC section 5. Stay inside yours.
- Only the main session edits project.godot, the main scene, this file,
  and docs/interfaces.md.
- One branch and one worktree per stream.

## Working with Nathan
- Lead with the result, then the reasoning.
- Make reasonable calls and log them in docs/decisions.md.
- Stop and ask before anything hard to undo. Ask taste and recommendation questions with your own pick.
- Include screenshots in reports. If Godot cannot run (cloud sessions), say clearly what has not been run in-engine.
- Finished-product quality: no placeholders or stubs left in a merged milestone.
