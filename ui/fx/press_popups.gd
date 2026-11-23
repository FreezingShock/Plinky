class_name PressPopups
extends Node2D
## Every press popup, drawn by ONE node from a fixed pool: no Label per press, no tweens, no allocations while playing.
## A popup is a small struct (Pop) that is rolled once at spawn (motion, easing, direction, size) so no two presses
## move alike, then animated purely from its age. Rules that keep the screen readable:
##   - Holding a pad keeps ONE running popup per pad that stacks every press into one number (locked decision).
##   - A press that lands within MERGE_WINDOW of the pad's last popup folds into it and re-pops it.
##   - Otherwise a new popup takes the first free lane around the anchor, so two numbers never sit on each other.
##   - At most MAX_POPS live at once, and relic pulses are dropped first when the screen is busy.
## Tier looks come from PopupStyle. Everything is whole pixels and hard colour steps. Lives in the screen-space overlay
## (see fx_bus.gd), so camera zoom never scales it.

const MAX_POPS: int = 24
const SOFT_CAP: int = 16            ## above this many live popups, relic pulses are skipped
const MAX_PARTS: int = 220
const MAX_LINKS: int = 8
const MAX_RINGS: int = 8
const MERGE_WINDOW: float = 1.2           ## a press this soon after a popup's last one folds into it
const MERGE_NEAR: float = 40.0            ## pixels: popups of the same stat this close are one stack
const LIFE: float = 0.95
const HOLD_LINGER: float = 0.5
const FLOAT_AFTER_HOLD: float = 0.8
const LANES: Array[Vector2] = [Vector2(0, 0), Vector2(-22, -6), Vector2(22, -6), Vector2(-42, -12), Vector2(42, -12), Vector2(0, -24), Vector2(0, -38), Vector2(-30, -26), Vector2(30, -26), Vector2(0, 26)]

enum Kind { PIXEL, STAR, SHARD }

class Pop:
	var live: bool = false
	var started: bool = false
	var key: StringName = &""
	var text: String = ""
	var anchor: Vector2 = Vector2.ZERO
	var lane: Vector2 = Vector2.ZERO
	var base: Vector2 = Vector2.ZERO       ## offset already earned before the last merge, keeps merges from jumping
	var age: float = 0.0                   ## negative while delayed
	var since_bump: float = 0.0
	var t0: float = 0.0                    ## age at which the float-away starts
	var life: float = 1.0
	var tier: int = 0
	var size_idx: int = 1
	var motion: int = 0
	var ease_id: int = 0
	var dir: float = 1.0
	var rnd: int = 0
	var rise: float = 16.0
	var total: float = 0.0
	var count: int = 1
	var crit: bool = false
	var pulse: bool = false
	var stat: String = ""                 ## name of the stat earned, drawn small under the number
	var stat_col: Color = Color.WHITE
	var banner: bool = false
	var running: bool = false
	var hidden: bool = false
	var check_t: float = 0.0
	var trail_t: float = 0.0
	var lay_text: String = ""
	var lay_size: int = 0
	var xs: PackedFloat32Array = PackedFloat32Array()
	var w: float = 0.0

class Link:
	var live: bool = false
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var age: float = 0.0       ## negative while delayed
	var life: float = 0.32
	var tier: int = 0

class Ring:
	var live: bool = false
	var at: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var life: float = 0.4
	var reach: float = 20.0
	var col: Color = Color.WHITE

static var instance: PressPopups

var font: Font
var _pops: Array[Pop] = []
var _links: Array[Link] = []
var _rings: Array[Ring] = []
var _runs: Dictionary = {}                 ## StringName pad key -> its running Pop
var _p_pos: PackedVector2Array = PackedVector2Array()
var _p_vel: PackedVector2Array = PackedVector2Array()
var _p_age: PackedFloat32Array = PackedFloat32Array()
var _p_life: PackedFloat32Array = PackedFloat32Array()
var _p_grav: PackedFloat32Array = PackedFloat32Array()
var _p_col: PackedColorArray = PackedColorArray()
var _p_size: PackedInt32Array = PackedInt32Array()
var _p_kind: PackedInt32Array = PackedInt32Array()
var _p_next: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0


