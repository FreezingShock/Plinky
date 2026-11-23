class_name BloomRitual
extends Control
## The Bloom animation: what plays when a zone reset (Bloom, later Reforge) pays out.
##
## The sim has already reset by the time this runs; the HUD rows are told to count down from the old values over the
## same span (RollValue.countdown), so they all land together. Then a centred sequence plays (ui/fx/bloom_timeline.gd
## has the clock): a light-dither veil and a closing ring of ASCII marks, a flash, a big pop of the currency icon, pixel
## rings, sparkles and petals, the earned amount counting up, and a fly into the HUD row, which then rolls to its new total.
##
## Only pixels: 4x4 Bayer dither, whole-texel rects, nearest-filtered icon at integer scales, the theme's fonts.
## No camera shake. Reduce flashing, Still meadow and Calm camera swap it for a short fade (no flash, rings or particles);
## Reduce screen effects also drops the veil. Any click or key after a moment skips ahead. Nothing here blocks input.

const VEIL: Shader = preload("res://ui/fx/bloom_veil.gdshader")
const FLOWERS: Array[StringName] = [&"dewdrop", &"clover", &"thistle", &"heather", &"foxglove", &"starbloom"]
const MARKS: String = ".o*O"
const SKIP_AFTER: float = 0.45
const NUMBER_SIZE: int = 32
const HEAD_SIZE: int = 24

var sim: Sim
var hud: Hud
var _t: float = -1.0    ## seconds since the reset; negative = idle
var _plan: Dictionary = {}
var _calm: bool = false
var _gained: int = 0
var _reset: ZoneResetDef
var _color: Color = Color.WHITE
var _icon: Texture2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _veil_rect: ColorRect
var _mat: ShaderMaterial
var _text: Control      ## the labels' common origin, moved on the fly-out
var _head: Label
var _number: Label
var _caption: Label
var _hint: Label
var _burst_done: bool = false
var _released: bool = false
var _ticks: int = 0
var _parts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _mote_acc: float = 0.0
var _seeds_row: RollValue
var _font: Font


## Builds one on the HUD and listens for zone resets.
static func attach(p_hud: Hud, p_sim: Sim, bus: Node) -> BloomRitual:
	var r: BloomRitual = BloomRitual.new()
	r.hud = p_hud
	r.sim = p_sim
	p_hud.add_child(r)
	bus.reset_done.connect(r.start)
	return r


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	set_process(false)
	set_process_input(false)


## The veil and labels are built on the first Bloom, so an idle HUD carries one node for this, not eight.
func _build() -> void:
	if _text != null:
		return
	_veil_rect = ColorRect.new()
	_veil_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = VEIL
	_veil_rect.material = _mat
	add_child(_veil_rect)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	_head = _label(HEAD_SIZE, -162.0, 28.0)
	_number = _label(NUMBER_SIZE, 0.0, 44.0)
	_caption = _label(16, 44.0, 22.0)
	_hint = _label(16, 66.0, 40.0)


func _label(font_size: int, y: float, h: float) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = &"PopupLabel"
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(360.0, h)
	l.position = Vector2(-180.0, y)
	_text.add_child(l)
	return l


## True when the gentle version should play.
static func is_calm() -> bool:
	return FxConfig.reduce_flashing or MeadowLife.reduce_motion or WorldCamera.calm


## True while a reset animation runs anywhere: toasts, tip cards and banners hold until it ends.
static var running: bool = false


func playing() -> bool:
	return _t >= 0.0


## A zone reset just paid `gained` of its currency.
func start(reset_id: StringName, gained: int) -> void:
	_reset = sim.reset_defs.get(reset_id) as ZoneResetDef
	if _reset == null or gained <= 0:
		return
	_build()
	_end(false)   # a reset inside a running animation starts it over
	_gained = gained
	_calm = is_calm()
	_plan = BloomTimeline.plan(_calm)
	_color = StatStyle.color(_reset.currency)
	var big: String = "res://assets/icons/big/%s.png" % String(_reset.currency)
	_icon = load(big if ResourceLoader.exists(big) else "res://assets/icons/%s.png" % String(_reset.currency)) as Texture2D
	_rng.seed = 7919 + sim.reset_count(reset_id) * 131
	_parts.clear()
	_rings.clear()
	_sparks.clear()
	_burst_done = false
	_released = false
	_ticks = 0
	_mote_acc = 0.0
	_font = get_theme_default_font()
	_count_down_rows()
	var d: StatDef = sim.stat_defs.get(_reset.currency) as StatDef
	_head.text = _reset.display_name
	_number.text = "+0"
	_caption.text = d.display_name if d != null else String(_reset.currency).capitalize()
	_hint.text = _hint_text()
	for l: Label in [_head, _number, _caption]:
		l.add_theme_color_override("font_color", _color if l != _head else StatStyle.PAPER)
	_hint.add_theme_color_override("font_color", StatStyle.gain())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t = 0.0
	running = true
	visible = true
	set_process(true)
	set_process_input(true)
	Audio.bloom_swell()


