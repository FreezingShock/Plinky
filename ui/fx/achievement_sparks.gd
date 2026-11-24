class_name AchievementSparks
extends Node2D
## Pixel particles for the achievement banner, one style per section (AchievementStyle.shape_of). Drawn as rects and
## small rings: no textures, no anti-aliasing, and no blinking, so it stays calm under Reduce flashing. Spawn it on the
## banner's host, set `position` to the banner centre and call spawn(). It frees itself when the last particle is gone.

const SPARK_GRAVITY: float = 180.0
const SWAY: float = 6.0

var _p: Array[Dictionary] = []
var _shape: StringName = &"spark"
var _half: Vector2 = Vector2.ZERO   ## half the banner size: spawn points lie inside it
var _colors: Array[Color] = []


func spawn(shape: StringName, colors: Array[Color], count: int, half: Vector2) -> void:
	_shape = shape
	_half = half
	_colors = colors
	for i in count:
		_p.append(_make(i))
	queue_redraw()


func _make(i: int) -> Dictionary:
	var col: Color = _colors[i % _colors.size()]
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life: float = randf_range(0.5, 0.9)
	var g: float = 0.0
	var w: int = 1
	var h: int = 1
	match _shape:
		&"spark":   # bursts out of the two ends of the banner
			var side: float = -1.0 if i % 2 == 0 else 1.0
			pos = Vector2(side * _half.x, randf_range(-_half.y, _half.y))
			vel = Vector2(side * randf_range(40.0, 120.0), randf_range(-70.0, 10.0))
			life = randf_range(0.4, 0.6)
			g = SPARK_GRAVITY
			w = 3
			h = 3
		&"petal":   # falls slowly across the whole width
			pos = Vector2(randf_range(-_half.x, _half.x), -_half.y)
			vel = Vector2(0.0, randf_range(14.0, 26.0))
			life = randf_range(1.2, 1.8)
			w = 2
		&"flame":   # short tongues rising from the bottom edge, centre-weighted
			pos = Vector2(randf_range(-_half.x * 0.5, _half.x * 0.5), _half.y)
			vel = Vector2(randf_range(-8.0, 8.0), randf_range(-90.0, -50.0))
			life = randf_range(0.4, 0.7)
			w = 2
			h = 2
		&"gem":   # tiny glints that hang in place
			pos = Vector2(randf_range(-_half.x, _half.x), randf_range(-_half.y, _half.y))
			vel = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			life = randf_range(0.5, 0.9)
		&"ring":   # one expanding ring from the centre
			pos = Vector2.ZERO
			life = randf_range(0.45, 0.6)
		&"bubble":   # rising, swaying rings
			pos = Vector2(randf_range(-_half.x, _half.x), _half.y)
			vel = Vector2(0.0, randf_range(-34.0, -18.0))
			life = randf_range(1.0, 1.4)
		&"ember":   # floating up off the whole banner
			pos = Vector2(randf_range(-_half.x, _half.x), randf_range(-_half.y * 0.2, _half.y))
			vel = Vector2(randf_range(-6.0, 6.0), randf_range(-60.0, -30.0))
			life = randf_range(0.7, 1.1)
		&"dust":   # streaks sliding out sideways
			var dir: float = -1.0 if i % 2 == 0 else 1.0
			pos = Vector2(-dir * _half.x, randf_range(-_half.y, _half.y))
			vel = Vector2(dir * randf_range(80.0, 140.0), 0.0)
			life = randf_range(0.4, 0.6)
			w = 4
	return {
		"pos": pos, "vel": vel, "life": life, "age": 0.0, "g": g,
		"w": w, "h": h, "col": col, "phase": randf() * TAU,
	}


func _process(delta: float) -> void:
	var alive: bool = false
	for q: Dictionary in _p:
		var age: float = float(q["age"]) + delta
		q["age"] = age
		if age >= float(q["life"]):
			continue
		alive = true
		var vel: Vector2 = q["vel"]
		vel.y += float(q["g"]) * delta
		q["vel"] = vel
		var pos: Vector2 = q["pos"]
		pos += vel * delta
		if _shape == &"petal" or _shape == &"bubble":   # gentle side-to-side sway
			pos.x += cos(age * 3.0 + float(q["phase"])) * SWAY * delta
		q["pos"] = pos
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for q: Dictionary in _p:
		var age: float = q["age"]
		var life: float = q["life"]
		if age >= life:
			continue
		var t: float = age / life
		var p: Vector2 = (q["pos"] as Vector2).round()
		var col: Color = q["col"]
		match _shape:
			&"spark":
				draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), col)
				draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), col)
			&"gem":
				draw_rect(Rect2(p, Vector2.ONE), col)
				if t < 0.4:   # the glint: a cross for the first part of its life
					draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), col)
					draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), col)
			&"ring":
				var r: float = lerpf(3.0, maxf(_half.y * 2.4, 6.0), t)
				draw_arc(p, r, 0.0, TAU, 24, col, 1.0, false)
			&"bubble":
				draw_arc(p, 2.5, 0.0, TAU, 8, col, 1.0, false)
			&"dust":
				draw_rect(Rect2(p, Vector2(4.0, 1.0)), col)
			_:
				draw_rect(Rect2(p, Vector2(float(q["w"]), float(q["h"]))), col)
