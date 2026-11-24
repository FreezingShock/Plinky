class_name SkyShadows
extends Node2D
## Cast shadows that follow the sun. Every tall prop and the walker gets a soft oval on the ground
## (render/shaders/cast_shadow.gdshader), laid in ground space and squashed to the 2:1 iso view: long and to one
## side when the sun is low, short and close at noon, a faint moon shadow at night. SkyCycle feeds the sun each
## frame; transforms only change once the sun has moved a visible step, so it costs next to nothing.
##
## The baked backdrop already has one set of shadows (lit from the left, mid morning). These add the part that
## moves, and the walker's. Rain and the horizon crossing fade them out.

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
	"gateway": {"size": Vector2(0.9, 0.8), "strength": 0.8, "length": 0.8, "soft": 0.1},
	"spire": {"size": Vector2(0.45, 0.95), "strength": 0.85, "length": 1.1, "soft": 0.1},
	"lintel": {"size": Vector2(0.9, 0.7), "strength": 0.7, "length": 0.7, "soft": 0.2},
	"gate_pillar": {"size": Vector2(0.5, 0.9), "strength": 0.8, "length": 0.9, "soft": 0.1},
}
const DEFAULT_KIND: Dictionary = {"size": Vector2(0.6, 0.45), "strength": 0.4, "length": 0.6, "soft": 0.35}
const SHADE: Color = Color(0.28, 0.38, 0.56)
const SHADE_DEEP: Color = Color(0.12, 0.18, 0.36)   # at low sun the ground is dark, so the shadow goes deeper to stay readable
const WALKER_SIZE: Vector2 = Vector2(11.0, 17.0)   # width of the walker's shadow and the height it stretches from
const QUANT: float = 24.0                          # sun values are rounded to 1/QUANT so the shadows move in steps

var mat: ShaderMaterial
var _ov_mat: ShaderMaterial          # the same shader, clipped to the pad diamonds, for the copies drawn above the pads
var _overlay: Node2D                 # z 1: above the pad plates (z 0). Holds a clipped copy of every shadow that can reach a pad
var _pads: Array[Vector2] = []
const PAD_REACH: float = 220.0       # a caster farther than this from every pad cannot shade one
var pad_reach: float = PAD_REACH    # per scene: a smaller reach means fewer overlay quads (the quarry sets it lower; each overlay is a node)
var _items: Array[Dictionary] = []   # {sprite: Sprite2D, foot: Vector2, w: float, h: float}
var _blob: Sprite2D
var _walker: Node2D
var _dir: Vector2 = Vector2(1.0, 0.2)    # ground direction a shadow falls, unit length
var _len: float = 0.3
var _key: Vector2i = Vector2i(-999, 0)
var _warm: int = 4   # frames drawn even when faded out, so the shadow shader compiles at load


func _init() -> void:
	RenderGlobals.ensure()
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	_ov_mat = ShaderMaterial.new()
	_ov_mat.shader = SHADER
	_ov_mat.set_shader_parameter("clip", true)


func _ready() -> void:
	_blob = _quad("WalkerShadow")
	_blob.visible = false
	_blob.set_instance_shader_parameter(&"item_soft", 0.25)   # the walker's shadow is a little softer than a tree's


func _quad(nm: String) -> Sprite2D:
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var sp := Sprite2D.new()
	sp.name = nm
	sp.texture = ImageTexture.create_from_image(white)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.offset = Vector2(-0.5, -1.0)
	sp.material = mat
	add_child(sp)
	return sp


## Register a prop sprite (as built by MeadowScene.spawn_occluders) with its kind and its foot position.
func add_caster(src: Sprite2D, kind: String, size: Vector2) -> void:
	var k: Dictionary = KIND.get(kind, DEFAULT_KIND) as Dictionary
	var share: Vector2 = k.size as Vector2
	var sp: Sprite2D = _quad("Sh_" + String(src.name))
	var it: Dictionary = {"sprite": sp, "foot": src.position, "w": size.x * share.x, "h": size.y * share.y, "ov": null,
			"src": src, "strength": float(k.strength), "soft": float(k.soft), "len": float(k.length)}
	_items.append(it)
	_tune(sp, it)
	_maybe_overlay(it)
	_lay(it)


## Per-caster strength and softness go to the shader as instance uniforms, so every caster keeps one shared material.
func _tune(sp: Sprite2D, it: Dictionary) -> void:
	sp.set_instance_shader_parameter(&"item_strength", float(it.get("strength", 1.0)))
	sp.set_instance_shader_parameter(&"item_soft", float(it.get("soft", 0.0)))


## Drop the shadow of a prop that has been unloaded (Larkmoor loads props by chunk). Frees its quad and its pad copy.
func remove_caster(src: Sprite2D) -> void:
	for i: int in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		if it.get("src") == src:
			(it.sprite as Sprite2D).queue_free()
			if it.ov != null:
				(it.ov as Sprite2D).queue_free()
			_items.remove_at(i)


