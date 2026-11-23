class_name PerfOverlay
extends CanvasLayer
## F3 toggles a small frame-time readout: fps, average and worst frame (ms) over the last 240 frames, draw
## calls, nodes, script time, video memory and the graphics quality. Hidden by default and free while hidden
## (it stops sampling). Debug tool: it does not follow the pixel grid, and it is never in screenshots unless shown.
## Attach once from main.gd: PerfOverlay.attach(self).

const REFRESH: float = 0.25      # seconds between text updates

var stats: PerfStats = PerfStats.new()
var _label: Label
var _clock: float = 0.0


static func attach(parent: Node) -> PerfOverlay:
	var o := PerfOverlay.new()
	o.name = "PerfOverlay"
	parent.add_child(o)
	if parent is Control and o._label != null:
		o._label.theme = (parent as Control).theme  # the project's body font, when the parent has the theme
	return o


func _init() -> void:
	layer = 127
	visible = false
	_label = Label.new()
	_label.position = Vector2(4.0, 4.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(_label)
	set_process(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		stats.clear()
		_clock = REFRESH


func _process(delta: float) -> void:
	stats.push(delta * 1000.0)
	_clock += delta
	if _clock < REFRESH:
		return
	_clock = 0.0
	_label.text = text()


## The readout. Public so the benchmark and tests can check it.
func text() -> String:
	var s: Dictionary = stats.summary()
	var c: Dictionary = PerfStats.counters()
	var warn: String = "  OVER BUDGET" if float(s.p95) > PerfStats.BUDGET_MS * 1.05 else ""
	return "%d fps  %.1f ms avg  %.1f p95  %.1f max%s\ndraws %d  nodes %d  script %.2f ms  vram %.0f MB\nquality %s" % [
		roundi(float(s.fps)), float(s.avg), float(s.p95), float(s.max), warn,
		int(c.draw_calls), int(c.nodes), float(c.script_ms), float(c.vram_mb), GraphicsQuality.label()]
