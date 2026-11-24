class_name WelcomeTile
extends Control
## One tile in the Welcome Back gallery: a 16 px icon over its amount, in a box outlined in its rarity colour (a flower
## row's colour for currency, the relic's for a find). Everything is drawn here, with no child nodes, so the count-up and
## the lift cost nothing to animate. Hover or focus lifts the icon a texel and brightens the box. The card binds the
## tooltip with Tip.bind, so this node knows nothing about the game.

const W: float = 46.0
const H: float = 36.0
const ICON: float = 16.0

var icon_tex: Texture2D
var outline: Color = Color.WHITE
var amount_color: Color = Color.WHITE
## The BigNum a count-up runs to, or null for a tile that only shows its text.
var amount: BigNum = null
var prefix: String = ""
## The amount as it reads once counted up.
var text: String = ""
var _shown: String = ""
var _lift: int = 0
var _rest: AsciiBox
var _lit: AsciiBox


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func setup(p_icon: Texture2D, p_outline: Color, p_amount_color: Color, p_amount: BigNum, p_prefix: String, p_text: String) -> void:
	icon_tex = p_icon
	outline = p_outline
	amount_color = p_amount_color
	amount = p_amount
	prefix = p_prefix
	text = p_text
	_rest = AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0)
	_rest.edge_override = outline
	_lit = AsciiBox.make(AsciiBox.Kind.SELECT, 0.0, 0.0)
	_lit.edge_override = outline.lightened(0.25)
	show_amount(1.0, 0)


## progress 0..1 counts a numeric amount up from nothing (the text is the prefix and the number so far). lift_px raises
## the icon for the pop. Tiles with no amount ignore progress and show their text.
func show_amount(progress: float, lift_px: int) -> void:
	var s: String = text
	if amount != null and progress < 1.0:
		s = prefix + NumberFormat.format(amount.mul(BigNum.from_float(clampf(progress, 0.0, 1.0))))
	if s == _shown and lift_px == _lift:
		return
	_shown = s
	_lift = lift_px
	queue_redraw()


func _draw() -> void:
	if _rest == null:
		return
	var lit: bool = is_hovered() or has_focus()
	(_lit if lit else _rest).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var lift: int = _lift + (1 if lit and not _calm() else 0)
	if icon_tex != null:
		draw_texture(icon_tex, Vector2(floorf((size.x - ICON) * 0.5), 4.0 - float(lift)), Color.WHITE)
	var font: Font = get_theme_font(&"font")
	var fs: int = get_theme_font_size(&"font_size")
	var tw: float = font.get_string_size(_shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	font.draw_string(get_canvas_item(), Vector2(floorf((size.x - tw) * 0.5), H - 6.0), _shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, amount_color)


static func _calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_motion or FxConfig.reduce_flashing
