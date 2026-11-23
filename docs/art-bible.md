# Plinky art bible (v1)

Status: working draft from the look board, 22 Nov 2026. Nathan approves the look at the M1 gate. Values here are the starting point for the debug overlay sliders in SPEC section 4.

Look board (rendered mockups): `art/look-board.html` and `art/mockups/`.

## 1. Look in one line
Real 3D at 640x360, shown as hand-made pixel art: dithered light bands, one ink outline, palette-index colour, and ASCII box-drawing for the HUD.

## 2. Pipeline values
- Internal resolution: 640x360. SubViewport 642x362 (one spare texel per edge).
- Display: whole-number scale, nearest filtering, letterboxed.
- Camera: orthographic, 30 degrees down, 45 degrees yaw, fixed. One world unit = 16 texels.
- Iso tile: 32x16 texels (2:1). Zone: 12x12 tiles in view. Diorama plinth: 10 texels deep.
- Dither: 4x4 Bayer. Threshold for index i is (BAYER[i] + 0.5) / 16.
  Bayer 4x4: 0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5.
- Light bands: 3 (lit, mid, shadow). Band edges are dithered, not hard.
- Outline: palette index 0. Drawn on an object or plinth texel whose 4-neighbour has a different object ID, or is empty. Ground-to-ground edges get no outline.
- Shadows: ellipse 9 x 4 texels under each object. Dithered at threshold 0.6 and drops one band.
- Pixel snapping: camera snapped to whole texels in camera space every frame. The leftover fraction is applied as a UI-image offset. This is the hardest part and is tested first (M1).

## 3. Palettes
Each palette is 8 colours in a 1x8 texture. Index roles are the same in every zone, so index 4 is always "light". Index 0 is always the outline ink. Index 7 is always paper, used for text and the walker's face.

Roles: 0 ink/outline, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper/UI.

| Palette | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Zone 1 Meadow Tally | #14161c | #1f3b35 | #2f6b55 | #5fa36a | #b7d978 | #f2e6a0 | #c2784e | #f6efd9 |
| Zone 2 Ember Quarry | #1a1116 | #4a1f2a | #8a3a2e | #d0602f | #e9a845 | #b77a7a | #5b3d5c | #f1d9b5 |
| Zone 3 Tidewater (reserved) | #0d1420 | #13324a | #1f6378 | #46a3a0 | #9fd4b5 | #f7d37a | #e67e6b | #dfeee8 |
| Rebirth Prestige Iris | #0c0a14 | #2a1d4a | #5d3f9c | #a68be0 | #f5d46b | #f7f3ea | #bfe6ef | #f0a9c2 |

Palette shift on zone entry: blend the two palette textures over 1.5 seconds (SPEC section 4).

## 4. Shader and effect values
| Effect | Value |
|---|---|
| Shimmer | Noise shifts the dither threshold, stepped at 10 fps. Always on. |
| Press ripple | Two ground-plane rings from the press. Radius 30 texels (width 2.2) and 52 texels (width 1.6). Lightens one band where Bayer > 0.4. Max 8 at once. |
| Wind | Vertex sway by height on tagged meshes. |
| Palette shift | 1.5 seconds, entering a zone. |
| Milestone flash | Palette index reversed (7 - i), 3 frames, then a wide ripple. Gate opens and rebirth. Off when reduce-flashing is on (M4). |
| Button press | Pad sinks 2 texels, 40 ms freeze, 6 to 12 square particles (1 to 2 texels, palette 5 or 6), number popup. |
| Idle life | Small props bob or blink on offset timers. |
| Rebirth redraw | ASCII cells, 8 x 8 texels per cell, luminance ramp " .:-=+*#%@". Stretch goal in M4. |

## 5. HUD rules
- Drawn in the same 640x360 space as the world, so UI texels match world texels.
- Font: monospace bitmap, 8 to 9 texels tall. Licence must be recorded in `assets/fonts/LICENSE.txt` before use. This draft did not verify any font licence. Candidates to check: Spleen, Tamzen.
- Frames: box-drawing ┌ ─ ┐ │ └ ┘. Double lines ═ ║ only for the rebirth summary.
- Bars: ▓ filled, ░ empty, 8 to 16 cells. Progress uses palette 3 or 4. Timers use palette 6.
- Number format: full digits to 999, then K, M, B, T, then scientific notation (1.23e15). Right-aligned.
- Labels above pads: two lines, cost then reward. Affordable: palette 5. Unaffordable: palette 6 dimmed.
- Popups: palette 5, bold, rise and fade over about 0.8 seconds.

## 6. Character
- Hooded walker (v3, redrawn 2026-11-23), about 17 x 30 texels. Index 0 outline, 6 terracotta cloak with 5 highlight and 1 shadow, 1-3 dark scarf, 5/7 face. Colour comes from palette indices, so it changes with the zone. Atlas has 20 poses (walk, crouch, slide, jump rise and fall); squash, stretch and lean are procedural, drawn a texel row at a time so nothing leaves the grid. No baked ground shadow: SkyShadows casts it and shrinks it in a jump. Generator: tools/art/gen_walker.py.
- Rows (k = ink, p = paper, b = butter):
```
..kkk..
.kpppk.
.kpkpk.
.kpppk.
..kkk..
.kbbbk.
kbbbbbk
kbbbbbk
kkkkkkk
.kk.kk.
```
- Nathan has not yet confirmed the character concept (SPEC open question). Keep it swappable: the character is a resource, not hard-coded.

## 7. Models
- Blender, `.glb`, flat vertex colours, hard edges. 50 to 300 triangles per prop.
- Until real models exist, primitives. Props are palette-index shapes in the look board, which is the reference for silhouettes.
- Reference silhouettes: round canopy tree on a 2-texel trunk, rock as a lit blob, pad as a 26 x 13 diamond with 3-texel sides, gate as a two-pillar arch with a dithered opening, shrine as a crystal on a 10-texel base, spire for zone 2.

## 8. Do not
- No image textures on world geometry.
- No anti-aliasing, reflections, or ambient occlusion.
- No copying of any existing game's assets, names, maps or number tables.
- Avoid names and looks that read as Plinko (game show and gambling genre).
