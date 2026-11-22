extends Control
## Main scene. Assembles the game: renderer view, baked meadow with pads/gate/walker, juice, HUD, relics.
## Everything gameplay-related talks to GameState/EventBus; this script only wires nodes together.
## Owned by the integrator (core thread).

const THEME_PATH: String = "res://theme/plinky_theme.tres"
const MEADOW_PATH: String = "res://world/meadow3d_scene.tscn"
const QUARRY_TINT: Color = Color(1.0, 0.78, 0.62)  # stand-in until zone 2 has its own art

var sim: Sim
var pv: PixelViewport
var world: Node2D
var meadow: Node2D
var walker: TexelWalker
var gate: TexelGate
var pads: Dictionary = {}  # button id -> TexelPad
var critter: TexelCritter
var pad_glow: PadGlow
var shake: ScreenShake
var camera: WorldCamera
var transitions: Transitions
var hud: Hud
var tooltip: PadTooltip
var relic_panel: RelicPanel
var display_panel: DisplayPanel
var dev_console: DevConsole
var window_frame: WindowFrame
var feedback_panel: FeedbackPanel
var palette_id: StringName = Palettes.MEADOW


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # pads and walker read clicks in _unhandled_input; STOP on the root swallowed them all
	PadInput.ensure()
	DisplaySettings.apply(get_window())
	DisplaySettings.apply_startup(get_window())  # saved monitor, window size, vsync and frame cap
	SettingsRegistry.apply_all()                 # stored settings (accessibility, number format, audio device, ...)
	get_window().size_changed.connect(_on_window_resized)
	sim = GameState.sim
	theme = (load(THEME_PATH) as Theme).duplicate(true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 1. Renderer view (bottom). Its 3D world is empty for now: the meadow is baked 2D art above it.
	shake = ScreenShake.new()
	add_child(shake)
	pv = PixelViewport.new()
	pv.screen_shake = shake
	add_child(pv)
	Fx.bind(pv)
	transitions = Transitions.new()
	transitions.rect = pv.post
	add_child(transitions)

	# 2. Meadow, pads, gate, walker (texel space, y-sorted).
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	meadow = (load(MEADOW_PATH) as PackedScene).instantiate()
	world.add_child(meadow)
	meadow.call("spawn_occluders", world)
	pad_glow = PadGlow.new()
	add_child(pad_glow)
	var anchors: Node = meadow.get_node("Anchors")
	walker = TexelWalker.new()
	var spawn: Marker2D = anchors.get_node_or_null("Walker") as Marker2D
	walker.position = spawn.position if spawn != null else Vector2(320, 240)
	world.add_child(walker)
	gate = TexelGate.new()
	var gate_marker: Marker2D = anchors.get_node_or_null("Gate") as Marker2D
	gate.position = gate_marker.position if gate_marker != null else Vector2(480, 120)
	gate.walker = walker
	world.add_child(gate)

	# 2b. Camera: follows the walker, wheel zoom, drag or edge pan (render/world_camera.gd).
	camera = WorldCamera.new()
	camera.world = world
	camera.target = walker
	camera.shake = shake
	add_child(camera)
	WalkMarker.attach(self, world, walker)  # click-to-walk ring and marching dots (ui/fx/walk_marker.gd)

	# 3. Juice (autoload) gets its targets.
	Juice.shake = shake
	Juice.transitions = transitions
	Juice.fx_root = world

	# 4. HUD above everything.
	hud = Hud.new()
	hud.z_index = 100  # world layers use z up to 90 (ParticleBurst) and 10 (LifeAir); z is global, so the HUD must sit above them
	add_child(hud)
	hud.setup(sim)
	_wire_relics()
	_wire_display()
	dev_console = DevConsole.attach(hud, sim, {"walker": walker, "gate": gate, "pads": pads, "spawn": walker.position})
	window_frame = WindowFrame.new()
	add_child(window_frame)
	window_frame.bind(get_window())
	tooltip = PadTooltip.new()
	add_child(tooltip)

	var bus: Node = get_node("/root/EventBus")
	bus.button_pressed.connect(_on_button_pressed)
	bus.gate_opened.connect(func(_id: StringName) -> void: Juice.milestone())
	bus.rebirth_done.connect(func(_p: BigNum) -> void: Juice.milestone())
	bus.zone_entered.connect(_on_zone_entered)
	bus.bonus_gained.connect(_on_bonus_gained)
	_enter_zone_visuals(sim.zone_id)
	_clear_spawn()
	Audio.start(sim.zone_id)


func _process(_delta: float) -> void:
	_layout_frame()
	_menu_focus()
	pad_glow.multiplier = sim.get_stat(&"mult").to_float() + 1.0
	_update_tooltip()


## Show the tooltip for the pad under the mouse, unless the mouse is over a HUD control.
func _update_tooltip() -> void:
	var over: Control = get_viewport().gui_get_hovered_control()
	if over != null and over.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		tooltip.hide_tip()
		return
	var m: Vector2 = world.get_local_mouse_position()
	for pad: TexelPad in pads.values():
		if pad.hit(m):
			tooltip.show_for(sim, pad.button_id, get_local_mouse_position())
			return
	tooltip.hide_tip()


func _unhandled_input(event: InputEvent) -> void:
	if Keybinds.matches(&"fullscreen", event):
		DisplaySettings.toggle_fullscreen(get_window())
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_toggle_feedback()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"plinky_back"):
		var any: bool = relic_panel.visible or hud.upgrades_open() or display_panel.visible or feedback_panel.visible
		relic_panel.hide()
		display_panel.close()
		feedback_panel.close()
		hud.close_panels()
		if any:
			get_viewport().set_input_as_handled()


