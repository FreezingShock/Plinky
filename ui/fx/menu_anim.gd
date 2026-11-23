class_name MenuAnim
extends Node
## The one open/close animation for every menu: a stepped 4x4 Bayer dither wipe plus a small slide, the same look the
## Stats and Attributes window has. Add it with MenuAnim.attach(panel); it lives as a child of the panel and routes
## open/close through the panel's `visible`, so MenuRouter can register `is_open`, `open` and `close` straight from it.
## Panels kept centred by the HUD pick the slide up from the "menu_slide" meta; others just get the wipe.
## Reduce flashing, or no scene tree (tests), skips the animation.

const OPEN_TIME: float = 0.42
const CLOSE_TIME: float = 0.28
const SLIDE: float = 14.0

var panel: Control
var reveal: DitherReveal
var closing: bool = false
var t: float = 0.0   ## wipe progress 0 (hidden) to 1 (shown); a reversed animation starts from here
var _tween: Tween


static func attach(p: Control) -> MenuAnim:
	var a := MenuAnim.new()
	a.panel = p
	a.reveal = DitherReveal.new()
	a.reveal.z_index = 1
	p.add_child(a)
	p.visibility_changed.connect(a._on_visibility)
	a.reveal.tree_entered.connect(a._sync_reveal)
	p.tree_exiting.connect(a._cleanup)
	if p.get_parent() != null:
		p.get_parent().add_child(a.reveal)
	else:
		p.tree_entered.connect(a._adopt_reveal, CONNECT_ONE_SHOT)
	return a


func _adopt_reveal() -> void:
	if reveal.get_parent() == null and panel.get_parent() != null:
		panel.get_parent().add_child(reveal)


func is_open() -> bool:
	return panel.visible and not closing


func open() -> void:
	closing = false
	if not panel.visible:
		t = 0.0
		panel.visible = true
	_run(true)


func close() -> void:
	if not panel.visible or closing:
		return
	closing = true
	Tip.hide_all()
	_run(false)


func _run(opening: bool) -> void:
	if _tween != null:
		_tween.kill()
	if FxConfig.reduce_flashing or not is_inside_tree():
		_set_t(1.0 if opening else 0.0)
		if not opening:
			_finish()
		return
	var to: float = 1.0 if opening else 0.0
	_set_t(t)
	_tween = create_tween()
	_tween.set_speed_scale(0.2 if IndexPanel.slow_mo else 1.0)
	_tween.tween_method(_set_t, t, to, maxf(0.01, (OPEN_TIME if opening else CLOSE_TIME) * absf(to - t)))
	if not opening:
		_tween.tween_callback(_finish)


func _finish() -> void:
	closing = false
	panel.visible = false   # _on_visibility clears the wipe


func _set_t(v: float) -> void:
	t = v
	var s: float = floorf(v * DitherReveal.STEPS) / DitherReveal.STEPS
	panel.set_meta(&"menu_slide", roundf((1.0 - s) * SLIDE))
	reveal.set_cover(1.0 - s)
	_sync_reveal()


func _on_visibility() -> void:
	if panel.visible:
		return
	if _tween != null:
		_tween.kill()
	closing = false
	t = 0.0
	panel.set_meta(&"menu_slide", 0.0)
	reveal.set_cover(0.0)


func _sync_reveal() -> void:
	if reveal.visible and panel.is_inside_tree():
		reveal.global_position = panel.global_position
		reveal.size = panel.size.max(panel.get_combined_minimum_size())


func _process(_d: float) -> void:
	_sync_reveal()


func _cleanup() -> void:
	if reveal != null and reveal.get_parent() != null and not reveal.is_queued_for_deletion():
		reveal.queue_free()