func _ready() -> void:
	instance = self
	_rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 100
	for i in MAX_POPS:
		_pops.append(Pop.new())
	for i in MAX_LINKS:
		_links.append(Link.new())
	for i in MAX_RINGS:
		_rings.append(Ring.new())
	_p_pos.resize(MAX_PARTS)
	_p_vel.resize(MAX_PARTS)
	_p_age.resize(MAX_PARTS)
	_p_life.resize(MAX_PARTS)
	_p_grav.resize(MAX_PARTS)
	_p_col.resize(MAX_PARTS)
	_p_size.resize(MAX_PARTS)
	_p_kind.resize(MAX_PARTS)
	for i in MAX_PARTS:
		_p_age[i] = 1.0
		_p_life[i] = 0.0
	set_process(false)


func _exit_tree() -> void:
	if instance == self:
		instance = null


## HoldPress.end(): every running popup holds a moment, then floats away with a last burst.
static func release_runs() -> void:
	if instance != null:
		instance.release_all()


# ------------------------------------------------------------------ spawning
## One pad press. key identifies the pad (merging and hold stacking are per pad). at is the screen anchor (centre, baseline).
func press(key: StringName, at: Vector2, amount: float, tier: int, crit: bool, held: bool, pulse := false, delay := 0.0, stat := "", stat_col := Color.WHITE) -> void:
	if not _ensure_font():
		return
	if pulse and _live_count() >= SOFT_CAP:
		return
	if held:
		var run: Pop = _runs.get(key) as Pop
		if run != null and run.live and run.running:
			run.total += amount
			run.count += 1
			run.crit = run.crit or crit
			_restyle(run, tier)
			return
	else:
		var m: Pop = _find_mergeable(key, at, stat)
		if m != null:
			_fold_in(m, amount, crit, tier)
			return
	var p: Pop = _alloc()
	_init_pop(p, key, at, amount, tier, crit, pulse, delay)
	p.stat = stat
	p.stat_col = stat_col
	if held:
		p.running = true
		p.t0 = 9999.0
		p.life = 9999.0
		_runs[key] = p
	else:
		_place(p)
	set_process(true)


## A banner or plain text popup ("GOLD", "LV 3"). It still takes a free lane, so it never lands on a number.
func label(key: StringName, at: Vector2, text: String, tier: int, banner := false, delay := 0.0) -> void:
	if not _ensure_font():
		return
	var p: Pop = _alloc()
	_init_pop(p, key, at, 0.0, tier, false, false, delay)
	p.text = text
	p.banner = banner
	p.size_idx = clampi(PopupStyle.size_index(tier, true, false, 0) + (1 if banner else 0), 0, PopupStyle.SIZES.size() - 1)
	p.rise = PopupStyle.rise_for(tier, p.size_idx) * 0.7
	p.life = 1.15 + 0.1 * float(tier)
	if banner:
		p.motion = PopupStyle.Motion.SLAM
	p.lay_text = ""
	_place(p)
	set_process(true)


## Radial burst of tier-coloured pixels. strength 1.0 is a normal press.
func burst(at: Vector2, tier: int, strength: float) -> void:
	var cols: Array[Color] = PopupStyle.spark_colors(tier, PopupStack.zone)
	var n: int = GraphicsQuality.particle_count(int(6.0 + float(tier) * 3.0 * strength + 4.0 * strength))
	for i in n:
		var a: float = _rng.randf() * TAU
		var s: float = _rng.randf_range(24.0, 70.0) * (0.7 + 0.4 * strength)
		var kind: int = Kind.STAR if (tier >= 2 and _rng.randf() < 0.3) else Kind.PIXEL
		_emit(at, Vector2(cos(a), sin(a) * 0.6 - 0.5) * s, _rng.randf_range(0.3, 0.6) + 0.04 * float(tier),
			cols[_rng.randi() % cols.size()], 2 if kind == Kind.STAR else _rng.randi_range(1, 2), kind, 120.0 if tier != 5 else 8.0)
	set_process(true)


