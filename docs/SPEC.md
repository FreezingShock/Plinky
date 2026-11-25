# Plinky: Build Spec and Handoff

Nov 21, 2026 · @nate

## 1. Overview

This is a single-player incremental game in Godot 4 where a small character walks onto 3D buttons to grow a chain of stats, unlocks new zones, and stacks buffs. It is seen from one fixed isometric camera and drawn as living pixel and dither art.

"Plinky" is the chosen name. Trademark and Steam checks are still open (see docs/decisions/README.md).

**Pillars, in priority order**

1. **Every press feels good.** A press gives a squash, a short freeze, particles, a number popup, and a ripple through the dither pattern.
2. **The screen is alive.** Shadows shimmer, grass sways, and palettes shift between zones, with no static frames.
3. **Numbers always climb toward a visible goal.** The next button, gate, or rebirth is always on screen with its cost.
4. **Content is data.** A new button, stat, relic, or zone is a new resource file, not new code.

**What the first build must prove**

- The look works: 3D rendered at low resolution reads as hand-made pixel art and does not shimmer when the camera pans.
- The loop works: five buttons and three stats are fun for ten minutes without any art beyond the test diorama.

If either fails, fix it before adding content.

**Inspirations and limits**

- Untitled Button Simulator (Roblox) for structure: walk onto buttons, stat tiers, zones, rebirths.
- Risk of Rain 2 for stacking items and bold stylized shapes.
- ASCII and 1-bit dither art for surface treatment and UI.
- These are references only. Do not copy their assets, names, maps, or exact number tables.

## 2. Decisions and assumptions

Nathan locked the first four rows. The rest are calls made for him and can be changed with one sentence.

| Topic | Decision | Source |
| --- | --- | --- |
| Engine | Godot 4, 3D | Nathan |
| Camera | One fixed isometric bird's-eye view, no rotation | Nathan |
| Art | Pixel and dither art that reacts to play, with ASCII influence | Nathan |
| Structure | Buttons, stats, attributes, buffs, zones | Nathan |
| Engine version | Godot 4.7.x stable, standard build, GDScript only | Assumed |
| Renderer | Forward+ | Assumed; needed for normal-based outlines |
| Input | Character walks with WASD or click-to-move; standing on a button presses it | Assumed |
| Camera pitch | 30 degrees down, 45 degrees yaw, orthographic | Assumed; gives clean 2:1 pixel lines |
| Internal resolution | 640×360, scaled by whole numbers | Assumed; fits 1080p ×3, 1440p ×4, 4K ×6 |
| Platform | Windows first, Mac second, no web export | Assumed; Forward+ does not target browsers |
| Main dev machine | The Windows PC | Assumed; it has the dedicated GPU |
| Save | One local JSON save, autosave every 30 seconds | Assumed |
| Multiplayer, leaderboards, monetization | Out of scope | Assumed |

The build agent records every new decision in `docs/decisions/README.md` with a date and one line of reasoning.

## 3. Game design

Refreshed 24 Nov 2026 at v0.63.2. The earlier Cash, Multiplier and Prestige design is gone. Numbers live in `content/` (`.tres`), not in this doc. Behaviour: [features.md](features.md). Balance: [balance.md](balance.md). Decision trail: [decisions/balance.md](decisions/balance.md).

### Core loop

1. Pads sit on each zone's ground. A pad costs one stat and pays the stat above it.
2. The walker stands on a pad, or holds the mouse on it, and the pad presses at its zone's press rate (`press_rate` in the zone file).
3. Each player press pays a share of the pad's reward. Higher stats boost the income of the stats below.
4. A zone gate opens when its gate stat passes its threshold, which leads to the next zone. Open gates stay open.
5. Each zone with a reset can reset (Bloom in the meadow, Nucleus in the quarry). A reset clears that zone's stats, pays its currency (Seeds or Core Shards), and makes every pad in the zone pay more for good.
6. Gifts (attributes) are bought with the currency of the reset that owns them, in Upgrades. Gifts are permanent.

### Stat chains

