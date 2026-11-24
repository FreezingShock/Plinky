class_name FarmWheat
extends Node
## Keeps the farm's wheat alive. Every clump is a canvas item that plays its baked gust sheet on the life clock (the same
## clock as the cozy wheat). The clumps are RenderingServer canvas items, not nodes: this one node owns all of them, so 170-odd
## clumps cost one node against the Larkmoor node ceiling. Each item is a child of the farm's y-sorted prop parent at its
## foot, so the walker, the trees and the props still sort against every clump by Y exactly as sprites did. When the walker comes near a clump, that clump is redrawn each frame from its stalks instead: each
## stalk leans away from the walker, and the walker's position follows a soft spring, so the stalks part as the walker
## comes in, stay parted while it stands, and spring back with a slight bounce after it passes. Far clumps keep the cheap
## sheet. Under Reduce Motion the sheets hold still and nothing parts. This is presentation only: it reads the walker and
## never changes gameplay.

const PUSH_RADIUS: float = 30.0      # texels from the walker's feet where a stalk starts to lean
const PUSH_AMOUNT: float = 9.0       # texels of lean at a stalk's tip, right at the walker's feet
const LIVE_RANGE: float = 34.0       # clumps whose centre is this near the walker are redrawn from their stalks
const SPRING_K: float = 90.0         # stiffness of the pull from the walker to the push point
const SPRING_C: float = 9.0          # damping: a little under critical, so the stalks spring back with a soft bounce
const MAX_STEP: float = 1.0 / 30.0   # longest simulated step, so a hitch cannot blow the spring up
const NOWHERE: Vector2 = Vector2(-99999.0, -99999.0)
const FIELD_RATE: float = 0.5        # gust frames per life step, as the cozy wheat

var _clumps: Array[Dictionary] = []  # {rid, origin, offset, clump, sheet, phase, frame, live, tex}
var _parent: Node2D                  # the y-sorted prop parent the clump items hang off
var _walker: Node2D
var _at: Vector2 = NOWHERE           # the push point, on the spring
var _vel: Vector2 = Vector2.ZERO
var _started: bool = false
var _t: float = 0.0
var _step: int = -1


## Push at the walker's feet: none under Reduce Motion.
static func push_for(calm: bool) -> float:
	return 0.0 if calm else PUSH_AMOUNT


## One semi-implicit step of the spring that carries the push point towards the walker. Returns [position, velocity].
static func spring_step(at: Vector2, vel: Vector2, target: Vector2, delta: float) -> Array:
	var dt: float = minf(delta, MAX_STEP)
	var accel: Vector2 = (target - at) * SPRING_K - vel * SPRING_C
	var v: Vector2 = vel + accel * dt
	return [at + v * dt, v]


## Adds a clump (its baked sheet and generated stalks) as a canvas item under `parent`, standing at `foot` (the item's
## y-sort point), whose top-left corner is `origin`. Both are in `parent`'s space.
func add_clump(parent: Node2D, origin: Vector2, foot: Vector2, sheet: Texture2D, clump: Dictionary, phase: int) -> void:
	_parent = parent
	var rid: RID = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, parent.get_canvas_item())
	RenderingServer.canvas_item_set_transform(rid, Transform2D(0.0, foot))
	RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	var c: Dictionary = {"rid": rid, "origin": origin, "offset": origin - foot, "clump": clump, "sheet": sheet,
		"phase": phase, "frame": 0, "live": false, "tex": null}
	_clumps.append(c)
	_draw_sheet(c)


func clump_count() -> int:
	return _clumps.size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for c: Dictionary in _clumps:
			RenderingServer.free_rid(c.rid as RID)
		_clumps.clear()


## Draws a clump's current gust frame from its baked sheet.
func _draw_sheet(c: Dictionary) -> void:
	var clump: Dictionary = c.clump as Dictionary
	var w: int = int(clump.w)
	var h: int = int(clump.h)
	var rid: RID = c.rid as RID
	RenderingServer.canvas_item_clear(rid)
	RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(c.offset as Vector2, Vector2(w, h)),
		(c.sheet as Texture2D).get_rid(), Rect2(float(int(c.frame) * w), 0.0, float(w), float(h)))


func _process(delta: float) -> void:
	var calm: bool = MeadowLife.reduce_motion
	if _walker == null or not is_instance_valid(_walker):
		_walker = get_tree().get_first_node_in_group(&"walker") as Node2D
	var target: Vector2 = _walker.global_position if _walker != null else NOWHERE
	if calm or not _started:
		_at = target
		_vel = Vector2.ZERO
		_started = true
	else:
		var s: Array = spring_step(_at, _vel, target, delta)
		_at = s[0] as Vector2
		_vel = s[1] as Vector2
	_t += delta
	var step: int = int(_t / GraphicsQuality.life_step())
	var stepped: bool = step != _step
	_step = step
	var push: float = push_for(calm)
	for c: Dictionary in _clumps:
		if stepped:
			c.frame = CozyAnimator.frame_at(step, WheatClump.FRAMES, int(c.phase), FIELD_RATE, calm)
		var clump: Dictionary = c.clump as Dictionary
		var w: int = int(clump.w)
		var h: int = int(clump.h)
		var origin: Vector2 = c.origin as Vector2
		var centre: Vector2 = _parent.to_global(origin + Vector2(w * 0.5, h * 0.5))
		var near: bool = push > 0.0 and _at.distance_to(centre) < LIVE_RANGE
		if near:
			var local: Vector2 = _parent.to_local(_at) - origin
			var img: Image = WheatClump.rasterize(clump, int(c.frame), local, push, PUSH_RADIUS)
			if c.tex == null:
				c.tex = ImageTexture.create_from_image(img)
			else:
				(c.tex as ImageTexture).update(img)
			if not bool(c.live):
				var rid: RID = c.rid as RID
				RenderingServer.canvas_item_clear(rid)
				RenderingServer.canvas_item_add_texture_rect(rid, Rect2(c.offset as Vector2, Vector2(w, h)),
					(c.tex as ImageTexture).get_rid())
		elif bool(c.live) or stepped:
			_draw_sheet(c)
		c.live = near
