class_name Transitions
extends CanvasLayer
## Full-screen transitions driven by a ColorRect shader (res://render/ owns the
## palette textures; this only sets uniforms). Required uniforms on the shader:
##   uniform float shift;   // 0..1 palette blend
##   uniform float invert;  // 0 or 1, index 7 - i
##   uniform float ascii;   // 0..1 ASCII redraw amount (stretch goal)
@export var rect: ColorRect

func _set_u(name: String, v: float) -> void:
	if rect and rect.material:
		(rect.material as ShaderMaterial).set_shader_parameter(name, v)

## Zone entry: blend palettes over 1.5 s with an ease-in-out, stepped to 12 fps.
func zone_shift() -> void:
	var t := create_tween()
	t.tween_method(func(v: float): _set_u("shift", floorf(v * 18.0) / 18.0), 0.0, 1.0, FxConfig.ZONE_SHIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

## Milestone / rebirth: invert for 3 frames, then the caller fires a wide ripple.
func invert_flash() -> void:
	if FxConfig.reduce_flashing:
		return
	_set_u("invert", 1.0)
	for i in FxConfig.FLASH_FRAMES:
		await get_tree().process_frame
	_set_u("invert", 0.0)

## Rebirth: dither-wipe to ASCII and back.
func rebirth_ascii(hold := 0.6) -> void:
	var t := create_tween()
	t.tween_method(func(v: float): _set_u("ascii", v), 0.0, 1.0, 0.8)
	t.tween_interval(hold)
	t.tween_method(func(v: float): _set_u("ascii", v), 1.0, 0.0, 0.8)
	await t.finished
