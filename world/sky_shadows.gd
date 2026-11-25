class_name SkyShadows
extends Node2D
## Cast shadows that follow the sun. Every tall prop and the walker gets a soft oval on the ground
## (render/shaders/cast_shadow.gdshader), laid in ground space and squashed to the 2:1 iso view: long and to one
## side when the sun is low, short and close at noon, a faint moon shadow at night. SkyCycle feeds the sun each
## frame; transforms only change once the sun has moved a visible step, so it costs next to nothing.
##
## The baked backdrop already has one set of shadows (lit from the left, mid morning). These add the part that
## moves, and the walker's. Rain and the horizon crossing fade them out.
##
## Every caster is one instance of a MultiMesh (one node for all props, one for the pad slabs, one for the pad copies),
## not a quad node each, so a zone's shadows cost three nodes whatever its prop count (docs/perf.md, the 1350 ceiling).
## Each instance carries its strength and softness as custom data (see cast_shadow.gdshader).

const SHADER: Shader = preload("res://render/shaders/cast_shadow.gdshader")
## Per prop kind (placements3d.json "kind"): the shadow's width and height as a share of the sprite, how dark it is
## (`strength`, 1 is a full tree), how far it stretches (`length`, times the sun's length) and how much softer than the
## global SkyConfig.shadow_softness it is (`soft`). Trees throw the big, dark pools; bushes, flower beds and cozy props a
## faint small one, so the eye reads the trees as the tall things they are.
const KIND: Dictionary = {
	"oak": {"size": Vector2(1.0, 0.9), "strength": 1.0, "length": 1.25, "soft": 0.1},
	"pine": {"size": Vector2(0.55, 1.0), "strength": 1.0, "length": 1.45, "soft": 0.1},
	"bush": {"size": Vector2(0.6, 0.35), "strength": 0.35, "length": 0.6, "soft": 0.35},
	"rock": {"size": Vector2(0.75, 0.5), "strength": 0.6, "length": 0.7, "soft": 0.2},
	"crystals": {"size": Vector2(0.5, 0.7), "strength": 0.7, "length": 0.9, "soft": 0.15},
	"menhir": {"size": Vector2(0.6, 0.9), "strength": 0.85, "length": 1.1, "soft": 0.1},
	"lantern": {"size": Vector2(0.35, 0.7), "strength": 0.5, "length": 0.8, "soft": 0.2},
	"sign": {"size": Vector2(0.5, 0.7), "strength": 0.6, "length": 0.8, "soft": 0.15},
	"tower": {"size": Vector2(0.7, 0.95), "strength": 0.9, "length": 1.1, "soft": 0.05},
	"windmill": {"size": Vector2(0.6, 0.95), "strength": 0.9, "length": 1.15, "soft": 0.05},
	"lighthouse": {"size": Vector2(0.5, 1.0), "strength": 0.9, "length": 1.1, "soft": 0.05},
	"obelisk": {"size": Vector2(0.45, 1.0), "strength": 0.85, "length": 1.0, "soft": 0.1},
	"ruin": {"size": Vector2(0.75, 0.7), "strength": 0.6, "length": 0.9, "soft": 0.12},
	"gateway": {"size": Vector2(0.9, 0.8), "strength": 0.8, "length": 0.8, "soft": 0.1},
	"spire": {"size": Vector2(0.45, 0.95), "strength": 0.85, "length": 1.1, "soft": 0.1},
	"lintel": {"size": Vector2(0.9, 0.7), "strength": 0.7, "length": 0.7, "soft": 0.2},
	"gate_pillar": {"size": Vector2(0.5, 0.9), "strength": 0.8, "length": 0.9, "soft": 0.1},
}
const DEFAULT_KIND: Dictionary = {"size": Vector2(0.6, 0.45), "strength": 0.4, "length": 0.6, "soft": 0.35}
## Ruins cast from one size, not their sprite size: a ruin's sprite depends on its walls, so a thin or low one would otherwise
## cast a faint shadow beside a big one. Strength 0.6 sits between flowers (0.35) and trees (1.0).
const RUIN_SHADOW_SIZE: Vector2 = Vector2(22.0, 26.0)
## Mauve at high sun: the Gower ground-shadow hue (mockup C, Nathan picked it 2026-11-25). SHADE_DEEP takes over at low sun.
const SHADE: Color = Color(0.306, 0.267, 0.439)
const SHADE_DEEP: Color = Color(0.12, 0.18, 0.36)   # at low sun the ground is dark, so the shadow goes deeper to stay readable
const WALKER_SIZE: Vector2 = Vector2(11.0, 17.0)   # width of the walker's shadow and the height it stretches from
## Garden flowers (world/garden_layer.gd draws them; their foot positions come from the garden list). Each flower casts a
## small dithered oval, so a field reads as shade under the heads and never as a block.
const FLOWER_SIZE: Vector2 = Vector2(3.0, 2.0)      # width and height-stretch of one flower's shadow, in texels
const FLOWER_LEN: float = 0.6                       # times the sun's length, as the props
const FLOWER_STRENGTH: float = 0.75              # a bush is 0.35, a tree 1.0: a field reads as dots of shade
const FLOWER_SOFT: float = 0.6
const QUANT: float = 24.0                          # sun values are rounded to 1/QUANT so the shadows move in steps