func ring(at: Vector2, tier: int, reach := 24.0) -> void:
	for r in _rings:
		if not r.live:
			r.live = true
			r.at = at
			r.age = 0.0
			r.life = 0.4
			r.reach = reach
			r.col = PopupStyle.accent_color(tier, _clock, PopupStack.zone)
			break
	set_process(true)


## A dashed spark line from one pad to another, for a relic pulse. It starts after `delay` seconds.
func link(from: Vector2, to: Vector2, tier: int, delay := 0.0) -> void:
	for l in _links:
		if not l.live:
			l.live = true
			l.from = from
			l.to = to
			l.age = -delay
			l.life = 0.32
			l.tier = tier
			break
	set_process(true)


## The chain just broke: a few dim pixels sink away from where the number was.
func fizzle(at: Vector2, tier: int) -> void:
	var cols: Array[Color] = PopupStyle.spark_colors(tier, PopupStack.zone)
	for i in GraphicsQuality.particle_count(8):
		_emit(at + Vector2(_rng.randf_range(-14.0, 14.0), 0.0), Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(4.0, 18.0)),
			_rng.randf_range(0.4, 0.8), cols[_rng.randi() % cols.size()].darkened(0.35), 1, Kind.PIXEL, 60.0)
	set_process(true)


func release_all() -> void:
	for key: StringName in _runs.keys():
		var p: Pop = _runs[key] as Pop
		if p != null and p.live and p.running:
			p.running = false
			p.t0 = maxf(p.age, 0.0) + HOLD_LINGER
			p.life = p.t0 + FLOAT_AFTER_HOLD
			if p.count >= 4:
				burst(_pos_of(p) + Vector2(0.0, -6.0), p.tier, minf(float(p.count) / 20.0, 2.0))
	_runs.clear()


func live_count() -> int:
	return _live_count()


# ------------------------------------------------------------------ pool and layout
func _ensure_font() -> bool:
	if font != null:
		return true
	if PopupNumber.ui_theme != null:
		font = PopupNumber.ui_theme.get_font(&"font", &"PopupLabel")
	if font == null:
		font = ThemeDB.fallback_font
	return font != null


func _live_count() -> int:
	var n: int = 0
	for p in _pops:
		if p.live:
			n += 1
	return n


## A free popup, or the one closest to finishing when the pool is full (never a running hold).
func _alloc() -> Pop:
	var best: Pop = null
	var best_p: float = -1.0
	for p in _pops:
		if not p.live:
			return p
		if p.running:
			continue
		var prog: float = p.age / maxf(p.life, 0.01)
		if prog > best_p:
			best_p = prog
			best = p
	if best == null:
		best = _pops[0]
		_runs.erase(best.key)
	best.live = false
	return best


func _format(p: Pop) -> String:
	return "+" + NumberFormat.short(p.total) + ("!" if p.crit else "")


func _hold_digits(total: float) -> int:
	return clampi(int(floor(log(maxf(total, 1.0)) / log(10.0))) - 1, 0, 2)


func _init_pop(p: Pop, key: StringName, at: Vector2, amount: float, tier: int, crit: bool, pulse: bool, delay: float) -> void:
	p.live = true
	p.started = false
	p.key = key
	p.anchor = at.round()
	p.lane = Vector2.ZERO
	p.base = Vector2.ZERO
	p.total = amount
	p.count = 1
	p.tier = tier
	p.crit = crit
	p.pulse = pulse
	p.banner = false
	p.running = false
	p.hidden = false
	p.check_t = 0.0
	p.trail_t = 0.0
	p.age = -delay
	p.since_bump = -delay
	p.rnd = _rng.randi() % 100000
	p.motion = PopupStyle.pick_motion(tier, _rng.randf())
	p.ease_id = _rng.randi() % PopupStyle.EASE_COUNT
	p.dir = -1.0 if _rng.randf() < 0.5 else 1.0
	p.size_idx = PopupStyle.size_index(tier, crit, pulse, 0)
	p.rise = PopupStyle.rise_for(tier, p.size_idx)
	p.t0 = 0.0
	p.life = LIFE + 0.08 * float(tier)
	p.text = _format(p)
	p.lay_text = ""


