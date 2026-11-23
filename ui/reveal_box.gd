class_name RevealBox
extends Container
## Holds one child and shows only a share of its height, clipping the rest, so a menu can fold open and shut in
## chunky steps. `floor_px` is a height that always shows (a half-hidden description), `fade` dithers the clipped edge.
## While fully shut with no floor the child is hidden, so keyboard and pad focus never land in it.

const STEPS: int = 8
const FADE_ROWS: int = 5

var amount: float = 1.0:
	set(v):
		v = clampf(snappedf(v, 1.0 / STEPS), 0.0, 1.0)
		if v != amount:
			amount = v
			_sync()
var floor_px: float = 0.0:
	set(v):
		floor_px = maxf(v, 0.0)
		_sync()
var fade: bool = false:
	set(v):
		fade = v
		if _veil != null:
			_veil.queue_redraw()
var _veil: Control
var _tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_veil = Control.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(_draw_veil)
	add_child(_veil)


func body() -> Control:
	for c in get_children():
		if c != _veil and c is Control:
			return c as Control
	return null


func is_open() -> bool:
	return amount > 0.0 and (_tween == null or not _tween.is_running() or amount >= 1.0 or _target)


var _target: bool = true


## Fold open or shut. Animated unless `animate` is false (or the tree is absent, as in tests).
func set_open(on: bool, animate: bool = true) -> void:
	_target = on
	if _tween != null:
		_tween.kill()
	var b: Control = body()
	if on and b != null:
		b.visible = true
	if not animate or not is_inside_tree():
		amount = 1.0 if on else 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "amount", 1.0 if on else 0.0, 0.22)


func _shown_height(full: float) -> float:
	var f: float = minf(floor_px, full)
	return f + (full - f) * amount


func _sync() -> void:
	var b: Control = body()
	if b != null:
		b.visible = _target or amount > 0.0 or floor_px > 0.0
	update_minimum_size()
	queue_sort()
	if _veil != null:
		_veil.queue_redraw()


func _get_minimum_size() -> Vector2:
	var b: Control = body()
	if b == null:
		return Vector2.ZERO
	var m: Vector2 = b.get_combined_minimum_size()
	if not b.visible:
		return Vector2(m.x, 0.0)
	return Vector2(m.x, floorf(_shown_height(m.y)))


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var b: Control = body()
	if b != null:
		var m: Vector2 = b.get_combined_minimum_size()
		fit_child_in_rect(b, Rect2(0.0, 0.0, size.x, maxf(m.y, 0.0)))
	fit_child_in_rect(_veil, Rect2(Vector2.ZERO, size))
	move_child(_veil, get_child_count() - 1)


func _draw_veil() -> void:
	if not fade or size.y < FADE_ROWS + 2:
		return
	var b: Control = body()
	if b == null or not b.visible or size.y >= b.get_combined_minimum_size().y - 0.5:
		return
	var bayer: Array[int] = AsciiBox.BAYER
	for r in FADE_ROWS:
		var level: int = (r + 1) * 3
		var y: int = int(size.y) - FADE_ROWS + r
		for x in int(size.x):
			if bayer[(y % 4) * 4 + (x % 4)] < level:
				_veil.draw_rect(Rect2(x, y, 1, 1), RelicStyle.ink)
