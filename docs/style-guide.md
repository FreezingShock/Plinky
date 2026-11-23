# Plinky surface style guide (zone 1 meadow)

Scope: how surfaces look. Lighting and atmosphere have their own thread; this guide covers materials, dither use and edges. Values live in `tools/art/gen_meadow3d.py` (RAMP table and material rules). Regenerate with `python3 tools/art/gen_meadow3d.py`, copy outputs into `assets/art/zone1/meadow3d/`, then rerun `tools/art/gen_life_anchors.py` (see decisions.md).

## Rules
1. **Warm vs cool by light.** Anything in shade drops to the cool greens (palette 1 and 2). Warm earth (palette 6) and accent (5) appear only where light hits. A shaded face must never be orange.
2. **Rock ramps are long and mostly cool**: shadow 1, 2, 2, then 6, 6, 6, then a single 5 highlight. Palette 5 on rock is a rare sparkle, not a fill, because stippled 5 on 6 reads as noise at 640x360.
3. **Hillsides wear moss.** Low and mid rock (height under 30, slope under 1.7) is moss (ramp 1, 2, 2, 3, 3). Bare earth only on ridges and steep faces. Moss is not walkable.
4. **Strata stay subtle** (0.04 light offset). Strong strata plus Bayer dither makes tiger stripes.
5. **Water is rows, not speckle.** Dither the depth gradient, then add long swell rows (every 6th row, 14 texels wide noise) in the next index up or down, plus short glints. Never single isolated bright pixels on a flat fill.
6. **One outline**: palette 0 between different objects. No outline between ground texels.
7. **Dither**: 4x4 Bayer only, pinned to world. Transition bands are 0.4 of a step wide so bands stay readable.

## Open taste questions
- Sky and horizon are still a flat teal fill (atmosphere thread).
- Distant mountains still read as blocky silhouettes on the right edge.