func _layout(p: Pop, fs: int) -> void:
	if p.lay_text == p.text and p.lay_size == fs:
		return
	p.lay_text = p.text
	p.lay_size = fs
	var spacing: float = 1.0 if p.banner else 0.0
	p.xs.resize(p.text.length())
	var x: float = 0.0
	for i in p.text.length():
		p.xs[i] = x
		x += font.get_char_size(p.text.unicode_at(i), fs).x + spacing
	p.w = x


func _size_px(p: Pop) -> int:
	return PopupStyle.SIZES[clampi(p.size_idx, 0, PopupStyle.SIZES.size() - 1)]


func _progress(p: Pop) -> float:
	return clampf((p.age - p.t0) / maxf(p.life - p.t0, 0.01), 0.0, 1.0)


func _pos_of(p: Pop) -> Vector2:
	return p.anchor + p.lane + p.base + PopupStyle.motion_offset(p.motion, _progress(p), p.rnd, p.dir, p.rise, p.ease_id)


func _rect_of(p: Pop) -> Rect2:
	_layout(p, _size_px(p))
	var wide: float = p.w + (10.0 if p.pulse else 0.0) + 4.0
	var high: float = float(_size_px(p)) + 4.0 + (13.0 if p.stat != "" else 0.0)
	var c: Vector2 = _pos_of(p)
	return Rect2(c.x - wide * 0.5, c.y - high + (13.0 if p.stat != "" else 0.0), wide, high)


## First lane whose rectangle clears every other live popup; if all are taken, the least crowded one.
func _place(p: Pop) -> void:
	var best: Vector2 = Vector2.ZERO
	var best_hits: int = 1000
	for ln: Vector2 in LANES:
		p.lane = ln
		var r: Rect2 = _rect_of(p)
		var hits: int = 0
		for q in _pops:
			if q.live and q != p and q.age > -0.2 and r.intersects(_rect_of(q)):
				hits += 1
		if hits < best_hits:
			best_hits = hits
			best = ln
		if hits == 0:
			break
	p.lane = best


## A live number of the same stat on this pad, or on a pad close by, that a new press should fold into.
func _find_mergeable(key: StringName, at: Vector2, stat: String) -> Pop:
	var best: Pop = null
	var best_d: float = MERGE_NEAR + 1.0
	for p in _pops:
		if not p.live or p.running or p.banner or p.total <= 0.0 or p.stat != stat:
			continue
		if p.since_bump < 0.0 or p.since_bump >= MERGE_WINDOW:
			continue
		var d: float = 0.0 if p.key == key else p.anchor.distance_to(at.round())
		if d < best_d:
			best_d = d
			best = p
	return best


## Fold a new press into a live popup: the number adds up, it re-pops, and it floats on from about where it is.
## The carried offset is capped, so a long run of presses keeps one number hovering instead of climbing off screen.
func _fold_in(p: Pop, amount: float, crit: bool, tier: int) -> void:
	var off: Vector2 = p.base + PopupStyle.motion_offset(p.motion, _progress(p), p.rnd, p.dir, p.rise, p.ease_id)
	p.base = Vector2(clampf(off.x, -16.0, 16.0), clampf(off.y, -p.rise * 0.9, 0.0))
	p.t0 = p.age
	p.life = p.age + LIFE + 0.08 * float(maxi(tier, p.tier))
	p.total += amount
	p.count += 1
	p.crit = p.crit or crit
	_restyle(p, tier)


