# Decisions: Art, lighting and rendering

Lighting, night, day/night, dither, props, pads, grass, shaders, palettes and icons. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## Day/night and weather (23 Nov)
| 2026-11-23 | Day/night is a dithered multiply shade (render/shaders/day_night.gdshader) over the 2D meadow, not a smooth tint | The meadow is 2D art drawn straight to the screen, so the post dither does not touch it. A 4x4 Bayer mask in world texels picks which texels get the shade, so it stays pixel art and pins to the world when the camera moves. Tints are blue-grey (night), warm (sunrise, sunset), cool grey (rain). |
| 2026-11-23 | Shade sits at z 5, rain at z 11, LifeAir stays at z 10 | Fireflies, lantern and shrine glow stay bright at night. The HUD (z 100) is never shaded. |
| 2026-11-23 | One day is 12 minutes of session time, starting in the morning (phase 0.32). Not tied to the system clock and not saved | A slow loop the player can notice without waiting for it. No save format change. Tunable in content/config/sky.tres. |
| 2026-11-23 | Rain and wind are pure functions of time (core/sky_model.gd): two sine waves decide rain (about 16% of the time, episodes of 30 to 65 s, capped at 0.6), gusts ride over a steady breeze | Deterministic, testable headless, no state to save. Rain is light on purpose. |
| 2026-11-23 | Trees and bushes sway by whole-texel row shifts (render/shaders/wind_sway.gdshader), crown moves most, foot stays. Sprites get 4 transparent texels of padding each side so the lean is never clipped. Rocks and crystals stay still | Pixel-stepped lean at 8 fps matches the art. Padding is built once at load. |
| 2026-11-23 | LifeGround reads MeadowLife.wind, so grass tips lean further in a gust | Grass and trees move together. |
| 2026-11-23 | Reduce motion: rain streaks and tree sway stop, grass lean follows wind 0, the shade still turns | Matches the existing rule that travelling motion freezes. |



| 2026-11-23 | HUD stat counters roll (RollValue, BigNum ease, 30 Hz); gains of 15% or more float "+N Stat" beside the counter, except cash | Presses already pop their own number, so cash floats would double up. Whole-number stats roll in whole numbers. Tuned in FxConfig. |
| 2026-11-23 | Momentum meter (bar and +% bonus, above the bottom bar) behind a Settings toggle, on by default | Nathan has not decided on the meter. Toggle is saved in settings.cfg so he can judge it and turn it off. |
| 2026-11-23 | Test builds come from .github/workflows/build.yml (manual run or a v* tag), Windows and macOS, uploaded as artifacts and as a prerelease on tags | Nathan wants builds he can hand to friends. One Linux job exports both, so it needs no Windows or Mac runner. |
| 2026-11-23 | Windows exports a single exe (embedded pck, no console), with icon editing off | Easier to share. Icon editing needs rcedit, which CI does not have; the exe icon is Godot's until that is added. |
| 2026-11-23 | Builds are unsigned and unnotarized. docs/TESTING.md tells testers how to open them | Signing needs paid certificates and Apple credentials. Ask Nathan before buying any. |
| 2026-11-23 | Feedback form (F8, or Settings) saves notes to user://feedback.txt with a context line, and copies or opens the folder. No network | Nathan: no external service unless approved. Local file plus clipboard is enough for friends to paste notes back. |
| 2026-11-22 | GUI consistency pass: one AsciiBox.panel() frame (8x6 padding, theme.md section 5) for every panel, tooltip, toast and settings; rarity tints the border via edge_override. RelicStyle.panel_box removed | Panels used 8x6, 10x8 and a flat StyleBoxFlat. Spec says 8x6 and one notched dither frame. |
| 2026-11-22 | All panel titles use TitleLabel (Pixelify). Dim and secondary text uses RelicStyle.dim (palette 3), never modulate alpha. Disabled button text is dim | Relic panel title was body font in green, several labels used alpha 0.7 which breaks palette indexing. |
| 2026-11-22 | Tooltip line separation 2 on both tooltips (grid steps 2, 4, 8). Focus ring on PixelButton left to the controller-navigation thread | That thread owns focus states; avoids a conflict. |
| 2026-11-22 | Relic toast moved from y300 to y274 | Its taller title line made it cover the bottom-bar buttons (y334). |

