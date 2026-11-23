# Changelog

Which version introduced which implementation. Format and rules: docs/versioning.md.
Scheme is MAJOR.MINOR.PATCH, starting at 0.1.0. MINOR = medium changes (features), PATCH = small
changes (fixes, tweaks). MAJOR changes only when Nathan asks. Any number can pass 9.

Every PR adds a line under **Unreleased**. `python3 tools/bump_version.py minor|patch` moves those lines
under a new version heading and updates the version everywhere.

## Unreleased

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