func _restyle(p: Pop, tier: int) -> void:
	if tier > p.tier:
		p.tier = tier
		p.motion = PopupStyle.pick_motion(tier, _rng.randf())
	p.size_idx = PopupStyle.size_index(p.tier, p.crit, p.pulse, _hold_digits(p.total) if p.running else 0)
	p.rise = PopupStyle.rise_for(p.tier, p.size_idx)
	p.text = _format(p)
	p.since_bump = 0.0
	if p.age >= 0.0:
		_sparkle(p, 2 + p.tier)


func _emit(at: Vector2, vel: Vector2, life: float, col: Color, size: int, kind: int, grav: float) -> void:
	var cap: int = clampi(GraphicsQuality.particle_count(MAX_PARTS), 24, MAX_PARTS)
	var i: int = _p_next % cap
	_p_next = (i + 1) % cap
	_p_pos[i] = at
	_p_vel[i] = vel
	_p_age[i] = 0.0
	_p_life[i] = life
	_p_grav[i] = grav
	_p_col[i] = col
	_p_size[i] = size
	_p_kind[i] = kind


## A few tier-coloured pixels around the popup.
func _sparkle(p: Pop, n: int) -> void:
	var cols: Array[Color] = PopupStyle.spark_colors(p.tier, PopupStack.zone)
	var c: Vector2 = _pos_of(p)
	var half: float = maxf(p.w * 0.5, 8.0)
	for i in GraphicsQuality.particle_count(n):
		var at: Vector2 = c + Vector2(_rng.randf_range(-half, half), _rng.randf_range(-float(_size_px(p)), 0.0))
		var kind: int = Kind.STAR if p.tier >= 2 and _rng.randf() < 0.5 else Kind.PIXEL
		var vel: Vector2 = Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-22.0, -4.0))
		var grav: float = 40.0
		if p.tier == 2:
			kind = Kind.SHARD
			vel = Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(2.0, 12.0))
		elif p.tier == 5:
			grav = 0.0
			vel *= 0.4
		_emit(at, vel, _rng.randf_range(0.3, 0.65), cols[_rng.randi() % cols.size()], 2 if kind == Kind.STAR else 1, kind, grav)


# ------------------------------------------------------------------ frame
func _calm() -> bool:
	return FxConfig.reduce_flashing or MeadowLife.reduce_motion or WorldCamera.calm


func _process(delta: float) -> void:
	_clock += delta
	var calm: bool = _calm()
	var any: bool = false
	var covered: Callable = PopupNumber.under_menu
	for p in _pops:
		if not p.live:
			continue
		any = true
		p.age += delta
		p.since_bump += delta
		if p.age < 0.0:
			continue
		if not p.started:
			p.started = true
			_on_start(p)
		if p.age >= p.life:
			p.live = false
			if _runs.get(p.key) == p:
				_runs.erase(p.key)
			continue
		# Trailing sparkles: each tier has its own rate and look; calm mode keeps a quarter of them.
		if p.tier >= 1:
			p.trail_t -= delta
			if p.trail_t <= 0.0:
				p.trail_t = (0.11 - 0.012 * float(p.tier)) * (4.0 if calm else 1.0)
				_sparkle(p, 1)
		p.check_t -= delta
		if p.check_t <= 0.0:
			p.check_t = 0.2
			p.hidden = covered.is_valid() and bool(covered.call(_pos_of(p)))
	for l in _links:
		if l.live:
			any = true
			l.age += delta
			if l.age >= l.life:
				l.live = false
	for r in _rings:
		if r.live:
			any = true
			r.age += delta
			if r.age >= r.life:
				r.live = false
	var cap: int = clampi(GraphicsQuality.particle_count(MAX_PARTS), 24, MAX_PARTS)
	for i in cap:
		if _p_age[i] < _p_life[i]:
			any = true
			_p_age[i] += delta
			var v: Vector2 = _p_vel[i]
			v.y += _p_grav[i] * delta
			_p_vel[i] = v
			_p_pos[i] += v * delta
	queue_redraw()
	if not any:
		set_process(false)


