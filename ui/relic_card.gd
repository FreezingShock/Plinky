class_name RelicCard
extends PanelContainer
## One relic in the gallery: a 40 px square, six across. The icon is centred and fills most of the card. The tier is
## the frame colour and the open tab (the grid shows one tier at a time), so there is no letter. An E marks an
## equipped relic, and a stack count shows bottom right once you own more than one. An unfound relic is a dark silhouette. Focus gets an accent edge and a focus ring,
## which stays still under Reduce Flashing. The whole card is the click target, and Tip.bind goes on it, so focus
## shows the same tooltip as hover.

signal pressed(card: RelicCard)

const W: float = 40.0
const ICON: int = 20

var relic: RelicDef
var stacks: int = 0
var equipped: bool = false
## True for the relic waiting for a slot to swap into.
var picked: bool = false

var _hover: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(W, W)
	mouse_entered.connect(func() -> void: _hover = true; _restyle())
	mouse_exited.connect(func() -> void: _hover = false; _restyle())
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)
	draw.connect(_on_draw)


## `p_silhouette` draws a relic you have not found: a dark icon, no marks.
func setup(def: RelicDef, p_stacks: int, p_equipped: bool, p_picked: bool = false, p_silhouette: bool = false) -> void:
	relic = def
	stacks = p_stacks
	equipped = p_equipped
	picked = p_picked
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(W, W)
	add_child(root)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var icon := TextureRect.new()
	icon.texture = IconSet.get_icon(String(def.id), ICON)
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p_silhouette:
		icon.modulate = Color(0.2, 0.2, 0.26, 1.0)
	center.add_child(icon)
	if not p_silhouette:
		if p_picked:
			_mark(root, "S", RelicStyle.accent, MarkCorner.BOTTOM_LEFT)
		elif p_equipped:
			_mark(root, "E", RelicStyle.good, MarkCorner.BOTTOM_LEFT)
		if p_stacks > 1:
			_mark(root, "x%d" % p_stacks, RelicStyle.text, MarkCorner.BOTTOM_RIGHT)
	_restyle()


enum MarkCorner { TOP_LEFT, BOTTOM_LEFT, BOTTOM_RIGHT }


## A small text mark in one corner of the card. Labels ignore the mouse, so the card stays the click target.
func _mark(root: Control, text: String, c: Color, corner: MarkCorner) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", c)
	match corner:
		MarkCorner.TOP_LEFT:
			l.set_anchors_preset(Control.PRESET_TOP_LEFT)
		MarkCorner.BOTTOM_LEFT:
			l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			l.grow_vertical = Control.GROW_DIRECTION_BEGIN
		MarkCorner.BOTTOM_RIGHT:
			l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(l)


func _restyle() -> void:
	if relic == null:
		return
	var lit: bool = _hover or has_focus()
	var kind: AsciiBox.Kind = AsciiBox.Kind.SELECT if (lit or equipped) else AsciiBox.Kind.BUTTON
	var b := AsciiBox.make(kind, 2.0, 2.0)
	# Focus and a waiting swap use the accent edge; otherwise the card keeps its rarity colour.
	b.edge_override = RelicStyle.accent if (picked or has_focus()) else relic.rarity.tint()
	add_theme_stylebox_override("panel", b)
	queue_redraw()


func _on_draw() -> void:
	if not has_focus():
		return
	var r := Rect2(Vector2.ZERO, size).grow(1.0)
	if FxConfig.reduce_flashing:
		draw_rect(r, RelicStyle.accent, false, 1.0)
	else:
		PadInput.draw_focus_ring(self, r, RelicStyle.accent)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		pressed.emit(self)
		accept_event()


func _process(_d: float) -> void:
	# The marching focus ring moves, so it only runs when Reduce Flashing is off.
	if has_focus() and not FxConfig.reduce_flashing:
		queue_redraw()
