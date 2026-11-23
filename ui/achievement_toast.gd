class_name AchievementToast
extends PanelContainer
## Small card that slides in when an achievement unlocks: the category icon, "Achievement" in the category colour, the
## name, and the title it earns if any. Unlocks that arrive together queue up and show one after another.
## Add to the HUD (it anchors itself bottom centre) and call bind() once. Pure presentation: it never changes the game.

const LIFETIME: float = 2.8
const GAP: float = 0.2
const MAX_QUEUE: int = 6

var _icon: TextureRect
var _kicker: Label
var _name: Label
var _sub: Label
var _tween: Tween
var _queue: Array[AchievementDef] = []
var _showing: bool = false


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -80.0      # centred left of the middle, clear of the tip cards on the right
	offset_right = -80.0
	offset_top = -92.0       # its bottom edge sits just above the relic toast
	offset_bottom = -92.0
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(LedgerPanel.ICON_SIZE, LedgerPanel.ICON_SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_kicker = Label.new()
	_kicker.text = "ACHIEVEMENT"
	_kicker.add_theme_font_override("font", StatStyle.tag_font())
	_kicker.add_theme_font_size_override("font_size", StatStyle.TAG_SIZE)
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_kicker)
	_name = Label.new()
	_name.theme_type_variation = &"TitleLabel"
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_name)
	_sub = Label.new()
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_sub)


## Listens to the Sim directly so the toast works in tests and tools; `enabled` lets Main hold it back during the tutorial.
var enabled: Callable = Callable()


func bind(sim: Sim) -> void:
	sim.achievement_unlocked.connect(func(id: StringName) -> void:
		var d: AchievementDef = sim.achievements.defs.get(id) as AchievementDef
		if d != null and (not enabled.is_valid() or bool(enabled.call())):
			enqueue(d))


func enqueue(d: AchievementDef) -> void:
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append(d)
	if not _showing:
		_next()


func queued() -> int:
	return _queue.size()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var d: AchievementDef = _queue.pop_front()
	var col: Color = LedgerPanel.color_of(d.category)
	add_theme_stylebox_override("panel", AsciiBox.panel(col))
	_icon.texture = LedgerPanel.icon_for(d.category, false)
	_kicker.add_theme_color_override("font_color", col)
	_name.text = d.display_name
	_name.add_theme_color_override("font_color", col)
	_sub.text = ("Title: %s" % d.title) if d.title != "" else Achievements.category_name(d.category)
	_sub.add_theme_color_override("font_color", RelicStyle.text if d.title != "" else RelicStyle.dim)
	visible = true
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	if not is_inside_tree():   # tools and tests that build a toast off-tree still get the content and the queue
		return
	await get_tree().process_frame   # let the labels report their new size before fitting the card to them
	if not is_inside_tree():
		return
	reset_size()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(LIFETIME - 0.4)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_interval(GAP)
	_tween.tween_callback(_next)