| Zone | Stats, lowest to highest | Gate |
| --- | --- | --- |
| Meadow (`zone1`) | Sunlight, Sprout (Dewdrops), Clover | Clover at 9 opens Larkmoor |
| Larkmoor | Thistle, Heather, Foxglove, Starbloom, with Sprout and Clover rows by the lake | Starbloom at 2,600 opens the quarry |
| Quarry (`zone2`) | Embers, Cinder, Ore, Slag, Ingot, Alloy, Emberheart | Emberheart at 600 |

Each zone's `boost_stat` sets which stat its pads feed. Each `StatDef` names the stat it boosts, so a new zone adds tiers without new systems.

### Pads, presses and mastery

- Pads list in each zone file as `pad_buttons`. Each zone has its own palette and its own press rate.
- **Mastery** levels each pad from its own presses, to level 25. Each level adds reward yield, crit chance and crit damage on that pad. Mastery is kept through resets. Numbers: `content/config/mastery.tres`.
- **Momentum** is a 0 to 1 charge. Walking charges it most, and presses and crits add to it. Its top stage gives up to +40% income.
- **Relics** drop from presses and stack. Some carry abilities. See [relics.md](relics.md).
- **Auto presses** come from the Dew Sprite and Wildflower gifts.

### Idle, offline and events

- Balance target: the idle profile (a player who does not walk or hold) takes about twice as long to open a gate as the active profile. It presses at 0.4 of the active rate in `content/config/sim_profiles.tres`.
- Offline progress pays 0.5 of income. The base cap is 2 hours, and the Offline gain gift adds to it.
- Seasonal events multiply income by day or season (`content/config/seasonal_events.tres`).

### Balance check

`tools/sim.gd` plays the meadow and Larkmoor under each profile in `sim_profiles.tres`, over seeded runs. It prints the median minutes to each gate. CI runs it in the `sim` job, which fails on a script error or a gate that is never reached. Pacing targets are in [balance.md](balance.md).

## 4. Art direction and rendering pipeline

The game renders real 3D at 640×360 and upscales it with no smoothing, then a post-process shader limits it to a small palette with dithering and outlines. Models carry no textures; the shader supplies all surface detail.

### Camera

- `Camera3D`, orthographic, rotation fixed at 30 degrees down and 45 degrees yaw. It only pans.
- The orthographic size is tuned so one world unit spans 16 texels across the screen.
- The camera follows the player with light smoothing and never rotates or zooms during play.

### Pixel viewport

1. The 3D world lives in a `SubViewport` sized 642×362, one spare texel on each edge.
2. The camera position is snapped to whole texels in camera space every frame.
3. The leftover fraction of a texel is applied as an offset to the upscaled image, so panning is smooth.
4. The image is shown with nearest filtering at a whole-number scale, letterboxed when the window does not divide evenly.

This snapping is what prevents shimmer. It is the hardest part of the pipeline and is tested first.

### Materials

- One shared toon `spatial` shader for all world geometry.
- Colour comes from vertex colours or a per-material palette index. No image textures.
- Lighting is quantized into 3 bands: lit, mid, shadow.
- One directional light with shadows. No ambient occlusion, no reflections, no anti-aliasing.

### Post-process

The post-process is a full-screen quad inside the pixel viewport with a `spatial` shader that reads the screen, depth, and normal textures. Per Godot's documentation, the normal texture is [only available in Forward+](https://docs.godotengine.org/en/4.3/tutorials/shaders/screen-reading_shaders.html).

It runs these steps in order:

1. **Outline:** mark a texel where depth or normal changes sharply against its neighbours. Draw it in the palette's darkest colour.
2. **Dither:** compare luminance against a 4×4 Bayer threshold to choose between two neighbouring palette colours.
3. **Palette:** snap the result to the zone's palette, an 8-colour 1×8 texture.

The Bayer pattern is indexed by texel position plus the snapped camera offset. The pattern then stays fixed to the world when the camera pans.

### Making each pixel feel alive

All of these are driven by global shader uniforms, so gameplay code sets a value and every material responds.

