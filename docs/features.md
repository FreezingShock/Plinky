# Plinky feature list and status

Status as of 2026-11-23, main at v0.27.0. "Tested" means headless tests in CI (about 2,600 checks); "PC checked" means seen running in Godot on Nathan's PC. The cloud cannot run Godot, so most items are tested only until the PC test thread confirms them. Update this file when a feature changes state. Fuller history: CHANGELOG.md and decisions.md.

| Area | Feature | Status |
|---|---|---|
| Core | BigNum, formulas, tick, sim, save and codec, slots, export and import, offline progress (passive income only) | In repo, tested |
| Core | Number formatter (short-scale -illion names, one formatter) | In repo, tested |
| Economy | Meadow flower ladder: Sprout, Clover, Thistle, Heather, Foxglove, Starbloom tiers, three pads each, one stat per row, Sunlight passive (v0.27.0) | In repo, tested; PC feel pass wanted |
| Economy | Tier buff chain (higher tiers boost the stats below; Percent or Factor display setting) | Partly in repo (`gain_boost_stat`); multiplier display setting in progress |
| Economy | Bloom (meadow reset layer, pays Seeds, Bloom Gifts) | Decided; not built. Rebirth, Prestige and RP are hidden in the meadow and return in the Quarry |
| Content | Larkmoor (second meadow area): four pad rows, relics, attributes, mastery | In repo, tested |
| Content | Zone 2 Ember Quarry ladder: Cinder, Ore, Slag, Ingots, Alloys, Emberhearts | Pitch approved (docs/zone2-ladder.md); partial content only |
| Relics | 6 relics, 8 rarities, drops with pity, equip slots (3, +1 at 5 and 20 rebirths), diminishing stacks (v0.26.7), card menu with sort, filter, compare | In repo, tested |
| Meta | Rebirth, Prestige, Rebirth Points perks, attributes, pad mastery, Momentum stages, golden critter, pad streak | In repo, tested |
| Calendar | 3 min day and 2 min night, seasons, sky cycle, season look, Welcome Back card | In repo, tested; PC checked in part |
| Render | Pixel viewport 640x360, iso camera, palettes, toon and dither shaders, sky, shadows, screen light | In repo |
| World | Meadow scene, walker (sprint, lock, jump, crouch, recentre), pads, gate, depth layering, life layer (butterflies, fireflies, birds, critters) | In repo |
| FX | Press popups with streak tiers, counter punch, relic hop, no camera shake | In repo |
| UI | HUD, Esc menu router with dither wipe, Index (Stats, Attributes), Relics, History, Settings (Access: colour-safe, large tooltips, sound subtitles), instant tooltips | In repo |
| Audio | Music, SFX, ambient mix, sound subtitles (autoload `Audio`) | In repo; PC checked in part |
| Tools | headless sim, bench with 150 ms frame ceiling, screenshot tool, bump_version | In repo, CI |
| Release | Name checks (Steam, USPTO, itch); v0.1.0 public prerelease tag | Open; tag on hold |
| Missing | Achievements, seasonal events, automation, offline relic drops, Field Guide | Not built (see audit-2026-11-23.md) |
