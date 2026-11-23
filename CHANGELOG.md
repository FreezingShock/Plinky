# Changelog

Which version introduced which implementation. Format and rules: docs/versioning.md.
Scheme is MAJOR.MINOR.PATCH, starting at 0.1.0. MINOR = medium changes (features), PATCH = small
changes (fixes, tweaks). MAJOR changes only when Nathan asks. Any number can pass 9.

Every PR adds a line under **Unreleased**. `python3 tools/bump_version.py minor|patch` moves those lines
under a new version heading and updates the version everywhere.

## Unreleased

## 0.14.0 - 2026-11-23
- Momentum overhaul: five named stages (Idle, Stride, Rhythm, Flow, Surge) with income kickers, a hold window before it drains (4 s at Surge), pad presses and crits feed it, and a new bar with stage ticks, a decay ghost, a hold line, stage colours, a tier-up flash and thump, and a tooltip with exact numbers. Full bar is still +40%.

## 0.13.0 - 2026-11-23
- Stats and Attributes are now a gallery: 32 px icon cards, hover info strip, and a detail page per stat with its sources (where it comes from, how to get more). New clean symmetric icon set, and `sim.stat_sources`. Attribute detail pages let you buy the next level.

## 0.12.0 - 2026-11-23
- Title screen overhaul: a layered dusk meadow (stars, sun, two drifting cloud decks, snow-capped mountains with mist, wooded ridge with a windmill and a smoking cottage, a lake with a sun glitter column, a swaying-tree meadow, fireflies, birds, falling leaves, tall foreground grass) on the texel grid with mouse parallax and per-layer dither; the logo and a framed menu sit left, the walker on its pad right. The menu gets pixel icons on every button: Continue (or Play), New Game, Saves, Settings, Update Log, Credits, Quit.
- Save slots: three slots (slot 1 is the existing save), a Saves list showing rebirths, play time, presses and save date with Load, Start and a two-step Delete; Continue loads the last used slot; nothing autosaves while the title is up.
- The version number on the boot and title screens is bright with an ink outline, underlines on hover, and opens the Update Log when clicked (boot waits while it is open). New Credits panel.

## 0.10.13 - 2026-11-23
- HUD top bar no longer overlaps: the clock card squeezes to fit between the stats and zone panels and sits under the zone list. The district banner is centred on the screen, 40% down.

## 0.10.12 - 2026-11-23
- Ember Quarry: meadow trees no longer carry over from Larkmoor (props are freed by reference, not by name); the forge gate gets real basalt-and-iron art with locked, open and tooltip states; pads, spawn and props moved off the cliff face onto visible ground.

## 0.10.11 - 2026-11-23
- Every menu (Upgrades, Relics, Settings, Feedback, Update Log, hamburger) now opens and closes with the same dither wipe and slide as Stats and Attributes, from one shared MenuAnim. Opening a menu no longer pops a tooltip on its first item; tooltips wait for hover or the first arrow, d-pad or Tab press.

## 0.10.10 - 2026-11-23
- Night tint and lantern glow are fully smooth gradients now (no step dither), removing the faint grid on the ground at night.

## 0.10.9 - 2026-11-23
- HUD currency panel: each stat name (Cash, Multiplier, Rebirths, Slag, Prestige) is drawn in Pixelify Sans in that stat's own tooltip colour instead of plain green Spleen; the name column sizes to the widest name so the numbers stay aligned.

## 0.10.8 - 2026-11-23
- Much less dither: the time-of-day grade, rain, sun-side light wash, edge shade, fog, haze, mist, god rays and depth fog are now smooth tints and soft alpha instead of checker patterns. Relit surfaces step through the palette with only a narrow dithered seam, and the season change spreads in coarse patches instead of a texel mosaic.

## 0.10.7 - 2026-11-23
- Hamburger menu polish: tiles hover and focus as a solid lifted panel (dither only as one dotted row under the border) so labels read cleanly; the ">" marker on Close menu, Quit to title and Quit game sits a fixed gap before the first letter on whole texels; Pixelify Sans renders without grey anti-aliasing.

## 0.10.6 - 2026-11-23
- Night is a solid cool tint instead of a blue checkerboard: the shade only dithers between two close tints where it thins (light pool edges, dusk, dawn), so props stay readable. Lantern and pool glow use the same soft ladder instead of a noisy dot blob.

## 0.10.5 - 2026-11-23
- Edge shade and full-frame light pass now step on the world texel grid and read the camera transform from the shared globals, so they no longer drift against the ground at zoom 3 (PC pan diff: 41% match with them on, 96.7% off).

## 0.10.4 - 2026-11-23
- Fixed the dither and light on the ground, grass, shadows, fog and rays shimmering as the camera moved. World shaders measured position in screen pixels at zoom 2 and up; they now use true world texels at every zoom (`world_origin` / `world_scale` globals set by the camera), so the pattern stays put on the ground.

## 0.10.3 - 2026-11-23
- `tools/bump_version.py` no longer glues the first changelog note onto the new version heading; covered by `tests/test_bump_version.py`, which CI now runs.

## 0.10.2 - 2026-11-23
- Lighting: the edge shade is now anchored to the world instead of the screen, so nothing follows the camera. Night and light-split veil turned down. New Access setting "Reduce screen effects".

## 0.10.1 - 2026-11-23

- Rarity tag on every tooltip is now one all-caps line in the bold display face, rarity then type (UNCOMMON BUTTON, RARE RELIC); the relic drop toast matches.