## Menus without a mouse: while a panel is open the walker stands still and focus lands on its first control.
## Arrows, d-pad or stick move focus, Enter/Space/pad A press, Esc or pad B closes (all via Godot ui_* actions).
func _menu_focus() -> void:
	var panels: Array[Control] = [dev_console, feedback_panel, display_panel, relic_panel, hud.upgrades_panel()]
	var open: Control = null
	for p: Control in panels:
		if p != null and p.visible:
			open = p
			break
	PadInput.menu_open = open != null
	var owner_ctl: Control = get_viewport().gui_get_focus_owner()
	if open == null:
		if owner_ctl != null:
			owner_ctl.release_focus()
	elif owner_ctl == null or not open.is_ancestor_of(owner_ctl):
		var first: Control = PadInput.first_focusable(open)
		if first != null:
			first.grab_focus()


## Lay the frame out in the window. The frame is the bleed size (640x360 until the wider backdrop is in),
## or smaller if the window is smaller. It is centred in the visible area, and the rest stays black.
func _layout_frame() -> void:
	# The custom title bar takes a strip off the top of the view, so it never covers the HUD.
	var top: float = window_frame.inset() if window_frame != null else 0.0
	var visible: Vector2 = get_viewport_rect().size - Vector2(0.0, top)
	var bleed: Vector2 = Vector2(DisplaySettings.bleed_size())
	var frame: Vector2 = Vector2(minf(visible.x, bleed.x), minf(visible.y, bleed.y)).floor()
	var origin: Vector2 = ((visible - frame) * 0.5).floor() + Vector2(0.0, top)
	if frame == size and origin == position:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = origin
	size = frame
	camera.frame = frame
	camera.frame_origin = origin
	camera.bounds = Rect2(-(bleed - Vector2(DisplaySettings.BASE)) * 0.5, bleed)
	hud.frame = frame


## Window resize: re-pick integer or fit scaling for the new window size.
func _on_window_resized() -> void:
	DisplaySettings.apply(get_window())


## The Walker anchor sits on the pad path. Slide the start away from every pad (>= SPAWN_CLEARANCE texels,
## vertical distance doubled for the 2:1 ground) so nothing auto-presses before the player moves.
const SPAWN_CLEARANCE: float = 40.0

func _clear_spawn() -> void:
	walker.position = WalkMask.nearest(walker.position)
	for i in 12:
		var near: bool = false
		for pad: TexelPad in pads.values():
			var d: Vector2 = walker.position - pad.position
			if Vector2(d.x, d.y * 2.0).length() < SPAWN_CLEARANCE:
				near = true
		if not near:
			return
		walker.position += Vector2(-12.0, 8.0)
		walker.position = Vector2(
			clampf(walker.position.x, TexelWalker.BOUNDS.position.x, TexelWalker.BOUNDS.end.x),
			clampf(walker.position.y, TexelWalker.BOUNDS.position.y, TexelWalker.BOUNDS.end.y))
		walker.position = WalkMask.nearest(walker.position)