| Effect | How it works | Trigger |
| --- | --- | --- |
| Shimmer | Noise shifts the dither threshold, stepped at 10 frames per second | Always on |
| Press ripple | A ring expanding from a world position offsets the threshold as it passes | Every button press; up to 8 at once |
| Wind | Vertex shader sways tagged meshes by height | Always on |
| Palette shift | Blend between two palette textures over 1.5 seconds | Entering a zone |
| Milestone flash | Whole screen inverts for 3 frames, then a wide ripple | Gate opens, rebirth |
| Button press | Pad sinks 2 texels, 40 ms freeze, 6 to 12 square particles, number popup | Every button press |
| Idle life | Small props bob or blink on offset timers | Always on |

### ASCII influence

- The HUD uses a monospace bitmap font, box-drawing borders, and text bars such as `[#####---]`.
- A stretch goal is a glyph shader that redraws the screen in character cells for special zones or the rebirth transition.

### UI layer

- The HUD is drawn in the same 640×360 space, so UI pixels match world pixels.
- Body text uses a bitmap font about 8 pixels tall. The font must have an open licence, recorded in `assets/fonts/LICENSE.txt`.

### Models

- Low-poly meshes from Blender, exported as `.glb`, with flat vertex colours and hard edges.
- Target size: a prop is 50 to 300 triangles. Fine detail is wasted at this resolution.
- Until real models exist, the build uses Godot primitive meshes so nothing blocks on art.

## 5. Technical architecture

The simulation is plain GDScript with no scene-tree or rendering dependencies, so it can be tested and balanced from the command line. World, UI, and rendering only listen to it.

### Folder layout

```
project.godot
CLAUDE.md
docs/        SPEC.md  interfaces.md  decisions/  art-bible.md  theme.md  balance.md  ...
core/        bignum.gd  formulas.gd  sim.gd  tick.gd  save_codec.gd  mastery.gd ...  (pure logic)
             event_bus.gd  game_state.gd  save.gd  calendar_service.gd  (autoload shells)
data/        stat_def.gd  button_def.gd  zone_def.gd  relic_def.gd  attribute_def.gd  tier_def.gd ...
world/       texel_walker.gd  texel_pad.gd  gate.gd  zone scenes, sky and light scripts
render/      pixel_viewport.gd  iso_camera.gd  fx_driver.gd  toon_material.gd  shaders/  palettes.gd
ui/          hud, menus, panels, ui/fx/ (Juice: popups, transitions)
boot/ audio/ theme/ fonts/ assets/
content/     stats/ buttons/ tiers/ zones/ areas/ relics/ rarities/ attributes/ config/   (.tres files)
tests/       run.gd  test_*.gd   (every suite is registered in run.gd)
tools/       screenshot.gd  sim.gd  bench.gd  bump_version.py ...
```

### Autoloads

| Name | File | Job |
| --- | --- | --- |
| `EventBus` | `core/event_bus.gd` | Signals only, no state |
| `GameState` | `core/game_state.gd` | Owns all stats, relics, attributes, and the tick |
| `Save` | `core/save.gd` | Load, save, migrate, offline progress |
| `Fx` | `render/fx_driver.gd` | Turns gameplay events into global shader uniforms |
| `Calendar` | `core/calendar_service.gd` | Day, season and year clock |
| `Juice` | `ui/fx/fx_bus.gd` | UI effects: popups, counters, banners |
| `Audio` | `audio/audio.gd` | Music, SFX, subtitles |
| `Banner` | `ui/banner.gd` | Centred popup banners |

### Interface contract

The live contract is `docs/interfaces.md` (autoloads, EventBus signals, who may do what). Changing it needs the main session's approval.

```
# EventBus signals
stat_changed(stat_id: StringName, value: BigNum)
button_pressed(button_id: StringName, world_pos: Vector3, gain: BigNum, crit: bool)
button_denied(button_id: StringName)
zone_entered(zone_id: StringName)
gate_opened(gate_id: StringName)
relic_gained(relic_id: StringName, stacks: int)
buff_started(buff_id: StringName, seconds: float)
rebirth_done(prestige_gained: BigNum)

# GameState API
get_stat(stat_id) -> BigNum
can_afford(button_id) -> bool
try_press(button_id, world_pos) -> bool
income_per_second(stat_id) -> BigNum
try_rebirth() -> bool
buy_attribute(attribute_id) -> bool
```

