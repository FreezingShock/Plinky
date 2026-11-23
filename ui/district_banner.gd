class_name DistrictBanner
extends PanelContainer
## Slim title card shown when the walker enters an area, and for short notices ("The way on is still being forged").
## Top-centre under the bars, about 1.6 s, slides down a few texels as it fades in and out. Area cards are themed by
## the zone's own palette: border and name in the area's colour, the area's 7x7 icon either side of the name, a dotted
## rule under it and the zone name small above. world/larkmoor_scene.gd reports districts; main.gd calls show_area().

const LIFETIME: float = 1.6
const FADE_IN: float = 0.18
const FADE_OUT: float = 0.35
const TOP_Y: float = 0.15    ## top edge of the card, as a share of the screen height (clear of the top bars)
const SLIDE: float = 4.0     ## texels it drops while fading in
const NAME_SIZE: int = 12

var _kicker: Label
var _label: Label
var _deco: Control
var _tween: Tween
var _icon_id: String = ""
var _col: Color = Color.WHITE
var _rule: Color = Color.WHITE
var _slide: float = 0.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	_kicker = Label.new()
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_kicker)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(_icon_ctl(false))
	_label = Label.new()
	_label.theme_type_variation = &"TitleLabel"
	_label.add_theme_font_size_override("font_size", NAME_SIZE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	row.add_child(_icon_ctl(true))
	_deco = Control.new()
	_deco.custom_minimum_size = Vector2(0, 3)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_rule)
	v.add_child(_deco)
	set_process(false)


func _icon_ctl(_mirror: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(AreaIcons.SIZE, AreaIcons.SIZE)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		if _icon_id != "":
			AreaIcons.draw(c, _icon_id, Vector2.ZERO, _col))
	return c


## Area card: themed by `zone_id`'s palette and the area's own role and icon.
func show_area(a: AreaDef, zone: ZoneDef) -> void:
	var cols: PackedColorArray = Palettes.colors(Palettes.for_zone(a.zone))
	var col: Color = cols[clampi(a.theme_role, 0, 7)]
	_theme(cols, col, a.icon)
	_kicker.text = zone.display_name.to_upper() if zone != null else ""
	_kicker.visible = _kicker.text != ""
	_present(a.display_name)


## Plain notice, no zone theme beyond the current palette.
func show_name(text: String) -> void:
	_theme(PackedColorArray(), RelicStyle.text, "")
	_kicker.visible = false
	_present(text)


## Season arrival: the event's name in the season's accent, its one-line effect small above.
func show_event(event_name: String, blurb: String, col: Color) -> void:
	_theme(PackedColorArray(), col, "")
	_kicker.text = blurb
	_kicker.visible = blurb != ""
	_present(event_name)


func _theme(cols: PackedColorArray, col: Color, icon: String) -> void:
	var ink: Color = RelicStyle.ink
	var edge: Color = col
	var dim: Color = RelicStyle.dim
	if cols.size() >= 8:
		ink = cols[0]
		dim = cols[3]
		edge = col.lerp(cols[3], 0.35)
	_col = col
	_rule = edge
	_icon_id = icon
	add_theme_stylebox_override("panel", _box(edge, ink))
	_label.add_theme_color_override("font_color", col)
	_kicker.add_theme_color_override("font_color", dim)
	for c: Node in find_children("*", "Control", true, false):
		(c as Control).queue_redraw()


static func _box(edge: Color, ink: Color) -> AsciiBox:
	var b := AsciiBox.make(AsciiBox.Kind.PANEL, 8.0, 3.0)
	b.edge_override = edge
	b.fill_override = ink
	return b


func _draw_rule() -> void:
	var w: int = int(_deco.size.x)
	for x in range(0, w, 2):
		_deco.draw_rect(Rect2(x, 1, 1, 1), _rule)


func _present(text: String) -> void:
	_label.text = text
	reset_size()
	visible = true
	set_process(true)
	_slide = SLIDE
	_place()
	modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(self, "_slide", 0.0, FADE_IN)
	_tween.chain().tween_interval(LIFETIME - FADE_IN - FADE_OUT)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		set_process(false))


func _process(_delta: float) -> void:
	_place()


## Centred across the whole screen, not the gap between panels. The parent is the HUD, which spans the frame.
func _place() -> void:
	var host: Control = get_parent() as Control
	if host == null:
		return
	var sz: Vector2 = size.max(get_combined_minimum_size())
	position = Vector2((host.size.x - sz.x) * 0.5, host.size.y * TOP_Y - SLIDE + _slide).floor()