## A shadow for something that is not a prop sprite (a pad slab): foot position, width, and the height it stretches from.
func add_blob(foot: Vector2, w: float, h: float) -> void:
	var sp: Sprite2D = _quad("Sh_blob%d" % _items.size())
	var it: Dictionary = {"sprite": sp, "foot": foot, "w": w, "h": h, "ov": null, "strength": 1.0, "soft": 0.1, "len": 1.0}
	_items.append(it)
	_tune(sp, it)
	_lay(it)


## A pad plate sits at `pos`. Shadows of nearby props get a clipped copy above the plates, so they cross the pad.
func add_pad(pos: Vector2) -> void:
	_pads.append(pos)
	var arr := PackedVector2Array()
	for p: Vector2 in _pads:
		arr.append(p)
	while arr.size() < 24:
		arr.append(Vector2.ZERO)
	_ov_mat.set_shader_parameter("clip_pads", arr)
	_ov_mat.set_shader_parameter("clip_count", mini(_pads.size(), 24))
	for it: Dictionary in _items:
		if it.ov == null and not _is_blob(it):
			_maybe_overlay(it)
			if it.ov != null:
				_lay(it)


func _is_blob(it: Dictionary) -> bool:
	return String((it.sprite as Sprite2D).name).begins_with("Sh_blob")


func _near_pad(foot: Vector2) -> bool:
	for p: Vector2 in _pads:
		if absf(foot.x - p.x) < pad_reach and absf(foot.y - p.y) * 2.0 < pad_reach:
			return true
	return false


func _maybe_overlay(it: Dictionary) -> void:
	if it.ov != null or _pads.is_empty() or _is_blob(it) or not _near_pad(it.foot as Vector2):
		return
	if _overlay == null:
		_overlay = Node2D.new()
		_overlay.name = "PadOverlay"
		_overlay.z_index = 1
		add_child(_overlay)
	var sp := _quad("Ov_" + String((it.sprite as Sprite2D).name))
	remove_child(sp)
	_overlay.add_child(sp)
	sp.material = _ov_mat
	_tune(sp, it)
	it["ov"] = sp


## Sun state from SkyCycle: light x (-1 left .. +1 right), shadow length in object heights, strength 0..1.
func set_sun(azimuth: float, length: float, strength: float, p: Dictionary) -> void:
	_warm = maxi(_warm - 1, 0)
	visible = strength > 0.004 or _warm > 0   # no caster quads in the draw list while the shadows are faded out (rain at dusk, the horizon crossing)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("density_foot", float(p.foot))
	mat.set_shader_parameter("density_tip", float(p.tip))
	mat.set_shader_parameter("shade", SHADE.lerp(SHADE_DEEP, clampf(float(p.get("low", 0.0)), 0.0, 1.0)))
	mat.set_shader_parameter("softness", clampf(float(p.get("soft", 0.5)), 0.0, 1.0))
	for k: StringName in [&"strength", &"density_foot", &"density_tip", &"shade", &"softness"]:
		_ov_mat.set_shader_parameter(k, mat.get_shader_parameter(k))
	if _overlay != null:
		_overlay.visible = visible
	var key := Vector2i(roundi(azimuth * QUANT), roundi(length * QUANT))
	if key == _key:
		return
	_key = key
	# Light from the left drops shadows to the right. Overhead sun leaves a short one toward the viewer.
	_dir = Vector2(-azimuth, 0.35 * (1.0 - absf(azimuth)) + 0.12).normalized()
	_len = length
	for it: Dictionary in _items:
		_lay(it)


## Lay one shadow: an oval from just behind the foot out along the shadow direction, in ground space.
func _lay(it: Dictionary) -> void:
	var len_k: float = float(it.get("len", 1.0))
	_place(it.sprite as Sprite2D, it.foot as Vector2, float(it.w), float(it.h), len_k)
	if it.ov != null:
		_place(it.ov as Sprite2D, it.foot as Vector2, float(it.w), float(it.h), len_k)


func _place(sp: Sprite2D, foot: Vector2, w: float, h: float, len_k: float = 1.0) -> void:
	var wid: float = w * 1.25
	var span: float = maxf(h * _len * len_k, 2.0) + wid * 0.7
	var dir_s := Vector2(_dir.x, _dir.y * 0.5)               # ground to screen: y squashed 2:1
	var perp_s := Vector2(-_dir.y, _dir.x * 0.5)
	var origin: Vector2 = foot - dir_s * (wid * 0.35)
	sp.transform = Transform2D(perp_s * wid, -dir_s * span, origin)


func _process(_delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		_walker = _find_walker()
		_blob.visible = _walker != null
	if _walker == null:
		return
	var air: float = WalkerMotion.shadow_scale(float(_walker.get("lift")) if "lift" in _walker else 0.0)
	_place(_blob, Vector2(roundf(_walker.position.x), roundf(_walker.position.y)), WALKER_SIZE.x * air, WALKER_SIZE.y * 0.9 * air)



## The walker is a sibling of the meadow in World. Found once, by type name (no hard dependency on its script).
func _find_walker() -> Node2D:
	var world: Node = get_parent().get_parent() if get_parent() != null else null
	if world == null:
		return null
	for c: Node in world.get_children():
		if c.is_in_group("walker") or (c.get_script() != null and (c.get_script() as Script).get_global_name() == &"TexelWalker"):
			return c as Node2D
	return null