## Lighting and atmosphere overhaul (23 Nov)
| Date | Decision | Why |
|---|---|---|
| 2026-11-23 | One sun for the whole scene, in `SkyModel`: azimuth (left at sunrise, overhead at noon, right at sunset; the moon rides the same arc), elevation, golden-hour factor, shadow length and strength. Weather is passed in as `rain01`, not read inside | Pure and testable; shadows, rim, rays, mist and particles all read the same sun. The baked backdrop is lit from the left, so sunrise matches it. |
| 2026-11-23 | Dynamic cast shadows (`world/sky_shadows.gd`, `cast_shadow.gdshader`): a soft oval per prop and for the walker, laid in ground space and squashed 2:1, as dither (density thins from foot to tip). Silhouette-projected shadows were tried first and came out as 1-texel slivers under a 2:1 view | Ovals read at any zoom and soften with the Bayer matrix. They add the moving part (dawn, dusk, moon, walker); the baked shadows stay. |
| 2026-11-23 | Light pools are done in the shade shader: inside a pool the night shade thins out and a warm tint comes in. Sources: shrine and any lantern in `meadow_life.json`, the gate, the pads, and a small pool that follows the walker. 24 pools max | Light clears the dark instead of being a sticker on top. One draw, no extra layers. |
| 2026-11-23 | Rim light lives in `wind_sway.gdshader` (one more material for rocks and crystals): a lit texel next to the dark outline on the sun side, warm at low sun, cool under the moon | Edge light on props makes them sit in the light. Same shader, no extra pass. |
| 2026-11-23 | Colour grade is four `Gradient` ramps in `sky.tres` (tint, density, haze colour, ray colour) sampled by time of day, applied as Bayer dither multiply | Hand-tunable per time of day without code. Replaces the single dusk tint. |
| 2026-11-23 | Haze over the far mountains (outside the island, by distance) and drifting mist over the sea and ponds (`sky_haze.gdshader`). Both are dithered texels with one fixed alpha. Mist is pulled toward grey so a sunset does not paint the water orange | Atmospheric perspective and depth without smooth gradients. |
| 2026-11-23 | God rays at sunrise and sunset (`god_rays.gdshader`): shafts from a sun point above the frame, added as dithered texels, off in rain | The golden-hour payoff. |
| 2026-11-23 | Vignette is a frame-fixed multiply layer (`world/screen_light.gd`) added by SkyCycle to the main Control at z 40: under the HUD, over the world. Strength in `sky.tres` | Does not touch main.gd; the pattern is pinned to screen texels. |
| 2026-11-23 | Particles follow the light: fireflies 2 by day, 12 at night, none in rain; pollen 14 by day, thin at night, up to 20 and paper-bright at golden hour; the pollen clock speeds up in a gust. `MeadowLife.night/low_sun/rain` are written by SkyCycle | Day and night feel different instead of one constant sprinkle. |
| 2026-11-23 | Reduce motion: no ray shimmer, no mist drift, steady pools, shadows still move with the sun (slow). Reduce flashing: pool flicker off. Nothing in the layer changes faster than 6 fps | Honours both settings. |
| 2026-11-23 | New tuning values (all in `content/config/sky.tres`) are look values, not balance. Not run on real hardware: GPU cost is 3 full-view ColorRects plus 37 small quads and one array uniform per frame | Review frame time on the PC. |
| 2026-11-23 | Meadow rock: cool shadow ramp, moss on low slopes, subtler strata; outer water gets swell rows. Rules in docs/style-guide.md | The cliffs were one big orange mass with tiger-stripe dither that fought the greens. Not run in Godot; art is regenerated from tools/art/gen_meadow3d.py. |

