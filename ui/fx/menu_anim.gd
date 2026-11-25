class_name MenuAnim
extends Node
## The one open/close animation for every menu: a stepped 4x4 Bayer dither wipe plus a small slide, the same look the
## Stats and Attributes window has. Add it with MenuAnim.attach(panel); it lives as a child of the panel and routes
## open/close through the panel's `visible`, so MenuRouter can register `is_open`, `open` and `close` straight from it.
## Panels kept centred by the HUD pick the slide up from the "menu_slide" meta; others just get the wipe.
## Reduce Motion (FxConfig.still) and Reduce flashing both drop the slide: the stepped wipe stays, since it never flashes.
## No scene tree (tests) skips the animation.

const OPEN_TIME: float = 0.42
const CLOSE_TIME: float = 0.28
const SLIDE: float = 14.0

var panel: Control
var reveal: DitherReveal
var closing: bool = false
var t: float = 0.0   ## wipe progress 0 (hidden) to 1 (shown); a reversed animation starts from here
var _tween: Tween


## Keeps a menu above the HUD's own pieces (meters, the relic bar, toasts, the sprint trail, and the HUD chips). Shown menus
## move to the end of their parent so they draw last, so no HUD piece draws over an open menu.
static func bring_front(p: Control) -> void:
	var par: Node = p.get_parent()
	if par != null and p.visible:
		par.move_child(p, par.get_child_count() - 1)
		# The panel's CloseX is a sibling that must stay after it: Godot routes clicks by tree order, so an X left
		# behind the panel never receives them.
		for c: Node in par.get_children():
			if c is CloseX and (c as CloseX).follows(p):
				par.move_child(c, par.get_child_count() - 1)


## Call once for any menu panel that is not attached with MenuAnim, so it gets the same front-of-HUD order.
static func front_on_show(p: Control) -> void:
	if not p.visibility_changed.is_connected(bring_front.bind(p)):
		p.visibility_changed.connect(bring_front.bind(p))


static func attach(p: Control) -> MenuAnim:
	var a := MenuAnim.new()
	a.panel = p
	a.reveal = DitherReveal.new()
	a.reveal.z_index = 1
	p.add_child(a)
	front_on_show(p)
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
	if not is_inside_tree():
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
	panel.set_meta(&"menu_slide", 0.0 if _no_slide() else roundf((1.0 - s) * SLIDE))
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


## The slide is motion, so Reduce Motion and Reduce flashing both leave the panel where it sits.
static func _no_slide() -> bool:
	return FxConfig.still() or FxConfig.reduce_flashing


func _sync_reveal() -> void:
	if reveal.visible and panel.is_inside_tree():
		reveal.global_position = panel.global_position
		reveal.size = panel.size.max(panel.get_combined_minimum_size())


func _process(_d: float) -> void:
	_sync_reveal()


func _cleanup() -> void:
	if reveal != null and reveal.get_parent() != null and not reveal.is_queued_for_deletion():
		reveal.queue_free()
