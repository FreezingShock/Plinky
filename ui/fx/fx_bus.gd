extends Node
## Autoload "Juice" (Fx is the renderer's). Gameplay calls one function; this fans out to every effect.
##   Juice.press(pad, world_pos, amount, big)   Juice.milestone()   Juice.zone_enter()
## Big presses are punchy by design: hitstop + shake (Nathan, 22 Nov).

@export var shake: ScreenShake
@export var transitions: Transitions
var fx_root: Node
var _overlay: CanvasLayer

## Popups go in a screen-space layer: crisp, unscaled by world zoom, always above the grass.
func _popup_parent() -> Node:
	if not is_instance_valid(_overlay):
		_overlay = CanvasLayer.new()
		_overlay.layer = 5
		fx_root.get_tree().current_scene.add_child(_overlay)
	# Borrow the theme from the nearest Control ancestor of the world (Main), once.
	if PopupNumber.ui_theme == null:
		var n: Node = fx_root
		while n != null and not (n is Control and (n as Control).theme != null):
			n = n.get_parent()
		if n != null:
			PopupNumber.ui_theme = (n as Control).theme
	return _overlay

## World (texel) position -> screen position, including camera zoom and pan. Whole texels.
func _to_screen(world_pos: Vector2) -> Vector2:
	return ((fx_root as CanvasItem).get_global_transform_with_canvas() * world_pos).round()

const PARTICLE_COLORS: Array[Color] = [Color("f2e6a0"), Color("c2784e")]

func press(pad: CanvasItem, pos: Vector2, amount: float, big := false, held := false) -> void:
	var sq := PressSquash.new()
	pad.add_child(sq)
	sq.play(pad)
	sq.finished.connect(sq.queue_free)
	if big:
		sq.hitstop(FxConfig.HITSTOP_MS * 2)
	ParticleBurst.spawn(fx_root, pos, PARTICLE_COLORS, randi_range(10, 14) if big else -1)
	PopupStack.spawn(_popup_parent(), _to_screen(pos) + Vector2(-8, -30), amount, big, held, big)
	if shake: shake.add(0.45 if big else 0.1)
	Audio.pad_press(big, held)

func milestone() -> void:
	if transitions: await transitions.invert_flash()
	if shake: shake.add(0.8)

func zone_enter() -> void:
	if transitions: await transitions.zone_shift()

## Wire to EventBus.relic_gained via a resolver that maps relic_id -> rarity id
## (the relic system owns that data), e.g.
##   EventBus.relic_gained.connect(func(id, _s): Juice.relic_drop(pad_glow, RelicDB.rarity_of(id)))
func relic_drop(glow: PadGlow, rarity: StringName) -> void:
	Audio.relic(rarity)
	if glow.flash_rarity(rarity) and shake and rarity in [&"mythic", &"divine", &"special"]:
		shake.add(0.2)
