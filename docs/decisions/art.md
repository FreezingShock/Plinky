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

## 2026-11-24: Rain wets the ground and fills the screen
- **Wetness** is `SkyModel.wetness(t)`: the mean rain over the last 45 s, so puddles fill during a shower and drain after it. Pure, sampled like `rain()`, covered by `tests/test_weather.gd`.
- **Ground** (`ground_light.gdshader`, `wet_ground`): the soil darkens by up to 60%. Puddles are smooth noise plus a bonus for dips in the height map, against an edge that falls as the ground wets, with a Bayer edge. They take a sky colour, with a palette-4 glint in the sun. Drop rings are a cell grid on the iso plane; at full rain 14% of cells ring at once. Under Reduce motion the rings stop and the puddles stay. Snow cover turns puddles off, winter rain is snow, and the quarry (not seasonal) keeps dry ground.
- **Rain** (`sky_rain.gd`): drops fall through the camera's window, not the whole field. Larkmoor's field is 2540x1640 texels, so 6000 drops left about 36 streaks on screen. Now 900 drops fill the reference view, scaled by the view's area (0.5 to 2.5x), and the cost does not grow with the map.
- **Petals and snow** (`season_particles.gd`) had the same bug: they spread over the whole field, so about 3 petals showed on screen. They now use the same camera window and density scale as the rain.
- **Snow drifts:** in winter, snow lies deeper in the height-map hollows (`texel_dip`, shared with the puddles), with a dithered edge.
- **Dawn mist:** the dawn part of `SkyModel.mist` (base haze ignored) lays a dithered low haze over the ground, drifting slowly, and holds still under Reduce motion.
- **Clock tooltip:** one line from `SkyModel.weather_words` (rain, snow, or clear with the ground drying). Pure, tested.
- **Why:** rain barely read on screen, and wet ground is the cue that says it is raining.
- **Verified in the cloud:** Godot 4.7.2 headless under xvfb with lavapipe. Tests 5346 checks, 0 failed. Shaders compile, and the screenshot set (tools/weather_shots.tscn) was checked by eye.
- **Not verified on the PC:** how puddles and rings look at zoom 1 and 4, the feel of the drop speed, and the night puddles against the moonlit path.

