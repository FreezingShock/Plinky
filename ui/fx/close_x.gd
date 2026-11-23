class_name CloseX
extends PixelButton
## The X in the top right of a menu panel. One component for every panel: CloseX.attach(panel, on_close).
## It floats over the panel's corner (top_level, so the panel's layout ignores it) and follows the panel each frame,
## even while the panel slides. The arms grow out from the centre in steps each time the panel opens; on hover
## they reach one texel further and thicken, and pressing sinks it with an accent fill.
## Progress values ease per frame, no tweens, so spamming it never stacks animations.
## Reduce motion / reduce flashing show it fully grown with no hover pop.

const SIZE: float = 13.0
const INSET: Vector2 = Vector2(5.0, 3.0)
const GROW_SPEED: float = 5.0     ## full growth in 0.2 s
const HOVER_SPEED: float = 10.0
const ARM: int = 3                ## arm length in texels at rest; hover adds one

var grow: float = 0.0
var hover_t: float = 0.0

var _host: Control
var _on_close: Callable


static func attach(host: Control, on_close: Callable) -> CloseX:
	var x := CloseX.new()
	x._host = host
	x._on_close = on_close
	host.add_child(x)
	return x


## Pure: where the X sits, in the host's own coordinates.
static func anchor(host_size: Vector2) -> Vector2:
	return Vector2(host_size.x - SIZE - INSET.x, INSET.y)


## Pure: arm length in whole texels for a grow and hover progress.
static func reach(g: float, h: float) -> int:
	var base: int = roundi(clampf(g, 0.0, 1.0) * float(ARM))
	return base + (1 if (g >= 1.0 and h >= 0.5) else 0)


static func calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_flashing


func _ready() -> void:
	super._ready()
	top_level = true
	z_index = 2
	text = ""
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0))
	add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, 0.0, 0.0))
	add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, 0.0, 0.0))
	add_theme_stylebox_override("disabled", AsciiBox.make(AsciiBox.Kind.DISABLED, 0.0, 0.0))
	pressed.connect(_on_pressed)
	if _host != null:
		_host.visibility_changed.connect(_on_host_visibility)
	_on_host_visibility()


func _on_host_visibility() -> void:
	if _host != null and _host.visible:
		grow = 1.0 if calm() else 0.0
		hover_t = 0.0
		_follow()


func _on_pressed() -> void:
	if _on_close.is_valid():
		_on_close.call()


func _follow() -> void:
	if _host == null:
		return
	var sink: float = 1.0 if (get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED) else 0.0
	global_position = _host.global_position + anchor(_host.size) + Vector2(0.0, sink)
	size = Vector2(SIZE, SIZE)


func _process(delta: float) -> void:
	super._process(delta)
	if _host == null or not _host.visible:
		return
	_follow()
	var g0: float = grow
	var h0: float = hover_t
	if calm():
		grow = 1.0
		hover_t = 0.0
	else:
		grow = minf(1.0, grow + GROW_SPEED * delta)
		hover_t = move_toward(hover_t, 1.0 if (is_hovered() or has_focus()) else 0.0, HOVER_SPEED * delta)
	if grow != g0 or hover_t != h0:
		queue_redraw()


func _draw() -> void:
	super._draw()
	var n: int = reach(grow, hover_t)
	var mode: DrawMode = get_draw_mode()
	var col: Color = RelicStyle.ink if (mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED) else (RelicStyle.accent if hover_t >= 0.5 else RelicStyle.text)
	var c: float = floorf(SIZE * 0.5)
	var thick: bool = hover_t >= 0.5
	for k in range(0, n + 1):
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				var px: float = c + float(sx * k)
				var py: float = c + float(sy * k)
				draw_rect(Rect2(px, py, 1.0, 1.0), col)
				if thick:
					draw_rect(Rect2(px + (1.0 if sx < 0 else -1.0), py, 1.0, 1.0), col)
