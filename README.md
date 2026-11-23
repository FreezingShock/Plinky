# Plinky
How work flows (PRs, merge, PC QA, resolving threads): docs/workflow.md. Rules for agents: CLAUDE.md.

## Main scene notes (integration)
- Autoloads: EventBus, GameState, Save, Fx (render/fx_driver.gd), Juice (ui/fx/fx_bus.gd). Stretch mode `viewport` at 640x360, integer scale.
- The meadow is a 3D render baked to pixel art (world/meadow3d_scene.tscn: ground with bleed, y-sorted occluder sprites, anchors); pads come from `ZoneDef.pad_buttons` in anchor order (Pad0, Pad1, ...). The renderer's 3D `PixelViewport` is bound to `Fx` but has no 3D content yet, so dither/palette-shift/ripples are not visible over the baked art. The HUD, pad ring, walker are placeholder `_draw` shapes.
- Relics: `GameState.relics` (same object as `Sim.relics`). Drops roll on every successful press. Effects: CASH_MULT on stats flagged `relics_boost_income`, MULT_GAIN on `relics_boost_gain`, PRESS_RATE and CRIT_DAMAGE multiply their base, DOUBLE_CHANCE doubles the reward, PULSE_CHANCE presses neighbours in the same row. Slots unlock on the count of rebirth actions.
