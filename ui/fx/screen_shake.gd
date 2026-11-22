class_name ScreenShake
extends Node
## Trauma-based shake on a Camera3D/Node. Offsets are WHOLE texels so the
## renderer's camera snap stays valid. Apply .offset to the UI-image offset
## the renderer already uses (read it each frame; do not move the camera).

var trauma := 0.0
var offset := Vector2.ZERO  # texels, integer-valued

func add(amount: float) -> void:
	if FxConfig.reduce_shake:
		return
	trauma = minf(trauma + amount, 1.0)

func _process(delta: float) -> void:
	trauma = maxf(trauma - FxConfig.SHAKE_DECAY * delta * 0.25, 0.0)
	var k := trauma * trauma
	offset = Vector2(
		roundf(randf_range(-1.0, 1.0) * FxConfig.SHAKE_MAX_TEXELS * k),
		roundf(randf_range(-1.0, 1.0) * FxConfig.SHAKE_MAX_TEXELS * k))
