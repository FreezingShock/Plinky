class_name SaveIndicator
extends Label
## A small "Saved" note that fades in the corner after every save, and "Save failed" in red if the write did not
## work. Off with Settings > Gameplay > Save indicator. Listens to EventBus; owns nothing else.

const SHOW_TIME: float = 1.6
const FADE_TIME: float = 0.5

static var enabled: bool = true

var _left: float = 0.0


func _init() -> void:
	theme_type_variation = &"CaptionLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	z_index = 120


func connect_bus(bus: Node) -> void:
	bus.game_saved.connect(show_note.bind("Saved", StatStyle.BUY_GREEN))
	bus.save_failed.connect(show_note.bind("Save failed", StatStyle.BUY_RED))


func show_note(text_in: String, col: Color) -> void:
	if not enabled and col != StatStyle.BUY_RED:
		return
	text = text_in
	add_theme_color_override("font_color", col)
	_left = SHOW_TIME + FADE_TIME
	modulate.a = 1.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	modulate.a = clampf(_left / FADE_TIME, 0.0, 1.0)