### Data resources

- Each definition is a custom `Resource` class with exported fields, saved as a `.tres` file under `content/`.
- `GameState` loads every file in those folders at start. Nothing is registered by hand.
- A `ButtonDef` holds: id, cost stat, base cost, reward stat, reward, zone, and row index.
- World scenes reference a `ButtonDef` by id. They hold no numbers of their own.

### Big numbers

- `BigNum` stores a mantissa between 1 and 10 and an integer exponent.
- It supports add, subtract, multiply, divide, power by a float, compare, and format.
- GDScript floats stop near 1e308, which an incremental game passes quickly.
- `test_bignum.gd` covers each operation, including adding numbers 20 orders of magnitude apart.

### Save

- Saves are JSON at `user://save.json` with a `version` field and a `.bak` copy of the previous save.
- `Save` runs migrations in order when the version is older.
- Saves happen every 30 seconds, on zone change, on rebirth, and on quit.
- A missing or corrupt save falls back to the backup, then to a new game. It never crashes.

### Code rules

- Static typing on every variable, parameter, and return value.
- Pure logic in `core/` never references nodes, scenes, or `render/`, `world/`, `ui/`. Autoload shells in `core/` are the only exception.
- Gameplay never sets shader values directly. It emits an event and `Fx` responds. Presentation scripts that own their material (sky, shadows, screen light, toon material, pixel viewport, window frame, transitions, boot and title backgrounds) set that material's own uniforms.
- No numbers in scripts that belong in `content/`.

## 6. Milestones

There are six builds. M1 and M2 run in parallel, and Nathan approves the look at M1 before M3 starts.

1. **M0: Repo and tooling.**
   - The project opens in Godot with Forward+ and the four autoloads registered as empty scripts.
   - `tests/run.gd` runs from the command line and exits with a pass or fail code.
   - `tools/screenshot.gd` runs a scene for 30 frames and writes a PNG.
   - `CLAUDE.md` and `docs/interfaces.md` are committed.
2. **M1: Look test.** Runs alongside M2.
   - One diorama: a floor, three props, one button, one light, all primitive meshes.
   - The full pipeline is on: pixel viewport, toon shader, outline, dither, palette.
   - The camera pans on arrow keys with no shimmer or crawling edges.
   - Pressing space fires a ripple from the button.
   - A debug overlay exposes every art value as a slider.
   - **Gate:** Nathan reviews screenshots and a short capture, then approves or redirects the look.
3. **M2: Core simulation.** Runs alongside M1.
   - `BigNum`, `GameState`, formulas, tick, and save all work with no scene open.
   - Zone 1 content exists as `.tres` files: 4 stats and 5 buttons.
   - All tests pass. `tools/sim.gd` prints time to reach each button and the gate.
4. **M3: Playable slice.**
   - The player walks, stands on buttons, and sees costs, rewards, and popups.
   - The HUD shows all stats with income per second.
   - The gate to zone 2 opens at its threshold and the palette shifts on entry.
   - Save and load work across restarts.
   - **Gate:** ten minutes of play is fun. If not, tune numbers and feel before M4.
5. **M4: Depth.**
   - Rebirth, the five attributes, six relics, one shrine buff, and offline progress.
   - A settings menu: window scale, volume, and a reduce-flashing option that disables the invert flash.
6. **M5: Second zone and release build.**
   - Zone 2 has its own stat tier, palette, buttons, and one new mechanic.
   - Sound effects for press, deny, gate, relic, and rebirth.
   - A Windows export runs on a machine without Godot installed.

## 7. Parallel workstreams

The work splits into five streams that each own separate folders, so several agents can build at once without editing the same files.

> **Superseded:** the repo is flat now. The `src/` paths below are the original plan, not the current layout. For the current folders and who usually edits what, see [codebase-map.md](codebase-map.md).

| Stream | Owns | Starts at | Needs first |
| --- | --- | --- | --- |
| A. Render | `src/render/` | M1 | M0 |
| B. Core | `src/core/`, `src/data/`, `tests/`, `tools/sim.gd` | M2 | M0 and the interface contract |
| C. World | `src/world/` | M3 | B's `GameState` API |
| D. UI | `src/ui/` | M3 | B's signals |
| E. Content | `content/`, balance notes in `docs/` | M2 | B's resource classes |