var mat: ShaderMaterial              # the main layer: every caster and pad slab
var _ov_mat: ShaderMaterial          # the same shader, clipped to the pad diamonds, for the copies drawn above the pads
var _caster_mm: MultiMeshInstance2D  # every shadow in the zone, one instance each (index = its slot in _items)
var _overlay: MultiMeshInstance2D    # z 1: above the pad plates (z 0). Clipped copies of the casters near a pad
var _walker_mm: MultiMeshInstance2D  # the walker's shadow: one instance, moved each frame
var _flowers_mm: MultiMeshInstance2D # one faint oval per garden flower, laid with the sun (set_flowers)
var _flower_feet: PackedVector2Array = PackedVector2Array()
var flower_strength: float = FLOWER_STRENGTH   # per-scene knob (the flower shadow's strength, 0..1)
var shade_tint: Color = SHADE                  # the shadow colour at high sun; SHADE_DEEP takes over as the sun drops
var _pads: Array[Vector2] = []
const PAD_REACH: float = 220.0       # a caster farther than this from every pad cannot shade one
var pad_reach: float = PAD_REACH     # per scene: a smaller reach means fewer casters get a pad copy (the quarry sets it lower)
var _items: Array[Dictionary] = []   # {idx, foot, w, h, len, strength, soft, src (the prop Sprite2D, null for a pad slab), blob, ov, xf}
var _capacity: int = 0               # instances the MultiMeshes hold (they grow by doubling, so a zone build is not quadratic)
var _layers_ready: bool = false
var _dir: Vector2 = Vector2(1.0, 0.2)    # ground direction a shadow falls, unit length
var _len: float = 0.3
var _key: Vector2i = Vector2i(-999, 0)
var _warm: int = 4   # frames drawn even when faded out, so the shadow shader compiles at load
var _walker: Node2D
static var _mesh: ArrayMesh = null   # one unit quad, shared by every layer: x -0.5..0.5, y -1..0 (what a 1x1 sprite at offset (-0.5, -1) drew)


func _init() -> void:
	RenderGlobals.ensure()
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	_ov_mat = ShaderMaterial.new()
	_ov_mat.shader = SHADER
	_ov_mat.set_shader_parameter("clip", true)


func _ready() -> void:
	_ensure_layers()


## The three layers, made on first use (the zone's casters can arrive before or after _ready).
func _ensure_layers() -> void:
	if _layers_ready:
		return
	_layers_ready = true
	_caster_mm = _make_layer("Casters", mat, 0)
	_overlay = _make_layer("PadOverlay", _ov_mat, 1)
	_overlay.visible = false
	_walker_mm = _make_layer("WalkerShadow", mat, 0)
	_walker_mm.multimesh.instance_count = 1
	_walker_mm.multimesh.set_instance_custom_data(0, Color(0.25, 1.0, 0.0, 0.0))   # the walker's shadow is a little softer than a tree's
	_walker_mm.visible = false
	_flowers_mm = _make_layer("FlowerShadows", mat, 0)


func _make_layer(nm: String, m: ShaderMaterial, z: int) -> MultiMeshInstance2D:
	if _mesh == null:
		_mesh = ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -1.0), Vector2(0.5, -1.0), Vector2(0.5, 0.0), Vector2(-0.5, 0.0)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = _mesh
	var node := MultiMeshInstance2D.new()
	node.name = nm
	node.multimesh = mm
	node.material = m
	node.z_index = z
	add_child(node)
	return node


