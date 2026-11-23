# Changelog

Which version introduced which implementation. Format and rules: docs/versioning.md.
Scheme is MAJOR.MINOR.PATCH, starting at 0.1.0. MINOR = medium changes (features), PATCH = small
changes (fixes, tweaks). MAJOR changes only when Nathan asks. Any number can pass 9.

Every PR adds a line under **Unreleased**. `python3 tools/bump_version.py minor|patch` moves those lines
under a new version heading and updates the version everywhere.

## Unreleased

## 0.29.0 - 2026-11-23
- The Ember Quarry is now a six-row forge ladder, Cinder, Ore, Slag, Ingot, Alloy and Emberheart: 18 pads climbing the terraces, each row opening the next, with new isometric voxel pad objects and per-row colours, tier buffs (1.25x and 1.5x) from Slag up, Rebirth that banks Ingots and only resets the quarry, and a small flat arrival purse. Old quarry saves migrate.

## 0.28.0 - 2026-11-23
- Higher flower tiers now buff several lower stats at once (Thistle and Heather 1.25x, Foxglove and Starbloom 1.5x, data-driven). New Settings option for multipliers as a factor (x1.5) or a percent (150%). Locked pads are clearly darker and buyable pads glow green. Larkmoor gate retuned to 2000 Starbloom Petals.

## 0.27.2 - 2026-11-23
- Docs only: CLAUDE.md and SPEC.md now match the flat repo layout, docs/interfaces.md added, shader-uniform rule amended, features.md and balance.md refreshed.

## 0.27.1 - 2026-11-23
- Fixed the title screen's input error (the menu pad actions are now registered before the title), and onboarding tip cards now step aside while any menu is open, so the Esc menu's buttons are never covered.

## 0.27.0 - 2026-11-23
- The meadow is now six flower tiers, Sprout, Clover, Thistle, Heather, Foxglove and Starbloom: three pads per tier paying one stat, each tier unlocking the next. Replaces Cash, Multiplier and Rebirth pads (they return in Zone 2). Old saves migrate. New Sunlight stat, a standing flower per tier on its pad that rises with a petal burst when the tier opens, locked buds, re-spaced pad rows.

## 0.26.7 - 2026-11-23
- Balance: the four linear relics (Gold Purse, Stopwatch, Growth Crystal, Sharp Fang) now diminish, so long play tops out near +100% per relic instead of running away; Gold Purse and Growth Crystal step down to 6% and 10%. Pad yield caps at 15 (was 25), Quick study at 10 (was 20), Press rate at 15 (was 20). Larkmoor pacing, pads, mastery, Rebirth Points and Momentum are unchanged.

## 0.26.6 - 2026-11-23
- Relics hop into their slot with a widening ring when equipped or swapped in (HUD strip and Relics menu; skipped under Reduce motion).

## 0.26.5 - 2026-11-23
- Stat counters punch with an overshoot when a big gain lands (stepped, skipped under Reduce motion).

## 0.26.4 - 2026-11-23
- Relics menu: the rarity name is back on each card (small, dim) with an On or Swap mark, bonuses wrap whole instead of mid-phrase, and the collection shows three card rows.

## 0.26.3 - 2026-11-23
- Relics menu: shorter collection so the panel fits 640x360, wider cards (less name truncation), bonuses on one wrapped line, and the card's second line shows only the stack count and Equipped or Swapping.

## 0.26.2 - 2026-11-23
- Fixed the Larkmoor transition stall (one 330 ms frame at the wipe): the zone scene loads on a worker thread, the prop sprites are built over several frames under the wipe, and CI now fails on any frame over 150 ms (300 ms for the covered zone swap) in the headless bench.

## 0.26.1 - 2026-11-23
- Sound subtitles sit on a dark plate so they read on bright ground, and up to four show at once.

## 0.26.0 - 2026-11-23
- Relics menu refresh: relics are now rarity-framed cards (exact rarity-colour outline, name in the rarity colour, stack count, Equipped mark) in a scrolling collection, with Sort (Rarity, Name, Stacks, Equipped), Show (All, Equipped, Unequipped) and Rarity filter buttons, an Active bonuses readout under the slots, and compare-on-hover.

