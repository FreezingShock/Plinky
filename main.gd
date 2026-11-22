extends Control
## Main scene. Assembles the game: renderer view, baked meadow with pads/gate/walker, juice, HUD, relics.
## Everything gameplay-related talks to GameState/EventBus; this script only wires nodes together.
## Owned by the integrator (core thread).

const THEME_PATH: String = "res://theme/plinky_theme.tres"
const MEADOW_PATH: String = "res://world/meadow_scene.tscn"
const QUARRY_TINT: Color = Color(1.0, 0.78, 0.62)  # stand-in until zone 2 has its own art

var sim: Sim
var pv: PixelViewport
var world: Node2D
var meadow: Node2D
var walker: TexelWalker
var gate: TexelGate
var pads: Dictionary = {}  # button id -> TexelPad
var pad_glow: PadGlow
var shake: ScreenShake
var transitions: Transitions
var hud: Hud
var palette_id: StringName = Palettes.MEADOW


func _ready() -> void:
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

	# 3. Juice (autoload) gets its targets.
	Juice.shake = shake
	Juice.transitions = transitions
	Juice.fx_root = world

	# 4. HUD above everything.
	hud = Hud.new()
	add_child(hud)
	hud.setup(sim)
	_wire_relics()

	var bus: Node = get_node("/root/EventBus")
	bus.button_pressed.connect(_on_button_pressed)
	bus.gate_opened.connect(func(_id: StringName) -> void: Juice.milestone())
	bus.rebirth_done.connect(func(_p: BigNum) -> void: Juice.milestone())
	bus.zone_entered.connect(_on_zone_entered)
	_enter_zone_visuals(sim.zone_id)


func _process(_delta: float) -> void:
	world.position = shake.offset
	pad_glow.multiplier = sim.get_stat(&"mult").to_float() + 1.0


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


func _enter_zone_visuals(zone_id: StringName) -> void:
	palette_id = Palettes.for_zone(zone_id)
	PlinkyTheme.apply(theme, String(palette_id))
	world.modulate = QUARRY_TINT if palette_id == Palettes.QUARRY else Color.WHITE
	var cols: PackedColorArray = Palettes.colors(palette_id)
	walker.palette = cols
	gate.palette = cols
	_build_pads()


func _on_zone_entered(zone_id: StringName) -> void:
	_enter_zone_visuals(zone_id)
	Juice.zone_enter()


func _on_button_pressed(button_id: StringName, _world_pos: Vector3, gain: BigNum, crit: bool) -> void:
	var pad: TexelPad = pads.get(button_id) as TexelPad
	if pad == null:
		return
	Juice.press(pad, pad.position, gain.to_float(), crit)


## Relic UI (PR #5): equipped bar, drop toast, collection panel, pad flash on Epic and above.
func _wire_relics() -> void:
	var inv: RelicInventory = GameState.relics
	var bar := RelicBar.new()
	bar.position = Vector2(200, 4)
	hud.add_child(bar)
	bar.bind(inv)
	var toast := RelicToast.new()
	toast.position = Vector2(220, 300)
	hud.add_child(toast)
	toast.bind(inv)
	var panel := RelicPanel.new()
	panel.position = Vector2(180, 60)
	panel.visible = false
	hud.add_child(panel)
	panel.bind(inv)
	hud.relic_panel_toggled.connect(func(_open: bool) -> void: panel.visible = not panel.visible)
	inv.relic_gained.connect(func(id: StringName, _s: int) -> void:
		Juice.relic_drop(pad_glow, inv.rarity_of(id)))
