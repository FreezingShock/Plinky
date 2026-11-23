class_name ParticleBurst
extends Node2D
## 6 to 12 square particles, 1-2 texels, palette 5 or 6. Drawn as rects (no
## textures, no AA). Cheap: one node, one _draw. Free itself when done.

var _p: Array[Dictionary] = []

const MAX_LIVE: int = 10   # spam-pressing never piles up more bursts than this
static var _live: int = 0

static func spawn(parent: Node, pos: Vector2, colors: Array[Color], count := -1) -> void:
	if _live >= MAX_LIVE:
		return
	_live += 1
	var b := ParticleBurst.new()
	b.position = FxConfig.snap(pos)
	b.z_index = 90
	parent.add_child(b)
	var n: int = GraphicsQuality.particle_count(count if count > 0 else randi_range(FxConfig.PARTICLES_MIN, FxConfig.PARTICLES_MAX))
	for i in n:
		var a := randf() * TAU
		var s := randf_range(40.0, 110.0)
		b._p.append({
			"pos": Vector2.ZERO, "vel": Vector2(cos(a), sin(a) * 0.5 - 0.6) * s,
			"life": randf_range(0.35, 0.6), "age": 0.0,
			"size": randi_range(1, 2), "col": colors[i % colors.size()],
		})

func _process(delta: float) -> void:
	var alive := false
	for q in _p:
		q.age += delta
		if q.age < q.life:
			alive = true
			q.vel.y += 260.0 * delta   # gravity
			q.pos += q.vel * delta
	queue_redraw()
	if not alive:
		queue_free()

func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)

func _draw() -> void:
	for q in _p:
		if q.age >= q.life:
			continue
		# Last 30% of life blinks, a pixel-art fade (no alpha blending).
		if q.age > q.life * 0.7 and int(q.age * 40.0) % 2 == 0:
			continue
		draw_rect(Rect2(q.pos.round(), Vector2.ONE * q.size), q.col)
