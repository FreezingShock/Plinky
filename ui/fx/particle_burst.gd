class_name ParticleBurst
extends Node2D
## 6 to 12 square particles, 1-2 texels, palette 5 or 6. Drawn as rects (no
## textures, no AA). One node, one _draw. Bursts are pooled: a finished burst is hidden and kept for the next spawn,
## with its particle arrays, so a stream of presses allocates nothing (perf.md: pooled effects). At most MAX_LIVE
## bursts are ever alive, so the pool never holds more than that many nodes.

const MAX_LIVE: int = 10   # spam-pressing never piles up more bursts than this

static var _live: int = 0
static var _idle: Array[ParticleBurst] = []   # finished bursts, hidden, waiting to be spawned again

var _active: bool = false
var _n: int = 0                               # particles in use this burst (the arrays may be longer)
var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _col: Array[Color] = []


static func spawn(parent: Node, pos: Vector2, colors: Array[Color], count := -1) -> void:
	if _live >= MAX_LIVE:
		return
	var b: ParticleBurst = _take_idle()
	if b == null:
		b = ParticleBurst.new()
	_live += 1
	b.position = FxConfig.snap(pos)
	b.z_index = 90
	if b.get_parent() != parent:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)   # an idle burst is hidden and holds no state, so it can move
		parent.add_child(b)
	b._start(GraphicsQuality.particle_count(count if count > 0 else randi_range(FxConfig.PARTICLES_MIN, FxConfig.PARTICLES_MAX)), colors)


## A hidden burst from the pool, or null. A burst whose parent was freed is gone with it, so it is skipped.
static func _take_idle() -> ParticleBurst:
	while not _idle.is_empty():
		var cand: Variant = _idle.pop_back()
		if is_instance_valid(cand):
			return cand as ParticleBurst
	return null


func _start(n: int, colors: Array[Color]) -> void:
	_n = n
	if _pos.size() < n:
		_pos.resize(n)
		_vel.resize(n)
		_life.resize(n)
		_age.resize(n)
		_size.resize(n)
		_col.resize(n)
	for i in n:
		var a := randf() * TAU
		var s := randf_range(40.0, 110.0)
		_pos[i] = Vector2.ZERO
		_vel[i] = Vector2(cos(a), sin(a) * 0.5 - 0.6) * s
		_life[i] = randf_range(0.35, 0.6)
		_age[i] = 0.0
		_size[i] = float(randi_range(1, 2))
		_col[i] = colors[i % colors.size()]
	_active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var alive := false
	for i in _n:
		_age[i] += delta
		if _age[i] < _life[i]:
			alive = true
			var v: Vector2 = _vel[i]
			v.y += 260.0 * delta   # gravity
			_vel[i] = v
			_pos[i] = _pos[i] + v * delta
	queue_redraw()
	if not alive:
		_finish()


## Hides the burst and returns it to the pool. It stays in the tree until it is spawned again or its parent goes.
func _finish() -> void:
	_active = false
	_live = maxi(_live - 1, 0)
	set_process(false)
	visible = false
	_idle.append(self)


func _exit_tree() -> void:
	if _active:   # freed or moved while still playing: release its slot
		_active = false
		_live = maxi(_live - 1, 0)


func _draw() -> void:
	for i in _n:
		if _age[i] >= _life[i]:
			continue
		# Last 30% of life blinks, a pixel-art fade (no alpha blending).
		if _age[i] > _life[i] * 0.7 and int(_age[i] * 40.0) % 2 == 0:
			continue
		draw_rect(Rect2(_pos[i].round(), Vector2.ONE * _size[i]), _col[i])