## Register a prop sprite (as built by MeadowScene.spawn_occluders) with its kind and its foot position.
func add_caster(src: Sprite2D, kind: String, size: Vector2) -> void:
	_ensure_layers()
	var k: Dictionary = KIND.get(kind, DEFAULT_KIND) as Dictionary
	var share: Vector2 = k.size as Vector2
	var cast_size: Vector2 = RUIN_SHADOW_SIZE if kind == "ruin" else size
	_push({"src": src, "foot": src.position, "w": cast_size.x * share.x, "h": cast_size.y * share.y,
			"strength": float(k.strength), "soft": float(k.soft), "len": float(k.length), "blob": false})


## Drop the shadow of a prop that has been unloaded (Larkmoor loads props by chunk). Its slot is refilled by the last one.
func remove_caster(src: Sprite2D) -> void:
	for i: int in range(_items.size() - 1, -1, -1):
		if _items[i].get("src") == src:
			_drop(i)


## The garden flowers, once per zone: `list` is the garden list ([x, y, stat, variant] per flower; x, y is the foot). Each
## flower gets one instance in its own layer. The flowers are not casters in the list, so they cost one draw and no pad copies.
func set_flowers(list: Array) -> void:
	_ensure_layers()
	_flower_feet.resize(list.size())
	var mm: MultiMesh = _flowers_mm.multimesh
	mm.instance_count = list.size()
	var data := Color(FLOWER_SOFT, flower_strength, 0.0, 0.0)
	for i: int in list.size():
		var f: Array = list[i] as Array
		_flower_feet[i] = Vector2(float(f[0]), float(f[1]))
		mm.set_instance_custom_data(i, data)
	_lay_flowers()


## Lays every flower's shadow for the current sun.
func _lay_flowers() -> void:
	var mm: MultiMesh = _flowers_mm.multimesh
	for i: int in _flower_feet.size():
		mm.set_instance_transform_2d(i, _xf(_flower_feet[i], FLOWER_SIZE.x, FLOWER_SIZE.y, FLOWER_LEN))


## A shadow for something that is not a prop sprite (a pad slab): foot position, width, and the height it stretches from.
func add_blob(foot: Vector2, w: float, h: float) -> void:
	_ensure_layers()
	_push({"src": null, "foot": foot, "w": w, "h": h, "strength": 1.0, "soft": 0.1, "len": 1.0, "blob": true})


## A pad plate sits at `pos`. Shadows of nearby props get a clipped copy above the plates, so they cross the pad.
func add_pad(pos: Vector2) -> void:
	_ensure_layers()
	_pads.append(pos)
	var arr := PackedVector2Array()
	for p: Vector2 in _pads:
		arr.append(p)
	while arr.size() < 24:
		arr.append(Vector2.ZERO)
	_ov_mat.set_shader_parameter("clip_pads", arr)
	_ov_mat.set_shader_parameter("clip_count", mini(_pads.size(), 24))
	for it: Dictionary in _items:
		it["ov"] = _near_flag(it)
		_apply(it)
	_overlay.visible = visible and not _pads.is_empty()


func _near_pad(foot: Vector2) -> bool:
	for p: Vector2 in _pads:
		if absf(foot.x - p.x) < pad_reach and absf(foot.y - p.y) * 2.0 < pad_reach:
			return true
	return false


## A caster gets a pad copy when it is not a pad slab itself and some pad is within reach of it.
func _near_flag(it: Dictionary) -> bool:
	return not bool(it.blob) and not _pads.is_empty() and _near_pad(it.foot as Vector2)


## Adds one caster to the layers: a free slot at the end, grown when full.
func _push(it: Dictionary) -> void:
	it["idx"] = _items.size()
	it["ov"] = _near_flag(it)
	it["xf"] = _xf(it.foot as Vector2, float(it.w), float(it.h), float(it.get("len", 1.0)))
	_items.append(it)
	if _set_capacity(_items.size()):
		_apply_all()   # the buffers were reallocated: every slot is written again
	else:
		_apply(it)
	_set_visible_count()


## Frees the slot of `i`: the last caster moves into it, so the instances stay packed at the front.
func _drop(i: int) -> void:
	var last: int = _items.size() - 1
	if i != last:
		_items[i] = _items[last]
		_items[i]["idx"] = i
		_apply(_items[i])
	_items.remove_at(last)
	_set_visible_count()


func _set_visible_count() -> void:
	_caster_mm.multimesh.visible_instance_count = _items.size()
	_overlay.multimesh.visible_instance_count = _items.size()


