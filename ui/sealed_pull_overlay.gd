class_name SealedPullOverlay
extends Control
## Opening a sealed cache: the pouch shakes, cracks with sparks and a thump, then the relic it held is shown in its rarity
## colour with its ability and how many you own now. A click or Enter during the animation skips to the reveal. Once
## revealed, Continue, a click outside the panel, or Esc closes it. The relic's own sound already played when it was
## granted (Juice.relic_drop from relic_gained), so it is not played again here.
## Reduce Motion skips the shake and the sparks and shows the reveal at once. The sparks never blink, so Reduce Flashing
## leaves them on.

const SHAKE_TIME: float = 0.6
const CRACK_TIME: float = 0.35
const REVEAL_TIME: float = 0.25
const SHAKE_TURN: float = 0.12        ## radians at full shake
const SHAKE_HZ: float = 70.0
const PICTURE_PX: float = 96.0        ## 16 px pouch at 6x, an integer scale
const ICON_PX: float = 32.0           ## 16 px relic icon at 2x
const VIEW_MARGIN: float = 12.0       ## room kept clear of the window edge, panel border included
const PANEL_W: float = 220.0
const OVERLAY_LAYER: int = 120        ## above the HUD (100) and the relic toast (its layer is inside the HUD)
const BACKDROP: Color = Color(0.0, 0.0, 0.0, 0.6)
const SPARK_COUNT: int = 28
const CRACK_SOUND: StringName = &"pad_big"

enum Phase { SHAKE, CRACK, REVEAL }

var _cache: SealedPullDef
var _relic: RelicDef
var _stacks: int = 1
var _phase: int = Phase.SHAKE
var _t: float = 0.0
var _closing: bool = false
var _layer: CanvasLayer
var _pouch: TextureRect
var _reveal: VBoxContainer
var _continue: Button
var _stage: CenterContainer
var _scroll: ScrollContainer
var _body: VBoxContainer


## Shows the overlay on top of everything. Call it once the relic has been granted, so `stacks` is the new count.
static func open(tree: SceneTree, def: SealedPullDef, relic: RelicDef, stacks: int) -> SealedPullOverlay:
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	var o := SealedPullOverlay.new()
	o._cache = def
	o._relic = relic
	o._stacks = maxi(1, stacks)
	o._layer = layer
	layer.add_child(o)
	tree.root.add_child(layer)
	return o


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", AsciiBox.panel())
	panel.custom_minimum_size.x = PANEL_W
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	# The body scrolls only when the window is too short for it, so the reveal never runs off the screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.x = PANEL_W
	panel.add_child(_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(v)
	_body = v
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = _cache.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	# The stage holds the pouch for the shake and the crack, then the reveal takes its place.
	_stage = CenterContainer.new()
	_stage.custom_minimum_size = Vector2(PANEL_W - 24.0, PICTURE_PX)
	v.add_child(_stage)
	_pouch = TextureRect.new()
	_pouch.texture = SealedArt.texture(_cache.palette)
	_pouch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pouch.custom_minimum_size = Vector2(PICTURE_PX, PICTURE_PX)
	_pouch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pouch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pouch.pivot_offset = Vector2(PICTURE_PX, PICTURE_PX) * 0.5
	_stage.add_child(_pouch)
	_reveal = VBoxContainer.new()
	_reveal.add_theme_constant_override("separation", 4)
	_reveal.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal.visible = false
	v.add_child(_reveal)
	var icon := TextureRect.new()
	icon.texture = _relic.icon
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reveal.add_child(icon)
	var rarity := Label.new()
	rarity.text = _relic.rarity.display_name
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", _relic.rarity.color)
	_reveal.add_child(rarity)
	var relic_name := Label.new()
	relic_name.theme_type_variation = &"TitleLabel"
	relic_name.text = _relic.display_name
	relic_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_name.add_theme_color_override("font_color", _relic.rarity.color.lightened(0.3))
	_reveal.add_child(relic_name)
	var ability := Label.new()
	ability.text = _relic.describe(_stacks)
	ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability.custom_minimum_size.x = PANEL_W - 24.0
	_reveal.add_child(ability)
	var owned := Label.new()
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.text = "New!" if _stacks == 1 else "You now have %d." % _stacks
	owned.add_theme_color_override("font_color", RelicStyle.accent if _stacks == 1 else RelicStyle.dim)
	_reveal.add_child(owned)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_close)
	_reveal.add_child(_continue)
	if FxConfig.still():
		_enter(Phase.REVEAL)
	else:
		_enter(Phase.SHAKE)
	_clamp_height.call_deferred()


func _process(delta: float) -> void:
	if _closing or _phase == Phase.REVEAL and _reveal.modulate.a >= 1.0:
		return
	_t += delta
	match _phase:
		Phase.SHAKE:
			var k: float = clampf(_t / SHAKE_TIME, 0.0, 1.0)
			_pouch.rotation = sin(_t * SHAKE_HZ) * SHAKE_TURN * k
			if _t >= SHAKE_TIME:
				_enter(Phase.CRACK)
		Phase.CRACK:
			var c: float = clampf(_t / CRACK_TIME, 0.0, 1.0)
			_pouch.scale = Vector2.ONE * (1.0 + 0.3 * sin(c * PI))
			_pouch.modulate.a = 1.0 - c
			if _t >= CRACK_TIME:
				_enter(Phase.REVEAL)
		Phase.REVEAL:
			_reveal.modulate.a = clampf(_t / REVEAL_TIME, 0.0, 1.0)


func _enter(p: int) -> void:
	_phase = p
	_t = 0.0
	match p:
		Phase.SHAKE:
			_pouch.rotation = 0.0
		Phase.CRACK:
			_pouch.rotation = 0.0
			Audio.play(CRACK_SOUND, 1.0, -2.0)
			_burst()
		Phase.REVEAL:
			_pouch.visible = false
			_stage.visible = false   # the reveal takes the stage's room, so the card stays short
			_reveal.visible = true
			_reveal.modulate.a = 1.0 if FxConfig.still() else 0.0
			_continue.grab_focus()
			_clamp_height.call_deferred()


## Sparks in the rarity colour, from the pouch's centre. Skipped under Reduce Motion.
func _burst() -> void:
	if FxConfig.still() or _relic == null:
		return
	var sp := AchievementSparks.new()
	sp.position = _pouch.get_global_rect().get_center() - get_global_rect().position
	sp.z_index = 2
	add_child(sp)
	var base: Color = _relic.rarity.color
	var colors: Array[Color] = [base, base.lightened(0.45), Color("f2e6a0")]
	sp.spawn(&"spark", colors, GraphicsQuality.particle_count(SPARK_COUNT), Vector2(PICTURE_PX, PICTURE_PX) * 0.5)


func _skip_to_reveal() -> void:
	if _phase != Phase.REVEAL:
		_pouch.visible = false
		_enter(Phase.REVEAL)
		_reveal.modulate.a = 1.0


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _phase != Phase.REVEAL:
		_skip_to_reveal()
	else:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		if _phase == Phase.REVEAL:
			_close()
		else:
			_skip_to_reveal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _phase != Phase.REVEAL:
		_skip_to_reveal()
		get_viewport().set_input_as_handled()


## Caps the panel's height at the window's height less a margin. The body scrolls past that, so a short window never clips the reveal.
func _clamp_height() -> void:
	if _scroll == null or _body == null or not is_inside_tree():
		return
	var room: float = get_viewport_rect().size.y - VIEW_MARGIN * 2.0
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, room)


func _close() -> void:
	if _closing:
		return
	_closing = true
	if _layer != null:
		_layer.queue_free()
	else:
		queue_free()