## 2026-11-23: Prop depth pass (baked)
- New shared `tools/art/depth_pass.py`, used by `gen_meadow3d.py` and `gen_larkmoor.py`. Screen-space pass on the z-buffer before the Bayer dither: contact/crevice AO (only props occlude, only things within ~13 units of height, so no seams at cliff lips or floating canopy outlines), a one-texel sun-side rim just inside the ink outline, and a small relief lift on raised surfaces. All three are light-band shifts, so palette and dither are unchanged.
- AO is computed from the full scene once and reused for the ground-only render, so ground.png carries contact shadows around prop bases while the sprites keep their own interior AO.
- Flowers are rebuilt as layers: stem, two leaf blades, cupped outer petal ring, raised inner ring in a second tint, centre. `--no-depth` reproduces the old render exactly (checked byte for byte on the meadow ground).
- Not done: runtime normal maps and parallax. Godot can't run in the cloud, so engine-side work waits for a PC check; the baked pass is deterministic and was verified from the PNGs. The mountain backdrop is left to the art-style thread.
| 2026-11-23 | ShaderWarm draws every world shader on screen for 4 frames at start (render/shader_warm.gd, called from main.gd) | The 4-frame warm inside SkyCycle did not stop the 166 ms Larkmoor sunset hitch on Low. Likely cause: those draws were off-screen or culled during the zone transition, and a draw that is not on screen compiles nothing. Low only hitches because it runs first in Larkmoor, so it is the first to reach that state. |
| 2026-11-23 | Haze shader runs its two noise lookups only where mist can show (water, ponds, outside the island) | Haze was the biggest single layer at noon on High (0.75 to 0.52 ms with it hidden). Same output pixel for pixel; the branch only skips work where mist is 0. On a software rasterizer (llvmpipe) the layer went from about 2.5 ms to 0.9 ms. Not measured on a GPU yet. |
| 2026-11-23 | Larkmoor gets the same lighting wiring as the meadow: SkyShadows with a caster per prop and landmark (kinds for tower, windmill, lighthouse, obelisk, menhir, lantern, sign, gateway, spire, lintel, gate pillar), rim material, light pools for the gate, arch, pads, lanterns and walker, rays sized to its world. Haze and mist are off there (placed for the meadow). Light pools raised from 12 to 24. Shadow colour deepens at low sun so it stays readable on the darker dusk ground | Larkmoor had a sky but no casters, so it showed no shadows. Test: tests/test_larkmoor.gd checks every prop registers a shadow and lanterns light. |
| 2026-11-23 | Larkmoor atmosphere: haze over the whole mountain strip along the top (no island in front, so full strength at every x), mist over the sea band beneath and over Heronmere lake and the pond. SkyCycle takes `haze_rects` and `haze_params`, so the shader is drawn only on the strip plus a rect per pond (about a fifth of the world, less than the meadow's single rect) | Cheap: haze was the costliest layer. Mountain placement will need a re-check when the art thread reworks the backdrop (horizon_y 92 in `larkmoor_scene.gd`). |
| 2026-11-23 | bench.gd fails (exit 1) on any script or shader error in the engine log, and CI runs it as "Play smoke" | A per-frame error in SkyCycle made the meadow bench look faster (the layer stopped drawing) and nothing failed. The boot smoke only runs a couple of seconds and is not gating. |
| 2026-11-23 | bench.gd prints a HITCH line for any frame over 40 ms, with its place in the phase and the engine counters | The Larkmoor first-row stall (166 to 237 ms) does not reproduce under software GL and ShaderWarm did not remove it, so it is not a shader compile of the shared shaders. The next PC run will say when it falls and whether nodes, objects or VRAM jumped with it. |

## 2026-11-23: Runtime prop relight
- Tall-prop sprites (trees, bushes, rocks, crystals) ship a `_n.png` beside them: world normal (R,G), material code (B), baked light (A). `wind_sway.gdshader` moves each texel's light by the change in N.L between the baked sun and the live sun (`SkyCycle` az and sun height), re-picks the colour from the material's ramp with Bayer dither (`render/shaders/prop_ramps.gdshaderinc`, generated), and keeps the baked texel while the change is under 0.03. Rim light and sway use the same shader, so there is no extra pass.
- `SkyCycle.prop_material()` gives each sprite its own ShaderMaterial (only the normal texture differs). Parameters are pushed only when quantised sun, rim or sway-step values change, not every frame.
- Flowers are 1.45x bigger and kept 7.5 units off the path. Depth pass treats flower and grass texels as occluders even though they share the terrain id.
- Fixed `var rects: Array[Rect2] = ... else [AREA]` in `sky_cycle.gd` (typed-array ternary aborted `_ready`, so `_shade_mat` was null and every frame logged an error). Same fix the lighting thread is making.
- Verified: headless tests, and real frames at dawn, morning, noon, golden hour, dusk and midnight under lavapipe. Not measured: GPU cost (software renderer), so `tools/bench.gd` numbers still need the PC.

## 2026-11-23: meadow sky hotfix, boot smoke test now gates
`SkyCycle` assigned an untyped array to `Array[Rect2]` (PR #60), which broke the meadow's sky on main. Larkmoor was fine, and no test loaded the meadow scene. Fixed with `.assign()`, added `run_meadow` in `test_lighting.gd` (fails with the exact engine error without the fix), and removed `continue-on-error` from the CI boot smoke test.
| 2026-11-23 | Audio.preload_all() loads every sfx and amb stream at start; bench HITCH lines say whether the audio cache grew | The Larkmoor Low stall falls at an unpredictable frame on a still scene with flat counters, which matches a random first use, and bird chirps are on a random timer with five lazily loaded variants. A guess, labelled as one in docs/perf.md; the next bench confirms or rules it out. |

## 2026-11-23: Stronger prop depth
- Baked light contrast raised (`.04 + 1.05 * N.L`, shader gain matches), foliage height gradient x3, AO .42 to .62 with a wider 8 texel ring so crown clusters separate, rim .30 to .55, relief .10 to .18. Crown layering comes from AO between overlapping leaf balls plus the height gradient, not a separate draw order (the balls are one sprite).
| 2026-11-23 | Larkmoor Low stall left open and documented (docs/perf.md), audio ruled out | The bench on aa46bae still shows one 271 ms frame at frame 230 of the first Larkmoor row on Low, audio cache unchanged, counters flat, steady from run to run. Not worth more guesses without a profiler capture; one frame once per session on the lowest setting is minor. |

## 2026-11-23 Pad plates and press feel
- The old pad was only a 1px outline (the meadow art bakes no pads by design; TexelPad drew the ring). Not a render glitch.
- Pads are now a raised plate drawn live in palette indices: ink outline, earth side faces (lit left, shadow right), dithered lit rim, glow inlay.
- Three states, because pads have no hard lock: Far (<10% of cost: stone, empty inlay), Close (gauge fills bottom-up with progress), Ready (inlay in the multiplier glow colour, one-step pulse, none under reduce flashing).
- Press = whole-texel sink (2), ripple ring, particles in the zone palette, existing number pop and sound. The pad animates itself via TexelPad.punch(), so spam-pressing restarts one timer instead of stacking tweens. Particle bursts are capped at 10 live.
- Colour-blind cue: ink tick on Ready, X otherwise. Hover lifts 1 texel and lights the rim; the walker approaching brightens it. The pad redraws only when its signature changes.
- Not yet run in-engine; PC thread to verify and capture before/after.
- Nathan, 23 Nov: pads are unique, green when affordable and red when not, with a secondary colour for the stat. Buy-state green/red are fixed hex (not palette) so they read in every zone; stat colours: mult blue, reb violet, slag amber. Each pad gets one of four inlay motifs from its id, and four stat-colour gems on the plate corners.

## Lighting overhaul, stage 1 (23 Nov)
- The scene is baked 2D plus canvas overlays (the 3D viewport is mostly empty), so a deferred normal-buffer light pass is not available. Instead a full-frame pass (render/shaders/light_grade.gdshader) reads the finished picture and re-lights every texel: sun-side lift, away-side cool or magenta shade, highlight and shadow split by luminance. All changes are Bayer-stepped, so it stays dither.
- Retuned content/config/sky.tres so light is readable at a glance: grade amount, vignette 0.6, haze 0.85, mist 0.75, rays 1.0, pools 1.0, rim 1.0. New knobs: light_side, light_split, light_lift.
- Dusk colour: orange fading to magenta (the away-side shade lerps to magenta as the sun gets low).
- Not yet run in-engine: PC pass needed for screenshots and perf (hint_screen_texture costs a screen copy per frame).

## Lighting overhaul, stage 3: real night (23 Nov)
- Night shade was a light dither (80% of texels, mid-blue). Now a separate night_shade 0.97 (night_strength stays 0.8, test_sky needs smooth steps) with darker tints (night 0.34/0.42/0.72, deep 0.16/0.20/0.42) and 60% of shaded texels take the deep tint, so night is genuinely dark. Light pools are about 1.5x wider so shrine, gate, pads and the walker clear the dark and read as light sources.
- Not run in-engine; PC pass to judge darkness and readability of pads and the HUD-adjacent scene.

## Lighting overhaul, stage 2a (redo) and the real cause of "barely visible" (23 Nov)
- Cause: terrain materials are codes 100..109 but the relight data and shader only accepted 10..47, so only ~11.7k of ~124k ground texels (props and flowers) were ever relit. The ground was effectively untouched. Now accepted range is < 110 (write_relight_data, write_ramp_include, both shaders); 122k of 124k ground texels carry a material code.
- Ground G-buffer: ground_n.png (normal, material, baked light) and ground_h.png (height) beside ground.png, written by gen_meadow3d.py; ground.png is byte-identical.
- ground_light.gdshader: N.L relight, height-march cast shadows (flowers, tufts, rocks, slopes), cool shadow tint (multiplied), contact occlusion, depth fog. Pushed hard on purpose: relight 2.2, shadow 1.2, AO 0.5, step length 1.6 texels at noon to 3.4 at low sun. Tune down in content/config/sky.tres from here.
- Debug: F6 cycles the ground view: off, albedo, normal, height, shadow only.
- Process note: the first stage 2a push never carried the code (a denied command was never run, then a hard reset dropped the edits). This commit is the first one that actually contains it.

## 2026-11-23 Pad art, rarity and Momentum label
- Nathan: pad inlay sprites were too small and all alike. Inlay is now 21x11 texels, and each pad gets a unique mirrored 5x5 emblem from its id, projected onto the plate, with a stat-colour spine. The centre stays clear for the tick or X.
- Pads have a rarity (`ButtonDef.rarity`, content only): Meadow common, common, uncommon, rare, epic; Larkmoor common to legendary by cost; Quarry uncommon, rare, epic. Frame ring in the tier colour (none for Common), white studs from Legendary. Shown in the tooltip through `Sim.pad_rarity`.
- Momentum label: Pixelify Sans, capitals, embolden 0.6 and a 2px ink outline.

## Lighting: vignette dither pinned to the world, Larkmoor ground relight (23 Nov)
- The dotted pattern over the top of the frame was the vignette: its shape is frame-fixed but its Bayer pattern was pinned to screen texels, so the dots stayed still while the ground scrolled (shower-door). Nathan likes the dither itself. The pattern is now computed in world texels (ScreenLight passes the world origin and zoom, snapped to whole texels), so it moves and scales with the ground. The other passes (night, grade, rays, haze, ground relight, shadows) already use world positions.
- Larkmoor gets the same ground G-buffer and relight as the meadow (gen_larkmoor.py writes ground_n.png and ground_h.png; ground.png unchanged). It uses the shared meadow ramp include, so Larkmoor's rock ramp is the meadow one (palette is the same).
- Not run in-engine: check the vignette dots scroll with the ground at zoom 1-4, and Larkmoor F6 views.
- Icons v3 (tools/art/gen_icons_v3.py + pixel_kit.py): shapes are geometry sampled at pixel centres, so symmetry is exact and diagonals are 45 degree or 2:1 steps. All 16 px icons regenerated, 32 px gallery icons in assets/icons/big/. Relic icons unchanged.

## 2026-11-23 Pad outlines on the texel grid
- Nathan: the pad outline looked sharp, finer than the world's pixels. draw_polyline diagonals are anti-aliased and sub-texel. Every pad outline, ring and ripple is now whole-texel rects (TexelPad._outline), and the pad snaps its position to whole texels in _ready (marker anchors are fractional, e.g. 245.5).

## Lighting overhaul, stages 4 and 5 (23 Nov)
- Stage 4: ground_fog.gdshader, a drifting two-band fog over the land, thicker toward the top of the frame, scaled by the existing mist curve (dawn, dusk, rain, night). The Bayer dither is in world texels (wpos), so it moves with the ground. Knob: fog_ground in sky.tres. Drawn only while amount > 0.01 and atmosphere is on, so it costs nothing at noon.
- Stage 5: the time-of-day grade now has a real midnight (cool blue, 0.6 coverage) and a warm noon (0.25 coverage) instead of an almost-white day and a no-grade night. Dusk stays orange fading to magenta.
- Not run in-engine. Parallax is still open: the far backdrop is baked into ground.png and needs a generator split.
- PC pass fixes: vignette dither used a rounded origin, which slipped against the ground when the camera offset was fractional (Larkmoor zoom 3, 30% match). It now uses the exact origin. Pad shadow stretches from 18 texels (was 9) so it reads. Larkmoor noon was overexposed: ground relight now scales 0.55 at noon to 1.0 at a low sun, light_lift 0.22 to 0.12, the full-frame highlight lift only starts at lum 0.66, and the noon grade covers 0.15 instead of 0.25.

## Backdrop parallax and PC pass tuning (23 Nov)
- The far backdrop (sky and mountains) is now its own image per zone (backdrop_far.png, 64 texels wider each side) and ground_fg.png is the ground with those texels transparent. Both generators write them; compositing them reproduces ground.png exactly (0 mismatching pixels), and ground.png itself is unchanged, so haze, mist, walk masks and the G-buffer keep working. FarLayer (world/far_layer.gd) follows the camera by parallax_far = 0.1 of its travel in whole texels. The water band stays in the ground art so the shoreline never slips.
- Tuning from the PC pass: ground fog halved (0.4) and tinted pale and cool instead of the dawn haze colour, god rays 1.0 to 0.6, Larkmoor noon down another step (ground relight 0.4 at noon, light_lift 0.06, light_split 0.4).
- Not run in-engine: check the seam where the far layer meets the ground at zoom 1 to 4 and while panning to the edge of the bleed.

## Lighting: nothing follows the camera
- The vignette shape was frame-fixed, so its dither crawled through a stationary dark rim while panning. Its shape is now computed in world texels from the playable area, so it only darkens when you pan toward an edge. All other passes (day/night, light grade, ground light, fog) were already world-anchored.
- Veil turned down: vignette 0.6 to 0.45, night_shade 0.97 to 0.8 (night_strength stays 0.8 for the smoothness test), light_split 0.4 to 0.3.
- New Access toggle "Reduce screen effects" (FxConfig.reduce_screen_fx) hides the edge shade and the full-frame light pass.

## World shaders use true world texels (anchor fix)
- Root cause of the camera-following dither: `MODEL_MATRIX` includes the `world` Node2D's transform, which WorldCamera scales by the zoom. Every world shader used `(MODEL_MATRIX * VERTEX).xy` as "world texels", so at zoom 2+ dither cells were single screen pixels (fine speckle, not texel-sized) and their phase slid against the ground as it panned. Zoom 1 only matched by luck, which is why the earlier PC pixel check passed.
- Fix: globals `world_origin` and `world_scale` (RenderGlobals.set_world, called from WorldCamera._apply) are divided out in the vertex stage of ground_light, wind_sway, cast_shadow, ground_fog, god_rays, sky_haze, day_night and light_grade. This also puts light pools and the area-based fog and shade back in true world coordinates at every zoom. Season recolour and shadow dither use the same wpos, so they are covered. The vignette already did its own conversion.
- Not run in engine. PC pass: pan at zoom 2 and 3 with frame diffs; ground dither should move 1:1 with the grass.

## Light passes read the shared camera globals, one value per world texel
- PC pan diff at zoom 3 (clock paused, calm, still): 41% match with Reduce screen effects off (best shift 32 px, not a whole texel), 96.7% on. The edge shade and the full-frame light pass were the remaining non-rigid layers.
- Vignette: dropped its private `w_origin` / `w_scale` (derived from a node transform in ScreenLight._process, so it could trail the camera) for the `world_origin` / `world_scale` globals. Both passes now evaluate their smooth fields (edge distance, sun-side gradient) at the texel centre, so every screen pixel of a texel gets the same value.
- Not run in engine; needs the same zoom-3 diff with Reduce screen effects off.
- Gallery (PR #90): cards are IndexCard (ui/index_card.gd), pages swap under the dither wipe, Esc steps back from a detail page before it closes the window (handled in IndexPanel._input, so the menu router is unchanged).

## Night is a solid tint, not a two-tone dither
- Nathan's Larkmoor night screenshot: a blue checkerboard of two strongly different tints (night_tint and deep_tint) over about 80% of texels buried the scene, and the walker lantern was a noisy dot blob.
- day_night.gdshader now multiplies a solid cool tint (mix to night_tint at 0.62) at full dark. A three-rung ladder (clear, soft 0.3, full 0.62) picks the rung by Bayer only where the dark is changing, so neighbouring rungs differ by about 0.15 and read as a gradient, not a pattern. The warm lantern cast uses the same ladder. deep_tint is no longer used; the uniform is kept so nothing that sets it breaks.
- Night still reads dark (blue multiply to about 0.6 to 0.8 of colour) but props keep their shapes. Not run in engine: needs night captures at Larkmoor on the PC.

## Dither cut: smooth washes by default
- Nathan, dawn in Larkmoor: "rough and honestly unbearable", still a checker grid over grass, path and props. Cause: nearly every full-frame pass was a Bayer dither (grade, rain, light grade, edge shade, fog, haze, rays, depth fog), stacked, plus the season scatter.
- Default is now a smooth tint or soft alpha for every wide pass. Dither survives only where it carries meaning: night ladder steps and the lantern glow (close tints), a narrow seam between palette ramp steps on relit surfaces (blend band 0.12 instead of 0.40), the cast-shadow rim, the sway rim light, and snow/season patches at a 12% Bayer weight over 4-5 texel patches. All of it is on whole world texels (world_origin / world_scale), so cells never scale with zoom.
- The pixel-art identity now comes from the palette ramps and texel grid, not from stacked screen dithers. Revisit if Nathan wants some dither back (the bible's section 2 and 4 describe dither as the lighting language).
- Not run in engine. PC check at dawn, noon, dusk and night, zoom 1 to 4.

## Night ladder removed
- PC at night, zoom 3 to 4, still showed a faint grid on the ground: the three-rung night ladder dithered wherever the shade was below full (any light pool falloff, dusk, dawn). Night tint and the lantern warm cast are now plain smooth multiplies of `dk` / `wk`; no Bayer in day_night.gdshader any more. Supersedes the ladder in the "Night is a solid tint" entry.

## Grass texture redesign (2026-11-23)
- Cause of the "randomized square patchwork": not the baked ground (it is smooth) but `season_recolor` in `render/shaders/season.gdshaderinc`, which switched green texels with a hash per 5x5 block and a per-texel tone hash. In spring it drew square lime/dark checkers on grass and square pink patches in canopies and rocks (props share the include). Fixed with smooth value noise on world texels, stretched 2:1 for the iso view (patch threshold, tone blobs, snow cover).
- Prototyped four grass designs in `tools/art/grass_tex.py` (`GRASS=a|b|c|d`, `old` = previous): A blade tufts gathering into clumps over soft broad drift, B soft noise bands with sparse flicks, C 2:1 iso strokes, D iso Voronoi clumps. Picked A: B read nearly as flat as the old ground, C was subtle, D was richer but too busy next to pads and props. Offsets are in baked light so the runtime relight (`ground_light.gdshader`) re-picks the same tufts at any sun angle.
- Grass terrain light lost most of the `tone` noise (0.26 to 0.10) and the fine `n2` noise; detail now comes from the tufts. Wang/autotile blending was not built (needs a hand-authored tileset; the world-anchored procedural field avoids visible repeats).
- Life sway tips (`world/meadow_life.json`) regenerated for the meadow. Larkmoor's `larkmoor_life.json` was not regenerated (its generator arguments are not recorded and the old file does not reproduce), so some old sway tips may sit on non-tip texels until it is.
- Not run in engine (no Godot in the cloud): previews are numpy ports of the ramp pick and the season recolour; needs a PC look at zoom 1 to 4, dusk, and a spring/autumn transition.

## Pond keeps its own palette in every season (2026-11-23)
- **Cause:** `season_recolor` picks "green" texels by `g - max(r,b)`; the water ramp's main colour (47,107,85) scores 22/255, past the 0.015..0.09 smoothstep, so the pond was recoloured with the grass patches (and would be snow-covered in winter).
- **Decision:** `ground_light.gdshader` skips the seasonal recolour and snow for material codes 107 (water) and 108 (foam). Water stays blue-green all year; no extra dither added. A subtle seasonal sky tint or winter ice is an open taste item, not built.

## 2026-11-23 Staged (multi-resolution) icons 
- Nathan: "better and more staged art for rebirth points, and everything else", meaning a hand-drawn variant per size, not scaled copies. Sizes: 8, 12, 16, 24, 32 (square, palette indices, nearest filter, no blur).
- Source of truth is `tools/art/staged/<name>.txt` (one ASCII grid per size, optional mirrored left half); `tools/art/gen_icons_staged.py` compiles them to `assets/icons/s8|s12/`, `s24/`, the existing 16 px path and `big/` (32 px), plus the contact sheet `docs/img/icons_staged.png`. `ui/icon_set.gd` (`IconSet.get_icon(name, slot_px)`) picks the largest staged size that fits a slot.
- Rebirth Points redrawn: a faceted green gem with a two-leaf sprout (a rebirth seed), distinct from the Rebirth ring-arrow, Prestige crown and Luck clover. Pale table, light girdle, deep pavilion, the sprout carries the "new life" read at 8 px.
- Audit before this change: stats, attributes, perks (19 icons) had 16 and 32 px only, both rendered from one shared geometry. Relics (6) have 16 px only, menu tile glyphs 9 px, area glyphs 7 px, rarity frames 20 px, hamburger and gallery menu icons 32 px. Now done: the 19 stat/attribute/perk icons have all five sizes; the 8 px and 12 px versions started from a reduction of the 16 px art and were redrawn by hand where it read badly (clock, book, Rebirth). Not done yet: relics, gallery menu icons.
- Not run in engine: no Godot in the cloud; CI runs the headless tests, the PC pass should judge the icons at 1x/3x in the HUD and gallery.

## 2026-11-23 Staged icons, second pass
- Same five sizes (8, 12, 16, 24, 32) for the flower and quarry stats (Sunlight, Dewdrop, Seeds, Clover, Thistle, Heather, Foxglove, Starbloom, Embers, Cinder, Ironore, Ingot, Alloy, Emberheart, Slag), the 6 relic icons and the 9 gallery menu icons. Relic files sit in `assets/icons/relics/` (16 px) with `s8 s12 s24 s32` folders beside them; menu icons at 32 px stay in `big/`, their 16 px is `assets/icons/menu_*.png`.
- These were seeded by `tools/art/seed_staged.py` (majority-colour reduction with a rebuilt outline; Scale2x for 16 to 32 on relics), not drawn from blank. Their 8 and 12 px versions are the weakest and are the first to polish by hand. Icons that need colours beyond the 8 zone roles list them in the .txt (`%a=#rrggbb`).
- Skipped on purpose: Rebirth and Prestige polish (the quarry reset is being replaced), the hamburger glyph (16 px only), menu tile glyphs (9 px) and area glyphs (7 px).

## Pads receive cast shadows
- Pads are plates drawn above the baked ground, so the ground's height-march shadow stopped at their edge and the pad stayed fully lit inside a shadow. New `pad_shadow.gdshader`: the same march from the plate's own top (ground height under the fragment plus `pad_lift`, 6 encoded units, about 2 world units), with the sun, slope, reach and strength SkyCycle already feeds the ground. SkyCycle owns it (`pad_material`, `_pad_mats`); each zone scene exposes `pad_material` and main.gd assigns it to the pads it builds (one line).
- The pad's own drop shadow blob was sized like a tree (26 x 18); it is now 22 x 4, the slab's width and thickness, in the same sun direction and softness as the other casters.
- Moving prop shadows (SkyShadows) are drawn beneath the pads, so they used to stop at the plate. Each caster within 220 texels of a pad now also gets a copy in a `PadOverlay` node at z 1 (above the plates), using the same shader with `clip` on: it only paints inside a pad's diamond (15 x 8 around the plate centre, up to 24 pads), so the shadow carries across the plate and nowhere else. Scenes call `add_pad` for every pad anchor.
- Not run in engine. PC: Larkmoor at golden hour, zoomed on a pad next to a tree.

## 2026-11-24: Ember Quarry lighting (quarry joins the sky system, plus its own light layer)
- The quarry was the only zone with no `SkyCycle`, so it had no time of day, no cast shadows and no light pools. It now runs `SkyCycle` and `SkyShadows` like Larkmoor, with `atmosphere = false` and `seasonal = false` so the mountain haze, the mist and the season particles stay off. Its banner keeps the time and drops the date, as before.
- `world/quarry_light.gd` adds three layers over the shade (z 6 to 8, under the embers): glow (`quarry_glow.gdshader`, additive, lava, vents, braziers and lamps), haze (`quarry_haze.gdshader`, warm near lava and cool and denser away from it, slanted light shafts from the top), and heat shimmer over the lava (`heat_shimmer.gdshader`, whole screen texels).
- Flicker is `core/lava_flicker.gd`: stepped at 6 fps and folded into each source's strength on the script side, so the shader only sums. Steady under Reduce Motion or Reduce Flashing; the glow and haze hold still, the shimmer is hidden.
- Glow rises at night (`SkyCycle.night01` times `lava_night_boost`), so the lava reads against the cool night shade. Tuning lives in `content/config/sky.tres` (quarry group).
- Props have no normal maps yet, so they use the sun rim material only. The lava's rim-like light on props is the additive glow, not a per-normal rim. A normal map pass for the quarry is the next step if PC QA wants real edge light.
- Not verified in-engine (cloud has no Godot): shader compile, the glow and haze strengths, and the 24-light cap, which drops the last braziers and lamps from the shade pools (they still glow).
- Props catch light from their nearest sources (`render/shaders/quarry_prop.gdshader`). Each sprite has a `_n.png` normal map from `tools/art/gen_quarry_normals.py` (its own silhouette, blurred into a height field), so the side that faces a lava pool, vent, brazier or lamp lights up. The nearest 8 sources per prop, flicker folded in on the 6 fps step, and the sun's rim from the SkyCycle rim material. This replaces the earlier "rim only" stopgap for the quarry; the edge light is a real normal shade now, not an outline dither.
- Not verified in-engine: the normal map is read from the silhouette, not a 3D render, so rim strength and the 8-source cap need a look on the PC.

## 2026-11-24: Cozy layer in the meadow (world/cozy)
- **Decision:** the cozy props come from their own manifest (`assets/art/zone1/cozy/cozy.json`, written by `tools/art/place_cozy.py`), not from `placements3d.json`. Kinds carry a `cozy_` prefix. Warm glows are `SkyCycle` light pools (three added), and the wheat, water wheel, swings, fountain, smoke and fireflies move on the life-step clock, frozen under Reduce Motion.
- **Why:** the meadow thread owns the baked layout and its generator; a separate manifest lets the cozy layer change without touching that render. Campfire, cottage windows and fountain are the warm and moving moments; the rug is striped, not checkered, so it does not read as a pad.
- **Not in v1:** a second wheat field, a waterfall, bird and petal life beyond what exists, and any sound (the swing creak and the water trickle need audio assets). Larkmoor gets no cozy layer yet.
## 2026-11-24: Pad affordability glow
- Each pad gets a dithered glow band just outside its plate: green when buyable, red (a little softer) when not. The colours are the buy-state hex from `StatStyle`, as the buy colours already are, so they read in every zone. The band sits on a child node at z 6, above the night shade (z 5), so it does not darken with the ground and reads brighter at night. Density and band width ramp with `PadGlow.night01`, set each frame from the zone's `SkyCycle` in main.gd, in 8 steps so the halo only redraws when the step changes.
- Rarity: the white Legendary corner studs are now glints in the rarity colour on the plate's corners (Epic and up), with a bright heart at Legendary and sparks at night. The dashed rarity ring on the top face stays.
- The glow does not pulse, so Reduce Flashing needs no branch. Locked pads draw no glow.
- Not verified in-engine (cloud has no Godot): the dither density by day and at midnight, the band width against the 2x1 plate, and whether the z 6 halo sits over the walker's feet when it stands on a plate. PC QA should check with `tools/play_shots.tscn` at noon and midnight.
- Fix (2026-11-24, same day): the first version drew the glow with bare `draw_rect` calls, which paint the pad's own canvas item, so the halo was never visible. Its draw calls now go through `_halo`, as the cost chip's already do, and the node is made in `_init`, so every pad has it from construction. Tests check the node exists, is visible, sits at z 6, and reads the night level.

## 2026-11-24: Pad glow as an additive halo
- The dithered band read as a thin outline, not a glow, in the night screenshot. The buy glow is now an additive radial halo that spills about twice the plate's width by day and about 3.5 times at night. It is one pre-rendered texture per state (green or red) and night step, drawn with one `draw_texture` call, with 8 alpha steps so it stays pixel-crisp at one texel per world texel.
- A gentle breath dims the halo by up to 20 percent over 1.6 seconds through `modulate`, so it does not redraw. Reduce Motion and Reduce Flashing hold it steady.
- Not verified in-engine: the halo brightness against the night shade, and whether the halo covers the walker standing on a plate. PC QA should check Larkmoor and the meadow at noon and midnight.

## 2026-11-24: Larkmoor farm district (Thistle Rise, first slice)
- **Decision:** a farm district east of the windmill, inside the footprint the map thread gave (about 260 x 220 layout texels centred on layout (1090, 520), doubled for the canvas). It is generated, not hand-placed: `tools/art/gen_farm.py` draws the sprites in the meadow palette roles, and `tools/art/place_farm.py` puts them on walkable grass with 19 layout texels clear of paths (the 1.7x widening the map thread asked for), 30 clear of pad plates, 24 of the windmill and gates, and 12 of the mere. Output: `assets/art/zone1b/farm/farm.json`.
- Contents (second pass): eight wheat fields as 8-frame gust sheets in four widths (96, 128 and 160 texels per frame), with golden straw stalks and orange-gold heads so they read as wheat, not blossom; three greens plots (leafy tufts over tilled soil) and three bare tilled plots; a barn, a shed, a scarecrow, two hay-bale stacks, a cart, two crate stacks; thirteen wobbly fence runs drawn in code (one node); and an irrigation channel across the box (`brooks` in farm.json, drawn with CozyBrook, one node). The channel is a decorative ditch, not fed from the mere.
- Runtime: `world/farm/farm_props.gd` (`FarmProps.spawn`) and `world/farm/farm_fences.gd`, hooked into `larkmoor_scene.gd` through `_add_farm`. The farm is always loaded, not chunked: about 17 nodes, so the Larkmoor count stays under the 1350 ceiling. Plain props take the rim material and cast shadows; fields reuse the cozy animator and stand still under Reduce Motion.
- **Why:** the coordinator asked for a farm that reads as a place, with fields that sway, not one node per stalk. A sheet per field costs one node, and the fence polylines cost one node per run.
- **Not in v1:** the animated windmill sails. The map thread will split them into their own sprite in its next slice (hub as the foot anchor); until that lands, the sails stay baked and the windmill stays still. Overlaying a second set of sails on the baked ones would double them. Also not in: a second barn, and fields that fill the box edge to edge (the valid grass is broken up by the paths, the cliff, pads and the mere).
- **Verified in-engine (Xvfb, morning):** the golden wheat reads as wheat at zoom 1 and 2, and the farm draws at both zooms. **Not verified in-engine:** the channel's look (it is not clearly visible in the captures), fence visibility at zoom 3 and 4, dusk and night, and the frame cost of the extra shadow casters and fields. PC QA should check Thistle Rise with `tools/larkmoor_shots.tscn` at noon and dusk.
## 2026-11-24: Larger pad glow
- PC QA found the halo nearly invisible at noon and small beside the dotted ground ring. Reach is about 1.9x by day and 1.8x at night (plate spread 3.0 by day, 2.6 more at night). Day strength is 0.6 and midnight 0.9, peak alpha 1.0, and the falloff is linear so the outer part still carries light. Not verified in-engine: whether the halo now washes out the ground ring or the neighbouring pads.

## 2026-11-24: Pad glow lights the plate and a bloom above it
- Nathan's feedback: the plate stayed dark, so the halo now lights from the pad's centre out and reaches the plate itself, in 16 steps so the falloff has no visible rings. A smaller squared-falloff bloom hangs over the plate. Props, grass and the walker are under the halo's layer, so it reaches them too.
- Not done: colouring the lighting shader's pad light pools by affordability. That shader is shared with the meadow rework thread, so it waits for coordination. Not verified in-engine.
- Pad light pools are coloured by affordability in the next entry (2026-11-24: Pad pool colour). Not verified in-engine.

## 2026-11-24: Pad pool colour (green or red light pools from pads)
- Each pad's light pool in the shared shade shader (`day_night.gdshader`) takes the pad's buy colour: green when buyable, red when not. Locked pads keep the warm default. Other lights (lanterns, shrine, gate, walker) keep `pool_tint`.
- How: `add_light` takes a `kind` (pads pass `&"pad"`), each light has a `tint` (alpha 0 = warm default), and `SkyCycle.set_pool_tint_at` sets it from main.gd each frame. The shader gets a `light_tint[48]` array beside `lights[48]`, and blends pool colours by falloff where they overlap.
- Why: the glow on the plate says "buy" but the ground around it stayed warm, so the colour did not carry to the ground. The change is additive: one array uniform, and no change to lantern strength or radius, so the meadow lantern work in the same shader is untouched.
- Not verified in-engine (cloud has no Godot): shader compile, and whether green and red pools read against the warm lanterns at night.