## 0.25.0 - 2026-11-23
- Settings > Access gains Colour-safe colours (red-green safe, blue-yellow safe) for rarity, buy and stat colours, Large tooltip text, and Sound subtitles (captions for crits, relic chimes, gates, birdsong, waves, footsteps and music changes).

## 0.24.4 - 2026-11-23
- Quarry embers are denser (12 per vent), bigger while hot (2 texels) and climb higher, so they read as a plume at 640x360.

## 0.24.3 - 2026-11-23
- History window is narrower still so it no longer covers the zone panel at 640x360, and its list area is taller.

## 0.24.2 - 2026-11-23
- HUD currency panel: the gain text (+x/s, xN) now sits left of each value in a smaller font, vertically centred, so the panel is narrower; values stay centred on the row and line up in a column.

## 0.24.1 - 2026-11-23
- History screen: taller graph that fills from the left with a first bar at once, a narrower window that clears the zone panel, and the tracked currency now comes from config (`income_stat`).

## 0.24.0 - 2026-11-23
- New press popups: one pooled node draws every number, rolls a motion, easing and size per press, stacks held presses into one number, merges quick clicks and keeps numbers off each other. Escalating streak tiers (Gold, Ice, Rainbow, Chroma, Galaxy) change colour, sparkles, pad ripple and sound. Relic pulses now ripple outward as echoes with spark links and their own sound. Twelve new sounds. Respects Quiet pad clicks, Reduce flashing and Calm camera.

## 0.23.1 - 2026-11-23
- **Pond stays water in autumn.** The ground shader's seasonal recolour treated the water ramp's green (47,107,85) as grass and dyed the pond orange/brown with the grass patches. Water and foam texels (material codes 107, 108) now skip the recolour in every season, in the meadow and Larkmoor. Light water-only snow/frost is left for a later pass.

## 0.23.0 - 2026-11-23
- World life follows the calendar: up to six butterflies by day in spring and summer (a few in autumn, none in winter, at night or in rain), each with its own wing colours, and fireflies fade out of winter.
- The Ember Quarry has its own air: embers rise and cool off the heat vents and ash drifts across the floor.
- Footsteps get a quarry surface (crunchy cinder; the pale road stays packed dust), and sprints and hard landings land heavier. The quarry now reads its own ground for footsteps instead of the meadow's.
- The History tile in the menu gets its own orange section colour (the Settings refresh and the History screen had landed side by side, leaving it uncoloured and the test red).

## 0.22.0 - 2026-11-23
- Settings and the Esc menu now match the gallery: every tab and menu tile has its own colour (coloured outlines, matching labels), each setting sits on its own outlined card, and all labels and buttons show in Title Case.


## 0.21.0 - 2026-11-23
- Added a History screen in the menu: session income graph, personal bests (longest chain, highest Momentum, best income), time in each zone and lifetime totals.


## 0.20.0 - 2026-11-23
- Ambient soundscape: six layered loops (day wind, night wind, winter wind, crickets, autumn leaves, forge crackle) fade with the time of day, the season and the zone. Birdsong thins at night and in winter and swells at dawn; the Ambience slider scales it all.

## 0.19.0 - 2026-11-23
- Quality of life: a small "Saved" note after each save (red "Save failed" if a write fails), a Welcome Back card with what you earned while away, a confirm card before Rebirth, and rebinding that accepts Shift, Ctrl and Alt combos plus new Sprint and Sprint lock keys. Settings > Gameplay can turn off the Saved note and the rebirth confirm.

## 0.18.1 - 2026-11-23
- The SPRINTING HELD / ENABLED label now has a dark backing plate so the ground no longer shows through its letters.

## 0.18.0 - 2026-11-23
- Walker overhaul: the hooded walker is redrawn (20 poses, no baked shadow) and animated procedurally (squash, stretch, lean, hop, dust). Shift sprints, Ctrl locks the sprint, Space jumps (a jump launches you faster and the camera rises with it), C crouches or slides while sprinting. A SPRINTING HELD / SPRINTING ENABLED label sits above Momentum. Recentre camera moves from C to Home.

## 0.17.4 - 2026-11-23
- Zone panel: a long zone name such as Ember Quarry drops to the 12 pt title size so the Travel button no longer clips it.

