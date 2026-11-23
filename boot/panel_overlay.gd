class_name PanelOverlay
extends Control
## Hosts one menu panel centred over the boot or title screen, with a dim scrim behind it. Clicking the scrim, the
## panel's animated X or Esc closes it. Used for the Update Log, Saves and Credits so every panel behaves the same.

signal opened
signal closed

const SCRIM_ALPHA: float = 0.55

var panel: Control
var _scrim: ColorRect


## Builds the overlay around `p` (a hidden panel) and adds it to `parent`.
static func host(parent: Control, p: Control, ink: Color, theme_res: Theme) -> PanelOverlay:
	var o := PanelOverlay.new()
	o.panel = p
	o.theme = theme_res
	o._scrim = ColorRect.new()
	o._scrim.color = Color(ink, SCRIM_ALPHA)
	o._scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(o)
	o.add_child(o._scrim)
	o._scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(p)
	p.visible = false
	CloseX.attach(p, o.close)
	return o


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_center)


func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	panel.visible = true
	_center()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	panel.visible = false
	closed.emit()


func _center() -> void:
	if panel == null or not visible:
		return
	panel.reset_size()
	var sz: Vector2 = panel.get_combined_minimum_size()
	panel.size = sz
	panel.position = ((size - sz) * 0.5).floor()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and not panel.get_global_rect().has_point(mb.global_position):
		close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"plinky_back"):
		close()
		get_viewport().set_input_as_handled()
