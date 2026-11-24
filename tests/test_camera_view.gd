extends RefCounted
## Camera view invariants: follow, zoom to cursor, free pan, the resting pointer, focus loss, Reduce motion,
## the view rect streaming reads, and the left click the world needs.

const VIEW: Vector2 = Vector2(640.0, 360.0)
const STEP: float = 1.0 / 60.0


class FakeWalker extends Node2D:
	var moving: bool = false
	var speed_factor: float = 1.0
	var lift: float = 0.0


func run(t: Object) -> void:
	_pure(t)
	_follow_zoom(t)
	_free_zoom(t)
	_resting_pointer(t)
	_edge_pan_when_moving(t)
	_focus_loss(t)
	_reduce_motion(t)
	_clicks(t)


## A bare camera in the test tree (so get_viewport works) following a fake walker.
func _rig(t: Object, walker_pos: Vector2, level: int) -> Array:
	var walker := FakeWalker.new()
	walker.position = walker_pos
	var cam := WorldCamera.new()
	cam.world = Node2D.new()
	cam.target = walker
	cam.frame = VIEW
	cam.frame_origin = Vector2.ZERO
	cam.bounds = WorldCamera.WORLD
	cam.zoom_level = level
	cam.set_pointer_for_test(VIEW * 0.5)   # the middle of the view: no edge pan unless a test asks for one
	t.root.add_child(cam)
	# _ready is queued while the suite is still in _init, so place the view on the walker here, as _ready would.
	cam._center = cam._clamp_center(walker.position + WorldCamera.FOCUS_LIFT)
	cam._last_target = walker.position
	return [cam, walker]


func _drop(cam: WorldCamera, walker: FakeWalker) -> void:
	cam.get_parent().remove_child(cam)
	cam.free()
	walker.free()


func _steps(cam: WorldCamera, n: int) -> float:
	var worst: float = 0.0
	var last: Vector2 = cam._center
	for i in n:
		cam._process(STEP)
		worst = maxf(worst, cam._center.distance_to(last))
		last = cam._center
	return worst


func _btn(b: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = pressed
	e.position = Vector2(10.0, 10.0)
	return e


func _motion(rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.position = Vector2(10.0, 10.0)
	return e


func _pure(t: Object) -> void:
	var r: Rect2 = WorldCamera.visible_rect(Vector2(320.0, 180.0), 2, VIEW)
	t.eq(r, Rect2(160.0, 90.0, 320.0, 180.0), "view rect at 2x is the centred half-frame")
	var odd: Rect2 = WorldCamera.visible_rect(Vector2(320.4, 180.0), 1, VIEW)
	t.ok(odd.position.x <= 0.4 and odd.end.x >= 640.4, "view rect rounds outward so it never misses a texel")
	t.eq(WorldCamera.visible_rect(Vector2(320.0, 180.0), 4, VIEW).size, Vector2(160.0, 90.0), "at 4x the view shows a quarter-size rect")


func _follow_zoom(t: Object) -> void:
	var rig: Array = _rig(t, Vector2(400.0, 250.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	_steps(cam, 120)
	var before: Vector2 = cam._center
	cam.zoom_step(1, Vector2(600.0, 330.0))   # a far cursor must not fling a following view
	t.ok(cam._center.distance_to(before) < 0.5, "zoom in follow mode keeps the view on the walker, no fling")
	t.ok(not cam.is_free(), "a zoom alone does not switch to free mode")
	var worst: float = _steps(cam, 120)
	t.ok(worst < 2.0, "the view settles after a follow-mode zoom without a jump (worst %.2f texels/frame)" % worst)
	t.ok(cam._center.distance_to(walker.position + WorldCamera.FOCUS_LIFT) < 1.5, "after the zoom the view sits on the walker")
	_drop(cam, walker)


func _free_zoom(t: Object) -> void:
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	_steps(cam, 120)
	cam._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, true))
	cam._unhandled_input(_motion(Vector2(-60.0, -20.0)))
	cam._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, false))
	t.ok(cam.is_free(), "a right-button drag switches to free mode")
	_steps(cam, 60)
	t.ok(cam.pan.length() > 10.0, "free mode keeps the panned offset while the drag is recent")

	# Zoom to cursor: the world point under the cursor stays put.
	var cursor: Vector2 = Vector2(400.0, 150.0)
	var world_before: Vector2 = cam._center + (cursor - VIEW * 0.5) / 2.0
	cam.zoom_step(1, cursor)
	var world_after: Vector2 = cam._center + (cursor - VIEW * 0.5) / 3.0
	t.ok(world_before.distance_to(world_after) < 0.01, "free-mode zoom keeps the world point under the cursor")
	t.ok(cam.is_free(), "zoom keeps free mode")
	var worst: float = _steps(cam, 60)
	t.ok(worst < 2.0, "no per-frame jump after a free-mode zoom (worst %.2f texels/frame)" % worst)

	# Zoom back out with a keyboard zoom (screen centre anchor): the view must not fling.
	var mid: Vector2 = cam._center
	cam.zoom_step(-1, VIEW * 0.5)
	t.ok(cam._center.distance_to(mid) < 0.5, "keyboard zoom at screen centre does not move the view")

	# Recentre glides back onto the walker and leaves free mode.
	cam.recenter()
	t.ok(not cam.is_free(), "recentre leaves free mode")
	_steps(cam, 240)
	t.ok(cam._center.distance_to(walker.position + WorldCamera.FOCUS_LIFT) < 5.0, "recentre glides the view back onto the walker (within the idle drift)")
	_drop(cam, walker)