## 2026-11-24: Lantern art, lamp glow and lamps by night only
- **Art:** `make_lantern` is a garden lantern in the same 19 by 29 window: a stone foot (kept within 1.9 texels, so its front corner stays inside the window), a thin timber post, a lit window (the paper colour lifted in the shade) framed by four dark corner posts, a hipped timber cap that overhangs the window, and a dark finial.
- **Glow sprite:** `LampGlow` (`larkmoor_scene.gd`) is a 32 texel dithered bloom, warm, with six Bayer steps and a bright core. It was 24 texels with four steps and a squared falloff, which read dim.
- **Pools by night only:** lantern pools are added with kind `&"lantern"`. `SkyCycle._push_lights` scales their strength by `lamp_light_k(night01)` (a smoothstep from 0.1 to 0.5 night), and a lamp at zero takes no shader slot. Before, the shader's warm cast ran at about 0.35 of full strength by day, so each lamp left a warm patch on a sunny lawn.
- **Why:** lamps should be on at dusk and off by day, and the glow should read at night without a flat blob.
- **Not touched:** `day_night.gdshader` (the pool shape and its colour math). The lamp pool is still the same falloff and warm cast; only its strength changes.
- **Not verified in-engine on the PC:** whether the lit window reads as warm enough next to the green pad pools at night.
## 2026-11-24: Fallen blossom in spring (recommendation 9, first of three)
- **Look:** pale petals (the first petal colour from the season's list, else a paper pink) gather in soft drifts on the outdoor ground in spring. `ground_light.gdshader`, `fallen_blossom`: a two-octave patch mask on the iso grid, and a per-texel hash inside each drift, so the petals are sparse and never a carpet.
- **Wiring:** `SkyCycle` sets `blossom` = spring weight x outdoor x (1 - snow), so it fades into summer and is gone under snow. Quarry and water are excluded.
- **Why:** the handoff's recommendation 9. Spring needs something on the ground, not only in the air.
- **Not verified on the PC:** the density. The cloud shot reads as scattered pale speckle in the meadow. Tune the 0.25 and the patch threshold after the PC look.

## 2026-11-24: Weather safe defaults (lighter puddles, wetter-dark nights, Low drops rings and mist)
- **Puddle water** (`sky_cycle.gd`, `puddle_col`): the day base lifts from (0.3, 0.5, 0.5) to (0.46, 0.64, 0.64). Coverage is unchanged. Night stays dark water.
- **Night wet** (`ground_light.gdshader`, new uniform `wet_night` = night x wet): wet soil and path darken further at night, from (0.88, 0.92, 0.95) to (0.66, 0.72, 0.8) at full wet. This darkens all wet ground, grass included, not only the path; there is no path mask to pick out the path alone.
- **Low quality** (`GraphicsQuality.rain_rings_and_mist`, false on Low): the splash rings and the dawn ground mist are skipped. Puddles, drops and wetting stay. Medium and High are unchanged.
- **Why:** these three were the safe defaults from the weather handoff (recommendations 2, 7 and 8). Nathan has not yet picked the rest.
- **Rain streaks** (`sky_rain.gd`, recommendation 3): near streaks are 2 texels wide, far ones stay 1. Same draw count.
- **Winter drift edges** (`ground_light.gdshader`, `snow_drifts`, recommendation 5): a cool blue shadow on the lip of each drift, where it steps down into flat snow. The drift threshold is unchanged.
- **Left for the PC look:** the splash ring density (recommendation 4, 14% of cells) and the dawn mist strength (recommendation 6). No in-engine view of either exists yet, so their numbers are unchanged.
- **Not verified in-engine:** the new puddle lift, the night darkening, the Low fallback, the 2-texel streaks and the drift shadow. The cloud render does not show rain streaks (see the handoff results note), so the look is an eye check on the PC.

## 2026-11-24: Pad glow crowding (a row of pads does not blow out)
- Nathan's screenshot: with the rows 42 texels apart, neighbouring halos and light pools added together into one blown-out green blob at night. Halos are additive, and pool strengths sum before the shader clamps them.
- Fix: each lit pad counts the lit pads within `TexelPad.CROWD_RANGE` (48 texels, a little over one row). Its halo and its shader pool are scaled by `crowd_scale(n) = 1 / max(1, n * 0.5)`. A lone pad or a pair keeps full light, and any crowd adds up to about two pads' worth at its busiest point.
- Why this and not a max blend: the halo and pool are additive on purpose (they light the ground), and changing the blend mode would change every pad. Scaling by crowd keeps one pad looking as it does now.
- Not verified in-engine: no Godot binary was available in this session, so the 5-pad row at night was not rendered. The 48-texel range and the 0.5 share are guesses to tune on the PC.

## 2026-11-24: Larkmoor wheat is thick, with no plots, and parts around the walker
- The fields are wheat only. The tilled plots and greens were removed: crops in spring took the sway shader's blossom recolour, and Nathan asked for wheat only.
- Each row is a thick mass over a dark under-mass, and rows overlap, so no soil or water shows between them. Water streams were dropped at Nathan's request.
- world/farm/farm_wheat.gdshader pushes the stalks away from the walker. Tips move, the rows' bases stay, and the push falls off with distance. FarmWheat feeds it the walker's position, and the push is zero under Reduce Motion.
- The parting is subtle at Larkmoor's zoom, so it needs a look on Nathan's PC.

## 2026-11-24: Larkmoor wheat is clumps of stalks, placed in organic patches, and parts around the walker
- Nathan's notes: each stalk needs its own shading and shadow, the walker must sort by Y and stand out above the wheat, the rustle must be real bending and parting rather than a blur, the fields need organic outlines, and the stalks should be bigger.
- The wheat is now clumps. `world/farm/wheat_clump.gd` generates each clump from a seed: stalks with a dark root, a golden body, a darker side on some, a lit head, a dark root mass for thickness, and a dithered contact shadow. Each gust frame bends the tips.
- `tools/art/place_farm.py` places the clumps in four wobbly patches. Each clump is a prop with its own foot, so the walker sorts against every clump by Y. The old rectangular fields and their fence runs are gone.
- `tools/bake_wheat.gd` bakes eight gust frames per clump into `assets/art/zone1b/farm/wheat/`. Far clumps play the sheets.
- `world/farm/farm_wheat.gd` redraws the clumps near the walker each frame from their stalks. Each stalk leans away from the walker and grows towards the tip, and the walker's push point follows a soft spring that bounces back after the walker passes. Under Reduce Motion nothing parts.
- Not changed here: the grass blades. Those belong to the grass and ground work.
- Not verified on the PC: how the parting reads at the player's own zoom and speed.


## 2026-11-24: Larkmoor wheat is re-laid denser inside the farm box, with a fence ring around each patch
- Five patches now sit on the walkable ground the placer allows inside the farm box (`tools/art/place_farm.py`). The box clips the old patch outlines, and cliffs and the mere cut the east side, so the old patches were partly off the grass.
- Clumps are smaller (28 to 32 canvas texels wide), on a tighter grid. Clumps may overlap each other a little (`WHEAT_DX`/`WHEAT_DY`), so the patches read thick, not stacked. Everything else keeps the 4 texel gap.
- The fence ring is 44 straight chords, each with posts and two rails. It is placed before the wheat, so the clumps grow inside it. Two walk-in gaps per patch. The whole ring is one batched item and one sprite (`tools/art/gen_farm.py` draws it), so it costs one node. Its foot is on its north edge, so it sorts behind the wheat and props south of it, and it casts no shadow.
- The farm is 49 sprites, one node each: 9 props, 39 wheat clumps, and the fence ring. The bench puts Larkmoor at 1214 nodes at peak, against the 1350 ceiling.
- Checked in the cloud render only (xvfb, software Vulkan), not on the PC.

## 2026-11-24: Larkmoor wheat grows in irregular fields on tilled soil
- Nathan picked two real-field shapes from mockups (g1 and g3) and asked for them to be placed irregularly round the farm. Shapes follow the irregular fields of varying size in satellite imagery of Germany (NASA imagery, via Geography Realm's "Agricultural Patterns Visible from Space"). `tools/art/farm_fields.py` builds them: a "notched" field (two lobes and a bite out of one edge) and a "blob" (a body, a bulge and a bump), as rounded rectangles in ground space, noise-warped, scaled and mirrored. Four fields (two of each) are placed by `FIELDS` in `tools/art/place_farm.py` where the walkable grass has room, found by a search over the farm box. The buildings and props (TARGETS) are untouched and belong to the barn thread.
- Each field has a soil decal (`assets/art/zone1b/farm/soil/`, kind `farm_soil_N`): dark soil in furrows (EARTH dithered with INK), a headland a few texels wider than the wheat, and an edge that dissolves into grass through a 4x4 Bayer band. It is drawn only on walkable grass and never over a building or prop. Its foot is on its north edge, so it sorts behind everything south of it. It takes no rim light and casts no shadow (`FarmProps.is_soil`).
- The wheat is wheat only, golden and late (brown), with no green sprouts (Nathan: not that tone of green anywhere). Roots, the root mass and the contact shadow are INK, not green, so the clumps sit on the soil. Colours are the eight palette roles only.
- The fence ring follows each field's outline at 12 layout texels, 34 pieces with two walk-in gaps per field, placed before the wheat. It keeps the broken look from #367.
- The silhouette cut: a stalk in front of the walker, within 9 texels of his column, stops 14 texels above his feet, so wheat tops do not cover him. It only runs for clumps near him, so it follows Reduce Motion (no push, no cut).
- Numbers: 4 fields, 51 clumps (45 golden, 6 brown), 4 soil decals, 34 fence pieces in one node. Tests 6537 checks, 0 failed. Bench (low quality, cloud, software GL): Larkmoor 1211 to 1215 nodes at peak against the 1350 ceiling.
- Checked in cloud captures only (xvfb, software GL), not on the PC. The field variation (short and thin patches) is subtle because tall wheat in front hides anything behind it from this camera.

## 2026-11-24: Bushes and rocks are re-shaped for the looking-down camera
- Rocks: a tilted plane shaves each crown flat, so the top reads as one lit face with a bevelled rim. Facets drop from 3 to 5 down to 1 to 3 low side cuts, and the bumpy noise is halved on big rocks. Facets no longer split a stone into pieces.
- Bushes: the lobes are squashed (height 0.8 of width), smaller crowns ride the top, and a flat skirt sits on the ground so the foot is wider than the crown. Each bush keeps its dark pockets from #361.
- Larkmoor bushes now get the dark pockets too (the M_DARKF material and ramp, same code as the meadow generator). #361 only changed `gen_meadow3d.py`.
- `world/larkmoor_life.json`: 9 sway tips no longer sat on palette 4 after the ground changed, so they are removed (1680 to 1671). Nothing else in that file changed.
- The meadow ground and walkable mask are not re-baked here. Only the meadow bush and rock sprites and `placements3d.json` change.
- Checked in engine with the cloud's software Vulkan render at game size, in `/mnt/project-files/plinky/bush-rock-looking-down/`. The change is subtle at 1x. Not checked on the PC.
## 2026-11-24: Stalk grass style F added beside E (not default)
- Audit: the live ground props (stumps, mushrooms, reeds, tufts) are SDF 3D renders from the elevated iso camera, so they already match the mockup D view. The flat read is the grass texture only.
- Added style `f` (`style_stalks` in `tools/art/grass_tex.py`): style E's vertical stalks, denser inside each clump, with the crown lit and the base shaded from the upper left. E's bare lawn between clumps is kept. Compared A, E and F as ground-only crops in `/mnt/project-files/plinky/ground-grass/grass_styles_a_e_f_ground.png`. F reads most like the stalk field of mockup D.
- Default stays `a` and no baked asset changes. The switch to a grass style belongs to the art-style thread. Recommended pick: F, for Nathan to confirm on PC at noon, since dawn grading hides texture.

## 2026-11-24: Trees to the looking-down angle (audit)
| Date | Decision | Why |
|------|----------|-----|
| 2026-11-24 | Oaks are already on the elevated 3/4 view. Crowns are lit from the upper left, the right side and underside take shadow, and the trunk shows. No change | Audit against wheat mockup D (style-guide "Camera angle standard"). Oak crown tops read as tops. |
| 2026-11-24 | Pines get a light bias on their tier tops: upward-facing normals lift the baked light, downward ledges drop it (`tools/art/gen_larkmoor.py`, `tools/art/gen_meadow3d.py`). Silhouettes, footprints and placement stay identical | Each tier's top reads from above. The four-band pine ramp is kept, so the runtime re-pick (`prop_ramps.gdshaderinc`) is unchanged. |
| 2026-11-24 | Conifers (material code 12) skip the seasonal foliage recolour in `render/shaders/wind_sway.gdshader`, so pines keep their green all year, snow included | The pink on pines was the spring blossom tint from `content/config/calendar.tres` (prop colour 0.96, 0.58, 0.72 at half strength), applied to every green texel. Blossom and autumn belong on broadleaf foliage. Snow on pines is a deliberate loss; revisit if Nathan wants it. |
| 2026-11-24 | Tried wider tier steps. Rejected: the silhouettes got lumpy and grew detached tails | Those tails look worse than the gain at game zoom. |
| 2026-11-24 | Not done: a dedicated pine tier-top band. That needs a fifth pine ramp band in `RAMP` and a regenerated `prop_ramps.gdshaderinc` | Larger change. Make it after Nathan picks a direction from mockups. |
- Checked in the cloud render only (xvfb, software Vulkan), not on the PC. The pink pines in Lanternwood (spring blossom tint on conifers) are fixed by the conifer rule above; the before and after shots were taken at 09:03 and 09:10 in-game, so the light differs a little between them.
- The conifer rule is runtime and applies to the committed sprites now. The tier light came in with PR #392 as generator code only. The follow-up bake (`gen_larkmoor.py` and `gen_meadow3d.py` on main after #399) regenerated the pine sprites and normal maps and the Larkmoor preview. Placement, the walkable mask and `ground.png` are unchanged. Five stale Larkmoor pine sprites (067, 068, 069, 129, 279) that no placement uses were left in place.
## 2026-11-24: Meadow grass blades are a shader layer, not nodes (interactive blades, slice 1)
- `world/grass_blades.gd` + `world/grass_blades.gdshader`: one quad over the meadow ground. Blades are generated per texel from a hash (one base per 3x3 cell, patch density from value noise), so there are no nodes per blade and nothing extra loads.
- Blades draw only on grass texels (the ground is palette-exact), so paths, dirt, water and pad plates stay clear. The wind wave and the walker bend use the same rules as `LifeGround.bend`. The node owns its material and sets the wind and pusher uniforms; gameplay still emits nothing new.
- Replaces the meadow's 120 baked sway tips with this layer. Larkmoor keeps `LifeGround` until the chunk streaming lands (1680 tips there, drawn on the CPU every step).
- Checked in the cloud render only (xvfb, lavapipe): no shader errors, tests pass. Not verified on the PC: the wind and walker bend, and the look at noon.
- Follow-up on the same PR: each rock and bush gets a thin, soft-edged dark contact slab under its foot, wider than the stone, so the base reads as shade on the ground. Rock tops are flatter (tilt .03 to .14). After main moved under the PR, the Larkmoor ground was regenerated, then `gen_gardens.py` (flower placement reads the ground) and the sway tips were refreshed; 6 sway tips were removed. Suite: 6428 checks, 0 failed.

## 2026-11-24: Grass style F is the default for the meadow and Larkmoor
- Nathan picked F on the decision card (A, E and F compared at bake, in engine at dawn, and at pinned noon and golden hour).
- Empirics: A, E and F have the same colour mix (within about 0.5 points) and speckle density. They differ only in arrangement. F reads as stalks at 3x; at 1x the change is subtle under the dawn and noon grades.
- Changed: `GRASS` default is `f` in `tools/art/gen_meadow3d.py` and `tools/art/gen_larkmoor.py`. Baked `ground.png`, `ground_n.png` and `ground_fg.png` for both zones. Heights, backdrops and sprites are unchanged, since grass does not touch them.
- Regenerated for the new ground: `world/meadow_life.json` (53 sway tips had left palette 4) and `world/larkmoor_life.json` (sway, flowers, pads and water from `tools/art/gen_life_anchors.py` with `--bounds 0,0,3040,1840`; farm, perches and forest edge kept), and `world/larkmoor_gardens.json` from `tools/art/gen_gardens.py`.
- Larkmoor life counts on F: sway tips 1674 (same as before), butterfly flower spots 240 down to 185.
- Withdrawn: an earlier count of 193 sway tips came from a bounds mistake (the default 640 window), not from F. Use `--bounds 0,0,3040,1840` for Larkmoor life.
- The Larkmoor A bake reproduces the committed ground exactly (0 texels differ), so the pipeline is trusted for both zones.
- Open: PR #378 and #395 put the blade shader over the grass. Their threads judge the combined look in engine and thin the blades if they double up.
## 2026-11-24: Larkmoor grass blades draw per loaded chunk, in one node
- `GrassBlades` gets a chunked mode. It draws one shader rect per loaded prop chunk (`chunk_loaded` / `chunk_unloaded` from `LarkmoorScene`), in a single node, so the grass follows the streaming and adds no node count. The rects are in zone texels, the same space as the blades.
- Pushers are a list of up to 6 points: the walker and the rabbits, chickens and frogs that are showing (`LifeCritters.ground_pushers`, read-only). Ducks are not included yet.
- `LifeGround` is no longer placed in Larkmoor or the meadow. The class stays for its tests.
- Pad plates are skipped by colour (they are not grass colours), not by the pad clearance, because Larkmoor has 31 pads and the shader holds 8.
- Checked in the cloud only (xvfb, lavapipe): no shader errors, `tests/run.gd` passes (6539 checks), `tools/larkmoor_shots.tscn` runs. Not verified on the PC.

## 2026-11-24: Grass blades: Low quality keeps the old tips, and the shader checks fewer cells
- `GraphicsQuality.GRASS_BLADES` is `[false, true, true]`. On Low the blades hide and `LifeGround` (the baked tips, with the existing Low stride and step) draws instead. The check runs every frame, so a level change takes effect without a reload.
- Cost, measured in the cloud (lavapipe, CPU-rasterised, so absolute numbers are not PC numbers; High, 150 frames per phase, `tools/bench.gd`): meadow noon average 40.2 ms with blades off, 57.1 ms with the first shader, 47.1 ms after the cell-limited shader. Larkmoor noon 58.9 / 64.7 / 56.1 ms. The blades' cost is per-pixel ALU over the whole screen, and the cell limit trims it about 17% on the meadow. Not measured on a GPU.
- The shader now checks only the cells that can reach a pixel (2 texels to each side, 2 below), not all 15 candidates. Output is the same except where two blades overlap a texel, where the first one found wins.
- Ducks are in the pusher list (`LifeCritters.ground_pushers`).
## 2026-11-24: Lightning in heavy rain (recommendation 9, third of three)
- **Look:** a brief cool-white lift on the whole frame in heavy rain (rain at 70% of max and up), made in the light grade pass (`light_grade.gdshader`, uniform `flash`). A strike flickers twice over about half a second.
- **Schedule:** `SkyModel.lightning_flash(t, rain01)`, pure. Each 40 s window has a strike half the time, at a hashed moment, so the same time always gives the same flash and the test can check it.
- **Flashing:** zero under Reduce motion or Reduce flashing (`steady` in `SkyCycle._update_light`). Reduce flashing defaults off, so lightning plays by default, as the handoff asked.
- **Low quality:** the light grade pass is skipped on Low (`GraphicsQuality.screen_grade`), so Low shows no lightning. Thunder sound is not included.
- **Not verified in-engine:** how strong the lift reads on the PC, and how often a strike falls in a real downpour.
## 2026-11-24: Larkmoor farm fields, edge groves and fences are re-laid (Nathan picked mockup C)
- **Decision:** `tools/art/place_farm.py` now lays seven fields (the original four plus three on the open grass south of them, found by a search over free walkable grass), a taller farm box (`BOX` is `(1090, 548, 260, 276)` layout texels, so it runs south of the yard), two tree groves on the south and east edge, and fences that follow the outside of each run.
- **Paths:** the old placer kept 12 canvas texels from the drawn sand. Wheat and soil now keep `FIELD_SAND_CLEAR` (22 canvas texels, 11 layout), fence chords `FENCE_SAND_CLEAR` (10). The walkable mask counts paths as walkable, so every check reads the drawn sand pixels in `ground.png`, never the mask. Nathan's mockup feedback traced to this.
- **Continuous fields:** fields may touch (their soil decals overlap, so the bed runs together). `SOIL_REACH` (7 layout texels) takes the soil up to within 5 of the fence at `FENCE_OFFSET` 12. A fence chord inside a neighbouring field's soil is dropped, and a run shorter than `FENCE_MIN_RUN` (3 chords) is dropped, so there are no inner fences and no stubs.
- **Packing:** `GRID_X` 7.5 and `GRID_Y` 4.5 layout texels, `WHEAT_DX` 15 and `WHEAT_DY` 9 canvas texels, and a clump foot may stand 3 texels outside the outline (`EDGE_INSET`), so the wheat fills out to the soil with only light overlap. 176 clumps, up from 57.
- **Groves:** the biggest oaks and pines (`TREE_FILES`) are copied into `assets/art/zone1b/farm/trees/` and placed as plain props (`farm_tree_N`). The placer checks only the trunk foot, so a crown may hang past the grass. This avoids editing `gen_larkmoor.py`, which other threads own. Ten trees fit; the free grass south and east is narrow.
- **Budget:** the bench (low quality, headless) shows Larkmoor at 1178 nodes at peak against the 1350 ceiling. The farm test's node budget goes from 120 to 240.
- **Checked:** in the cloud with Godot 4.7.2 under xvfb and software Vulkan (shots in `/mnt/project-files/plinky/farm-edge-in-engine/`), tests 7740 checks, 0 failed. Not checked on the PC. `tools/farm_edge_shots.tscn` captures the farm at day and night (`-- zoom=1|2`).

## 2026-11-24: Pad beds drawn from above
Nathan picked mockup A (mounds) from the three styles in `plinky/pad-stage-mockups/` on the project files, over the stalks and the planter. The beds are baked by `tools/art/gen_pad_beds.py` into a leaf layer, a shade layer and a greyscale bloom layer, so the stat colour and the colour-blind tint still apply at runtime. The side sprouts, the gold crown and the twinkle glints are now in the art or gone; a glint pass can come back on the bloom tops.
## 2026-11-24: Walker is redrawn from above with 8 facings (Nathan picked mockup B)
- **Look:** mockup B of the three walker mockups. The walker is drawn from the elevated, looking-down view: a lit shoulder top plane, a domed hood with the face set lower in it, and lit toe caps. The silhouette, cloak colours, scarf and satchel stay.
- **Facings:** N, NE, E, SE, S, SW, W, NW. Five are drawn (E, SE, S, NE, N) and SW, W and NW are mirrors at runtime, so the art is not duplicated. The mirror keeps light from the upper left, as the other flipped sprites do.
- **Idle keeps the last facing,** so the walker stays turned the way it last moved. It used to snap to front.
- **Atlas:** 55 cells in 8 columns (512 x 448). `world/walker_pose.gd` holds the cell numbers and the octant mapping, and `tests/test_walker_pose.gd` checks them.
- **Not verified in-engine on the PC:** the diagonal three-quarter views and the sprint tails at normal zoom. Checked in the cloud with Godot 4.7.2 under xvfb, `tests/run.gd` passes (7890 checks) and `tools/walker_cells_shot.gd` draws every facing and phase through `WalkerBody`.
## 2026-11-24: Rain glow and moonlit puddles (Nathan picked mockup C of three)
- **Look:** in rain, each lamp pool grows 35% wider and 40% brighter (`SkyModel.lamp_bloom`, full rain at 1.0). The flower-field glow grows 50% (`FlowerGlow.RAIN_BLOOM`). Each lamp is mirrored in the wet ground 14 texels below it, dithered by the Bayer matrix so it reads as puddle glints, not a sheen. Night puddles lighten toward a moon grey-teal instead of black.
- **Where:** `SkyCycle._push_lights` (bloom), `day_night.gdshader` (`reflect_amt`, mirror summed in the same pool loop), `SkyCycle._update_light` (puddle colour, reflect amount), `FlowerGlow._apply_alpha` (flower bloom; alpha now follows rain even with Reduce motion on).
- **Rejected:** a stronger bloom (about twice the first) floods the flower fields in blue, so it is not the look.
- **Pure:** `SkyModel.lamp_bloom` is tested in `tests/test_weather.gd` (dry unchanged, wet brighter, monotone, capped).
- **Checked in the cloud:** Godot 4.7.2 under xvfb with software Vulkan. Tests 7787 checks, 0 failed. Night and dusk, clear and rain, in `tools/weather_mock_shots.tscn`. Frame times in `tools/weather_perf.tscn` are within noise of the old build on software Vulkan, so the cost is not measured on a GPU.
- **Not verified on the PC:** how strong the mirror reads on a real GPU, and the night look at full quality.
- **Not in this change yet:** drips off trees and roofs, the sound layers, and the fog and snow pass. These need their own mockups.

## 2026-11-24: Pad signs clear of the beds, mounds fuller
- **Nathan's note (PC QA, batch 103):** the plank sign sat over the pad's centre bed, and the mound was not clearly separable at zoom 1.
- **How:** `SIGN_X` moves from 17 to 26 texels, which clears the bed's right edge (x 24) and the plate's right corner. The plank keeps its height and width, so the text and the post still fit. `tools/art/gen_pad_beds.py` raises the head radii about 15% (`HEAD_R` 1 to 5: 4.2, 3.4, 3.1, 2.8, 2.6). It regenerates `assets/art/zone1/pads/`.
- **Check:** the headless suite passes (7941 checks). An in-engine contact sheet (`tools/pad_sheet.tscn -- rich`, xvfb with lavapipe) shows the sign beside the bed and the stage 1 and 2 mounds as separate domes at 1x.
- **Not checked:** the night and dusk tones, and the walker's footprint against the moved sign. PC QA should look at those.
## 2026-11-24: Farm wheat clumps are canvas items under one node (Larkmoor was over the node cap)
- **Decision:** `FarmWheat` creates each clump as a `RenderingServer` canvas item parented to the y-sorted prop parent, at the clump's foot, instead of a `Sprite2D` per clump. One node owns all 176. The items y-sort against the walker, trees and props exactly as the sprites did, because the renderer sorts a parent's child items by their transform origin. Plain props, trees, the fence and soil stay `Sprite2D` (they take the rim material or shadows).
- **Why:** #434 laid 176 clumps, which put Larkmoor at 1357 against the 1350 ceiling. The bench now shows about 1000 nodes at peak. A single draw node would have lost the per-clump sort with the walker.
- **Same look:** same sheet frames, same live redraw near the walker, same nearest filter. Day shots at five spots match before and after except for the gust and sun clock. Tests 7941 checks, 0 failed. Not run on the PC.

## 2026-11-24: Lamps spread into mist (Nathan picked "fog halo only" of three)
- **Look:** at full mist each lamp pool grows 60% wider (`SkyModel.fog_halo`, `FOG_HALO` 0.6). Clear air leaves the lamps as they were. Mist comes from `SkyModel.mist` (dawn, dusk and after rain), and `MeadowLife.fog` carries it to the lights. Outdoor scenes only.
- **Not changed:** the lamp-head glow sprites do not grow with mist, only the light pools. That keeps this change off the batched lamp glows (#463).
- **Rejected for now:** tree drips off the crowns. They are small in still frames and need a look in motion on the PC first. The prototype is kept in the project files, not committed.
- **Checked in the cloud:** Godot 4.7.2 under xvfb with software Vulkan. Tests pass; the fog halo is tested in `tests/test_weather.gd`.
- **Not verified on the PC:** how far the spread reads at dawn in a real mist.
