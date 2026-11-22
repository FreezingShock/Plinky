extends Node
## Autoload "Fx". Turns events into shader state: global time and wind, shimmer steps, press
## ripples (max 8), palette targets. UI Transitions owns `shift`, `invert` and `ascii` tweens.
##
## Zone entry sequence: Fx.set_zone_palette(id) (sets palette_a = old, palette_b = new, shift = 0),
## then Transitions.zone_shift() tweens shift 0 -> 1. Fx does this itself on EventBus.zone_entered.
## Milestone: Transitions.invert_flash(); Fx adds the wide ripple on gate_opened / rebirth_done.

const MAX_RIPPLES := 8
const RIPPLE_TIME := 0.8
const MILESTONE_TIME := 1.4
const SHIMMER_FPS := 10.0

var pv: PixelViewport
var current_palette: StringName = Palettes.MEADOW
var _pos := PackedVector2Array()
var _age := PackedFloat32Array()
var _dur := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _t := 0.0
var _arr := PackedVector4Array()   # reused each frame, so the ripple upload allocates nothing
var _uploaded_idle := false        # true once an all-zero ripple array is on the GPU side
var _shimmer_sent := -1.0

func _init() -> void:
	RenderGlobals.ensure()
	for i in MAX_RIPPLES:
		_pos.append(Vector2.ZERO)
		_age.append(1.0)
		_dur.append(RIPPLE_TIME)
		_scale.append(0.0)

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.connect("button_pressed", _on_button_pressed)
		bus.connect("zone_entered", _on_zone_entered)
		bus.connect("gate_opened", _on_milestone)
		bus.connect("rebirth_done", _on_milestone)

func bind(viewport_node: PixelViewport) -> void:
	pv = viewport_node
	set_palette_now(current_palette)

func set_palette_now(id: StringName) -> void:
	current_palette = id
	if pv and pv.post_material:
		pv.post_material.set_shader_parameter("palette_a", Palettes.texture(id))
		pv.post_material.set_shader_parameter("palette_b", Palettes.texture(id))
		pv.post_material.set_shader_parameter("shift", 0.0)

## Start a shift. Caller (Transitions) then tweens `shift` from 0 to 1.
func set_zone_palette(id: StringName) -> void:
	if pv == null or id == current_palette:
		return
	var m := pv.post_material
	m.set_shader_parameter("palette_a", Palettes.texture(current_palette))
	m.set_shader_parameter("palette_b", Palettes.texture(id))
	m.set_shader_parameter("shift", 0.0)
	current_palette = id

func spawn_ripple_texel(center: Vector2, radius_scale: float = 1.0, duration: float = RIPPLE_TIME) -> void:
	var slot := 0
	var oldest := -1.0
	for i in MAX_RIPPLES:
		if _scale[i] <= 0.0:
			slot = i
			break
		var a := _age[i] / _dur[i]
		if a > oldest:
			oldest = a
			slot = i
	_pos[slot] = center
	_age[slot] = 0.0
	_dur[slot] = duration
	_scale[slot] = radius_scale

func spawn_ripple(world_pos: Vector3, radius_scale: float = 1.0) -> void:
	if pv:
		spawn_ripple_texel(pv.world_to_texel(world_pos), radius_scale)

func _process(delta: float) -> void:
	_t += delta
	RenderingServer.global_shader_parameter_set(&"fx_time", _t)
	if pv == null:
		return
	var active := false
	if _arr.size() != MAX_RIPPLES:
		_arr.resize(MAX_RIPPLES)
	for i in MAX_RIPPLES:
		if _scale[i] > 0.0:
			active = true
			_age[i] += delta
			if _age[i] >= _dur[i]:
				_scale[i] = 0.0
		var p := clampf(_age[i] / _dur[i], 0.0, 1.0)
		_arr[i] = Vector4(_pos[i].x, _pos[i].y, p, _scale[i])
	# With no ripple alive the shader ignores the array (w = 0), so upload it once and then leave it alone.
	if active or not _uploaded_idle:
		pv.post_material.set_shader_parameter("ripples", _arr)
		_uploaded_idle = not active
	var step := floorf(_t * SHIMMER_FPS)
	if step != _shimmer_sent:
		_shimmer_sent = step
		pv.post_material.set_shader_parameter("shimmer_step", step)

func _on_button_pressed(_id: StringName, world_pos: Vector3, _gain: Variant, _crit: bool) -> void:
	spawn_ripple(world_pos)

func _on_zone_entered(zone_id: StringName) -> void:
	set_zone_palette(Palettes.for_zone(zone_id))

func _on_milestone(_a: Variant = null) -> void:
	await get_tree().create_timer(0.05).timeout   # after the 3-frame invert
	if pv:
		spawn_ripple_texel(Vector2(PixelViewport.VIEW) * 0.5, 4.0, MILESTONE_TIME)
