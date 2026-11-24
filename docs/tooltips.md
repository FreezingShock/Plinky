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
| `kicker` | one rich line straight under the title, above the body. Currency cards use it for their rarity tag. |
| `icon` | file name under assets/icons, drawn 16 px beside the title |
| `body` | prose, Spleen 12, wraps at 150 texels (short text keeps its natural width) |
| `lines` | rich lines: an Array of lines, each an Array of segments: a String, `Tip.seg(text, colour)`, or `Tip.icon(name)` |
| `hint` | last line, dim unless `hint_color` is set |
| `color` | border tint (rarity or stat colour) |
| `beside` | true = sit beside the hovered control (relic slots) instead of at the cursor |
| `roomy` | true = wider gaps between the header, lines, description and hint (Stats and Attributes cards) |

An empty spec (null, or nothing in it) shows nothing.

## Colour rules (one look everywhere)

- Stat names and icons use their stat colour: `StatStyle.color(id)` (Cash gold, Multiplier blue, Rebirths violet...).
- Numbers: `StatStyle.BUY_GREEN` for a gain or an affordable cost, `StatStyle.BUY_RED` for a cost you cannot pay (`StatStyle.buy(can)`).
- Rarity is one all-caps tag in the bold display face (`Tip.tag`, `TipText.rarity_tag`): rarity then type, in rarity colour, e.g. UNCOMMON BUTTON, RARE RELIC. Border uses the rarity colour too. The relic drop toast uses the same face. Currency cards in Stats wear the rarity of the pads that pay them, as a `kicker` under the name. Sunlight reads STARTER STATISTIC in yellow. A currency no pad touches has no line.
- Copy for existing UI lives in `ui/tip_text.gd`; pad specs in `PadTooltip.spec_for`.
- Call to action: the last line of a tooltip you can click is yellow, `TipText.click_color()`. Use "Click to open!" for a
  card that opens a page, and "Click to buy!" for a control that buys (the Buy button). A disabled buy says what is
  needed instead, in red, with no yellow line.
- Stats and Attributes cards: `TipText.index_row(row)` builds the spec from a `StatIndex` row. Header with icon, name
  and stat colour; the level or amount; the effect now and next; the cost; the description; then the yellow line.
  The index has no info strip under it: the grid uses that height.

## Pooling

- `TipHost` is the only tooltip panel, and it keeps its rows, labels and icons in pools. A show takes nodes from the pool
  and parks them again when the tip changes, instead of building and freeing them each time. Parked nodes sit under a
  hidden node inside the host, so they are freed with it.
- Adding a new tooltip needs no node work. Do not make a second panel or a per-menu label for hover text.
- Tests: `tests/test_tooltips.gd` checks that showing the same tip, or switching tips, builds no new nodes once warm.

## Behaviour

- Minecraft-style and instant: no hover delay, no grace window, no fade. A bound control shows its tip on the frame the
  mouse reaches it, the tip follows the cursor, and it is gone on the frame the mouse leaves. Nothing lingers.
- The host asks the viewport which control is under the mouse every frame, so it never depends on `mouse_entered` /
  `mouse_exited` and is right at any stretch scale. A bound control under the mouse (or a bound ancestor of what is
  under it) stays up for as long as the mouse rests there.
- Keyboard or pad focus shows at once under the control (flips above near the bottom).
- Moving straight onto another bound control swaps to its tip on the same frame.
- Godot's built-in `tooltip_text` is not used anywhere: it has its own delay that we cannot turn off per control.
- Pressing a bound button hides its tip until the mouse leaves it.
- Drawn in the 640x360 stretch view and clamped to the visible rect. Borrows the theme of the control it describes
  and sets Spleen / Pixelify explicitly, so the font is never the default.
- Binding a control whose mouse_filter is IGNORE switches it to PASS so it can see the mouse; clicks still pass through.
- Tests: tests/test_tooltips.gd (spec, colours, fonts, instant show and hide, on-screen clamp, pooling, index cards).

## Writing tooltips

Say what it does and what it costs in one or two lines. Title is the noun; hint is the next step or why it is
unavailable. No jargon the HUD does not already use,.
