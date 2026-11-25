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

## Zone crossing: a full-window Bayer dither wipe (render/shaders/cross_wipe.gdshader) covers the picture, `swap` runs
## while it is covered, then it clears. The post-process ASCII wipe only touches the (empty) 3D view, so the cover is
## its own overlay above the HUD. Awaiting this returns once the new zone is fully visible.
const WIPE_SHADER: Shader = preload("res://render/shaders/cross_wipe.gdshader")
var _wipe: ColorRect

func _wipe_rect() -> ColorRect:
	if _wipe == null:
		layer = 60
		_wipe = ColorRect.new()
		_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
		_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = WIPE_SHADER
		_wipe.material = m
		_wipe.visible = false
		add_child(_wipe)
	return _wipe

## Reduce flashing: no dither wipe. A solid fill of the palette's darkest ink fades in, the swap runs under it, and it
## fades out. A smooth fade with no strobe, so the swap is still covered and nothing flashes.
const CALM_FADE_IN: float = 0.35
var _calm: ColorRect

func _calm_rect() -> ColorRect:
	if _calm == null:
		layer = 60
		_calm = ColorRect.new()
		_calm.set_anchors_preset(Control.PRESET_FULL_RECT)
		_calm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_calm.color = Palettes.colors(Palettes.MEADOW)[0]
		_calm.visible = false
		add_child(_calm)
	return _calm


func _calm_cover(swap: Callable, hold: float, clear: float) -> void:
	var r: ColorRect = _calm_rect()
	r.modulate.a = 0.0
	r.visible = true
	var t := create_tween()
	t.tween_property(r, "modulate:a", 1.0, CALM_FADE_IN)
	await t.finished
	await swap.call()
	await get_tree().create_timer(hold).timeout
	var t2 := create_tween()
	t2.tween_property(r, "modulate:a", 0.0, clear)
	await t2.finished
	r.visible = false


func _set_wipe(v: float) -> void:
	var r: ColorRect = _wipe_rect()
	r.visible = v > 0.0
	(r.material as ShaderMaterial).set_shader_parameter("amount", floorf(v * 12.0) / 12.0)   # stepped, like the other transitions

func cross_zone(swap: Callable, cover := 0.45, hold := 0.12, clear := 0.55) -> void:
	if FxConfig.reduce_flashing:
		await _calm_cover(swap, hold, clear)
		return
	var t := create_tween()
	t.tween_method(_set_wipe, 0.0, 1.0, cover)
	await t.finished
	_set_wipe(1.0)
	await swap.call()   # may spread its work over several frames under the full-cover wipe
	await get_tree().create_timer(hold).timeout
	var t2 := create_tween()
	t2.tween_method(_set_wipe, 1.0, 0.0, clear)
	await t2.finished
	_set_wipe(0.0)

## Rebirth: dither-wipe over the whole window and back. Uses the same overlay as cross_zone, because the post-process
## `ascii` uniform only reaches the (empty) 3D view and never showed over the 2D world.
func rebirth_ascii(hold := 0.6) -> void:
	if FxConfig.reduce_flashing:
		return
	var t := create_tween()
	t.tween_method(_set_wipe, 0.0, 1.0, 0.8)
	t.tween_interval(hold)
	t.tween_method(_set_wipe, 1.0, 0.0, 0.8)
	await t.finished
	_set_wipe(0.0)