## 0.10.0 - 2026-11-23
- Title screen after boot (Play or Continue, Settings, Quit, version in the corner). Dev and test launches skip it with `-- --skip-title` or PLINKY_SKIP_TITLE; the CI boot smoke test uses it.
- Esc in game now opens the hamburger menu as the pause menu (it still closes any open menu first). The menu gets text actions Close menu, Quit to title and Quit game with an animated accent hover, and its icon tiles show their label only on hover, typing in like the bottom bar chips.

## 0.9.1 - 2026-11-23
- Calendar uses plain season names (Spring, Summer, Autumn, Winter) and months (Early Spring, Late Spring, and so on). The window title bar shows the day count and in-game time in the middle.

## 0.9.0 - 2026-11-23
- Upgrades menu overhaul: real stat values as "now -> next" (current greyed, next lit), level pips, green/red costs, an animated Buy (squash, cost flies to Prestige, numbers tick up, pip pop, rising click), and three new upgrades unlocked by Rebirths (Crit power at 3, Quick study at 5, Pad yield at 10) with padlock rows for locked ones.

## 0.8.0 - 2026-11-23
- In-game calendar (5-day months, 10-day seasons), HUD clock, outdoor seasons (blossom, lush, amber, snow) with season particles, 3 min day / 2 min night, save v3.

## 0.7.0 - 2026-11-23
- Tooltip rework: one rich tooltip system (stat icons and colours, green/red cost, tooltips on every stat and attribute, hover that stays up), relic slots moved onto it.

## 0.6.0 - 2026-11-23
- Bottom bar buttons no longer move: labels float above the button instead of widening it, open after a short hover intent (instantly on focus), linger briefly, and the hit areas fill the gaps. New setting Access > Bottom bar labels (On hover / Always / Never); number keys 1 to 5 press Upgrades, Relics, Stats, Attributes and Menu.
- Hamburger menu at the bottom right: a gallery of big icon tiles (Stats, Attributes, Upgrades, Relics, Travel, Settings, Update Log) with the version shown; Settings moves into it.
- Fixed the close X: it now draws a full 13 texel frame with arms and clicks reliably; the Stats, Settings and Feedback windows no longer have text Close buttons.
- Update Log tile shows this changelog in the game.
- Menus close and switch reliably when spammed, with an animated close X on every panel; bottom bar buttons expand to icon plus label.

## 0.5.0 - 2026-11-23
- Single source of truth for the game version (`core/build_info.gd`), shown small on the boot screen, with `BuildInfo.string()` and `BuildInfo.changelog()` for the Update Log tile.
- `tools/bump_version.py`, `tests/test_version.gd`, this changelog and docs/versioning.md.

## 0.4.0 - 2026-11-23 (#71-#95)
- HUD click fix on world switch (#71). Pad plates with green/red buy state and per-stat colours (#72). Shared Tip tooltips (#73).
- Pad mastery XP, levels and crit bonuses (#74), retuned twice to keep Larkmoor near 61 min (#79, #81).
- Zone menu with themed locations, areas and a foldable travel list (#75, #92, #93).
- Stats and Attributes index with dither wipe (#76, #85, #86). Pad art: emblems, rarity frames, bold Momentum label (#78). Pad outlines on the texel grid (#88).
- Lighting overhaul: full-frame light pass (#80), ground G-buffer and relight (#82, #83, #87), pad shadows (#89), ground fog, real midnight and noon grade (#91), backdrop parallax layer (#94).
- Bottom bar icon chips that expand to a typewriter label (#84). Spam-safe menus and an animated close X (#95).

## 0.3.0 - 2026-11-23 (#47-#70)
- Larkmoor, the big meadow past the onboarding gate (#49), with its own lighting, shadows, haze and mist (#54, #59, #60).
- Lighting and atmosphere overhaul: sun shadows, light pools, haze, god rays, grade, vignette (#47).
- Prop depth: baked AO and rim, layered flowers, runtime relight (#63, #68). Rebirth wipe on the full-window overlay (#53).
- Perf passes: bench rows, shader warm-up, sound preload (#55-#57, #61, #66, #67). Larkmoor pad costs tuned for a 60-90 minute first run (#70).
- Pad arrow and window fixes (#50, #51, #65, #69).

## 0.2.0 - 2026-11-22 (#32-#46)
- Custom windowed frame and fullscreen dither wipe (#40). Settings menu, window size and monitor, dev console (#43). Keyboard and gamepad navigation (#36).
- Day/night cycle, light rain and wind sway (#41). Zone 2 Ember Quarry blockout with Slag and Heat (#42).
- Onboarding with staged unlocks (#39). Camera polish (#32), GUI consistency pass (#33), world reacts to the walker (#34).
- Juicier number feedback and Momentum meter (#37). Footsteps and shore ambience (#38). Meadow surface pass (#45). Perf overlay and Graphics quality (#46).
- Shareable test build workflow and feedback form (#35). macOS export fix (#44).

## 0.1.0 - 2026-11-22 (#3-#31)
- Core simulation, content, save, number formatter (#3). Atomic saves and CI on Godot 4.7 headless (#13).
- 3D zone 1 meadow with y-sorted occluders and life layers (#4, #19). Dither renderer, UI juice, HUD frames and icons (#18).
- Walker as the player, click-to-walk marker, depth layering, walkable mask (#10-#12, #25, #27). Pad tooltips (#8).
- Procedural audio (#16, #24, #29). Momentum, streaks, golden critter, rebirth push (#17). Relics with eight rarities (#5).
- Boot screen with threaded loading (#20). Screens at every size, Wide view bleed (#21, #23, #26, #30, #31). App icon and export presets (#14).
