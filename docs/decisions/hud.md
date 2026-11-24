# Decisions: HUD, menus and UI

HUD strip, menus, galleries, tooltips, popups, the title and settings screens, window handling, History and Ledger. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## Settings menu and dev console (23 Nov)
| 2026-11-23 | The settings menu is data: every row is a Dictionary in SettingsRegistry (ui/settings/settings_registry.gd). Other PRs add a setting with one register() or register_stored() call, not panel code. Re-registering an id replaces the row | Four open PRs (#32 Reduce motion, #35 feedback, #36 gamepad, #37 momentum meter) each add controls to the old panel and would clash. With a registry they fold in as rows. |
| 2026-11-23 | Tabs: Audio, Display, Gameplay, Access, Controls, Data. DisplayPanel keeps its class name and bind/open/close/refresh so main.gd and the HUD wiring stay put | Smallest change to the integrator's files. |
| 2026-11-23 | All saved settings share user://settings.cfg through SettingsFile, which loads the file before writing a section | DisplaySettings used to overwrite the whole file, which would erase the new [game] and [keys] sections on every window change. |
| 2026-11-23 | Controls are plain buttons and a texel-drawn AsciiSlider, with < > steppers for choices. No OptionButton, CheckBox or HSlider | Those use Godot's default popup and slider look, which is not in the theme. Steppers stay in the dither style and work with keyboard and pad focus. |
| 2026-11-23 | Window size: a dropdown of common sizes that fit the monitor (hidden when they don't), plus the monitor's native size, plus Free. Dragging an edge flips the choice back to Free. Fit scaling needs no change: it already scales to any size | Nathan wants resolution settings that work with free drag-resizing. Programmatic resizes are ignored for 800 ms so they are not mistaken for a drag. |
| 2026-11-23 | Monitor selector appears only with more than one screen. Choosing a monitor re-centres the window and clamps a picked size to that monitor | Hidden when useless. |
| 2026-11-23 | No UI scale option | The HUD lives inside the 640x360 (or 840x480) viewport, so the window scale already is the UI scale. A second factor would break integer texels. Revisit if text needs to be larger than Spleen 6x12. |
| 2026-11-23 | Rebinding covers Settings, Fullscreen, Relics, Upgrades, Recentre camera and Dev console. Esc is fixed. Binding a used key swaps the two actions | Nothing is ever left unbound or doubled. WASD and the click-to-walk are not rebindable yet (PR #36 adds pad actions). |
| 2026-11-23 | Number format: Letters, Scientific, Engineering, kept in NumberFormat.style (one formatter still) | Counters pick it up on their next update. |
| 2026-11-23 | Dev console is open only in a debug build, with a --dev launch argument, or with Settings > Data > Developer console on. Opens with the backtick key | Players can't stumble into it, and testers can still turn it on in an exported build. |
| 2026-11-23 | Console logic is core/dev_commands.gd (pure, tested). Node commands (tp, speed, save, clear) are registered by ui/dev_console.gd | core/ never touches nodes. |
| 2026-11-23 | Sim gets god_mode (presses cost nothing, not saved), dev_set_stat and dev_force_zone | The only way to set a stat or skip a gate without going around the Sim's own signals. |
| 2026-11-23 | tests/test_script_loads.gd loads main.gd and every script under core, data, ui, world, render, theme, audio and boot | CI already greps for parse errors, but this names the file and fails the suite on its own. |
| 2026-11-23 | project.godot enables Import ETC2 ASTC | Godot refuses a universal macOS export without it (first CI build failed on exactly this). Only adds import data; the game is unaffected. |

## 2026-11-22 Custom window frame and fullscreen wipe
- Windowed mode is borderless with the game's own 12 texel title bar (ui/window_frame.gd): drag, double-click to maximise, minimise / maximise / close, resize on every edge and corner (5 px bands, 12 px corners, measured in window pixels). Drag and resize use DisplayServer.window_start_drag and window_start_resize, so one path covers Windows and macOS.
- The bar takes 12 texels off the top of the view, and main.gd shrinks the HUD frame by that, so nothing is covered. Fullscreen and the System frame setting give the 12 texels back.
- Settings panel has a Window frame row: Plinky frame (default) or System frame (native OS border). Saved as display/native_frame.
- Fullscreen to windowed and back plays a dither wipe: eight stepped frames of a 4x4 Bayer sweep in the zone ink colour cover the screen, the mode switches while it is covered, then it uncovers. Reduce flashing switches at once. DisplaySettings.set_fullscreen calls the registered animator, so F11 and the panel buttons both get it.
- Spam: SwitchQueue (core/switch_queue.gd) runs one switch at a time and collapses requests made meanwhile to the latest, which runs after only if it differs from the mode reached. A 3 s watchdog uncovers the screen if a switch hangs.
- Sizes: resize bands are max(5 px x screen scale, one texel of the scaled view) and hit-test in window pixels via the window's final transform, so they hold on 4K, HiDPI and letterboxed windows. The black letterbox on the title row drags the window too. The wipe renders at content resolution, so its cost does not grow with window size. The bar redraws only when width, maximised state or palette change.

| 2026-11-23 | Camera polish: 14-texel look-ahead (eased at 2.2/s), 2-texel downward punch on crits, drift of 4x2.5 texels over 23 s and 31 s after 6 s still | Subtle on purpose, so none of it reads as sway or causes motion sickness. Layered on top of follow, so pan, zoom and PR #31 scaling are untouched. |
| 2026-11-23 | Camera polish has its own Access row, "Calm camera" (WorldCamera.calm), beside Reduce screen shake and Still meadow | Fits the settings registry. Follow, zoom and pan stay when it is on. |

## 2026-11-23: Window size picks work when maximised, from fullscreen, and at native size
Picking a size in Settings > Display did nothing in three cases: the window was maximised (the custom title bar's
maximise button), it was coming out of fullscreen (the OS restored its old size over ours), or the pick was the
monitor's native size (taller than the usable area, so the window hung under the taskbar and the clamp reset the pick).
`set_resolution` now returns to windowed first, clamps to the usable area, and re-applies the size after the mode
change settles. The last option is the biggest window the monitor holds, labelled "(native)" or "(max)".
Not run in-engine from the cloud; the PC test thread should confirm.

## 2026-11-23: HUD buttons ate mouse clicks
`Main._menu_focus` released focus from the focused control every frame while no menu was open. A Button takes focus on press, so it lost focus before release and the click was cancelled. Every HUD button was affected, including the world switch (Go: zone). Focus is now dropped only on the frame a menu closes (`PadInput.should_release_focus`). Found by pushing real mouse events at the HUD in headless Godot.

## 2026-11-23: Zone menu, areas and the zone card
- New `AreaDef` (content/areas/*.tres, loaded into `sim.areas_in_zone()`): a named sub-area of a zone with a 7x7 pixel icon (ui/area_icons.gd), a palette role and the pads it lists. Larkmoor's seven districts reuse the district ids from the scene (so the walker entering a district moves the card), the Meadow has Starting Clearing and Standing Stones (invented names), the Quarry has Forge Floor. `ZoneDef` gained `description` and `theme_role`.
- `ZonePanel` replaces the gate panel, the Go buttons and the Pads list: title, gate bar, a foldable Travel menu (every location with its areas, each in its zone palette colour, locked zones shown as Locked), and the current area card (description, every pad with cost, mastery). With Travel open the card folds to a one-line dithered stub (title plus one description line); closed it shows in full. Folding is `RevealBox` (8 steps, 0.22 s). Rows are focusable `ListRow`s with the marching-dot ring.
- Clicking a location or an area in another zone travels there and shows that area. Clicking an area in the current zone only views it; walking into a district moves the card back.
- Mastery row sums `sim.mastery` level, progress and crit bonuses over the area's pads. Tooltips use the shared `Tip.bind`.
- Not run in-engine from the cloud.

## Stats and Attributes index (2026-11-23)
- One window (ui/index_panel.gd) with two tabs, opened by two icon-only HUD buttons, keys I (Stats) and O (Attributes), pad Back and Left-stick click. Read only: buying stays in Upgrades.
- Rows come from core/stat_index.gd, pure data, so tests cover them. Crit damage is `sim.crit_damage()`; Pad mastery is the sum of `sim.mastery.level(id)` over all pads.
- Open and close are a stepped 6 level Bayer wipe (ui/fx/dither_reveal.gd) plus an 8 texel slide; the header icon plays a 4 frame sheet. Reduce flashing turns the wipe off.
- Tooltips use the shared `Tip`.
- New 16x16 icons (tools/art/gen_index_icons.py): stats_menu, attrs_menu (+4 frame sheets), crit_dmg, mastery, presses, clock; heat.png copied from the library set.

## 2026-11-23: Shared tooltip system (`Tip`)
`Tip.bind(control, spec)` gives any Control a themed tooltip (hover delay 0.35 s following the cursor, focus 0.08 s anchored, instant inside a 0.3 s grace window, clamped on screen). The host panel is created lazily under the scene root instead of an autoload, so project.godot is untouched. Existing PadTooltip and RelicTooltip stay as they are (they show richer rows); new UI uses `Tip`. API in docs/tooltips.md. Not run in-engine from the cloud; CI runs tests/test_tooltips.gd.

## 2026-11-23: Tooltips on the existing UI
HUD stat rows, bottom bar (Rebirth, Upgrades, Relics, Settings), upgrade rows, zone travel, the gate bar, and every Settings row that has a hint now use `Tip.bind`. Copy lives in `ui/tip_text.gd`; no balance numbers in it, live values (cost, gain) come from the caller. Pads and relics keep their own richer tooltips. Not run in-engine from the cloud; PC pass should hover each and tab through the HUD.

## 2026-11-23: Pad and relic tooltips moved onto Tip
`PadTooltip` and `RelicTooltip` are now thin wrappers (plain Nodes) over `Tip.show_free`, so every tooltip shares one look, delay and on-screen clamp. Content for pads comes from `PadTooltip.spec_for`, which adds a "Rarity: <Name>" line and tints the border and title when `Sim.pad_rarity` exists and the pad is above common (the pad thread adds it). `Tip.show_free` gained `exact` to place beside a slot instead of a cursor. Relic stat lines lose their separate green colour (one body colour now). Not run in-engine from the cloud.

## 2026-11-23: Bottom bar chips (ExpandChip)
- Bottom-bar buttons (Rebirth, Upgrades, Relics, Settings) are icon-only at rest and open to icon + label on hover or focus. `ui/fx/expand_chip.gd`, extends PixelButton so focus ring, press sink and AsciiBox frame carry over.
- One eased progress value, no tweens, so spamming hover is continuous. Label types in with 3 scrambled trailing glyphs (ASCII noise at ~22 Hz) and a short settle flicker. Width grows in whole texels; the HBox slides neighbours aside. Reduce motion snaps with no noise.
- Each chip has a Tip tooltip so the icon-only state is named. New 16x16 `assets/icons/settings.png` (meadow palette). Stat rows and panel headers not changed: Nathan scoped this to the bottom bar.

## 2026-11-23: Menus and the bottom bar
- Chips stay clickable while a menu is open: Main raises the bottom bar above every panel, and `_menu_focus` no longer pulls focus out of the bar (that yank cancelled clicks, same class of bug as #71). Opening a menu from the bar still puts focus in the new menu.
- One menu at a time (`Main._close_others`): a chip opens its menu and closes the others; the same chip closes its own. Upgrades goes through `Hud.toggle_upgrades` and `menu_opened`.
- Upgrades and Relics panels are centred in the free area above the bottom bar (`Hud.keep_centered`). `PanelDivider` (dotted 1 texel rule with air) separates sections. Tooltips untouched: the tooltips thread owns them.

## 2026-11-23: MenuRouter and the shared close X
- Nathan could not close menus with the bottom buttons. Every opener (chips, hotkeys, the X, Esc, Feedback row) now goes through `MenuRouter` (ui/menu_router.gd): toggle closes an open menu, opening one closes the rest, Stats and Attributes share a group so switching tabs flips the window instead of closing it. Pure RefCounted, tested with stubs.
- Spam safety: the index window's wipe now starts from its current progress (`_t`) and only plays the distance left, so reversing mid-animation never jumps or sticks. The X and chips use per-frame eased values, not tweens. `tests/test_menus.gd` spams 20 and 21 toggles and asserts the end state.
- `CloseX` (ui/fx/close_x.gd): one animated X for the top right of Upgrades, Relics, Stats/Attributes, Settings and Feedback. Floats over the corner (top_level), arms grow out in steps each open, hover reaches one texel further and thickens, press sinks with an accent fill. Reduce motion / flashing shows it grown and still. The zone panel is a permanent HUD panel with its own Travel fold, so it has no X.

## 2026-11-23: Upgrades menu overhaul
- Each row shows what the upgrade gives: "now -> next" with the current value greyed and the next lit (`UpgradeText`, pure, tested), level pips (`PipBar`), and a Buy button with the cost green when affordable, red when not. Unaffordable is still clickable: it plays a small deny wobble and sound instead of silently doing nothing.
- Animated buy (`UpgradeRow.play_buy`): button squash, "-cost" in red flying to the Prestige readout, now/next numbers ticking up in 8 steps, newest pip popping, a click and tick that rise in pitch with the level (gate sound on max). Reduce motion / flashing keep the sound and skip the motion.
- Upgrades now unlock through Rebirths: `AttributeDef.unlock_rebirths`, `Sim.attr_unlocked`, `buy_attribute` refuses locked ones. Locked rows show a pixel padlock and "Unlocks at N Rebirths (have/need)". Gate is Rebirths done, not Prestige (Nathan's correction).
- Three new upgrades: Crit power (3 Rebirths, +5% crit multiplier per level, 20 levels), Quick study (5 Rebirths, +5% Mastery XP per level, 20 levels), Pad yield (10 Rebirths, +2% press reward per level, 25 levels, base cost 20). Pad yield opens after the Zone 1 gate at 9 Rebirths, and prestige is spent only after rebirthing, so the 57 to 61 minute Larkmoor pacing is unchanged (sim_larkmoor does not buy attributes). NOT run: the sim and the tests need Godot; CI and the PC pass will confirm.
- Left for the stats thread: `sim.stat_sources()` and the 32px icons. The row tooltip goes through Tip and `UpgradeText.tip`; it can pick up the coloured tooltip format when that lands.

## 2026-11-23: Tooltip rework (one system, rich lines, polled hover)
- Hover is now found by polling `gui_get_hovered_control()` instead of trusting `mouse_entered`/`mouse_exited`/a rect check; the old rect check could hide a tip under the stretch scale and some rows never fired. A tip hides 0.10 s after the mouse leaves, never on a timer.
- Specs gained `icon`, `title_color`, `lines` (coloured segments and inline 16 px icons), `hint_color`, `beside`. Colours come from `StatStyle`: stat names in stat colour, cost green/red by affordability, gains green.
- `RelicTooltip` is gone (relic slots use `Tip.bind` with `beside`); `PadTooltip` stays a thin wrapper for the world pads only. Every Stats and Attributes index row, HUD stat and upgrade row has a tooltip.
- Taste call: icons are the existing 16 px stat icons (no 8 px set exists; scaling would blur). Used in the title and on cost/gain lines. If Nathan wants 8 px icons they need new art.
- Not run in-engine from the cloud.

## 2026-11-23: Hamburger gallery menu
- Nathan: the bottom bar should not be the only home for sections, but must not go empty. Bar keeps Rebirth, Upgrades, Relics, Stats and Attributes; Travel stays in the zone panel. A hamburger chip at the bottom right (key M, rebindable) opens `GalleryMenu`: big 32 texel tiles for Stats, Attributes, Upgrades, Relics, Travel, Settings and Update Log, with the build version in the header. Settings and Update Log live only here (F10 still opens Settings).
- Tiles lift in steps on hover or focus, are normal focusable buttons (keyboard and pad), and show Locked until the tutorial unlocks that section. Picking one goes through `MenuRouter` (gallery closes, section opens); Travel closes the gallery and opens the zone panel's Travel list. Gallery and Update Log both get the shared `CloseX`.
- Update Log renders `res://CHANGELOG.md` (parsed headings, bullets, text) and shows "No update log yet." until the versioning thread adds the file. Exports need `CHANGELOG.md` in the export include filter (export_presets.cfg include_filter is empty today): flag for the main session.
- Icons: `tools/art/gen_menu_icons.py` writes `assets/icons/big/menu_*.png` (32 texel, meadow palette) and the 16 texel hamburger. The stats thread's `gen_icons_v3.py` may replace these later; swap the file names in `GalleryMenu.ENTRIES`.

## 2026-11-23: Bottom bar that holds still
- Nathan: sweeping the mouse across the chips was hard because each one widened and shoved the others. Chips now keep a fixed size; the label is a framed bubble drawn above the chip (typewriter and scramble kept) at a higher z so it overlays the meter and neighbours without touching layout. The hamburger's bubble opens leftwards from the screen edge.
- One shared state: focus (keyboard or pad) opens it at once; the mouse needs 130 ms of rest (a quick sweep opens nothing) and the label lingers 150 ms after leaving (no flicker across the gap). Hit areas extend 2 texels sideways and 4 up and down, so neighbours meet in the gaps and the margin below the bar is clickable.
- Settings > Access > Bottom bar labels: On hover (default), Always (labels sit in fixed, wider chips, nothing animates), Never (icons only; tooltips still name them). Reduce motion / flashing snaps the bubble with no scramble.
- Number keys 1 to 5 press Upgrades, Relics, Stats, Attributes, Menu (fixed numbers, shown in each chip's tooltip). Rebirth has no number key on purpose, so it cannot be hit by accident.

## Title screen and Esc pause menu
- Boot now dissolves into `boot/title_screen.tscn`; `TitleScreen.game_scene` carries the preloaded game so Play is instant. Skip with `-- --skip-title` or env `PLINKY_SKIP_TITLE` (CI boot smoke test uses it). Quit to title returns to the title even when the flag is set.
- Esc = `plinky_back`: closes open menus first, otherwise opens the hamburger gallery. The game is not hard-paused (menus never paused it; the walker already stands still while a menu is open), so "Close menu" just closes the menu. Quit to title / Quit game save first.
- Gallery tiles are icon-only at rest and type their label in on hover or focus (ExpandChip.reveal); tiles never change size. Text actions use `MenuTextButton` (Pixelify Sans, no frame, accent colour, sliding ">" and sweeping underline) so they read as different from the icon chips. Close menu (was Resume) is green (palette 4), quits are accent (palette 5).
- Not run with a GPU from the cloud: headless tests and a scripted Esc / Play / Quit to title walk-through pass; visuals unverified.

## Hamburger tiles: solid hover, crisp accent text
- Nathan's screenshot: the Update Log tile hover used the button dither wash (cream dots over the whole tile), so the label and icon sat on noise. New AsciiBox.Kind.SELECT: ink tinted 22% toward the edge green, accent border, one dotted row under the bottom border as the only dither. Used for tile hover and keyboard focus; pressed stays the accent fill with ink text.
- Menu text buttons (Close menu, Quit to title, Quit game): the ">" marker was positioned at half-texel steps and touched the first letter. It is now right-aligned ARROW_GAP (4) texels before the text on whole texels. The Pixelify Sans FontFile had default import settings (grey anti-aliasing, light hinting; *.import files are not committed), so CrispFont.apply sets AA off, normal hinting and no subpixel positioning in code.
- Not run in engine; needs a PC capture at zoom 1 and 3.

## 2026-11-23: one menu animation, quiet focus on open
- Every menu registers through `Main._register_animated`, which attaches `MenuAnim` (ui/fx/menu_anim.gd): the same stepped dither wipe and 14 px slide Stats/Attributes use. Stats/Attributes keeps its own copy inside `IndexPanel` (another thread is rebuilding it); fold it into MenuAnim when that lands. Travel keeps its RevealBox fold.
- Menu-open auto-focus goes through `Tip.grab_quiet`, so no tooltip pops on the first item. `Tip.focus_muted` clears on the first ui_up/down/left/right/Tab input; mouse hover is never muted.
- Not run in engine (no Godot in the cloud): needs a PC check of the wipe on Upgrades, Relics, Settings, Log and the hamburger.

## Title screen overhaul (0.12.0)
- Layout: logo and a framed ASCII menu on the left (clear of the horizon), the walker on its pad at the right on the meadow, so no button ever sits on the horizon line. The menu is a bordered panel with pixel icons (MenuIcons, 9x9, exactly symmetric) to the left of each label; icon buttons skip the ">" marker and brighten the icon plus sweep the underline instead.
- Backdrop: title_background.gdshader (sky, stars, sun, clouds, far mountains, mid ridge, lake, near meadow) plus TitleScenery (baked pines, trees, windmill, cottage, birds, fireflies, leaves, foreground grass). Every layer dithers on its own parallax-shifted texels (mouse parallax, whole texels, reduce motion freezes it), so dither never swims over its layer. TitleScenery.mid_ridge and near_hill mirror the shader functions; keep them in step.
- Version link (VersionLink): bright paper colour with ink outline at rest (it was palette index 3, which is the dim role and vanished over the dark ground), accent plus underline on hover or focus, click or Enter opens the Update Log. Used on the boot and title screens. Boot holds its dissolve while the log is open.
- Saves: three slots. Slot 1 is user://save.json (existing saves keep working), slots 2 and 3 are user://save_2.json and save_3.json; the last used slot is in user://slot.txt. SaveSlots holds the pure file helpers; the Save autoload holds the active slot and has a `paused` flag the title sets, so nothing autosaves (or writes an empty save) while browsing or deleting. Continue loads the active slot, else the newest save. New Game takes the first empty slot, or opens Saves when all three are full. Delete is two presses within 3 seconds.
- Credits panel lists Godot, Pixelify Sans (OFL) and Spleen (BSD 2-Clause). Names Nathan only as the maker; change the line if a different credit is wanted.
- Run in a software GL (Mesa llvmpipe, gl_compatibility) for captures, so the look is confirmed for the 2D title; the real Forward+ run on the PC is still the check for frame timing.

## Gallery PC-pass fixes (index panel)
- Cards use the SELECT solid style (as the hamburger tiles). The detail page hides the hover strip and uses DETAIL_H (230) instead of the grid's 150, since nothing sits under it. Panel centring uses the combined minimum size. All index focus grabs are quiet (no tooltip on open or page change).
- Detail page: header panel (icon+name left, value+gain right) and sub-tabs About / Sources / Level (attributes only), one page visible at a time instead of one long scroll.

## Galleries overhaul (colour, Title Case, short labels, Rebirth Perks)
- Cards take StatStyle colour via row["color_id"] (attribute effect, or rp for perks). Card labels use row["short"] (SHORT dict, max 12 chars); a test enforces it. Perks are grouped by currency == rp. Icons rest/lore/fortune added to gen_icons_v3.py. RP value floors to a whole number.

- Larkmoor sway tips regenerated: `python3 tools/art/gen_life_anchors.py --backdrop assets/art/zone1b/larkmoor/ground.png --placements assets/art/zone1b/larkmoor/placements3d.json --out world/larkmoor_life.json --bounds 190,110,1340,725 --sway-count 420`. Only `sway` and `drift` change. `tests/test_life.gd` now checks Larkmoor tips sit on palette 4 texels. Not run in engine.

- **Grass style A locked (2026-11-23, Nathan: "I like A baked the most").** Blade tufts gathering into clumps, baked into the ground by tools/art/grass_tex.py (default `GRASS=a`) for the meadow and Larkmoor. B, C, D stay in the module as alternatives only; do not change the default without Nathan.

## 2026-11-23: Tooltips are instant (Minecraft-style)
- Nathan: tooltips should appear the same frame the cursor enters a hoverable, follow the cursor, and disappear the same frame it leaves. No delay, no fade, no lingering.
- `TipHost` lost its hover delay (was 0.35 s), focus delay (0.08 s), grace window (0.30 s) and hide delay (0.10 s). A bound control shows on entry, focus shows at once, and leaving hides on that frame. Moving straight onto another bound control swaps on that frame.
- Godot's built-in `tooltip_text` (which has its own delay) was the one remaining user: the version link on boot and title now uses `Tip.bind`. Nothing in the project uses `tooltip_text` any more, so `gui/timers/tooltip_delay_sec` is not touched (project.godot is the integrator's file).
- Kept: "no tooltip on menu open" (`Tip.grab_quiet`, `focus_muted`), so a menu opening does not pop a tip until the player navigates. A pressed button still hides its tip until the mouse leaves it.
- Not changed on purpose: the gallery hover strip and display-panel hint are card/text readouts, not tooltips, and the chip label grace in `ui/fx/expand_chip.gd` is a HUD animation.

## 2026-11-23: Zone entry card made slim and themed (Nathan: less intrusive, themed by area)
- The district banner was a big centred 16 pt panel (2.2 s) over the play area. It is now a slim card at 15% down (1.6 s, slides 4 texels while fading), 12 pt Pixelify name, with the zone name small in Spleen above. Per-area theme: the zone's own palette (ink fill, border and name in the area `theme_role` colour blended to role 3), the area's 7x7 icon on both sides of the name, and a dotted rule underneath. Plain notices ("The way on is still being forged") use the same slim card without a theme. `AsciiBox` gained `fill_override`. Not run in engine (CI only).
- The top-right zone panel card (description, pads, mastery) re-opens on area entry and folds to its stub after 3.5 s (ZonePanel.PEEK), so it no longer sits over the world. Nathan called this 'the timed menu', so both it and the banner are quieter. Not run in engine.

## 2026-11-23: Relics menu refresh (rarity cards, sort/filter, compare)
- **Cards.** The collection is `RelicCard`s (AsciiBox border in the exact rarity colour, name in the readable rarity colour, `xN`, and an Equipped mark in the good green). Equipped and hovered cards sit on the lifted SELECT fill. The whole card is the click target. The collection scrolls past about four rows so a full relic list never outgrows the 360 texel view.
- **Sort and filter.** `RelicQuery` (core, pure): Sort (Rarity, Name, Stacks, Equipped), Show (All, Equipped, Unequipped), Rarity (All, then each tier owned). Three buttons cycle them; filters reset with the game, not saved. `RelicInventory.sorted_owned()` is now the default query.
- **Compare on hover.** `RelicInventory.preview_change(id, replacing)` is a pure what-if on the equipped totals. Hovering an unequipped relic shows "If equipped" with before and after per effect when a slot is free, or "If swapped for X" against the equipped relic that shares its effect when slots are full. While a swap is pending, hovering an equipped slot shows that swap. Green after-value for a gain, red for a loss. No arrows (Spleen has none): "Cash Income +10% to +20%".
- **Bonuses readout.** The panel lists active bonuses (Title Case effect names) under the slots.
- **Icons.** The multi-size relic icons from the icon thread were not merged yet, so cards use the 16 texel icons in the 20 texel frame. Swap in the larger icon once they land.
- Not run in the cloud: the engine. CI runs the headless tests; the PC pass judges card spacing, scroll height and the tooltip layout.

## 2026-11-23: Accessibility options
- **Where.** New rows in Settings > Access (`SettingsRegistry._register_access`), state in `core/access_options.gd` (`AccessOptions`, no nodes). The Settings refresh thread owns how the menu looks; this only adds registry rows.
- **Already there, left alone.** Reduce flashing, Reduce screen shake, Reduce screen effects, Calm camera, Still meadow and Bottom bar labels. Menus already take arrows, Tab, Enter, Space, d-pad, stick, A, B and Esc (`PadInput`), and chips take keys 1 to 5, so no new nav layer.
- **Colour-safe colours.** Three modes: Off, Red-green safe (Okabe-Ito based: buy gain becomes blue, can't-afford orange, rarities spread over blue, teal, pink, yellow, vermillion) and Blue-yellow safe (Multiplier, Cash, Prestige, Press Rate, Mythic, Divine, Legendary shifted). It is a lookup of the game's fixed hex colours, so zone palettes are untouched. Colour is never the only cue: rarity name tags, frame art shapes, dashed rarity rings and stat icons already carry it. `StatStyle.BUY_GREEN` / `BUY_RED` stay as the base values; code reads `StatStyle.gain()` / `cant()`.
- **Text scale (call made).** The game renders at 640x360 with a bitmap body face, so a smooth percentage scale would break the pixel grid and menus are fixed layouts. The option is therefore a two-step Large tooltip text (Pixelify Sans 16 body / 20 title in tooltips, whole-number sizes). Menu and HUD text scaling waits for the Settings refresh, which can lay out wider panels.
- **Sound subtitles.** `Audio.cue(text)` fires from `Audio.play` for sounds in `Audio.CAPTIONS`, plus shore and music changes. Pad clicks, hovers and ticks have none on purpose. `SubtitleBar` (top centre, 3 lines, 2.6 s each) shows them only when the option is on.
- Not run in the cloud: the engine. CI runs the headless tests; the PC pass checks looks and placement.

## 2026-11-23: Press popups rebuilt, streak tiers, relic pulse echoes (v0.19.0)
- **One node, one pool.** `PressPopups` (ui/fx/press_popups.gd) draws every press number, banner, sparkle, ring and pulse link in a single `_draw` from fixed pools (24 popups, 220 particles, 8 links, 8 rings; particles scale with Graphics quality). No Label or tween per press, so spam-pressing allocates nothing. The old `PopupStack` keeps only the shared zone id; `PopupNumber` stays for HUD floats and the critter bonus.
- **No overlap, still one stacking number.** Holding a pad keeps ONE running popup per pad that adds every press into it (locked decision), grows by whole font sizes at 10/100/1000, shows a small `xN` count, holds 0.5 s after release, then floats off with a final burst. A press within 0.35 s of the pad's last popup folds into it and re-pops it. Otherwise a new popup takes the first free lane (seven positions around the anchor); if the screen is busy, relic pulses are skipped past 16 live popups and the pool recycles the one nearest to done.
- **Procedural variety.** Each popup rolls a motion (Rise, Arc, Spring, Wave, Zig, Slam, Orbit; the set depends on tier), one of five easings (out cubic, out back, out expo, in-out sine, out elastic), a side and a seed at spawn. Letters wave, glitch or twinkle per tier. Everything is whole pixels, integer font sizes (12 to 32) and hard colour steps; fades are four steps; no alpha blending of particles (they blink out).
- **Streak tiers (presentation only, income unchanged).** Presses chain while each lands within `popup_streak_gap` (1.6 s) of the last. Score = chain length x (1 + Momentum stage x 0.35). Thresholds 8, 20, 45, 90, 180 give Gold, Ice, Rainbow, Chroma, Galaxy. At a steady hold (about 9 presses a second) that is roughly 1 s, 2 s, 5 s, 10 s and 20 s; standing on a pad (about 1 a second) Surge gets Gold in about 3 presses, and Galaxy takes about 75. A Momentum drop never takes a tier away mid-chain; a pause longer than the gap ends the chain (a tiny fizzle and sigh if it was Gold or better). Numbers live in `content/config/game.tres`.
- **Tier looks.** Gold: warm metal with a sweeping glint. Ice: glassy blues, a cold 1 px shiver and falling shards. Rainbow: seven hues cycling letter by letter. Chroma: red and cyan split edges, a white core and one-slot glitch jumps. Galaxy: a drifting nebula of indigo, violet, magenta and cyan with twinkling stars. Tier colours are fixed hex, like rarity colours, and the same in every zone; Plain follows the zone palette. A new tier shows NO name text (Nathan, same day: the tier is only the colour and treatment of the stacked gain number); it gets a ring, burst and chime. **No camera shake from presses or tiers at all** (Nathan): crits, tiers 3+ press the pad itself deeper (one extra texel) and shake it one texel sideways for 0.1 to 0.2 s instead; hitstop on crits stays.
- **Relic pulses are echoes.** Sim now reports which pad started a pulse (`pulse_source`, `pulse_order`) while it presses the neighbours. Each neighbour gets a dashed spark line from the source, then (0.09 s apart) its own smaller popup with a cyan diamond, a pad ripple and a soft double ping that steps up the pentatonic per neighbour.
- **Sound.** 12 new sounds from `tools/audio/gen_audio.py press` (own section, so existing files are byte-identical): a click per tier (`pad_press_1..5`), a flourish per tier-up (`tier_up_1..5`), `pulse_echo`, `streak_lost`. Quiet pad clicks silences tier clicks and pulse pings the same way as before; tier-up chimes always play (they are rare).
- **Access.** Reduce flashing freezes colour cycling and the white flash; Calm camera, Still meadow and Reduce flashing force plain Rise motion, no wave, glitch or shiver, and a quarter of the sparkle trail. Screen shake still follows Reduce screen shake. Popups hide under open menus as before.
- **Taste calls to confirm with Nathan:** the tier thresholds, whether Galaxy should be the top or a sixth tier (e.g. Void) should follow, and how loud the tier chimes should be.
- Not run in the cloud: the engine. CI runs the headless tests; the PC pass judges the look and sound.

## Settings and Esc menu refresh
- **Colours.** Each Settings tab and each Esc menu tile takes one fixed stat colour (Audio cyan, Display blue, Gameplay gold, Access green, Controls purple, Data pink; Stats gold, Attributes blue, Upgrades green, Relics purple, Travel cyan, Settings paper, Update Log mint). Panel border, title, row labels and tab outlines use it, like the gallery's stat cards.
- **Title Case is applied at display time** (`DisplayPanel.title_case`), not by editing registry strings, so rows added by other threads (Access, QoL, rebind screen) are covered automatically. Words with capitals or digits (VSync) are kept.
- **Layout untouched.** Rows still come from SettingsRegistry; only visuals changed, so parallel threads adding rows do not conflict.
- Not run in the cloud: the engine. The PC pass judges the colours and spacing.

## 2026-11-23 Quality-of-life bundle (v0.21.0)
- **Rebind with modifiers.** A binding is a keycode OR-ed with `KEY_MASK_SHIFT/CTRL/ALT/META`, so old saves (plain keycodes) still load. A modifier alone (Shift, Ctrl) binds when released with no other key pressed. Sprint (Shift) and Sprint lock (Ctrl) are now rebindable actions. A binding's modifiers must be held; extra held modifiers are tolerated, so Shift+C still crouches-slides while sprinting.
- **Save indicator.** "Saved" fades after each save, beside the Menu chip; a failed write shows red "Save failed" even with the indicator off (`EventBus.save_failed`). Setting: Gameplay > Save indicator.
- **Welcome Back card** replaces the 5 s toast: time away, each gain in its stat colour, a note when the offline cap was hit. Shown only after 1 minute or more away. Stays until Collect.
- **Rebirth confirm** card shows the Prestige and Rebirth Points you will get. Setting: Gameplay > Confirm rebirth (default on).
- Buy max and Buy x10 were dropped from this bundle at Nathan's request.
- Not run in the cloud: the engine. CI runs the headless tests; the PC pass judges card placement and the indicator.

## 2026-11-23: History screen
- **What.** New menu tile and window, History, opened through MenuRouter with the shared dither wipe and close X, in the same panel style as the Stats gallery. Sections: Income (last 10 minutes), Bests, Totals, Time in each zone.
- **Data.** `core/run_stats.gd` (`Sim.run_stats`) samples Cash per second every 5 s into a 120-sample ring (the session graph, not saved). Saved with the game, no save version bump because missing keys default: time per zone, longest pad chain, chains finished, highest Momentum stage, crits, best income.
- **Graph.** Log scale (income spans many orders of magnitude), 2 px bars, dotted quarter lines, a gold line under each rebirth. Pure sizing in `HistoryGraph.bar_heights`.
- **Best streak.** The streak tiers (Plain to Galaxy) in PR #144 are not on main yet, so "best streak" is the longest pad chain plus the highest Momentum stage. When #144 merges, swap or add its tier name to the Bests rows in `HistoryPanel.rows_for`.
- **Unlock.** Same gate as Stats (after the first press). Not run in the cloud: Godot itself; CI runs the headless tests, the PC pass checks the look.

## 2026-11-23: Popup stacking and stat caption (v0.24.2, Nathan: numbers still overlapped)
- A press now folds into ANY live number of the same stat that sits on the same pad or within 40 px of it and was last bumped under 1.2 s ago (was: same pad, 0.35 s). Different stats still take separate free lanes (now 10, including above and below). The carried float offset is capped at 90% of the rise, so a long run of presses keeps one number hovering instead of climbing away.
- Under each number, centred: the stat's display name in 12 px Pixelify, in the stat's own colour (StatStyle), outlined; while a hold stacks, " xN" follows it in the streak colour. The number keeps the streak colour. The caption sits 9 px plus 14% of the number's size below the baseline, so it holds up as the number grows through the font sizes.
| 2026-11-23 | The Larkmoor "sunset hitch" was the zone swap, fixed by threaded scene prefetch and sliced prop spawning (0.26.2); CI gets a 150 ms frame budget | PC profiling: 0 new pipelines, 1.5 ms script, hitch at +771 ms = swap time + stall. Stage trace: load 36, ready 22, occluders 170 ms. Earlier shader and audio warm-ups were guesses and are harmless but were not the cause. |

## 2026-11-23 Achievements and the Ledger (0.37.0)
- **Rewards are cosmetic only: a title.** No income, drop or balance effect, per the audit pick. The newest unlocked achievement with a title sets the Ledger's title.
- **40 achievements, 8 categories** (Presses, Meadow, Streaks, Relics, Rebirth, Growth, Quarry, Journey), plain names, no streak-tier words. One `.tres` each in `content/achievements/`; targets are content, not script.
- **Counters reuse History** (`RunStats` crits, chains, Momentum best) plus Sim totals. Stat achievements use saved **peaks** so spending never loses progress. A zone's first tier counts as opened only once the zone is entered.
- **Old saves are backfilled silently**, loading never replays unlocks, and the toast stays quiet during the tutorial.
- **No Bloom achievements yet**: Bloom is not built. Divine and Special relic grants are proposed in `docs/achievements.md`, not implemented.
- **Menu:** `Ledger` is a gallery tile after History (gold accent), a MenuRouter window like History, locked until Dewdrops unlock. Rows rebuild only when something changed.
- Verified: 2838 headless checks, 0 failed, and the boot smoke test is clean. Screenshots rendered in the cloud on software OpenGL (`tools/ledger_shots.tscn`); the real look is for the PC pass.

## Customizable HUD stat strip (2026-11-23, v0.33.0)
- **Decision (Nathan):** the strip gets deep customization: quick controls on the strip, one button for an edit mode with icon-only suggestion chips, a capped row count, a Default layout with Reset, and matching settings.
- **Model:** `core/hud_layout.gd` (pure, saved in the game dict as `hud_layout`, so it is per save). No entry for a zone means Default: the zone's own stats in ladder order, same as v0.29. The first edit copies that into an explicit ordered row list plus a `seen` list; a stat the zone gains later is appended once, so an old layout never hides new content. Saves from before this load as Default (no save version bump; the key is optional like `calendar`). Unknown ids are dropped on load.
- **Per zone:** each zone has its own layout, so the flower ladder and the Ember Quarry ladder never fight. Stats you have met in another zone are offered as suggestions after the zone's own hidden ones, so a pinned extra is possible.
- **Cap:** 10 rows (the Ember Quarry's full Default is 10, so the cap only binds when pinning extras or when a layout is full). The last row cannot be hidden, so the strip is never empty.
- **Quick controls:** right-click a row hides it (Settings > Gameplay can turn that off). The pencil under the strip (dim, shown once Dewdrops unlock) opens edit mode: every layout row shows with move up, move down and hide buttons, and under the strip a grid of 22 px icon chips (instant tooltip with the stat name, click to add), a Default or Custom row count, Reset (this zone) and Done. Opening any menu leaves edit mode. Done saves.
- **Settings (Gameplay tab):** Edit Stat Strip (closes the menu first, then starts edit mode), Reset Stat Strip (every zone, press twice), Strip Gain Rates (the small +x/s), Strip Unearned Rows (show a layout row before you have held it), Right-click Hides a Row. These display toggles are global (settings.cfg); the layout is per save. Not added to the Stats menu on purpose: one place for settings, and the strip itself is the other.
- **Side fix:** the strip panel now shrinks back when rows are hidden (it only ever grew before, because nothing resets a top-level PanelContainer's size).
- Not run in the cloud: the engine look of the pencil, glyphs and chips. `tools/hud_shot.tscn -- edit` captures it on the PC.

## 2026-11-23 Travel menu lists top-level areas only 

## 2026-11-23 Travel menu lists top-level areas only (v0.34.0)
Travel shows Meadow and Ember Quarry plus two locked "???" teaser rows (`travel_teased_rows` in game.tres). Larkmoor is inside the Meadow (`ZoneDef.travel_parent`), so its districts leave the list. The Meadow row lands in the furthest unlocked zone of the Meadow (Larkmoor once the first gate is open), or stays put if you are already inside it. Sub-area expand toggles removed.

## 2026-11-23 Menu tiles always show their names
Nathan wanted the hamburger menu words visible, not only on the focused tile. Tiles now always draw their name; a locked tile still says "Locked" while hovered. Grid is 3 columns (nine tiles fill 3x3) and tiles are 96 wide. New hover: a slanted band of 4x4 Bayer dither in the section colour sweeps across once (0.4 s), the icon bobs one texel, plus the existing lift. All off under reduced motion / flashing. Tooltips unchanged. Not run in-engine from the cloud.

## Popup banners (Banner autoload)
- `Banner.announce({title, lines, icon, color, duration, key, interrupt})` (ui/banner.gd, logic in core/banner_queue.gd). `show` is taken by CanvasLayer, so the call is `announce`.
- Bottom-middle, typed from the centre outward and collapsed back to it. The panel is a fixed size for the whole banner, so it never jitters. Queue holds 4, same key is a duplicate, a repeat within 6 s is dropped, `skip()` ends early.
- Reduced motion: new Access toggle "Still banners" (`FxConfig.reduce_motion`): banners show whole with no typing or collapse.
- Replaces the old DistrictBanner. Area arrival (core/area_banner.gd): name, then season/date from `/root/Calendar.now()` when that autoload exists, then time; with no calendar it shows the sky clock and period only. `ZoneDef.outdoor` (default true) turns it off for indoor zones. Larkmoor shows district banners, other zones show a zone banner on arrival and at boot.
- Calendar keys read: season (name or 0-3), month, day, hour, minute, period. Not wired: season_changed banner (waiting on the calendar thread's signal names).

## 2026-11-23 Clock chip centred, season shown once, zone title unclipped
- The clock chip centres on the screen (between the stats panel and the zone card, clamped to both). Squeeze levels are unchanged.
- The season appears once: the month line reads "Early Summer · Day 2" in the season accent, and the season accent is also the dial's bottom texel row. The separate "Summer" line is gone.
- The dial fills the chip's full inner height (1 texel inside the frame top and bottom) and sizes itself to the text height. Art: dithered sky, a rising and falling horizon with grass tufts, a sun or moon on its arc, twinkling stars at night.
- The zone card's Travel button moved to its own full-width row under the title. A 152 px card cannot fit "Ember Quarry" beside the button. Titles that still overflow drop to the small size.
- Not verified in-engine: cloud threads cannot run Godot. The PC QA thread should check the chip at 640x360 and at a wide frame, plus the Ember Quarry card.

## 2026-11-23 Clock dial follows the zone palette
- The dial reads the palette of the current zone (Palettes.for_zone) and recolours within a tenth of a second of a zone change. Meadow stays green.
- Ember Quarry's sun uses the amber role (4), not the dusty rose role (5), so it reads as ember. Other zones keep role 5.
- Not verified in-engine. The PC QA thread should check the dial in the meadow and in Ember Quarry, by day and at night.

## Hamburger menu layout (2026-11-24)
- **Why:** the menu's footer set the panel width, so the 3-column tile grid sat in a wide empty strip on the right (Nathan's v0.49.0 screenshot). The tile order also put Settings and Stats in the middle of the gameplay tiles.
- **What:** four columns, so the grid is exactly as wide as the menu. Tiles run Play (Upgrades, Relics, Attributes, Travel), then Info (Stats, History, Ledger, Update Log), with Settings alone on a full-width row. Groups are split by a dotted rule. `GalleryMenu.GROUPS` sets the row sizes. Keyboard and d-pad order follows the same sequence.
- **Taste pick, easy to reverse:** Settings is a full-width bar, not a small centred tile. If Nathan prefers a square tile, drop the `n == 1` expand line in `ui/gallery_menu.gd`.
- Not run in engine: no Godot in the cloud. `tests/test_gallery.gd` covers the order, groups and Settings neighbours. PC QA should check the menu at 1920x1080 and 800x600 for the empty strip, the footer alignment and the focus landing on Upgrades.

## Upgrades card feedback (2026-11-24)
- **Base:** built on #230's gallery (tabs, tiers, two-across `UpgradeCard`, centred exit). The gallery layout was not redone.
- **Whole card buys:** a click anywhere on the card buys (press starts the hold, release ends it). The Buy button still takes its own press and keyboard focus, so a click on it never buys twice. The card's press does not touch `_skip_pressed`.
- **Feedback:** the card pops (1.04 to 1), seven pixel sparks leave its centre (drawn, so no nodes), and the currency's header badge pops (1.18 to 1). All of it is skipped under Reduce Motion or Reduce Flashing, and the sounds stay.
- **Sizes:** the card is 56 px tall (was 50) and the list is 232 px (was 196), about four rows. Not checked in-engine: whether the taller panel clears the zone panel and the bottom bar at 640x360.
- **Lock text:** "Unlocks after 1 Nucleus reset" (was "Nucleuss").
- **Taste call for Nathan:** hover puts a faint wash on a card you can afford. Say if you want the hover left off.
- Not verified in-engine: the sparks, the pop timing and the taller panel. PC QA should check both zones with motion on and off.

## 2026-11-24 Achievement banner and the Achievements tile
- **Layout:** the unlock card is now a wide banner centred across the screen, its middle at 38% of the height (a bit above centre), 380 texels wide, so it sits clear of the bottom bar and the centre of the pads. A taste call made in this thread; Nathan can ask for another height.
- **Menus:** unlocks are held while any menu is open, and a banner up when a menu opens is cut short and shown again later. This replaces the old z-order-only rule, so a menu is never covered.
- **Look:** the banner unfurls from a sliver in eight whole steps (no smooth scale), Reduce Flashing turns off the dither ink. Per-section particle styles and chimes use existing sound files, so no new audio was added.
- **Naming:** the hamburger tile and the window title read "Achievements". The internal id `ledger` and the icon file stay, so saves and tests are unaffected.
- **Not run in-engine:** Godot is not available in the cloud. Unverified: the banner's real size and position at 640x360 and at other window sizes, the particle look, the unfurl timing and the chimes. PC QA should capture an unlock in each section and check it against an open menu.
- **Every banner waits for menus (PC QA, 2026-11-24):** the season banner and the zone banners (`Banner`, via `Banner.hold`) and the relic toast also wait while a menu is open, and a banner up when a menu opens is held back to the front of the queue and shown after it closes. PC QA saw the season banner cut across the Upgrades cards, and the achievement toast over Stats and Upgrades. Subtitles and tip cards are unchanged (tips already yield to open menus).

## Upgrades menu fit and menu layer (2026-11-24)
- **Cards:** stacked to three lines (name and level; now to next; pips and cost). The Buy button is gone: the whole card buys, and Enter or Space buys while the card has focus. Two across at 150 px, so the panel is about a third narrower.
- **Outline and dim:** affordable is a bright green frame; unaffordable is a red frame with the contents dimmed to 55%, so the two read apart. Maxed is gold, locked is dim.
- **Uniform tiers:** each tier's grid has a fixed width, so tier 2 matches tier 1.
- **Height:** the list takes what its tab needs, up to 180 px, then scrolls.
- **Menu layer:** a shown menu moves to the end of its parent (`MenuAnim.bring_front`), so the relic bar, momentum meter, sprint trail and HUD chips all draw under it. No HUD piece draws over an open menu. Every menu is covered: animated ones through `MenuAnim.attach`, the rest through `MenuAnim.front_on_show`.
- **Tab highlight:** one function (`Hud._apply_upgrade_tab`) sets the page and the highlight together, and runs on every select and refresh. Opening the menu picks the current zone's tab.
- Not verified in-engine: the new size at 640x360, the z order against each HUD piece, the dim levels. PC QA should check both zones and a click, a hold and a Enter buy.

## Menus clear of the meter, zone gifts only in Upgrades (2026-11-24)
- **Meter:** a centred menu whose column reaches the momentum meter's column stops 6 px above the meter, so the meter's corner is never covered. Menus that do not reach the meter's column stay centred on the frame. Chosen over hiding the meter while a menu is open, because the meter's state stays visible during a menu.
- **Attributes:** the Stats and Attributes page lists only Prestige and Rebirth Perk attributes. Zone gifts (Bloom, Nucleus) appear only in the Upgrades gallery, which already groups them. Chosen over filtering by zone, because a gift has one home and two places showing it would drift.
- Not verified in-engine: the panel's new height above the meter at 640x360, and the Attributes page with a Nucleus save. PC QA should check both.

## Every zone's gifts get a tab in Upgrades (2026-11-24)
- **Why:** #228 showed only the zone you stand in, so the quarry's Upgrades gallery was one lone "Nucleus Gifts" header. It read as empty.
- **Tabs:** every zone reset's gifts have a tab, locked or not. The zone you stand in comes first in the strip, then the others in reset order. Each tier already says what gates it.
- **Kept as is:** `group_shown` still hides a zone's contents until that zone opens. The HUD currency chips and the Stats index use it, so their behaviour does not change. The gallery uses the new `UpgradeText.tab_shown`.
- **Tab look:** the active tab is drawn in its accent colour with a solid underline, not a dotted focus box. The tab keeps the ">" marker and sweep on hover or focus. The title and pause menus keep their focus box.
- Not verified in-engine: the strip at 640x360 with two zones, and the tab order after a zone change. PC QA should check the meadow and the quarry.

## Tap-to-move ignores clicks on the GUI (2026-11-24)
- **Why:** with the Relics panel open, a click inside it drew the walk ring and dots under the panel. Godot only routes a click to `_unhandled_input` when no Control stopped it, and a panel background with PASS or IGNORE lets it through.
- **Rule:** `GuiGuard.covers` (ui/gui_guard.gd) checks rectangles of visible Controls at the click point. It counts STOP and PASS controls and any Panel or PanelContainer whatever its filter. It skips IGNORE labels and containers and full-screen layout roots, so floating numbers and the pixel view never block the world.
- **Pads and critters:** the same check stops a click on the GUI from pressing a pad or catching a critter under it. Clicks in the world are unchanged.
- **Menus:** no tap-to-move at all while a menu is open, since the walker is frozen then and a late walk after the menu closes would surprise.
- **Chosen over** `gui_get_hovered_control()`, because the hovered control is only updated on mouse motion and can be stale on a click. The check runs on the click's own position.
- Not verified in-engine: a click on the Relics panel, the HUD and a tooltip, and a click on empty meadow next to a panel edge. PC QA should check all four.

## Upgrade tabs follow keyboard focus (2026-11-24)
- **Why:** PC QA found that Left and Right moved the tab highlight in the quarry but left the cards on Nucleus. The tab only selected on press, so focus and selection drifted apart.
- **Fix:** a tab that gains focus selects its page, the same as a press. Mouse, Enter and pad all still work. Focus and selection now always agree.
- Not verified in-engine. PC QA should check Left and Right across both zones' tabs.

## 2026-11-24: Shared tooltips for the Stats and Attributes index
- The index's hover strip is gone, so the grid is taller (`IndexPanel.SCROLL_H` 150 to 200). Each card binds `Tip` to `TipText.index_row`: header with icon, name and stat colour; level or amount; effect now and next; cost; description; then a yellow "Click to open!". Buy says "Click to buy!" when affordable.
- Reason: one shared, pooled tooltip for every menu, instead of a per-menu strip. `TipHost` reuses its rows, labels and icons between shows.
- The stale "Prestige and RP" header is removed (both went in #209). Display settings drop their hover-to-hint lines; rows with a hint use the shared tooltip.
- Yellow is `TipText.CLICK` (#ffd93d). Not run in-engine: `tests/test_tooltips.gd` passed on CI's unit job after one fix (the "now" field). PC QA should hover each card, check spacing at 640x360 and a large UI scale, and buy one attribute.

## 2026-11-24: Popup text is crisp, and popups blink out instead of fading
- Popups drew with the popup face at import defaults (grey AA, light hinting), so the 640x360 base upscaled to soft edges. `CrispFont.theme_font` now applies the crisp settings to `PopupLabel` (`PressPopups`, `PopupNumber`, fx_bus).
- Taste call: no alpha fades. The last 30% of a popup blinks in 8 Hz steps (`PopupStyle.shows_now`); Reduce Flashing holds it solid, then cuts it. Outline stays 2 px. Pixelify has no single pixel unit, so no "native size" applies.
- Not verified in-engine: PC QA should check "+418K", "+100QnVg!" and the quarry's "Iron Ore" at 1x and 3x, with Reduce Flashing on and off.

## 2026-11-24 Tighter achievement banner (Nathan's feedback on #239)
- **Why:** Nathan said the merged banner had too much blank space and was too intrusive at small sizes. In his screenshot it ran into the right-hand stat strip.
- **What:** a tighter frame pad (5x3 texels, not the usual 8x6 from theme.md section 5, a deliberate deviation for this one card); the category icon at its native 16 texels; the card is 36% of the HUD width, clamped to 168 to 240 texels, so it scales with the window; the middle sits at 30% of the height, higher than before; the name and description wrap to two lines at most and then end in an ellipsis, so the card cannot grow taller; the shakes are softer (0.06 and 0.14).
- Not run in-engine. PC QA should check it at 640x360 and at a small window, beside the stat strip and the zone panel.

## Every zone's gifts get a tab in Upgrades (2026-11-24)
- **Why:** #228 showed only the zone you stand in, so the quarry's Upgrades gallery was one lone "Nucleus Gifts" header. It read as empty.
- **Tabs:** every zone reset's gifts have a tab, locked or not. The zone you stand in comes first in the strip, then the others in reset order. Each tier already says what gates it.
- **Kept as is:** `group_shown` still hides a zone's contents until that zone opens. The HUD currency chips and the Stats index use it, so their behaviour does not change. The gallery uses the new `UpgradeText.tab_shown`.
- **Tab look:** the active tab is drawn in its accent colour with a solid underline, not a dotted focus box. The tab keeps the ">" marker and sweep on hover or focus. The title and pause menus keep their focus box.
- Not verified in-engine: the strip at 640x360 with two zones, and the tab order after a zone change. PC QA should check the meadow and the quarry.

## Upgrade tabs follow keyboard focus (2026-11-24)
- **Why:** PC QA found that Left and Right moved the tab highlight in the quarry but left the cards on Nucleus. The tab only selected on press, so focus and selection drifted apart.
- **Fix:** a tab that gains focus selects its page, the same as a press. Mouse, Enter and pad all still work. Focus and selection now always agree.
- Not verified in-engine. PC QA should check Left and Right across both zones' tabs.

## WASD walks while a menu is open (2026-11-24)
- **Why:** opening any menu froze the walker, so a player could not walk while a panel was up. The ask was WASD only, with GUI clicks still blocked.
- **Rule:** `PadInput.move_vector` reads WASD by physical key while `menu_open` (`menu_walk_vector`, `walk_from_keys`). Arrows, d-pad and the left stick do not walk in a menu, because Godot's ui_* actions use them for menu focus. Pad users still cannot walk in a menu. That is a choice, not a gap.
- **Still blocked:** Space (jump) while a menu is open, because Space presses buttons. Typing in any LineEdit or TextEdit (Feedback, dev console) stops all walking. A Settings key rebind (`PadInput.key_capture`, set by the display panel) stops walking too, so W can be bound without moving.
- **Sprint and crouch** still work while walking in a menu. They are modifiers, and no menu uses Shift or C.
- **Tap-to-move:** a pending walk target is dropped when a menu opens or a field takes keys, so the walker does not keep walking after the menu is up.
- Not verified in-engine: walking with WASD under the Upgrades, Relics and Settings panels, typing in Feedback with W/A/S/D, and rebinding W in Settings. PC QA should check those four.
## Restored after the #220 split (lost text from the pre-split log)

### Restored lines under: 2026-11-23 Menu tiles always show their names
- Offline Sunlight uses the same `income_per_second` as the live tick, at idle factor 1 (Dewdrop boost, relics, Bloom and Sun-rate bonuses all included). Only Momentum is absent, because it is zero at load. A QA reading of 0.25/s against 0.88/s on a fresh save came from Dewdrops being 0 at load and later pressed; the new test pins offline rate / live rate = 1.

## 2026-11-23 Zone banner on zone entry only, area card swaps in place
- Nathan: the full banner plays when entering each zone, not each subarea. Walking into a district (Old Oak Crossing and so on) no longer calls `Banner.announce`; `ZonePanel.set_district` changes the top-right area card instead, with a crossfade of SWAP_OUT 0.1 s then SWAP_IN 0.2 s, stepped in quarters so it dithers. The fade is skipped when "Still banners" (FxConfig.reduce_motion) is on.
- Larkmoor is a zone (its own ZoneDef, scene and arch), so it gets a zone banner on arrival. This was the one case that used to get none. Its districts get none. If Nathan wants Larkmoor treated as part of the Meadow instead, change `_announce_zone_arrival` only.
- Zone banner styling: the border and title use the zone's palette role (`ZoneDef.theme_role`), and the panel fill uses the zone palette's ink (index 0) through a new optional `fill` key on the banner spec. Season tint is dropped for zone banners so Meadow and Larkmoor (same palette, different role) read apart. Hold 3 s (`ZONE_BANNER_HOLD`).
- `ui/district_banner.gd` is no longer used by anything. Left in place for a later cleanup PR.
- PC QA fixes in the same PR: Banner rebuilds its panel if the HUD that held it was freed (Quit to Title), so a later banner never touches a freed node, and `_tl` starts as a full timeline so no key can be missing. Tip cards hold while a banner shows and the next tip waits for it, so the Welcome card no longer covers a zone banner at 640x360.
- Not run in-engine from the cloud: the crossfade, the banner palette and the 640x360 overlap need a PC check.

## 2026-11-23 Popup Q gets a tail; popups use a derived font
- PC QA on v0.45.2: "+100QnVg!" read as "+1000nVg!" at popup size. Correction to the entry above: that atlas check used Spleen 6x12, but popups draw in Pixelify Sans 16 (`PopupLabel` in plinky_theme.tres). The Pixelify Q's tail sat under the bowl and the 2 px popup outline filled the gap, so it read as a 0.
- Fix: `fonts/PixelifySans-popup.ttf`, a derived copy of Pixelify Sans whose Q has a tail detached from the bowl by the bottom-right notch. Only Q changes, advance width is the same, and the family is renamed "Pixelify Sans Popup". Pixelify Sans is OFL 1.1 with no Reserved Font Name, so the derived copy is allowed. `PopupLabel` uses it. Titles, menus and the stock Q stay as they were. Built by `tools/build_popup_font.py`.
- Candidates compared at 16 px with the 2 px outline: a filled-corner descender and a stair tail both read as lowercase q, so the detached diagonal was chosen.
- QA finding 2: "1.5e15" shown as "+30d" at 3x. Not reproduced in the cloud. `NumberFormat.short(1.5e15)` gives "1.5Qd" (checked against a Python mirror of the formatter and now pinned in tests/test_format.gd), and the popup path (`PopupNumber.spawn`, `PressPopups._format`, `FxBus.bonus_popup`) passes the value straight through with no truncation. Nothing in the popup code produces a "d" suffix; the only "d" output is the skip duration in core/dev_commands.gd. Likely a probe or input mismatch. The PC probe should print the label's `.text` to settle it.
- Not run in engine: no Godot in the cloud. PC QA should check "+100QnVg!" and "+1.5Qd" at 1x and 3x, and "Quarry" in a popup.
- Offline credit now uses the day or night income rate you left with (the calendar advances after crediting), so offline Sunlight per second equals the live rate; before, advancing the clock first made the rate depend on when you came back (a test caught 1.08x). Verified with the headless suite (4393 checks, 0 failed).

## 2026-11-23 Banners build when they show; season toast lifts above the Momentum meter
- A zone banner is queued with a `resolve` Callable (Banner, `ui/banner.gd`). It is built when it is about to show, so it names the zone the walker is in then and reads the calendar as it is then. QA saw "Meadow" with a stale date after walking into Larkmoor. The payload had been composed when it was queued, from the boot arrival path, and waited in the queue. A resolved banner that is now indoor or a repeat of one just shown is dropped.
- The arrival at boot (1.2 s after start) goes through the same path, so it can no longer name a zone the walker has left.
- Bottom-centre banners lift clear of the Momentum meter (bottom-left, `Banner.avoid` set by the HUD) when the two would overlap. At 640x360 a wide season toast ("Long Light") covered the meter's right half. Lifted only when it overlaps, so the usual position is unchanged. The overlap test is `BannerQueue.bottom_clearance` (pure, tested).
- Not run in-engine from the cloud: the banner text after a Quit to Title, and the lifted position at 640x360 need a PC check.
- Offline pay is capped by design: passive income credits at `offline_income_fraction` (0.5) of the rate you left with, in one slice, so tending cannot compound it. This restores the locked rule that idle takes about twice as long as active play. The 12-slice compounding from #197 paid about 294x on a fresh save and is off (`offline_slices = 1`).

## HUD strip polish (2026-11-23)
- **Stable width:** the value column is 52 px and the gain column 68 px (right-aligned, clipped), so a ticking number never resizes the panel. The strip is a little wider than before when gain rates are on; turn off Strip Gain Rates to drop that column.
- **Cap:** `HudLayout.cap_for()` is 12 or the zone's own Default if longer, so the count never reads over its cap (the quarry's Default plus Seeds was 11 against a cap of 10). A zone-reset currency (Seeds) shows by default only in its own zone (main's `reset_for_currency` rule); it can still be pinned from the chips.
- **Edit mode:** the three boxed buttons per row became a frameless grip (drag the row, or Up and Down while the grip has focus) and a frameless hide mark, dim until the row is hovered. This drops the move up and move down buttons, so there is nothing to disable at either end.
- **Motion:** rows glide to new places, fade out when hidden and fade in when added, the grips and footer ease open in six steps, and chips pop in. All of it snaps under Reduce Motion or Reduce Flashing.
- Not run in-engine from the cloud; needs a PC capture.

## 2026-11-23 Popups slide clear of the zone panel
- PC QA: long popups such as "+100QnVg!" were cut off where the zone panel starts (the panel sits top right, x 480 to 632, and draws over the popup layer). Popups were only hidden under menus, never moved for the zone panel.
- Fix: `PopupClear.slide_clear` (ui/fx/popup_clear.gd) moves a popup left of the first blocker it overlaps, repeating if that lands on another. If there is no room left of the blocker, the popup is skipped for that frame instead of drawn half hidden. `HUD.clear_rects()` supplies the zone panel's global rect through `PopupNumber.keep_clear`, set in the same place as `under_menu`.
- Menus keep the existing behaviour: popups under an open menu are hidden. The clamp is only for the zone panel.
- I could not find PR #157 in history, so I could not compare against its clamp. This follows the existing viewport clamp in `_draw_pop`.
- Not run in engine: no Godot in the cloud. Tests in tests/test_popup_clear.gd cover the geometry. PC QA should check a popup on a pad beside the zone panel, with the panel open and with Travel open.

## 2026-11-23 Upgrades gallery and centred Bloom exit (minor)
- **Upgrades layout:** one tab per currency group (Prestige, Rebirth Perks, then each zone reset's gifts, named by `ZoneResetDef.menu_title`). Tabs come from the data, so a new reset gets its own tab with no HUD change. Within a tab, gifts are grouped into tiers by their unlock gate, each with a heading ("Tier 1: Open", "Tier 2: Unlocks After 2 Blooms"). Cards sit two across in a scroll list about 3.5 rows tall, so the panel fits above the bottom bar at 640x360.
- **Card outline:** green when the next level is affordable, red when not (the existing colour-safe tint), gold when maxed, dim while locked. The fill is transparent so the panel shows through. Taste call: gold for maxed is my pick; say if you want maxed to stay green.
- **Code:** `ui/upgrade_row.gd` is replaced by `ui/upgrade_card.gd` (same buy, hold-to-repeat and tick logic). `UpgradeText` gains `tier_key`, `tier_head` and `tab_name` (pure, tested).
- **Exit:** the coin, number, rays and ring stay centred. The coin steps down 4 to 3 to 2 to 1 pixels in place and is gone at the end of the exit, the number fades, the rays fold in and one pixel ring closes on the centre. Only a few motes (about ten a second, pixel-sized) drift from the centre into the HUD row, which still rolls up when they land. Calm (Reduce flashing, Still meadow, Calm camera) keeps the coin at full size and only fades it.
- **Timeline:** `BloomTimeline.fly_progress` is replaced by `exit_progress` and `exit_alpha`. The plan keys (`fly_end` and so on) keep their names so the existing timing tests still apply.
- Not run in-engine from the cloud: the tab and card layout at 640x360, the card text width at 150 px for the delta line, and the exit motion. `tools/bloom_shot.tscn` now samples the exit densely (`bloom_full_*` frames) for a PC capture.

## 2026-11-24: Pad captions lift their stat colour toward white
- Reasoning: PC QA found the quarry's "Iron Ore" caption (dark green) hard to read on dark rock. The lift keeps each stat's hue; on the mid quarry rock (8a3a2e) Iron Ore goes from 2.96:1 to 4.9:1, and a test holds every stat caption at 4:1 or better.
- Not verified in-engine: PC QA should check "Iron Ore" in the quarry at 1x and 3x.

## 2026-11-24: Dev console is a floating window with tab completion
A draggable, resizable window (not a full-width strip) so the game stays visible behind it, with the input focused on open. Commands are one table in core/dev_commands.gd, so help, Tab and the tests read the same list; the window only adds the node-level commands and layout. Errors use the accent colour with a "!" because the palette has no red role.
## 2026-11-24: Welcome Back as a gallery
- **Model and view split:** `core/welcome_back.gd` builds the four sections and every number as data (pure, tested in `tests/test_welcome_back.gd`). `ui/welcome_card.gd` and `ui/welcome_tile.gd` only draw it. The HUD's `_on_offline` now opens the card instead of a text ModalCard.
- **Tiles:** 46 px, seven across, so the card is 334 px wide at 640x360 and a full return of about 25 tiles stays under the frame height. Outline is the tier's rarity for currency and the relic's rarity for finds. Amounts sit at the bottom, green for gains and red for spends, through `StatStyle`.
- **Tooltips:** one shared `Tip` per tile: name in its stat colour, rarity tag, exact amount, rate and mastery detail. Frame takes the rarity colour.
- **Exact amounts:** `NumberFormat.exact()` adds thousands commas up to 10^15 and falls back to the short form beyond that.
- **Close:** Collect sparks and closes. Esc and the X close without sparks. There is no separate Close button. The sim already banked the time away, so closing either way loses nothing.
- **Taste call:** the count-up runs on open (staggered, about 1 s for a full return), and Collect is the only sparks moment. Say if you want the count-up off.
- Not run in-engine from the cloud: the 640x360 layout, the tooltip placement over the card, the spark timing and the sound. PC QA should capture the card after a long absence and after a short one.

## 2026-11-24: Welcome Back fit fixes (after QA on v0.60.0)
- **Width:** six tiles of 44 px (was seven of 46), so the card is about 300 px and centred at 640x360 it stops short of the zone card's left edge at x 480.
- **Height:** the grid grows with its content up to 190 px, then scrolls. This is the 25+ tile case: the card never leaves the frame, whatever the count.
- **Tooltips:** tile tips use the beside placement (`"beside": true`) and Collect joins the `tip_avoid` group, so a tip opens beside its tile and never covers the button. Cursor-placed tips ignore that group, which is why the tiles opt in.
- Not run in-engine from the cloud: the scroll appearing at 25+ tiles and the tip position. PC QA should capture both.

## 2026-11-24: Gain popups fold and stack
- Same-currency presses within 120 px fold into one number that rolls up to its total (was 40 px, so neighbouring pads never folded). Placement boxes count the stat caption, which is about 2.4 times the number's width, and a popup stacks above another when every fixed lane is taken. Reason: Nathan's Starbloom screenshot had captions overlapping as separate popups.

## 2026-11-24: Gain popups settle every frame
- Visible popups are pushed up each frame so no two boxes overlap (`PopupLanes.settle`, oldest first). Spawn-time placement alone let overlaps form when popups grew, merged or started late. Relic echoes (delayed popups) now merge and get placed too. Reason: Nathan's v0.62.2 screenshot showed two "+13.24K" popups stacked on each other.
## 2026-11-24: Title and loading screens follow the day (golden hour)
- **Time of day comes from the meadow's own sky.** `core/title_mood.gd` samples keyframes by `SkyModel` phase (midnight, dawn, sunrise, morning, noon, afternoon, golden hour, sunset, dusk), and the sun or moon rides `SkyModel.azimuth`. Reason: the title then shows the same arc, golden light and night shade as the game, and the look is tested in pure GDScript.
- **Palettes are per keyframe, not per zone.** Sky and far land take the eight palette roles, and the meadow ground takes four new ground roles (`g0` to `g3`), so golden hour warms the sky without turning the grass orange. Golden hour and sunset use the README banner's plum-to-orange sunset.
- **Scenery is graded, not repainted.** The scenery is baked once in meadow indices; the mood's tint multiplies it and a Bayer dither adds the night shade (`boot/title_scenery.gdshader`), the same way `day_night.gdshader` shades the meadow. Fireflies come out at night, birds fly by day.
- **Smooth transitions, one clock.** The title and loading screens share one `TitleBackground` clock. The chip in the bottom left names the time and runs the sky forward to the next stop over 1.6 s. Reason: nothing snaps.
- **Reduce Motion (call made):** the clock holds on golden hour, the parallax stays still, the chip jumps instantly, and the screen change cross-fades instead of sweeping. Reason: the sweep is motion, and the fade keeps the same ink colour.
- **Superseded 2026-11-24:** the ink wipe below was removed. See "Seamless scene handoff" at the bottom of this file.
- **Scene change is a themed wipe** (`boot/title_wipe.gdshader`): a slanted, dithered sweep in the mood's ink with a sun-coloured lead line, used for Continue, New Game, Saves slots and the loading screen's hand-off. Reason: replaces the plain ink dissolve.
- **Tagline (call made):** "+ Press. Walk. Bloom. +" from the README banner replaces "Press. Tally. Rebirth.", on both screens. Revert if the old line was intended.
- **Icon:** the 1024 master is drawn by `tools/art/gen_app_icon.py` on a 64 texel grid from the golden keyframe, with the existing walker sprite pasted unchanged. Reason: it matches the title and reads at 16 px.
- Not run in-engine from the cloud (no Godot here): the shader, the wipe and the chip need a PC look at each time of day and at Reduce Motion.

## 2026-11-24: Capstone gifts get their own unlock moment and icons (minor)
- **Why:** a capstone is the biggest purchase in a tree, and a plain card buy pop reads the same as a level-1 gift.
- **Moment:** the first and only level of a crown emits `EventBus.attribute_bought`. `Juice` (`ui/fx/fx_bus.gd`) names it in a banner in its currency's colour, plays the divine relic chime and calls the existing milestone flash and shake. The flash checks Reduce Flashing and the shake checks Reduce Shake, as they already did. The banner is gentle under Reduce Motion.
- **Gallery:** the card, its tier heading ("Unlocks After 5 Blooms") and its Tip are data-driven, so the crown gets them with no HUD change.
- **Icons:** `bloom_crown` (a gold crown with a seed gem) and `nucleus_crown` (a teal crystal crown with an ember gem), at 8, 12, 16, 24 and 32 px. They were drawn by one generator from a single outline per size, not hand-placed per size, so they are a deviation from the staged-icon rule. Redraw at PC QA if they read poorly at 640x360.
- Not run in the engine: check the banner width and the crown icons on the Bloom and Nucleus tabs with a screenshot.

## 2026-11-24: Title peak has no slope-driven lit mask
- The far-mountain lit face and snow used the ridge slope per column, so the lit/snow choice changed at one column and drew a straight vertical edge down the central peak (PC QA, v0.68.0; still hard after the dithered-slope version at noon, x 343 to 351). The lit weight and snow no longer read the slope: facets follow the diagonal gullies, and snow is a flat dither at 60% by height. Trade-off: fewer slope-shaded faces on the far ridge. Not confirmed in-engine yet: PC QA should compare the six keyframes after merge.
## 2026-11-24: One label per currency that accumulates
- Nathan's v0.70.0 screenshot showed same-currency gains from neighbouring pads as a column of separate "+1.080Qd Thistle Down" labels. Now a same-stat gain within 200 px of a live label folds into that label. The label holds its spot with no motion, ticks its number up and pops on each gain. It rises and fades only after 0.5 s (`QUIET_AFTER`) with no new gain. Separate labels appear only for different currencies, or for pads more than 200 px apart. Reduce Motion still snaps the number. The 200 px radius and 0.5 s quiet time are my picks and are tunable constants.

## 2026-11-24: Gain labels hold through standing presses and every source combines
- **Why:** standing presses arrive about every 2 s, longer than the 0.5 s quiet window, so each one started a new label and a column formed (Nathan's "+7.28 Starbloom Petals" screenshot). Pad presses, auto presses, relic echoes and Sunlight bonuses also had their own labels. Reason: Nathan asked for every number label from a button to combine.
- **Fold range 360 px (supersedes 200 px above).** A same-currency gain within 360 px of a live label folds into it, holding or floating, and running holds take it too. A QA run had two Dewdrop labels 208 px apart. My pick: a pad row or cluster is about that wide.
- **Adaptive quiet window.** A label of a currency waits 1.5 times that currency's smoothed gain interval (`QUIET_MULT`), kept between 0.5 s (`QUIET_AFTER`) and 4 s (`QUIET_MAX`). So a 2 s cadence holds for 3 s. A gap longer than 4 s is capped so one long pause does not stretch the window.
- **Floating labels catch gains.** A floating label that takes a same-currency gain holds again where it is. It does not jump or rise while it is holding.
- **All sources route through one accumulator.** `FxBus.auto_press` used to pass a screen position plus a lift and no caption; it now passes the pad's world position and its caption. `FxBus.bonus_popup` goes through `press()` with Sunlight's caption, so it can fold into a Sunlight label from a pad.
- Not run in-engine from the cloud: the 2 s cadence, the 360 px fold and the fade timing need a PC look (a standing pad and a bonus at once). Tests cover the cadence, floating capture, a 420 px split and a running fold (`tests/test_popup_lanes.gd`).
- **Currency rarity goes under the name.** Each currency card in Stats wears the rarity tag its pads wear ("UNCOMMON STATISTIC"), taken from the pads that pay it, or the pads that spend it when none pays it (Embers reads Common). Sunlight is the starter statistic, shown as STARTER STATISTIC in yellow. Currencies no pad touches (Seeds, Core Shards, Rebirths, Prestige, Rebirth Points) show no line. The tag sits in the new `kicker` slot of the shared Tip, so it lands between the name and the description. Not run in-engine from the cloud: the tag width and the kicker spacing need a PC look.

## 2026-11-24: Gain numbers stay over the button that gave them
- **Why:** Nathan saw a gain from one button appear over a neighbouring button. A label kept its first pad's position when a 360 px cross-pad fold added gains from other pads, so the number sat off its source. He chose "Same pad only" on the decision card.
- **Rule:** a gain folds only into a live label from the same pad and of the same currency, running holds included. A neighbouring pad's gain starts its own number over its own button. This supersedes the 360 px cross-pad fold above, and `MERGE_NEAR` is removed.
- **Kept:** repeat gains from one pad still add up on one number, and the adaptive quiet window still applies. Crowded pads still shift labels sideways or stack them above the button (`PopupLanes`).
- **Sunlight bonuses** have their own key, so they fold only with each other and not with a pad's Sunlight number. Say so if that splits a Sunlight number you wanted combined.
- Not run in-engine from the cloud: PC QA should check a neighbouring pad's gain and a standing press on one pad.

## 2026-11-24: Gain numbers and their pad caption stay apart
- **Why:** on the first-hour playtest, "+6.89" sat right on "Clover Leaves" and the two read as one block. The caption started 2 px under the number's baseline, and the number's 2 px outline and 2 px wave motion pushed into it.
- **Change:** the caption starts 6 px under the number's baseline (`CAPTION_DROP` 18 px, with the caption 14 px down). The placement box grows to match, so stacked popups still clear the caption.
- Verified by rendering two neighbouring-pad presses under Xvfb with software Vulkan: the caption now sits clearly under the number. The suite passes, 6141 checks, 0 failed.
- Not checked: a caption running into the zone panel. The panel clip still shortens "Clover Leaves" there, which is the existing clear-zone behaviour and not part of this change.
## 2026-11-24: Seamless scene handoff
- **Why:** Play, Quit to title and the loading screen's hand-off went through an ink wipe that filled the screen, then a plain `change_scene`. The game's first frames showed the default grey, and the zone art loaded on the main thread, so the screen went black or grey and cut.
- **Rule:** `SceneSwap` (`boot/scene_swap.gd`) captures the frame being left and covers the window with it. The next scene is swapped in underneath, draws four warm frames there, then the cover sweeps away to reveal it (`boot/scene_reveal.gdshader`, a dithered edge with a sun-coloured lead line). Under Reduce Motion the cover cross-fades. Nothing is drawn in a flat colour.
- **Loading:** Play goes to the loading screen in handoff mode. It opens at the title's time of day, loads the slot's zone art on a worker thread (`Loading Larkmoor art... 62%`) and keeps the scene alive until the game has used it. It waits while a swap is still revealing, so no leave is dropped.
- **Label:** ASCII dots, because Spleen has no ellipsis glyph.
- **Same backdrop, no sweep (Nathan, 24 Nov):** when the next screen draws the same backdrop, the swap is a plain foreground change with no cover. Title to loading is the case, since the loading screen opens at the title's time of day on the same backdrop. Real backdrop changes keep the sweep (boot to title, loading to game, pause menu to title).
- **Warm-up is adaptive:** the cover holds until the arriving scene draws at least four frames and two frames in a row cost about the same, capped at 40. A slow PC warms longer; a fast one reveals sooner.
- Verified headless under Xvfb with lavapipe: boot, title, Play, loading, game, and the Reduce Motion path. No frame is near-black or flat, and the largest frame-to-frame jump is a sweep, not a cut (`tools/transition_frames.tscn`). Not run on the PC: the zone-art label for Larkmoor and Ember Quarry (a cold zone load), the Quit to title path, and the feel of the sweep at full speed.
- **Queued swaps (fix, 24 Nov):** a swap requested while another is still revealing now waits for it. It used to return at once, so a Play pressed during the title's fade-in was dropped after the title had already set its starting flag, and the title stayed up for good. Reproduced headless with a save present by pressing Play at 0 s and 0.3 s after the title appears (`TRANSITION_SETTLE=<seconds>` on `tools/transition_frames.tscn`); both now reach the game.
## 2026-11-24: Zone currencies open their gifts and show a full card
- **Why:** Seeds and Core Shards only said "You have X". Nathan wanted the card to say what the currency is and how it is earned, and a click to take you to the gifts it buys.
- **Rule:** a zone currency's HUD row and its Upgrades badge use `TipText.currency` (copy in `ZoneResetDef.currency_body`, the page line in `gift_blurb`). The row is clickable, and its card ends on "Click to open!". A click opens Upgrades on that zone's tab, and a click while the menu is open only moves to the tab. The badge's card has no call to action, since the menu is already open.
- **Gifts menu:** each page has a centred head in its currency colour, tier heads take the zone colour, and the grid is centred. The list has one height for every tab (the tallest tab, up to the cap), so a tab switch or a buy never resizes the panel. The header balances have a fixed width. `ZoneResetDef.plural_name` fixes "Nucleuss" to "Nuclei".
- Not run in-engine from the cloud: the Seeds card, the Bloom and Nucleus pages and the one-size panel were rendered headless under xvfb (`tools/gifts_shot.tscn`). The Core Shards card was covered by a world gate tooltip in that harness and is checked by `tests/test_zone_currency.gd`. PC QA should click both rows and both tabs.
## 2026-11-24: HUD gain label beside each statistic
- **Why:** Nathan wants the stat strip to show what a stat just earned, without a per-gain number in the world. The new label is a small "+123" right of the stats panel, level with its row, with the income rate ("+x/s") moved just past it.
- **Source:** `EventBus.button_pressed` (every pad press, auto and relic pulses included). Bonus payouts are not a source; see the 2026-11-24 pad-only entry below. Idle income is not a gain here, so the label stays hidden while a stat only ticks up passively.
- **Behaviour:** a run starts at the stat's first gain and sums every gain until HOLD (3 s) after the last one, then fades and drifts up over OUT (0.4 s). A gain during the run keeps adding to the same number; a gain after the run starts again from zero. It hides when its row is hidden.
- **Colour:** the streak tier of the latest pad press (`Juice.last_tier`), using the same `PopupStyle` colours as the world numbers. Tier 0 uses the stat's own colour. A bonus payout uses whatever tier the last press had.
- **Performance:** one pooled `HudGainLabel` per row, and the sums live in `HudGainTally`. No node is made per gain. Sparkles are a fixed pool of six per label.
- **Reduce Motion:** the label keeps its fade and drops the rise, the jump and the sparkles.
- Not run in-engine from the cloud: check the label's position beside a long value, the "+x/s" moving past it, and the sparkles on a crit.

## 2026-11-24: HUD gain labels follow pad presses only
- **Why:** PC QA on v0.85.2 saw "+X" beside Sunlight after Sprout presses, not Dewdrops. Traced in-engine: finishing a pad row fires the streak bonus (`bonus_gained`), which pays `streak_bonus_seconds` of income to every passive stat. Sunlight is passive, Dewdrops is not, so the label went to Sunlight. The Sunlight gain was real, but the stat strip should show what the pad that was pressed gave.
- **Decision:** the stat label takes its gains from `EventBus.button_pressed` only (the pad's `reward_stat`). `bonus_gained` is no longer connected to the HUD. Streak and critter payouts keep their gold popup at the walker or critter (`main.gd` `_on_bonus_gained`), which already shows the Sunlight payout.
- **Not chosen:** showing bonus payouts on the stat labels. A bonus would look like a press on Sunlight, which the player did not make.
- **Check in-engine:** three `sim.try_press` calls on `sprout_1..3` leave only the `dewdrop` label visible (before the fix, a `sunlight` label appeared too).

## 2026-11-24: Income rate shows only with a recent gain
- **Why:** PC QA on #358: the "+x/s" income rate beside each row sat on screen while nothing was pressed, and Nathan wants the strip quiet until something is gained.
- **Decision:** a row's "+x/s" rate shows only while that row's gain label is up (a pad gain in the last 3.4 s). Idle income is no longer shown there. The Strip Gain Rates setting still turns the rate off entirely. The prestige row's multiplier is not a rate and keeps its old rule.
- **Cause of the flicker:** the stats refresh set the rate's visibility on its own timer, which overrode the per-frame placement. The refresh no longer touches visibility.
- **Check in-engine:** idle, the Sunlight rate is hidden. A simulated Sunlight gain shows the rate beside the gain label, and both hide after the fade.
- **Open:** if Nathan wants idle income visible after all, the change is one condition in `_place_rates`.

## 2026-11-24: Income rate stays visible; gain label sits after it (reverses the entry above)
- **Why:** the coordinator's review of #366: the "+x/s" income rate is long-standing information that Nathan never asked to hide. It only looked like a stray label in QA. Hiding it while idle was the wrong call.
- **Decision:** the rate shows whenever the row has income, as before. The gain label now sits just past the rate instead of between the panel and the rate. The rate never moves when a gain appears or fades, and the gain label never overlaps it. Only the gain label's own width changes the strip's extent, and only while it is up.
- **Check in-engine:** Sunlight's rate sat at x=93 idle and while a gain was up, and at x=93 after the fade. The gain label sat at x=133, which is 93 + rate width 37 + 3.
- **Not done:** no animation on the gain label's position, so nothing glides or jumps.

## 2026-11-24: Banner time-of-day words use the sun, not the raw clock (17:28 was Dusk)
- **Cause:** `AreaBanner.period_of` sets its word bands on the sun phase (0.25 sunrise, 0.75 sunset), but the banner passed it the clock fraction. A clock of 0.73 (17:28) fell in the Dusk band (below 0.8). The zone banner's fallback also passed the sun phase where the clock fraction was expected.
- **Fix:** `period_of` takes a clock fraction and converts it with `SkyModel.phase_of_clock` at the sky's daylight, so the bands stay on the sun. `compose` takes the clock fraction and daylight. `main.gd` converts `sky.clock_phase()` to the clock with `clock_of_phase`, and passes the sky's daylight.
- **Boundaries:** the sun-phase bands are unchanged. Dusk starts at sun phase 0.7, which is 17:46 at daylight 0.6, about 86 minutes before sunset at 19:12. If QA wants Dusk later, change the 0.7 band in `period_of`; that is a taste call.
- **Tests:** `tests/test_banner.gd` checks the dawn, noon and sunset clock fractions, 17:28 as Afternoon, and the fallback line "17:28 - Afternoon".
- **Not run in-engine:** the cloud cannot run Godot.

## 2026-11-24: Sprint tag matches the HUD frame and text
- **Why:** Nathan's screenshot of "SPRINTING ENABLED" above the Momentum panel looked dim, dark green and borderless, unlike the cream text in the panel's green notched frame. Cause in code: the tag used a plain square StyleBoxFlat plate with a 1px dim edge, not the AsciiBox frame, and it took a per-state green (`RelicStyle.good`, or `accent` for HELD) with a 2px ink outline that likely thins the 14px glyph strokes (not confirmed in-engine).
- **Decision:** the tag uses `AsciiBox.make(PANEL, 6, 2)`, the same frame as the panel and the relic and achievement toasts, with `RelicStyle.text` for both states and no font outline. The state is still shown by the word.
- **Not chosen:** keeping HELD in the accent yellow. It is a one-line change if Nathan wants the colour back.
- **Checked:** the other toasts. Relic and achievement toasts already use AsciiBox. The subtitle bar keeps its ink plate with no green frame, on purpose, so captions read over the world.
- **Check in-engine:** hold Shift and tap Ctrl. The tag should show cream text in the notched green frame, centred over the panel, with no resize of the Momentum panel.
- **Not run in-engine:** the cloud cannot run Godot.

## 2026-11-24: Upgrades menu uses a tier rail
- **Decision:** each zone's gift page is a tier rail on the left (one row per tier, its gate in the tier's colour, e.g. "2  Requires 1 Bloom") and the chosen tier's gifts two across on the right. The rail follows the mouse, Up and Down with keyboard and pad, and opens on the frontier tier (the first tier with a gift open and not maxed). Tier colours are palette roles 3, 6, 4, 5, 7, then the currency colour for a sixth tier.
- **Why:** the old page stacked six tiers in one scrolling list with small cards, which read as cluttered. Nathan picked the rail from three mockups (tier chips, a five-across gallery, the rail), and asked for coloured tiers and "Requires N Bloom(s)" gates.
- **Not chosen:** the five-across gallery (all 15 gifts at once, too dense) and the tier chips (cramped gate labels at 640 px). A description line under the gifts was dropped at Nathan's request; the shared Tip on each card carries the detail.
- **Kept:** `UpgradeText.tier_head` keeps its "Unlocks After" wording, which tests read. The rail uses the new `UpgradeText.tier_gate`.
- **Checked:** `tests/run.gd` passes headless (6839 checks, 0 failed). The gifts capture (`tools/gifts_shot.tscn`) and a tier-switch check ran under Godot 4.7.2 with lavapipe. The panel stays 523 by 262 across tiers and tabs.
- **Not run in-engine on the PC:** the look on a real GPU, and the feel of the rail hover and focus.
## 2026-11-24: Bloom and Nucleus ritual, themed moments and a gift card
- Picked by Nathan from three mockups: themed moments per reset (Bloom petals and a light shaft, Nucleus streaks, core and shards) plus a bigger Gift Ready card. Reduce flashing and Still meadow keep the calm fade; world and hover tips are held while the ritual runs.
## 2026-11-24: Sprint tag centred over the Momentum panel
- **Why:** PC QA batch 99 on v0.89.29 saw the tag on the panel's left edge, about 27 px off centre (a 138 px tag on a 192 px panel).
- **Decision:** the tag centres on the panel's width, floored to a whole pixel, and is re-placed every frame it shows, since its width changes with the state.
- **Colour:** the tag's font colour is `RelicStyle.text` (palette index 7, paper, cream in every zone). An in-engine capture at Zone 1 shows cream. QA's "green" report matches the pre-#428 tag, so the editor probably still runs the old code. Re-check after a pull and F5.
- **Check in-engine:** hold Shift, then tap Ctrl. The tag's centre sits over the panel's centre, and the tag is cream.
- **Not run on the PC:** the capture was a headless Godot 4.7.2 run under xvfb in the cloud, not Nathan's machine.
