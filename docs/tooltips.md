# Tooltips

One system, one call. `Tip` (ui/tip.gd) binds a themed tooltip to any Control; `TipHost` (ui/tip_host.gd) is the single
panel it drives. There is no autoload: the host is created on first use under the scene root (CanvasLayer 120).
Every tooltip in the game goes through it: HUD, settings, upgrades, zone menu, Stats and Attributes index, pads, relics.
Do not use Godot's built-in `tooltip_text` and do not add a second tooltip node.

## Use it

```gdscript
Tip.bind(button, "Opens the relic screen.")                                   # prose only
Tip.bind(slot, func() -> Variant: return TipText.relic(def, n, equipped, "")) # rebuilt every time it shows
Tip.bind_all(row, spec)           # the container and every Control directly inside it
Tip.set_spec(row, new_spec)       # change later; refreshes if showing
Tip.unbind(row)
Tip.show_free(tree, spec, at)     # not a Control (a pad): call every frame while hovered
Tip.hide_free(tree)
Tip.hide_all()                    # when a menu closes
```

## Spec (a Dictionary, or a String for prose only)

| key | meaning |
|---|---|
| `title` | Pixelify Sans 16. `title_color`, else `color`, else paper. |
| `icon` | file name under assets/icons, drawn 16 px beside the title |
| `body` | prose, Spleen 12, wraps at 150 texels (short text keeps its natural width) |
| `lines` | rich lines: an Array of lines, each an Array of segments: a String, `Tip.seg(text, colour)`, or `Tip.icon(name)` |
| `hint` | last line, dim unless `hint_color` is set |
| `color` | border tint (rarity or stat colour) |
| `beside` | true = sit beside the hovered control (relic slots) instead of at the cursor |

An empty spec (null, or nothing in it) shows nothing.

## Colour rules (one look everywhere)

- Stat names and icons use their stat colour: `StatStyle.color(id)` (Cash gold, Multiplier blue, Rebirths violet...).
- Numbers: `StatStyle.BUY_GREEN` for a gain or an affordable cost, `StatStyle.BUY_RED` for a cost you cannot pay (`StatStyle.buy(can)`).
- Rarity is one all-caps tag in the bold display face (`Tip.tag`, `TipText.rarity_tag`): rarity then type, in rarity colour, e.g. UNCOMMON BUTTON, RARE RELIC. Border uses the rarity colour too. The relic drop toast uses the same face.
- Copy for existing UI lives in `ui/tip_text.gd`; pad specs in `PadTooltip.spec_for`.

## Behaviour

- The host asks the viewport which control is under the mouse every frame, so it never depends on `mouse_entered` /
  `mouse_exited` and is right at any stretch scale. A bound control under the mouse (or a bound ancestor of what is
  under it) shows after 0.35 s and stays up for as long as the mouse rests there. It hides 0.10 s after the mouse leaves.
- Keyboard or pad focus shows after 0.08 s under the control (flips above near the bottom).
- Moving straight onto another bound control, or within 0.3 s of the last tip, shows instantly.
- Pressing a bound button hides its tip until the mouse leaves it.
- Drawn in the 640x360 stretch view and clamped to the visible rect. Borrows the theme of the control it describes
  and sets Spleen / Pixelify explicitly, so the font is never the default.
- Binding a control whose mouse_filter is IGNORE switches it to PASS so it can see the mouse; clicks still pass through.
- Tests: tests/test_tooltips.gd (spec, colours, fonts, 1.5 s hold, grace, on-screen clamp).

## Writing tooltips

Say what it does and what it costs in one or two lines. Title is the noun; hint is the next step or why it is
unavailable. No jargon the HUD does not already use,.
