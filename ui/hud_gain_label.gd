class_name HudGainLabel
extends Control
## The HUD gain label for one statistic: "+123" beside its row, outside the stats panel. It is one pooled node per row,
## never one per gain. It rises in on a run's first gain, jumps a little on each gain, throws a few sparkles in the
## tier's colours, then fades out once HudGainTally's hold has passed. Reduce Motion keeps the fade and drops the rise,
## the jump and the sparkles.

const SIZE: int = 10              ## font size in pixels; smaller than the world number, which is the point
const SPARKS: int = 6             ## most sparkles alive at once: a fixed pool, not a node per gain
const SPARK_LIFE: float = 0.45    ## seconds a sparkle lives
const SPARK_SPEED: float = 26.0   ## pixels per second a sparkle starts with
const BUMP: float = 2.0           ## pixels the label jumps on each gain, easing back to its rest spot
const BUMP_TIME: float = 0.12     ## seconds the jump takes to ease back

var _text: String = ""
var _colour: Color = Color.WHITE
var _alpha: float = 0.0
var _rise: float = 0.0            ## pixels above the rest spot (pop-in, and the float out)
var _bump_t: float = -1.0         ## seconds since the last gain's jump; negative means no jump is running
var _calm: bool = false
var _spark_pos: PackedVector2Array = PackedVector2Array()
var _spark_vel: PackedVector2Array = PackedVector2Array()
var _spark_life: PackedFloat32Array = PackedFloat32Array()
var _spark_col: Array[Color] = []


func _init() -> void:
	theme_type_variation = &"TitleLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for i in SPARKS:
		_spark_pos.append(Vector2.ZERO)
		_spark_vel.append(Vector2.ZERO)
		_spark_life.append(0.0)
		_spark_col.append(Color.WHITE)


## Sets the text and tint. The minimum size follows the text, so the row's panel never clips it.
func show_text(t: String, col: Color) -> void:
	if t != _text:
		_text = t
		var font: Font = get_theme_font(&"font", &"TitleLabel")
		custom_minimum_size = Vector2(font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 4.0, font.get_height(SIZE) + 4.0)
		size = custom_minimum_size
	_colour = col
	queue_redraw()


## One frame of the label's state: `alpha` 0 to 1, and `rise`, the pop-in and float height in pixels.
func set_state(alpha: float, rise: float, calm: bool) -> void:
	var r: float = 0.0 if calm else rise
	var shown: bool = alpha > 0.0
	if calm == _calm and alpha == _alpha and r == _rise and shown == visible:
		return   # the HUD sets this every frame; redraw only when the label actually moved or faded
	_calm = calm
	_alpha = alpha
	_rise = r
	visible = shown
	queue_redraw()


## A gain landed: the label jumps a little and eases back. Nothing moves under Reduce Motion.
func bump() -> void:
	if _calm:
		return
	_bump_t = 0.0
	set_process(true)


## Throws up to `n` sparkles from the label's middle in the given colours. Off under Reduce Motion.
func sparkle(n: int, colours: Array[Color]) -> void:
	if _calm or colours.is_empty():
		return
	var spawned: int = 0
	for i in SPARKS:
		if spawned >= n:
			break
		if _spark_life[i] > 0.0:
			continue
		var a: float = randf() * TAU
		_spark_pos[i] = Vector2(size.x * 0.5, size.y * 0.5)
		_spark_vel[i] = Vector2(cos(a), sin(a) - 0.6) * SPARK_SPEED * randf_range(0.6, 1.0)
		_spark_life[i] = SPARK_LIFE
		_spark_col[i] = colours[randi() % colours.size()]
		spawned += 1
	if spawned > 0:
		set_process(true)


func _process(delta: float) -> void:
	var live: bool = false
	for i in SPARKS:
		if _spark_life[i] <= 0.0:
			continue
		_spark_life[i] -= delta
		_spark_pos[i] += _spark_vel[i] * delta
		live = live or _spark_life[i] > 0.0
	if _bump_t >= 0.0:
		_bump_t += delta
		if _bump_t >= BUMP_TIME:
			_bump_t = -1.0
		else:
			live = true
	queue_redraw()
	if not live:
		set_process(false)


func _draw() -> void:
	if _text == "" or _alpha <= 0.0:
		return
	var font: Font = get_theme_font(&"font", &"TitleLabel")
	var bump: float = 0.0
	if _bump_t >= 0.0:
		bump = BUMP * (1.0 - _bump_t / BUMP_TIME)
	var pos: Vector2 = Vector2(2.0, (size.y - font.get_height(SIZE)) * 0.5 + font.get_ascent(SIZE))
	pos = (pos + Vector2(0.0, -(_rise + bump))).round()
	var ink: Color = RelicStyle.ink
	ink.a = _alpha
	var col: Color = _colour
	col.a = _alpha
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 3, ink)
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, col)
	for i in SPARKS:
		if _spark_life[i] <= 0.0:
			continue
		var c: Color = _spark_col[i]
		c.a = _alpha * clampf(_spark_life[i] / SPARK_LIFE, 0.0, 1.0)
		draw_rect(Rect2((_spark_pos[i] - Vector2(0.5, 0.5)).round(), Vector2(1.0, 1.0)), c)