func _resting_pointer(t: Object) -> void:
	# The mouse rests in a view corner (the headless pointer sits at 0,0) while nothing else happens. The old
	# edge pan drifted the view away for as long as the pointer stayed there; it must not move now.
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	cam.set_pointer_for_test(Vector2(2.0, 180.0))   # at the left edge of the view, and not moving
	var start: Vector2 = cam._center   # measured from the first frame: the old drift began in the first quarter second
	_steps(cam, 240)
	t.ok(cam._center.distance_to(start) < 0.5, "a resting pointer at the edge does not pan the view")
	t.ok(not cam.is_free(), "a resting pointer does not enter free mode")
	_drop(cam, walker)


func _edge_pan_when_moving(t: Object) -> void:
	# A pointer that moves inside the left edge zone pans the view left, and stops when it stops.
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	_steps(cam, 30)
	var start: Vector2 = cam._center
	for i in 30:
		cam.set_pointer_for_test(Vector2(2.0 + float(i % 2), 180.0))
		cam._process(STEP)
	t.ok(cam._center.x < start.x - 5.0, "a moving pointer in the left edge zone pans the view left")
	t.ok(cam.is_free(), "edge pan enters free mode")
	cam.set_pointer_for_test(Vector2(2.0, 180.0))   # the pointer comes to rest on the edge
	_steps(cam, 20)                                  # a third of a second: the settle window, the pan may still run
	var offset: Vector2 = cam.pan   # the offset the edge pan built up: it must stop growing
	_steps(cam, 60)
	t.ok((cam.pan - offset).length() < 1.0, "edge pan stops once the pointer has been still a moment")
	_drop(cam, walker)


func _focus_loss(t: Object) -> void:
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	cam._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, true))
	cam._notification(WorldCamera.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	t.ok(not cam._dragging, "losing focus ends a drag that never saw its release")
	var pan_before: Vector2 = cam.pan
	cam._unhandled_input(_motion(Vector2(50.0, 50.0)))
	t.eq(cam.pan, pan_before, "after focus loss mouse motion no longer pans the view")
	_drop(cam, walker)


func _reduce_motion(t: Object) -> void:
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	var was: bool = MeadowLife.reduce_motion
	MeadowLife.reduce_motion = true
	walker.moving = true
	for i in 60:
		walker.position.x += 3.0
		cam._process(STEP)
	t.ok(WorldCamera.polish_off(), "Reduce motion turns the camera polish off")
	t.eq(cam._look, Vector2.ZERO, "Reduce motion: no look-ahead lean while the walker walks")
	t.eq(cam._drift(), Vector2.ZERO, "Reduce motion: no drift")
	MeadowLife.reduce_motion = was
	walker.moving = false
	_drop(cam, walker)


func _clicks(t: Object) -> void:
	# A left press is never the camera's: it must not start a drag or pan. The world click path reads the
	# transform, so after zoom and pan the world-local point under a cursor must round-trip to the same texel.
	var rig: Array = _rig(t, Vector2(320.0, 200.0), 2)
	var cam: WorldCamera = rig[0]
	var walker: FakeWalker = rig[1]
	_steps(cam, 60)
	cam._unhandled_input(_btn(MOUSE_BUTTON_LEFT, true))
	t.ok(not cam._dragging and not cam.is_free(), "a left press neither starts a drag nor pans")
	cam._unhandled_input(_btn(MOUSE_BUTTON_LEFT, false))
	cam.zoom_step(1, Vector2(500.0, 120.0))
	cam._apply()
	var p: Vector2 = Vector2(300.0, 190.0)   # a world texel near the walker
	var screen: Vector2 = cam.world.position + p * float(cam.zoom_level)
	var back: Vector2 = (screen - cam.world.position) / float(cam.zoom_level)
	t.ok(back.distance_to(p) < 0.01, "the world-local point under a cursor round-trips after a zoom")
	t.ok((cam.world.position - WorldCamera.world_position(cam._clamp_center(cam._center), cam.zoom_level, VIEW)).length() < 0.01, "the world sits where the camera says it does")
	_drop(cam, walker)