## 0.17.3 - 2026-11-23
- Tooltips are instant, like Minecraft: no hover or focus delay, no grace window, and they vanish the frame the cursor leaves. The version link on the boot and title screens moved from Godot's delayed tooltip to the shared tooltip.

## 0.17.2 - 2026-11-23
- The top-right area card now folds to its one-line stub 3.5 s after you walk into an area (hover keeps it open).
- Entering an area now shows a slim title card (about 1.6 s, top-centre, 12 pt name) instead of the big centred panel. It takes the zone palette: border and name in the area colour, the area icon either side, a dotted rule and the zone name small above.

## 0.17.1 - 2026-11-23
- Larkmoor grass sway tips regenerated for the new grass, so every flicking tip sits on a blade; a test now checks it.

## 0.17.0 - 2026-11-23
- Grass redrawn: the square light/dark patchwork is gone. Seasonal recolour now spreads as smooth organic blobs (it was hashed 5x5 squares, also showing in tree canopies and rocks), and the ground has hand-placed blade tufts that gather into clumps instead of random noise patches, in the meadow and Larkmoor.

## 0.16.3 - 2026-11-23
- Ember Quarry: the way back to Larkmoor is now a cave mouth in the rock instead of a second gate: rough basalt, a dark inside with a window of green meadow light, grass, moss and flowers at the lip, cool motes drifting out, and a green light spill on the road.

## 0.16.2 - 2026-11-23
- Ember Quarry: the south road now ends at a stone landing under a way-back arch (cool ash glow) that returns you to Larkmoor, with a tooltip; no more road to nowhere.

## 0.16.1 - 2026-11-23
- Stats and Attributes galleries overhaul: every card outline and name wears its stat's colour (brighter, solid on hover or focus); maxed attributes read a gold MAX; all names in Title Case; long names get a short card label (Rebirth Pts) so nothing clips, cards are 76 px wide; RP shows as a whole number; the three Rebirth Perks sit under their own Rebirth Perks header, each with its own icon (Deep Sleep, Pad Lore, Lucky Streak); the detail header frame and name use the stat colour.

## 0.16.0 - 2026-11-23
- Hold a Buy button in Upgrades to keep buying, faster the longer you hold. The Upgrades header shows Prestige as an icon and value on the right. New currency: Rebirth Points, paid on every rebirth and spent on Rebirth perks (Pad lore, Lucky streak, Deep sleep). World popups no longer draw over open menus. Save format v4.

## 0.15.0 - 2026-11-23
- Ember Quarry redesigned as a whole map facing the camera: a hub plaza at the middle where you spawn, a main road to the gate and branches to the three pads, ground in every direction, no rock wall in front of the camera; the gate gets a dark recess that glows when open.

## 0.14.7 - 2026-11-23
- Ember Quarry: the near cliff face is now layered basalt strata with ember seams, a lip highlight and a fall-off to dark; pads and the spawn sit well back from the lip; walk clicks near a ledge land a few texels back from the edge.

## 0.14.6 - 2026-11-23
- Stats and Attributes window is centred by the HUD, so it stays centred at Wide and other view sizes; the detail header keeps a minimum width for the value so a long name can't clip it.

## 0.14.5 - 2026-11-23
- The Welcome back toast now sits centred in the upper third, clear of the momentum panel, and the momentum tooltip is trimmed to charge, income, next stage, sources and hold/drain.

## 0.14.4 - 2026-11-23
- Stat detail header: a stat with no gain line centres its value vertically against the icon and name.

## 0.14.3 - 2026-11-23
- Momentum bar no longer grows or crowds the panel border on a stage-up: the pop is now colour and frame flash only, and the stage name has fixed room.

## 0.14.2 - 2026-11-23
- Click-to-walk ring and dots now snap to the nearest walkable ground, so they no longer sit on cliff faces or water.

## 0.14.1 - 2026-11-23
- Stats and Attributes gallery fixes from the PC pass: focused and hovered cards use a solid fill; the detail page hides the grid strip and gets more height so Next level, the sources and Buy fit; Back no longer pops a tooltip on open; the Prestige-to-spend header clears the close X; the panel recentres at wide sizes. The detail page is now a solid header (icon and name left, value and gain right) over About / Sources / Level sub-tabs, so it no longer scrolls.

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
