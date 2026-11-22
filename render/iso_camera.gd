class_name IsoCamera
extends Camera3D
## Fixed orthographic iso camera. 30 deg down, 45 deg yaw, 1 world unit = 16 texels.
## Position is snapped to whole texels in camera space; the leftover fraction is exposed as
## frac_shift (screen texels) for PixelViewport to apply as the image offset.

signal snapped(texels: Vector2i, frac: Vector2)

const TEXELS_PER_UNIT := 16.0
const VIEW_HEIGHT_TEXELS := 362
const DISTANCE := 60.0

@export var target: Node3D
@export var follow_speed: float = 6.0

var focus: Vector3 = Vector3.ZERO
var snap_texels: Vector2i = Vector2i.ZERO   # camera-space texels (x right, y up)
var frac_shift: Vector2 = Vector2.ZERO      # screen texels to shift the image by

func _init() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	size = VIEW_HEIGHT_TEXELS / TEXELS_PER_UNIT
	near = 0.1
	far = 200.0
	basis = Basis.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(45.0), 0.0))

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK       # id 0 = empty in the G-buffer
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment = env
	if target:
		focus = target.global_position
	_apply()

func _process(delta: float) -> void:
	if target:
		focus = focus.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	_apply()

func snap_to(pos: Vector3) -> void:
	focus = pos
	_apply()

func _apply() -> void:
	var right := basis.x
	var up := basis.y
	var fwd := -basis.z
	var cx := focus.dot(right) * TEXELS_PER_UNIT
	var cy := focus.dot(up) * TEXELS_PER_UNIT
	var sx := roundf(cx)
	var sy := roundf(cy)
	var base := fwd * focus.dot(fwd)
	global_position = base + right * (sx / TEXELS_PER_UNIT) + up * (sy / TEXELS_PER_UNIT) - fwd * DISTANCE
	var t := Vector2i(int(sx), int(sy))
	var f := Vector2(-(cx - sx), cy - sy)
	if t != snap_texels or not f.is_equal_approx(frac_shift):
		snap_texels = t
		frac_shift = f
		snapped.emit(t, f)
