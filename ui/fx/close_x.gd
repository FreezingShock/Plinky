class_name CloseX
extends Control
## The X in the top right of a menu panel. One component for every panel: CloseX.attach(panel, on_close).
## It is a sibling of the panel (added right after it in the same parent), so the panel's container layout never
## touches it, and it follows the panel's position, size and visibility every frame, even while the panel slides.
## It draws its own frame (AsciiBox) and glyph, handles its own click, Enter and pad A, and keeps no state that
## can stick: spamming it just calls on_close each time.
## The arms grow out from the centre in steps each time the panel opens; on hover they reach one texel further and
## thicken; pressing sinks it with an accent fill. Reduce motion / flashing shows it fully grown and still.

const SIZE: float = 13.0
const INSET: Vector2 = Vector2(5.0, 3.0)
const GROW_SPEED: float = 5.0     ## full growth in 0.2 s
const HOVER_SPEED: float = 10.0
const HEADER_GAP: float = 26.0     ## width of the spacer a panel header reserves so the X never sits against its text
const ARM: int = 3                ## arm length in texels at rest; hover adds one

var grow: float = 0.0
var hover_t: float = 0.0

var _host: Control
var _on_close: Callable
var _down: bool = false
var _hover: bool = false
var _box_normal: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, 0.0, 0.0)
var _box_hover: AsciiBox = AsciiBox.make(AsciiBox.Kind.HOVER, 0.0, 0.0)
var _box_press: AsciiBox = AsciiBox.make(AsciiBox.Kind.PRESSED, 0.0, 0.0)


static func attach(host: Control, on_close: Callable) -> CloseX:
	var x := CloseX.new()
	x._host = host
	x._on_close = on_close
	var parent: Node = host.get_parent()
	if parent != null:
		parent.add_child(x)        # after the host, so it draws above it and gets the click first
	else:
		host.add_child(x)
	return x


## True when this X belongs to the given panel.
func follows(panel: Control) -> bool:
	return _host == panel


## Pure: where the X sits, relative to the host's own top left.
static func anchor(host_size: Vector2) -> Vector2:
	return Vector2(host_size.x - SIZE - INSET.x, INSET.y)


## Pure: arm length in whole texels for a grow and hover progress.
static func reach(g: float, h: float) -> int:
	var base: int = roundi(clampf(g, 0.0, 1.0) * float(ARM))
	return base + (1 if (g >= 1.0 and h >= 0.5) else 0)


static func calm() -> bool:
	return FxConfig.still() or FxConfig.reduce_flashing


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	z_index = 2
	if _host != null:
		_host.visibility_changed.connect(_on_host_visibility)
		_host.tree_exiting.connect(queue_free)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false)
	_follow()
	_on_host_visibility()


func _on_host_visibility() -> void:
	if _host != null and _host.visible:
		grow = 1.0 if calm() else 0.0
		hover_t = 0.0
	_follow()


## Closes the panel. The click, Enter and pad A all end up here; tests call it directly.
func press() -> void:
	if _on_close.is_valid():
		_on_close.call()


func _follow() -> void:
	if _host == null:
		return
	visible = _host.visible
	size = Vector2(SIZE, SIZE)
	position = (_host.position + anchor(_host.size)).floor() + Vector2(0.0, 1.0 if _down else 0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			if is_inside_tree():
				grab_focus()
			accept_event()
			queue_redraw()
		else:
			var was_down: bool = _down
			_down = false
			accept_event()
			queue_redraw()
			if was_down and Rect2(Vector2.ZERO, size).has_point((event as InputEventMouseButton).position):
				press()
	elif event.is_action_pressed(&"ui_accept") and has_focus():
		accept_event()
		press()


func _process(delta: float) -> void:
	if _host == null:
		return
	_follow()
	if not visible:
		return
	var g0: float = grow
	var h0: float = hover_t
	if calm():
		grow = 1.0
		hover_t = 0.0
	else:
		grow = minf(1.0, grow + GROW_SPEED * delta)
		hover_t = move_toward(hover_t, 1.0 if (_hover or has_focus()) else 0.0, HOVER_SPEED * delta)
	if grow != g0 or hover_t != h0 or has_focus():
		queue_redraw()


func _draw() -> void:
	var box: AsciiBox = _box_press if _down else (_box_hover if (_hover or has_focus()) else _box_normal)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var n: int = reach(grow, hover_t)
	var col: Color = RelicStyle.ink if _down else (RelicStyle.accent if hover_t >= 0.5 else RelicStyle.text)
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
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), RelicStyle.accent)