## Every stat that dropped counts down over the plan's span; the currency row holds its old value until the number lands.
func _count_down_rows() -> void:
	var span: float = float(_plan["count"])
	for sid: StringName in hud.stat_value_ids():
		var row: RollValue = hud.stat_value(sid)
		var before: BigNum = sim.bloom_before.get(sid, null) as BigNum
		if row == null or before == null:
			continue
		if sid == _reset.currency:
			_seeds_row = row
			row.hold(before.max_zero(), float(_plan["total"]) + 2.0)   # released by the animation; the long span is a safety net
		elif sim.get_stat(sid).lt(before):
			row.countdown(before, span)


func _hint_text() -> String:
	var line: String = "%s %d: every pad pays +%d%% for good" % [_reset.display_name, sim.reset_count(_reset.id), int(roundf(sim.reset_bonus() * 100.0))]
	for a: AttributeDef in sim.attribute_defs.values():
		if a.currency == _reset.currency and sim.attr_unlocked(a.id) and sim.attr_level(a.id) < a.cap and not sim.attribute_available(a).lt(sim.attribute_cost(a.id)):
			return line + "\n" + "A gift is ready: open Upgrades [Tab]"
	return line


## The colours of the burst: the reset's own ladder (Nucleus: Embers to Emberheart), the flowers by default.
func _ladder() -> Array[StringName]:
	var out: Array[StringName] = []
	if _reset != null:
		for s: String in _reset.fx_stats:
			out.append(StringName(s))
	if out.is_empty():
		out.append_array(FLOWERS)
	return out


func _center() -> Vector2:
	return Vector2(roundf(size.x * 0.5), roundf(size.y * 0.36))


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var p: Dictionary = _plan
	if not _burst_done and _t >= float(p["burst"]):
		_burst()
	_set_light(p)
	_step_text(p)
	_step_fx(delta, p)
	if not _released and _t >= float(p["fly_end"]):
		_released = true
		if _seeds_row != null:
			_seeds_row.release()
	if _t >= float(p["total"]):
		_end(true)
		return
	queue_redraw()


## Veil and flash strength on the shader.
func _set_light(p: Dictionary) -> void:
	var veil: float = BloomTimeline.veil_at(_t, p)
	var flash: float = BloomTimeline.flash_at(_t, p)
	if FxConfig.reduce_screen_fx or _calm:
		veil = 0.0 if FxConfig.reduce_screen_fx else veil * 0.4
		flash = 0.0
	_mat.set_shader_parameter("veil", veil)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("size_px", size)


func _step_text(p: Dictionary) -> void:
	var burst: float = float(p["burst"])
	var shown: int = BloomTimeline.number_at(_gained, _t, p)
	_number.text = "+%d" % shown
	var steps: int = BloomTimeline.tick_steps(_gained, _t, p)
	if steps > _ticks:
		_ticks = steps
		Audio.bloom_tick(steps)
	var fade_in: float = clampf((_t - burst) / 0.25, 0.0, 1.0)
	var fly: float = BloomTimeline.fly_progress(_t, p)
	var alpha: float = fade_in * (1.0 - clampf((fly - 0.35) / 0.65, 0.0, 1.0))
	_text.modulate = Color(1.0, 1.0, 1.0, alpha)
	_hint.modulate.a = clampf((_t - float(p["up_end"])) / 0.3, 0.0, 1.0)
	var home: Vector2 = _center() + Vector2(0.0, 68.0)
	_text.position = (home.lerp(_target() , fly)).round()


## Where the icon and number fly to: the HUD row of the currency.
func _target() -> Vector2:
	if _seeds_row != null and is_instance_valid(_seeds_row):
		return (_seeds_row.global_position + _seeds_row.size * 0.5 - global_position).round()
	return Vector2(40.0, 20.0)


func _icon_pos(fly: float) -> Vector2:
	return _center().lerp(_target(), fly).round()