## Pads come from the zone's pad_buttons, in the order of the scene's Pad0, Pad1, ... anchors.
func _build_pads() -> void:
	for p: TexelPad in pads.values():
		p.queue_free()
	pads.clear()
	var z: ZoneDef = sim.current_zone()
	gate.zone_id = z.id if z != null else &""
	if z == null:
		return
	var anchors: Node = meadow.get_node("Anchors")
	for i in z.pad_buttons.size():
		var marker: Marker2D = anchors.get_node_or_null("Pad%d" % i) as Marker2D
		if marker == null:
			continue
		var pad := TexelPad.new()
		pad.button_id = StringName(z.pad_buttons[i])
		pad.position = marker.position
		pad.walker = walker
		pad.glow = pad_glow
		pad.palette = Palettes.colors(palette_id)
		world.add_child(pad)
		pads[pad.button_id] = pad
	if critter == null:
		critter = TexelCritter.new()
		world.add_child(critter)
	critter.palette = Palettes.colors(palette_id)
	critter.anchors = PackedVector2Array()
	for pad: TexelPad in pads.values():
		critter.anchors.append(pad.position)


func _enter_zone_visuals(zone_id: StringName) -> void:
	palette_id = Palettes.for_zone(zone_id)
	PopupStack.zone = String(palette_id)
	PlinkyTheme.apply(theme, String(palette_id))
	world.modulate = QUARRY_TINT if palette_id == Palettes.QUARRY else Color.WHITE
	var cols: PackedColorArray = Palettes.colors(palette_id)
	walker.palette = cols
	gate.palette = cols
	_build_pads()


func _on_zone_entered(zone_id: StringName) -> void:
	_enter_zone_visuals(zone_id)
	Juice.zone_enter()


## Streak and critter payouts float up as a gold popup at the walker or the critter.
func _on_bonus_gained(kind: StringName, gains: Dictionary) -> void:
	var g: BigNum = gains.get(&"cash") as BigNum
	if g == null:
		return
	var at: Vector2 = critter.position if (kind == &"critter" and critter != null) else walker.position
	PopupNumber.spawn(world, at + Vector2(0.0, -14.0), g.to_float(), true)
	Juice.milestone()


func _on_button_pressed(button_id: StringName, _world_pos: Vector3, gain: BigNum, crit: bool) -> void:
	var pad: TexelPad = pads.get(button_id) as TexelPad
	if pad == null:
		return
	if pad.standing or pad.holding:
		walker.squash()
	Juice.press(pad, pad.position, gain.to_float(), crit, pad.holding)


## Relic UI (PR #5): equipped bar, drop toast, collection panel, pad flash on Epic and above.
func _wire_relics() -> void:
	var inv: RelicInventory = GameState.relics
	var bar := RelicBar.new()
	bar.position = Vector2(8, 76)  # below the stats panel
	hud.add_child(bar)
	bar.bind(inv)
	var toast := RelicToast.new()
	toast.position = Vector2(220, 274)  # clear of the bottom bar (y 334)
	hud.add_child(toast)
	toast.bind(inv)
	var panel := RelicPanel.new()
	relic_panel = panel
	panel.position = Vector2(180, 60)
	panel.visible = false
	hud.add_child(panel)
	panel.bind(inv)
	hud.relic_panel_toggled.connect(func(_open: bool) -> void: panel.visible = not panel.visible)
	inv.relic_gained.connect(func(id: StringName, _s: int) -> void:
		Juice.relic_drop(pad_glow, inv.rarity_of(id)))


## Settings panel (F10 or the bottom-bar button). Centred over the view, closes with F10 or Esc.
func _wire_display() -> void:
	display_panel = DisplayPanel.new()
	hud.add_child(display_panel)
	display_panel.bind(get_window())
	hud.settings_toggled.connect(func(_open: bool) -> void:
		if display_panel.visible:
			display_panel.close()
		else:
			display_panel.open())
	feedback_panel = FeedbackPanel.new()
	hud.add_child(feedback_panel)
	feedback_panel.bind(GameState.sim)
	display_panel.feedback_requested.connect(_toggle_feedback)


func _toggle_feedback() -> void:
	if feedback_panel.visible:
		feedback_panel.close()
	else:
		display_panel.close()
		feedback_panel.open()
