class_name RelicCard
extends PanelContainer
## One relic in the collection: a rarity-framed card. The 20 texel rarity frame and icon on the left, the name in
## the rarity colour, then stack count and an Equipped mark. The card edge is the exact rarity colour (the same
## colour-coded outline the gallery cards use); equipped cards sit on a lifted fill, a hovered or focused card
## gets the lifted fill and a marching focus ring. The whole card is the click target, and Tip.bind goes on the card.

signal pressed(card: RelicCard)

const W: float = 126.0

var relic: RelicDef
var stacks: int = 0
var equipped: bool = false
## True for the relic waiting for a slot to swap into.
var picked: bool = false

var _hover: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(W, 0.0)
	mouse_entered.connect(func() -> void: _hover = true; _restyle())
	mouse_exited.connect(func() -> void: _hover = false; _restyle())
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)
	draw.connect(_on_draw)


## `p_silhouette` draws a relic you have not found: dark art, name hidden, rarity still shown.
func setup(def: RelicDef, p_stacks: int, p_equipped: bool, p_picked: bool = false, p_silhouette: bool = false) -> void:
	relic = def
	stacks = p_stacks
	equipped = p_equipped
	picked = p_picked
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var s := RelicSlot.new()
	s.setup(def, p_stacks, false)
	if p_silhouette:
		s.modulate = Color(0.2, 0.2, 0.26, 1.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := Label.new()
	n.text = "???" if p_silhouette else def.display_name
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_color_override("font_color", RelicStyle.dim if p_silhouette else def.rarity.readable_color(RelicStyle.ink))
	v.add_child(n)
	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", 4)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	# Rarity by name (not colour alone), then a short state mark: On = equipped, Swap = waiting for a slot.
	l2.add_child(_label(def.rarity.display_name, RelicStyle.dim))
	if p_silhouette:
		pass
	elif p_picked:
		l2.add_child(_label("Swap", RelicStyle.accent))
	elif p_equipped:
		l2.add_child(_label("On", RelicStyle.good))
	_restyle()


func _label(t: String, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", c)
	return l


func _restyle() -> void:
	if relic == null:
		return
	var lit: bool = _hover or has_focus()
	var kind: AsciiBox.Kind = AsciiBox.Kind.SELECT if (lit or equipped) else AsciiBox.Kind.BUTTON
	var b := AsciiBox.make(kind, 4.0, 3.0)
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
