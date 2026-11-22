extends Node
## Autoload "Fx". Gameplay calls one function; this fans out to every effect.
##   Fx.press(pad, world_pos, amount, big)   Fx.milestone()   Fx.zone_enter()
## Big presses are punchy by design: hitstop + shake (Nathan, 22 Nov).

@export var shake: ScreenShake
@export var transitions: Transitions
var fx_root: Node

const PARTICLE_COLORS: Array[Color] = [Color("f2e6a0"), Color("c2784e")]

func press(pad: CanvasItem, pos: Vector2, amount: float, big := false) -> void:
	var sq := PressSquash.new()
	pad.add_child(sq)
	sq.play(pad)
	sq.finished.connect(sq.queue_free)
	if big:
		sq.hitstop(FxConfig.HITSTOP_MS * 2)
	ParticleBurst.spawn(fx_root, pos, PARTICLE_COLORS, randi_range(10, 14) if big else -1)
	PopupNumber.spawn(fx_root, pos + Vector2(-8, -14), amount, big)
	if shake: shake.add(0.45 if big else 0.1)

func milestone() -> void:
	if transitions: await transitions.invert_flash()
	if shake: shake.add(0.8)

func zone_enter() -> void:
	if transitions: await transitions.zone_shift()
