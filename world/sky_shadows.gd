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
## Width and height of a shadow as a share of the sprite's own size, by prop kind (placements3d.json "kind").
const KIND: Dictionary = {
	"oak": Vector2(0.80, 0.80), "pine": Vector2(0.45, 0.95), "bush": Vector2(0.85, 0.45),
	"rock": Vector2(0.80, 0.55), "crystals": Vector2(0.50, 0.85),
	"menhir": Vector2(0.55, 0.9), "lantern": Vector2(0.4, 0.8), "sign": Vector2(0.5, 0.7), "tower": Vector2(0.7, 0.95),
	"windmill": Vector2(0.6, 0.95), "lighthouse": Vector2(0.5, 1.0), "obelisk": Vector2(0.45, 1.0),
	"gateway": Vector2(0.9, 0.8), "spire": Vector2(0.45, 0.95), "lintel": Vector2(0.9, 0.7), "gate_pillar": Vector2(0.5, 0.9),
}
const SHADE: Color = Color(0.28, 0.38, 0.56)
const SHADE_DEEP: Color = Color(0.12, 0.18, 0.36)   # at low sun the ground is dark, so the shadow goes deeper to stay readable
const DEFAULT_KIND: Vector2 = Vector2(0.7, 0.6)
const WALKER_SIZE: Vector2 = Vector2(11.0, 17.0)   # width of the walker's shadow and the height it stretches from
const QUANT: float = 24.0                          # sun values are rounded to 1/QUANT so the shadows move in steps

var mat: ShaderMaterial
var _ov_mat: ShaderMaterial          # the same shader, clipped to the pad diamonds, for the copies drawn above the pads
var _overlay: Node2D                 # z 1: above the pad plates (z 0). Holds a clipped copy of every shadow that can reach a pad
var _pads: Array[Vector2] = []
const PAD_REACH: float = 220.0       # a caster farther than this from every pad cannot shade one
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
	var k: Vector2 = KIND.get(kind, DEFAULT_KIND) as Vector2
	var sp: Sprite2D = _quad("Sh_" + String(src.name))
	_items.append({"sprite": sp, "foot": src.position, "w": size.x * k.x, "h": size.y * k.y, "ov": null})
	_maybe_overlay(_items[_items.size() - 1])
	_lay(_items[_items.size() - 1])


## A shadow for something that is not a prop sprite (a pad slab): foot position, width, and the height it stretches from.
func add_blob(foot: Vector2, w: float, h: float) -> void:
	var sp: Sprite2D = _quad("Sh_blob%d" % _items.size())
	_items.append({"sprite": sp, "foot": foot, "w": w, "h": h, "ov": null})
	_lay(_items[_items.size() - 1])


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
		if absf(foot.x - p.x) < PAD_REACH and absf(foot.y - p.y) * 2.0 < PAD_REACH:
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
	it["ov"] = sp


## Sun state from SkyCycle: light x (-1 left .. +1 right), shadow length in object heights, strength 0..1.
func set_sun(azimuth: float, length: float, strength: float, p: Dictionary) -> void:
	_warm = maxi(_warm - 1, 0)
	visible = strength > 0.004 or _warm > 0   # no caster quads in the draw list while the shadows are faded out (rain at dusk, the horizon crossing)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("density_foot", float(p.foot))
	mat.set_shader_parameter("density_tip", float(p.tip))
	mat.set_shader_parameter("shade", SHADE.lerp(SHADE_DEEP, clampf(float(p.get("low", 0.0)), 0.0, 1.0)))
	for k: StringName in [&"strength", &"density_foot", &"density_tip", &"shade"]:
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
	_place(it.sprite as Sprite2D, it.foot as Vector2, float(it.w), float(it.h))
	if it.ov != null:
		_place(it.ov as Sprite2D, it.foot as Vector2, float(it.w), float(it.h))


func _place(sp: Sprite2D, foot: Vector2, w: float, h: float) -> void:
	var wid: float = w * 1.25
	var span: float = maxf(h * _len, 2.0) + wid * 0.7
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
	_place(_blob, Vector2(roundf(_walker.position.x), roundf(_walker.position.y)), WALKER_SIZE.x, WALKER_SIZE.y * 0.9)


## The walker is a sibling of the meadow in World. Found once, by type name (no hard dependency on its script).
func _find_walker() -> Node2D:
	var world: Node = get_parent().get_parent() if get_parent() != null else null
	if world == null:
		return null
	for c: Node in world.get_children():
		if c.is_in_group("walker") or (c.get_script() != null and (c.get_script() as Script).get_global_name() == &"TexelWalker"):
			return c as Node2D
	return null
