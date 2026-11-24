# Plinky decisions log

Format: date, decision, one line of reasoning. Newest at the bottom. The build agent appends here. Project-side decisions made in the Claude Project go here too (SPEC section 8).

| Date | Decision | Reasoning |
|---|---|---|
| 2026-11-21 | Engine: Godot 4.7.x stable, standard build, GDScript only | Spec, assumed. Needed for Forward+ and normal-based outlines. |
| 2026-11-21 | Renderer: Forward+ | Normal texture only available in Forward+ (Godot docs). |
| 2026-11-21 | Camera: 30 degrees down, 45 degrees yaw, orthographic | Clean 2:1 pixel lines. |
| 2026-11-21 | Internal resolution 640x360, whole-number scale | Fits 1080p x3, 1440p x4, 4K x6. |
| 2026-11-21 | Platform: Windows first, Mac second, no web export | Forward+ does not target browsers. Depth-only outline is the fallback if web matters later. |
| 2026-11-21 | Save: one local JSON, autosave every 30 seconds | Spec, assumed. Simplest that meets the loop. |
| 2026-11-21 | Out of scope: multiplayer, leaderboards, monetization | Spec, assumed. Keeps the first release small. |
| 2026-11-22 | Name: Plinky | Nathan chose it on the look board. Steam exact-term search, USPTO and itch.io checks still open. |
| 2026-11-22 | Palette roles fixed as indices 0 to 7 in every zone | One rule lets a single prop set work in every zone with no new art. |
| 2026-11-22 | Rebirth flash inverts the palette by reversing index order | Gives a true inversion without a second palette. |
| 2026-11-22 | Name risk: PlinkIdle (Steam, app 3684530) shares the Plink root | Same genre and root. Nathan decides whether this matters before public use. |
| 2026-11-22 | Name risk: Plinko is a known game show and gambling genre | Players may read Plinky as Plinko. Keep the look and store copy distinct. |
| 2026-11-22 | Rebirths boost Multiplier gain only; removed (1 + rebirths) from cash_per_second | Nathan confirmed. The spec had both, which counted rebirths twice. |
| 2026-11-22 | Zone 1 base cash set to 0.25 per second, gate at 9 rebirths, gate lands at about 10.8 minutes | Nathan wants the gate near the 10-minute fun target. At 0.1 per second the gate was at 28 minutes, which was too slow. |
| 2026-11-22 | Autoload names: `Fx` = renderer (shader uniforms), `Juice` = UI effects | Fx owns shader uniforms per SPEC. Both PRs add their own project.godot line. |
| 2026-11-22 | Main scene uses the baked 2D meadow with texel-space walker/pads, renderer view bound but empty | Fastest playable path. 3D scene content comes later. |
| 2026-11-22 | ZoneDef.pad_buttons maps scene pad anchors to button ids | Keeps scenes number-free and data driven. |
| 2026-11-22 | Relic effects in Sim: PRESS_RATE and CRIT_DAMAGE are multipliers (1 + total); double press doubles the reward (cost paid once); pulse presses same-row neighbours; slots unlock on rebirth actions, not the reb stat | PR #5 left these open. Revisit in balance. |

---

# Decisions: Core and cross-cutting

Foundation decisions from 21 Nov (the engine, camera, resolution, save) and any decision that spans several areas. Index: [README](README.md). Append new decisions to the end of this file as `## <date>: <title>` with one line of reasoning.

## 2026-11-23 Capital Qd and Qn again
- Nathan asked for Qd and Qn capitalised. This reverses the lowercase q from PR #193, which QA raised because a Q in "+100QnVg" read as a 0 at popup size. Only Qd and Qn change (`N_SMALL`, `UNITS`, tests). qg, qq, qe and qi stay lowercase, so compound names now mix cases (a name with Qd next to one with qg). Taste call to revisit: capitalise the rest too, or keep the split.
- Atlas check (not in engine): Spleen 6x12 capital Q has a one-pixel tail that separates it from 0 at 4x zoom. The tail is the only difference, so PC QA should look at "+100QnVg" and "1.5Qd" in a popup at 1x and 3x.
- Not run in engine: no Godot in the cloud. CI runs the headless tests.

## 2026-11-24 Camera: follow and free modes, zoom around the walker unless panning
- Follow is the default and has no offset: the view eases onto the walker. Free mode starts only on a right or middle drag, edge pan, or stick pan, and ends on recentre (Home or C) or when the idle return settles the offset to zero.
- Wheel and +/- zoom in follow mode keep the view on the walker, so a far cursor never flings it. In free mode they zoom to the cursor (the world point under it stays put). Keyboard zoom anchors at screen centre.
- Edge pan runs only while the pointer moves, never over GUI. A resting cursor at a window edge or over the HUD clock does not pan. The old drift was 152 texels in 3 s in a headless probe.
- A window focus loss ends a drag, so a release that happens elsewhere cannot leave the view stuck in drag mode.
- Reduce motion turns off the same polish layers as Calm camera (look-ahead, punch, drift, jump lift).
- `WorldCamera.view_rect()` returns the visible rect in zone texels (rounded outward). Streaming reads it instead of the old GraphicsQuality route.
- Not run in engine: the cloud has no PC, so the button click path and the moving-pointer edge pan are covered by headless tests only. PC QA should check them.
