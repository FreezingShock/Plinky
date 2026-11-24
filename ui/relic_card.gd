class_name RelicCard
extends PanelContainer
## One relic in the gallery: a small square card. The icon sits centred, the edge is the exact rarity colour, and a
## stack count shows in the corner once you own more than one. Names and state live in the hover tip and the detail
## view, so the grid stays dense. An unfound relic is a dark silhouette. Equipped cards get the lifted fill, and a
## focused card gets a marching focus ring. The whole card is the click target, and Tip.bind goes on the card.

signal pressed(card: RelicCard)

## Square side. Four across in the gallery.
const W: float = 62.0
const ICON: int = 24

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


## `p_silhouette` draws a relic you have not found: a dark icon, no count.
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
	if not p_silhouette and p_stacks > 1:
		var n := Label.new()
		n.text = "x%d" % p_stacks
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_theme_color_override("font_color", RelicStyle.text)
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		root.add_child(n)
	_restyle()


func _restyle() -> void:
	if relic == null:
		return
	var lit: bool = _hover or has_focus()
	var kind: AsciiBox.Kind = AsciiBox.Kind.SELECT if (lit or equipped) else AsciiBox.Kind.BUTTON
	var b := AsciiBox.make(kind, 3.0, 2.0)
	b.edge_override = RelicStyle.accent if picked else relic.rarity.tint()
	add_theme_stylebox_override("panel", b)
	queue_redraw()


func _on_draw() -> void:
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), RelicStyle.accent)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		pressed.emit(self)
		accept_event()


func _process(_d: float) -> void:
	if has_focus():
		queue_redraw()   # marching dots