func _on_start(p: Pop) -> void:
	_sparkle(p, 3 + p.tier * 2 + (4 if p.crit else 0))
	if p.crit or p.tier >= 3:
		ring(_pos_of(p) + Vector2(0.0, -float(_size_px(p)) * 0.4), p.tier, 18.0 + 6.0 * float(p.tier))


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if font == null:
		return
	var calm: bool = _calm()
	for r in _rings:
		if r.live:
			_draw_ring(r)
	for l in _links:
		if l.live and l.age >= 0.0:
			_draw_link(l)
	for p in _pops:
		if p.live and p.age >= 0.0 and not p.hidden:
			_draw_pop(p, calm)
	_draw_particles()


func _px(c: Vector2, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(c.round(), Vector2(w, h)), col)


func _draw_ring(r: Ring) -> void:
	var f: float = r.age / r.life
	var rad: float = r.reach * PopupStyle.ease_fn(0, f)
	if int(f * 12.0) % 2 == 1 and f > 0.6:
		return
	var n: int = 10 + int(rad * 0.7)
	for i in n:
		var a: float = TAU * float(i) / float(n)
		_px(r.at + Vector2(cos(a) * rad, sin(a) * rad * 0.55), 1.0, 1.0, r.col)


func _draw_link(l: Link) -> void:
	var f: float = clampf(l.age / l.life, 0.0, 1.0)
	var d: Vector2 = l.to - l.from
	var steps: int = maxi(int(d.length() / 3.0), 2)
	var col: Color = PopupStyle.accent_color(l.tier, _clock, PopupStack.zone).lerp(PopupStyle.PULSE, 0.5)
	var head: int = int(f * float(steps))
	for k in steps + 1:
		if k > head:
			break
		if (k + int(l.age * 40.0)) % 2 == 0:
			_px(l.from + d * (float(k) / float(steps)), 1.0, 1.0, col)
	_px(l.from + d * f - Vector2(1.0, 1.0), 3.0, 3.0, PopupStyle.STAR)