func _burst() -> void:
	_burst_done = true
	Audio.bloom_land()
	if _calm:
		return
	var c: Vector2 = _center()
	for i in 3:   # three pixel rings, each a different colour and speed
		_rings.append({"age": -0.08 * float(i), "life": 0.7 + 0.15 * float(i), "r0": 14.0, "r1": 70.0 + 38.0 * float(i),
			"col": [Color("fff1c8"), _color, StatStyle.color(_ladder()[-1])][i], "w": 2 if i == 0 else 1})
	var ladder: Array[StringName] = _ladder()
	var n: int = GraphicsQuality.particle_count(44)
	for i in n:
		var a: float = _rng.randf() * TAU
		var s: float = _rng.randf_range(50.0, 170.0)
		var col: Color = _color if i % 3 == 0 else StatStyle.color(ladder[i % ladder.size()])
		_parts.append({"pos": c + Vector2(cos(a), sin(a)) * 18.0, "vel": Vector2(cos(a), sin(a) * 0.8) * s, "life": _rng.randf_range(0.7, 1.5), "age": 0.0,
			"size": 2 if i % 4 == 0 else 1, "col": col, "grav": -30.0 if _reset.fx_rise else 40.0, "drag": 1.6})
	for i in GraphicsQuality.particle_count(16):
		var a2: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(36.0, 120.0)
		_sparks.append({"pos": (c + Vector2(cos(a2), sin(a2) * 0.85) * r).round(), "age": -_rng.randf_range(0.0, 0.7), "life": _rng.randf_range(0.5, 0.9),
			"col": [Color("fff1c8"), _color, Color("ffffff")][i % 3], "big": 1 + (1 if i % 3 == 0 else 0)})


func _step_fx(delta: float, p: Dictionary) -> void:
	for q: Dictionary in _parts:
		q["age"] = float(q["age"]) + delta
		var v: Vector2 = q["vel"] as Vector2
		v *= maxf(0.0, 1.0 - float(q["drag"]) * delta)
		v.y += float(q["grav"]) * delta
		q["vel"] = v
		q["pos"] = (q["pos"] as Vector2) + v * delta
	for r: Dictionary in _rings:
		r["age"] = float(r["age"]) + delta
	for s: Dictionary in _sparks:
		s["age"] = float(s["age"]) + delta
	_parts = Array(_parts.filter(func(q: Dictionary) -> bool: return float(q["age"]) < float(q["life"])), TYPE_DICTIONARY, "", null)
	_rings = Array(_rings.filter(func(r: Dictionary) -> bool: return float(r["age"]) < float(r["life"])), TYPE_DICTIONARY, "", null)
	_sparks = Array(_sparks.filter(func(s: Dictionary) -> bool: return float(s["age"]) < float(s["life"])), TYPE_DICTIONARY, "", null)
	# Seeds drift up off the resting icon.
	if not _calm and _t >= float(p["up_start"]) and _t < float(p["hold_end"]):
		_mote_acc += delta * float(GraphicsQuality.particle_count(14))
		while _mote_acc >= 1.0:
			_mote_acc -= 1.0
			var c: Vector2 = _center()
			_parts.append({"pos": c + Vector2(_rng.randf_range(-44.0, 44.0), _rng.randf_range(10.0, 52.0)), "vel": Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-34.0, -16.0)),
				"life": _rng.randf_range(0.8, 1.4), "age": 0.0, "size": 1 + _rng.randi() % 2, "col": _color if _rng.randf() < 0.6 else Color("fff1c8"), "grav": 0.0, "drag": 0.0})


