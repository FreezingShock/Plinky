class_name DistrictBanner
extends PanelContainer
## Names a district when the walker enters it ("Heronmere"). Top centre of the HUD, ASCII panel like the relic toast,
## fades after a moment. world/larkmoor_scene.gd reports districts; main.gd calls show_name() on a change.

const LIFETIME: float = 2.2

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
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	position.y = 18.0


func show_name(text: String) -> void:
	_label.text = text
	reset_size()
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position.y = 18.0
	visible = true
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(LIFETIME - 0.5)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func() -> void: visible = false)
