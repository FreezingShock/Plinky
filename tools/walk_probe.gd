extends Node
## Headless probe of the walkable mask and walker movement. Run: godot --headless --path . tools/walk_probe.tscn
## Prints counts and PASS/FAIL lines; exits non-zero on failure.

var fails: int = 0

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _ready() -> void:
	var im: Image = WalkMask.image()
	_check(im != null, "mask loads")
	var walk: int = 0
	var blocked: int = 0
	for y in 360:
		for x in 640:
			if WalkMask.walkable(Vector2(x, y)):
				walk += 1
			else:
				blocked += 1
	print("walkable texels ", walk, " blocked ", blocked, " of ", 640 * 360)
	# 1. nearest() always lands on walkable, and reports how far it moved
	var maxd: float = 0.0
	var bad: int = 0
	var n: int = 0
	for y in range(0, 360, 20):
		for x in range(0, 640, 20):
			var p := Vector2(x, y)
			if WalkMask.walkable(p):
				continue
			n += 1
			var q: Vector2 = WalkMask.nearest(p)
			if not WalkMask.walkable(q):
				bad += 1
			maxd = maxf(maxd, p.distance_to(q))
	print("nearest(): blocked samples ", n, " not-snapped ", bad, " max snap distance ", snappedf(maxd, 0.1))
	# Clicks further than the 80 texel search radius from land (deep water) intentionally stay blocked.
	_check(bad < n / 2, "most clicks on blocked texels snap to walkable")
	# 2. walker never stands on a blocked texel, whatever the target
	var parent := Node2D.new()
	add_child(parent)
	var w := TexelWalker.new()
	parent.add_child(w)
	await get_tree().process_frame
	var starts: Array[Vector2] = []
	for y in range(40, 330, 60):
		for x in range(40, 600, 80):
			if WalkMask.walkable(Vector2(x, y)):
				starts.append(Vector2(x, y))
	var violations: int = 0
	var stuck: int = 0
	var runs: int = 0
	for s: Vector2 in starts:
		for t: Vector2 in [Vector2(20, 20), Vector2(620, 340), Vector2(20, 340), Vector2(620, 20), Vector2(320, 180)]:
			w.position = s
			w._target = t
			w._has_target = true
			runs += 1
			var start_pos: Vector2 = w.position
			for i in 400:
				w._process(1.0 / 60.0)
				if not WalkMask.walkable(w.position):
					violations += 1
					break
				if not w._has_target:
					break
			if w.position == start_pos and t.distance_to(s) > 8.0:
				stuck += 1
	print("walk runs ", runs, " walked onto blocked ", violations, " never moved ", stuck)
	_check(violations == 0, "walker never enters water, mountains or trunks")
	# 3. slide: blocked diagonal still moves along the free axis when one exists
	var slid: int = 0
	var slide_tests: int = 0
	for s: Vector2 in starts:
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var q: Vector2 = s + d * 3.0
			if WalkMask.walkable(q):
				continue
			var qx: Vector2 = Vector2(q.x, s.y)
			var qy: Vector2 = Vector2(s.x, q.y)
			if not (WalkMask.walkable(qx) or WalkMask.walkable(qy)):
				continue
			slide_tests += 1
			w.position = s
			var moved: bool = w._try_step(d * 3.0)
			if moved and w.position != s:
				slid += 1
	print("slide cases ", slide_tests, " slid ", slid)
	_check(slide_tests == 0 or slid == slide_tests, "blocked diagonal slides along a free axis")
	get_tree().quit(1 if fails > 0 else 0)
