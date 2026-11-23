class_name DistrictBanner
extends PanelContainer
## Names a district when the walker enters it ("Heronmere"). Screen-centred, 40% down, ASCII panel like the relic toast,
## fades after a moment. world/larkmoor_scene.gd reports districts; main.gd calls show_name() on a change.

const LIFETIME: float = 2.2
const CENTER_Y: float = 0.4   ## centre of the card sits 40% down the screen (a 60/40 split), clear of the top bar

var _label: Label
var _tween: Tween


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AsciiBox.panel())
	_label = Label.new()
	_label.theme_type_variation = &"TitleLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_process(false)


func show_name(text: String) -> void:
	_label.text = text
	reset_size()
	visible = true
	set_process(true)
	_place()
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(LIFETIME - 0.5)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func() -> void:
		visible = false
		set_process(false))


func _process(_delta: float) -> void:
	_place()


## Centred on the whole screen, not on the gap between panels. The parent is the HUD, which spans the frame.
func _place() -> void:
	var host: Control = get_parent() as Control
	if host == null:
		return
	var sz: Vector2 = size.max(get_combined_minimum_size())
	position = Vector2((host.size.x - sz.x) * 0.5, host.size.y * CENTER_Y - sz.y * 0.5).floor()
