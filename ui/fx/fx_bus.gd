extends Node
## Autoload "Fx". Gameplay calls ONE function; this fans out to every effect.
## Gameplay code stays free of juice details (SPEC: content is data).
##   Fx.press(pad_node, world_pos, amount)
##   Fx.milestone()
## Wire-up: Project Settings > Autoload > res://ui/fx/fx_bus.gd as "Fx".

@export var shake: ScreenShake
@export var transitions: Transitions
var fx_root: Node  # set by the HUD/world scene; parent for popups and particles

const PARTICLE_COLORS: Array[Color] = [Color("f2e6a0"), Color("c2784e")] # palette 5, 6 (Zone 1)

func press(pad: CanvasItem, pos: Vector2, amount: float, big := false) -> void:
	var sq := PressSquash.new()
	pad.add_child(sq)
	sq.play(pad)
	sq.finished.connect(sq.queue_free)
	ParticleBurst.spawn(fx_root, pos, PARTICLE_COLORS)
	PopupNumber.spawn(fx_root, pos + Vector2(-8, -14), amount, big)
	if shake: shake.add(0.35 if big else 0.12)

func milestone() -> void:
	if transitions: await transitions.invert_flash()
	if shake: shake.add(0.8)

func zone_enter() -> void:
	if transitions: await transitions.zone_shift()
