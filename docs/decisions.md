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
| 2026-11-22 | Relics: own stacks of every relic, equip relic types into 3 slots (+1 at 5 and 20 rebirths), equipped types apply all stacks | Makes drops a choice, keeps stacking, and gives rebirths a second reward. Swapping is free so it stays quick. |
| 2026-11-22 | Eight rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Special, with Hypixel SkyBlock colours | Nathan asked. Replaces the 3-tier spec. Special has drop weight 0 (events and achievements only). |
| 2026-11-22 | Rarity colours are fixed hex, not palette roles | A tier must read the same in every zone. Frames use exact colour; tooltip text lightens Rare and Epic to reach 4.5:1 on ink. |
| 2026-11-22 | Drop rolls pick a rarity by weight first, then a relic inside it | Divine stays rare however many relics each tier gains. Weights 60, 25, 9, 4, 1.5, 0.4, 0.1, 0. |
| 2026-11-22 | Equip rules: one slot per relic type, no dupes in slots, tooltip shows next-stack gain | Duplicates are stacks, so a second slot for the same type would add nothing. |
| 2026-11-22 | Divine and Special never drop randomly (rebirths and achievements only); Epic+ drops get a coloured toast and pad flash; slots stay a rebirth reward | Nathan approved all three. |
