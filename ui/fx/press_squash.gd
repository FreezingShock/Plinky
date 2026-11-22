class_name PressSquash
extends Node
## Pad sink + walker squash + hitstop. Attach as a child of any Node2D/Control
## and call play(target). Sink is whole texels so it stays pixel-true.

signal finished

func play(target: CanvasItem) -> void:
	var base: Vector2 = target.position
	var base_scale: Vector2 = target.scale
	target.position = base + Vector2(0, FxConfig.PRESS_SINK_TEXELS)
	target.scale = base_scale * Vector2(1.12, 0.84)
	await get_tree().create_timer(FxConfig.HITSTOP_MS / 1000.0, true, false, true).timeout
	var t := create_tween().set_parallel(true)
	t.tween_property(target, "position", base, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "scale", base_scale, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await t.finished
	finished.emit()

## Freeze gameplay briefly without freezing FX timers (they ignore time scale).
func hitstop(ms: int = FxConfig.HITSTOP_MS) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