func _draw() -> void:
	if _t < 0.0:
		return
	var p: Dictionary = _plan
	var burst: float = float(p["burst"])
	var c: Vector2 = _center()
	# The ring of ASCII marks closing in on the middle while the rows finish counting.
	if not _calm and _t >= float(p["charge"]) and _t < burst + 0.05 and _font != null:
		var u: float = clampf((_t - float(p["charge"])) / (burst - float(p["charge"])), 0.0, 1.0)
		var radius: float = lerpf(150.0, 22.0, u * u)
		var n: int = 28
		for i in n:
			var a: float = TAU * float(i) / float(n) + u * 1.6
			var marks: String = _reset.fx_marks if _reset != null and _reset.fx_marks != "" else MARKS
			var ch: String = marks[(i + int(_t * 18.0)) % marks.length()]
			var at: Vector2 = c + Vector2(cos(a), sin(a) * 0.8) * radius
			draw_string(_font, (at + Vector2(-3.0, 4.0)).round(), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, _color.lerp(Color.WHITE, u))
	var icon_scale: int = BloomTimeline.icon_scale(_t, p)
	var fly: float = BloomTimeline.fly_progress(_t, p)
	# Slow rays behind the resting icon.
	if not _calm and _t >= burst and fly < 0.2:
		var spin: float = _t * 0.6
		for k in 12:
			var a3: float = spin + TAU * float(k) / 12.0
			var dir: Vector2 = Vector2(cos(a3), sin(a3) * 0.85)
			for j in 6:
				var rr: float = 74.0 + float(j) * 7.0
				if (j + k + int(_t * 8.0)) % 2 == 0:
					draw_rect(Rect2((c + dir * rr).round(), Vector2.ONE), Color(_color.r, _color.g, _color.b, 1.0) if j < 4 else Color("fff1c8"))
	for r: Dictionary in _rings:
		_draw_ring(c, r)
	for q: Dictionary in _parts:
		var age: float = float(q["age"])
		var life: float = float(q["life"])
		if age > life * 0.7 and int(age * 40.0) % 2 == 0:
			continue   # the last part of a particle's life blinks out, pixel-art style
		var sz: float = float(q["size"])
		draw_rect(Rect2((q["pos"] as Vector2).round(), Vector2(sz, sz)), q["col"] as Color)
	for s: Dictionary in _sparks:
		_draw_spark(s)
	if icon_scale > 0 and _icon != null:
		var px: float = float(_icon.get_width() * icon_scale)
		var tint: Color = Color.WHITE
		if _calm:
			tint.a = clampf((_t - burst) / 0.4, 0.0, 1.0) * (1.0 - clampf((fly - 0.35) / 0.65, 0.0, 1.0))
		var bob: float = 0.0 if _calm or fly > 0.0 or _t < burst + 0.3 else roundf(sin(_t * 3.0))
		var centre: Vector2 = _icon_pos(fly) + Vector2(0.0, bob)
		draw_texture_rect(_icon, Rect2((centre - Vector2(px, px) * 0.5).round(), Vector2(px, px)), false, tint)


func _draw_ring(c: Vector2, r: Dictionary) -> void:
	var age: float = float(r["age"])
	if age < 0.0:
		return
	var u: float = age / float(r["life"])
	var radius: float = lerpf(float(r["r0"]), float(r["r1"]), 1.0 - pow(1.0 - u, 2.5))
	var n: int = maxi(16, int(radius * 1.1))
	var w: float = float(r["w"])
	for i in n:
		if (i + int(age * 30.0)) % 2 == 1 and u > 0.5:
			continue   # the ring thins into dashes as it fades
		var a: float = TAU * float(i) / float(n)
		draw_rect(Rect2((c + Vector2(cos(a), sin(a) * 0.85) * radius).round(), Vector2(w, w)), r["col"] as Color)


## A four-point twinkle that grows and shrinks in whole pixels.
func _draw_spark(s: Dictionary) -> void:
	var age: float = float(s["age"])
	if age < 0.0:
		return
	var u: float = age / float(s["life"])
	var arm: int = [1, 2, 3, 2, 1][clampi(int(u * 5.0), 0, 4)] * int(s["big"])
	var at: Vector2 = s["pos"] as Vector2
	var col: Color = s["col"] as Color
	draw_rect(Rect2(at, Vector2.ONE), Color.WHITE)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		for k in range(1, arm + 1):
			draw_rect(Rect2(at + d * float(k), Vector2.ONE), col)


func _input(event: InputEvent) -> void:
	if _t < SKIP_AFTER:
		return
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo)
	if press:
		skip()


## Jump ahead: rows stop counting, and the animation goes to the hold (or the fly-out if it is already resting).
func skip() -> void:
	if _t < 0.0:
		return
	for sid: StringName in hud.stat_value_ids():
		var row: RollValue = hud.stat_value(sid)
		if row != null and row != _seeds_row and row.timed():
			row.finish_timed()
	var p: Dictionary = _plan
	if _t < float(p["hold_end"]):
		_t = maxf(_t, float(p["burst"]) + 0.01)
		if _t < float(p["up_end"]) + 0.05:
			_t = float(p["up_end"]) + 0.05
	elif _t < float(p["fly_end"]):
		_t = float(p["fly_end"]) - 0.02


## Stop and tidy up. `finished` is true on a normal end (a reset inside a running animation passes false).
func _end(finished: bool) -> void:
	if _t < 0.0 and not finished:
		return
	_t = -1.0
	running = false
	visible = false
	set_process(false)
	set_process_input(false)
	if _mat != null:
		_mat.set_shader_parameter("veil", 0.0)
		_mat.set_shader_parameter("flash", 0.0)
	if _seeds_row != null and is_instance_valid(_seeds_row):
		_seeds_row.release()
	_seeds_row = null
	for sid: StringName in hud.stat_value_ids():
		var row: RollValue = hud.stat_value(sid)
		if row != null and row.timed():
			row.finish_timed()