**Rules for running in parallel**

- The main session is the integrator. Only it edits `project.godot`, the main scene, `CLAUDE.md`, and `docs/interfaces.md`.
- Each stream works on its own branch in its own git worktree, and never edits outside its folders.
- A stream that needs something from another stream asks the main session. It does not reach in.
- Before merging, the main session runs the tests and the screenshot tool on the branch.
- C and D can build against a stub `GameState` that returns fixed values, so they do not wait for B to finish.
- Scene files are the main merge risk. One stream owns each `.tscn`, and shared scenes are composed from instanced sub-scenes.

**Nathan's own stream**

- Blender models into `assets/models/`, following the limits in section 4.
- Look and feel reviews at the M1 and M3 gates.
- The game's name.

## 8. Setup and iteration loop

The build runs in Claude Code on the Windows PC, opened in the repo folder. That is what gives Claude access to the files, the terminal, and Godot. A Claude Project holds this spec for design conversations, but it cannot edit files or run the game on its own.

### One-time setup

1. Install Godot 4.7.x stable, standard build, on the Windows PC. Add it to PATH so `godot --version` works in a terminal.
2. Install Git. Create a private GitHub repo and clone it, for example to `C:\dev\button-game`.
3. Export this doc as Markdown and save it as `docs/SPEC.md` in the repo.
4. Open Claude Code in that folder and paste the kickoff prompt from section 9.
5. Create a Claude Project for the game and add this doc as project knowledge. Use it for design, balance, and art direction talk.
6. On the Mac, clone the same repo. Push and pull to move between machines.

### The two roles

| Tool | Use it for | Can touch the computer |
| --- | --- | --- |
| Claude Code in the repo | Writing code, shaders, scenes, and content; running tests and Godot; parallel agents | Yes, inside the repo folder |
| Claude Project | Design decisions, balance ideas, art direction, reviewing screenshots | No |

Decisions made in the Project go into `docs/decisions/README.md`, so the build agent sees them.

### The agent's own loop

The agent runs this after every change, without waiting for Nathan:

1. Check scripts parse: `godot --headless --check-only --script <file>`.
2. Run tests: `godot --headless --script tests/run.gd`. Godot documents [headless mode for use with `--script`](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html).
3. Capture the look: `godot --path . tools/play_shots.tscn` (gameplay) or `tools/hud_shot.tscn -- early|late` (HUD panel), which save PNGs and quit.
4. Open the PNG, compare it with the goal, and fix what is wrong.
5. Commit with a one-line message once tests pass.

Screenshots need a real window, because headless mode does not render. The window can open and close on its own.

### Nathan's loop

- **Look:** run the game, press F1, and drag sliders in the debug overlay. Every art value in section 4 is a slider. "Save" writes the values to a resource file in the repo.
- **Feel:** play for two minutes, then send one screenshot or clip and one sentence about what is off.
- **Balance:** ask for the simulator table. `tools/sim.gd` plays the best strategy for a set time and prints minutes to each button and gate.
- **Content:** ask for a button, relic, or zone in plain words. The agent adds the `.tres` file and reruns the simulator.

The simulator is the fastest tool here. It replaces an hour of play with a few seconds of output.

### Optional: let the agent drive the running game

