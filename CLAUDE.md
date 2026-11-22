# Plinky

Incremental button-presser in Godot 4.7, GDScript, Forward+. Fixed isometric
camera, 3D rendered at 640x360 with dither, palette, and outline post-process.
Full spec: docs/SPEC.md. Art values: docs/art-bible.md. Interfaces: docs/interfaces.md. Log: docs/decisions.md.

## Rules
- Read docs/SPEC.md and docs/art-bible.md before starting any milestone.
- Static typing everywhere.
- src/core/ never references nodes, scenes, or other src/ folders.
- Gameplay emits EventBus signals. Only Fx sets shader uniforms.
- No balance numbers in scripts. They live in content/*.tres.
- All stat values are BigNum, never float.
- No image textures on world geometry. Colour is vertex colour or palette index.
- Do not copy assets, names, or number tables from any existing game.
- Do not use the word "Plinko" in game text, store copy, or file names.

## After every change
1. godot --headless --script tests/run.gd
2. godot --path . tools/screenshot.tscn, then look at the PNG
3. Commit only when tests pass

## Parallel work
- Streams own folders as listed in SPEC section 7. Stay inside yours.
- Only the main session edits project.godot, the main scene, this file,
  and docs/interfaces.md.
- One branch and one worktree per stream.

## Working with Nathan
- Lead with the result, then the reasoning.
- Make reasonable calls and log them in docs/decisions.md.
- Stop and ask only at the M1 and M3 gates, or before anything hard to undo.
- Finished-product quality: no placeholders or stubs left in a merged milestone.
