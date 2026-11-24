# Decision log, by topic

Read this index, then open only the topic file you need. Each topic file is append-only, newest entries at the bottom of that file. Do not read every file.

Before you start a task, find the topic that matches it and read that file. Then add your own decisions to the matching file, as a `## <date>: <title>` section with one line of reasoning. Use the topic file, not this index, for new entries.

| Topic | Covers | Entries |
|---|---|---|
| [core](core.md) | Foundation decisions from 21 Nov (engine, camera, resolution, save) as a table, plus cross-cutting choices. | 1 section and the foundation table |
| [world](world.md) | Calendar, clock, seasons and seasonal events, the walker, zone entry cards, the travel map. | 3 |
| [meadow](meadow.md) | Zone 1 and Larkmoor: the meadow map, the flower ladder, Bloom, and meadow pacing. | 4 |
| [quarry](quarry.md) | Ember Quarry (zone 2): blockout, map, forge ladder, Embers, Cinder, Reforge, quarry balance. | 7 |
| [art](art.md) | Lighting, night, day and weather, dither, props, pads, grass, shaders, palettes, icons. | 26 |
| [audio](audio.md) | Audio autoload, footsteps, ambient soundscape, world-life and press sounds. | 5 |
| [hud](hud.md) | HUD strip, menus, galleries, tooltips, popups, title and settings, window, History, Ledger. | 41 |
| [balance](balance.md) | Economy numbers, Mastery, Momentum, Hold-to-buy, Rebirth and zone resets, relic stacks, balance sims. | 11 |
| [ci-workflow](ci-workflow.md) | CI jobs, release stamping, changelog rules, performance passes, docs and repo hygiene. | 6 |

## Notes
- Entries are kept in full, including old ones. Nothing is deleted. Superseded entries are marked **Superseded** on the entry, with what replaced them.
- The topic split was made by section heading on 23 Nov 2026. A few sections mix topics (for example the first Audio section also holds a table of balance and HUD rows). Read the topic file in full for those.
- Originally one file, `docs/decisions.md`, which now points here. Code comments that still name `docs/decisions.md` resolve through that pointer.