## Makes room for `n` instances. Returns true when the buffers were reallocated (every slot must be written again).
func _set_capacity(n: int) -> bool:
	if n <= _capacity:
		return false
	var cap: int = maxi(_capacity * 2, 64)
	while cap < n:
		cap *= 2
	_capacity = cap
	_caster_mm.multimesh.instance_count = cap
	_overlay.multimesh.instance_count = cap
	return true


func _apply_all() -> void:
	for it: Dictionary in _items:
		_apply(it)


## Writes one caster into its slot: where it lies, and its strength, softness and pad copy flag.
func _apply(it: Dictionary) -> void:
	var i: int = int(it.idx)
	var data := Color(float(it.soft), float(it.strength), 1.0 if bool(it.ov) else 0.0, 0.0)
	_caster_mm.multimesh.set_instance_transform_2d(i, it.xf as Transform2D)
	_caster_mm.multimesh.set_instance_custom_data(i, data)
	_overlay.multimesh.set_instance_transform_2d(i, it.xf as Transform2D)
	_overlay.multimesh.set_instance_custom_data(i, data)


## Sun state from SkyCycle: light x (-1 left .. +1 right), shadow length in object heights, strength 0..1.
func set_sun(azimuth: float, length: float, strength: float, p: Dictionary) -> void:
	_warm = maxi(_warm - 1, 0)
	visible = strength > 0.004 or _warm > 0   # no caster instances drawn while the shadows are faded out (rain at dusk, the horizon crossing)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("density_foot", float(p.foot))
	mat.set_shader_parameter("density_tip", float(p.tip))
	mat.set_shader_parameter("shade", shade_tint.lerp(SHADE_DEEP, clampf(float(p.get("low", 0.0)), 0.0, 1.0)))
	mat.set_shader_parameter("softness", clampf(float(p.get("soft", 0.5)), 0.0, 1.0))
	for k: StringName in [&"strength", &"density_foot", &"density_tip", &"shade", &"softness"]:
		_ov_mat.set_shader_parameter(k, mat.get_shader_parameter(k))
	if _overlay != null:
		_overlay.visible = visible and not _pads.is_empty()
	var key := Vector2i(roundi(azimuth * QUANT), roundi(length * QUANT))
	if key == _key:
		return
	_key = key
	# Light from the left drops shadows to the right. Overhead sun leaves a short one toward the viewer.
	_dir = Vector2(-azimuth, 0.35 * (1.0 - absf(azimuth)) + 0.12).normalized()
	_len = length
	for it: Dictionary in _items:
		_lay(it)
	_lay_flowers()


## Lay one shadow: an oval from just behind the foot out along the shadow direction, in ground space.
func _lay(it: Dictionary) -> void:
	it["xf"] = _xf(it.foot as Vector2, float(it.w), float(it.h), float(it.get("len", 1.0)))
	_apply(it)


func _xf(foot: Vector2, w: float, h: float, len_k: float) -> Transform2D:
	var wid: float = w * 1.25
	var span: float = maxf(h * _len * len_k, 2.0) + wid * 0.7
	var dir_s := Vector2(_dir.x, _dir.y * 0.5)               # ground to screen: y squashed 2:1
	var perp_s := Vector2(-_dir.y, _dir.x * 0.5)
	var origin: Vector2 = foot - dir_s * (wid * 0.35)
	return Transform2D(perp_s * wid, -dir_s * span, origin)


func _process(_delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		_walker = _find_walker()
		_walker_mm.visible = _walker != null
	if _walker == null:
		return
	var air: float = WalkerMotion.shadow_scale(float(_walker.get("lift")) if "lift" in _walker else 0.0)
	var foot := Vector2(roundf(_walker.position.x), roundf(_walker.position.y))
	_walker_mm.multimesh.set_instance_transform_2d(0, _xf(foot, WALKER_SIZE.x * air, WALKER_SIZE.y * 0.9 * air, 1.0))



## The walker is a sibling of the meadow in World. Found once, by type name (no hard dependency on its script).
func _find_walker() -> Node2D:
	var world: Node = get_parent().get_parent() if get_parent() != null else null
	if world == null:
		return null
	for c: Node in world.get_children():
		if c.is_in_group("walker") or (c.get_script() != null and (c.get_script() as Script).get_global_name() == &"TexelWalker"):
			return c as Node2D
	return null
