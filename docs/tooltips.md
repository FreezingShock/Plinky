# Tooltips

One system, one call. `Tip` (ui/tip.gd) binds a themed tooltip to any Control; `TipHost` (ui/tip_host.gd) is the single
panel it drives. There is no autoload: the host is created on first use under the scene root (CanvasLayer 120), so
nothing in project.godot changes.

## Use it

```gdscript
Tip.bind(button, "Opens the relic screen.")                                   # body only
Tip.bind(row, {"title": "Luck", "body": "Better drops.", "hint": "Rebirth to raise it."})
Tip.bind(slot, func() -> Variant: return {"title": name, "body": describe()}) # rebuilt every time it shows
Tip.bind_all(row, spec)             # the container and every Control directly inside it
Tip.set_spec(row, new_spec)       # change text later; refreshes if showing
Tip.unbind(row)
```

Spec parts, all optional: `title` (Pixelify Sans), `body` (Spleen, wraps at 150 texels), `hint` (dim line),
`color` (border and title tint, e.g. a rarity colour). Use palette roles from `RelicStyle`, never raw hex.

For something that is not a Control (a pad in the world), call every frame while the cursor is over it:

```gdscript
Tip.show_free(get_tree(), spec, get_local_mouse_position())
Tip.hide_free(get_tree())         # when it leaves
```

`Tip.hide_all()` dismisses whatever is showing (call it when a menu closes).

## Behaviour

- Mouse: shows after 0.35 s and follows the cursor. Keyboard or pad focus: shows after 0.08 s, anchored under the
  control (flips above near the bottom). Moving to the next tip within 0.3 s shows it instantly.
- Hides on mouse exit, focus loss, button press, control hidden, or control freed.
- Drawn in the 640x360 stretch view, so it scales with the UI. Clamped to the visible rect (bleed included).
- Binding a control whose mouse_filter is IGNORE switches it to PASS so it can see the mouse; clicks still pass through.
- Tests: tests/test_tooltips.gd. Not run in-engine from the cloud; the PC pass should hover a HUD button.

## Writing tooltips

Say what it does and what it costs in one or two lines. Title is the noun; hint is the next step or why it is
unavailable ("Need 40 more Cash"). No jargon the HUD does not already use, and never the word Button.

## Where the words live

`ui/tip_text.gd` (TipText) holds the copy for the HUD: stat rows, bottom buttons, upgrades, zone travel, gate bar. Settings rows reuse each row's `hint`.