func _diamond(c: Vector2, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var half: int = r - absi(dy)
		draw_rect(Rect2(roundf(c.x) - float(half), roundf(c.y) + float(dy), float(half * 2 + 1), 1.0), col)


func _draw_pop(p: Pop, calm: bool) -> void:
	var prog: float = _progress(p)
	var motion: int = PopupStyle.Motion.RISE if calm else p.motion
	var off: Vector2 = p.base + PopupStyle.motion_offset(motion, prog, p.rnd, p.dir, p.rise, p.ease_id)
	# The first moments of every press and merge are one size bigger: the punch, in whole font sizes.
	var idx: int = p.size_idx + (1 if (p.since_bump < 0.07 and not calm) else 0)
	var fs: int = PopupStyle.SIZES[clampi(idx, 0, PopupStyle.SIZES.size() - 1)]
	_layout(p, fs)
	var icon_w: float = 10.0 if p.pulse else 0.0
	var x0: float = p.anchor.x + p.lane.x + off.x - (p.w + icon_w) * 0.5
	var y: float = p.anchor.y + p.lane.y + off.y
	var fade: float = ceilf(clampf((1.0 - prog) / 0.3, 0.0, 1.0) * 4.0) / 4.0
	var n: int = p.text.length()
	var tcol: float = 0.0 if FxConfig.reduce_flashing else p.age
	var flash: bool = p.since_bump < 0.05 and not FxConfig.reduce_flashing
	var oc: Color = PopupStyle.outline_color(p.tier)
	oc.a = fade
	var shiver: float = 0.0
	if p.tier == 2 and not calm and p.since_bump < 0.12:
		shiver = 1.0 if int(p.age * 60.0) % 2 == 0 else -1.0   # a cold 1 px shiver on arrival
	# Outlines first, so neighbours never cover each other's fill.
	for i in n:
		var cx: float = roundf(x0 + icon_w + p.xs[i] + shiver + PopupStyle.glitch_x(p.tier, p.rnd, i, p.age, calm))
		var cy: float = roundf(y + (0.0 if calm else PopupStyle.char_wave(p.motion, p.tier, i, p.age)))
		draw_char_outline(font, Vector2(cx, cy), p.text[i], fs, 2, oc)
	if p.pulse:
		var dc: Vector2 = Vector2(x0 + 4.0, y - float(fs) * 0.32)
		var dk: Color = PopupStyle.INK
		dk.a = fade
		_diamond(dc, 4, dk)
		var pc: Color = PopupStyle.PULSE
		pc.a = fade
		_diamond(dc, 3, pc)
	for i in n:
		var gx: float = PopupStyle.glitch_x(p.tier, p.rnd, i, p.age, calm)
		var cx: float = roundf(x0 + icon_w + p.xs[i] + shiver + gx)
		var cy: float = roundf(y + (0.0 if calm else PopupStyle.char_wave(p.motion, p.tier, i, p.age)))
		if p.tier == 4 and not calm:
			var gr: Color = PopupStyle.CHROMA_RED
			gr.a = fade
			var gc: Color = PopupStyle.CHROMA_CYAN
			gc.a = fade
			draw_char(font, Vector2(cx - 1.0, cy), p.text[i], fs, gr)
			draw_char(font, Vector2(cx + 1.0, cy), p.text[i], fs, gc)
		var col: Color = PopupStyle.STAR if flash else PopupStyle.char_color(p.tier, i, n, tcol, p.rnd, PopupStack.zone)
		col.a = fade
		draw_char(font, Vector2(cx, cy), p.text[i], fs, col)
	if p.stat != "" or (p.running and p.count >= 3):
		_draw_caption(p, x0 + icon_w, y, fs, off, fade, tcol, oc)


## Under the number, centred: the stat's name in the stat's own colour, then " xN" (streak colour) while a hold stacks.
func _draw_caption(p: Pop, _x0: float, y: float, fs: int, off: Vector2, fade: float, tcol: float, oc: Color) -> void:
	var count_txt: String = (" x%d" % p.count) if (p.running and p.count >= 3) else ""
	var w_name: float = 0.0
	for k in p.stat.length():
		w_name += font.get_char_size(p.stat.unicode_at(k), 12).x
	var w_cnt: float = 0.0
	for k in count_txt.length():
		w_cnt += font.get_char_size(count_txt.unicode_at(k), 12).x
	var sx: float = roundf(p.anchor.x + p.lane.x + off.x - (w_name + w_cnt) * 0.5)
	var sy: float = roundf(y + 9.0 + float(fs) * 0.14)
	if p.stat != "":
		var sc: Color = p.stat_col
		sc.a = fade
		draw_string_outline(font, Vector2(sx, sy), p.stat, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 2, oc)
		draw_string(font, Vector2(sx, sy), p.stat, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, sc)
	if count_txt != "":
		var cc: Color = PopupStyle.accent_color(p.tier, tcol, PopupStack.zone)
		cc.a = fade
		draw_string_outline(font, Vector2(sx + w_name, sy), count_txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, 2, oc)
		draw_string(font, Vector2(sx + w_name, sy), count_txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, cc)


func _draw_particles() -> void:
	var cap: int = clampi(GraphicsQuality.particle_count(MAX_PARTS), 24, MAX_PARTS)
	for i in cap:
		var age: float = _p_age[i]
		var life: float = _p_life[i]
		if age >= life:
			continue
		if age > life * 0.7 and int(age * 40.0) % 2 == 0:
			continue   # the last 30% blinks out, a pixel-art fade
		var c: Vector2 = _p_pos[i].round()
		var col: Color = _p_col[i]
		var s: int = _p_size[i]
		match _p_kind[i]:
			Kind.STAR:
				if int(age * 16.0) % 2 == 0:
					draw_rect(Rect2(c + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), col)
					draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), col)
				else:
					draw_rect(Rect2(c, Vector2.ONE), col)
			Kind.SHARD:
				draw_rect(Rect2(c, Vector2(1.0, 2.0)), col)
			_:
				draw_rect(Rect2(c, Vector2(float(s), float(s))), col)