Several third-party Godot MCP servers let Claude Code run the project, send input, and take screenshots. One example, [godot-mcp-runtime](https://mcpservers.org/servers/erodenn/godot-mcp-runtime), describes exactly those tools.

- None of these has been reviewed for this spec. Each can run scripts on the computer.
- Read the source and pin a version before installing one.
- The loop above works without any of them, so add one only if the screenshot script proves too limited.

## 9. Handoff text

Two blocks to copy: the `CLAUDE.md` file for the repo root, and the kickoff prompt for the first Claude Code session.

### CLAUDE.md

```markdown
# Plinky (working title)

Incremental button-presser in Godot 4.7, GDScript, Forward+. Fixed isometric
camera, 3D rendered at 640x360 with dither, palette, and outline post-process.
Full spec: docs/SPEC.md. Interfaces: docs/interfaces.md. Log: docs/decisions/README.md.

## Rules
- Read docs/SPEC.md before starting any milestone.
- Static typing everywhere.
- src/core/ never references nodes, scenes, or other src/ folders.
- Gameplay emits EventBus signals. Only Fx sets shader uniforms.
- No balance numbers in scripts. They live in content/*.tres.
- All stat values are BigNum, never float.
- No image textures on world geometry. Colour is vertex colour or palette index.
- Do not copy assets, names, or number tables from any existing game.

## After every change
1. godot --headless --script tests/run.gd
2. godot --path . tools/play_shots.tscn (gameplay) or tools/hud_shot.tscn (HUD panel, `-- early|late`), then look at the PNG
3. Commit only when tests pass

## Parallel work
- Streams own folders as listed in SPEC section 7. Stay inside yours.
- Only the main session edits project.godot, the main scene, this file,
  and docs/interfaces.md.
- One branch and one worktree per stream.

## Working with Nathan
- Lead with the result, then the reasoning.
- Make reasonable calls and log them in docs/decisions/README.md.
- Stop and ask only at the M1 and M3 gates, or before anything hard to undo.
- Finished-product quality: no placeholders or stubs left in a merged milestone.
```

### Kickoff prompt

```text
Read docs/SPEC.md in full. You are the main session and integrator for this
Godot 4.7 project.

1. Do M0 yourself: create the project, folder layout, empty autoloads,
   CLAUDE.md from SPEC section 9, docs/interfaces.md from SPEC section 5,
   tests/run.gd, and tools/screenshot. Confirm godot runs from the terminal.
   Commit.
2. Then start two agents in parallel, each in its own git worktree:
   - Stream A builds M1, the look test, inside src/render/.
   - Stream B builds M2, the core simulation, inside src/core/, src/data/,
     tests/, tools/sim.gd, and content/.
3. Review each branch yourself: run tests, capture screenshots, look at them,
   and send fixes back before merging.
4. When M1 is merged, stop. Show me three screenshots and the path to run it,
   and wait for my approval of the look.
5. After approval, run streams C and D in parallel for M3.

Log every decision you make in docs/decisions/README.md. If Godot is not on PATH or
anything in the spec turns out wrong for Godot 4.7, tell me before working
around it.
```

## 10. Risks and open questions

The largest risk is scope: 3D zones take far longer to build than buttons and numbers, so content stays capped at one zone until the M3 gate passes.

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Scope creep | Each zone needs models, palette, layout, and balance | No zone 2 content before M3 is fun |
| Shimmer when panning | It breaks the pixel art illusion | Texel snapping is built and tested first, in M1 |
| Small text is unreadable | 8-pixel fonts at 360 lines leave little room | Test the HUD at ×3 scale in M3; raise internal resolution only if needed |
| Spec details unverified in 4.7 | Shader and viewport specifics were not test-run for this doc | The agent reports any mismatch before working around it |
| Agents collide on scenes | `.tscn` merges are painful | One owner per scene; folder ownership in section 7 |
| Third-party MCP servers | They run scripts on the computer | Optional, source-reviewed, version-pinned |
| No web build | Forward+ outlines rule out a browser version | Accepted; a depth-only outline is the fallback if web matters later |
| Flashing effects | The invert flash can bother some players | Reduce-flashing setting in M4 |

**Open questions for Nathan**

- [x] What is the game called? Plinky (chosen 22 Nov 2026).
- [ ] WASD, click-to-move, or both?
- [ ] Is the character a person, a creature, or an abstract shape?
- [ ] What is zone 2's theme and new mechanic?
- [ ] Is a Steam or itch.io release a goal, and by when?

**Sources**

- [Godot docs: screen-reading shaders](https://docs.godotengine.org/en/4.3/tutorials/shaders/screen-reading_shaders.html)
- [Godot docs: command line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
- [Godot release news](https://godotengine.org/news)
- [godot-mcp-runtime listing](https://mcpservers.org/servers/erodenn/godot-mcp-runtime)
