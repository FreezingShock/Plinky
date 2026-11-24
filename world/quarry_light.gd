class_name QuarryLight
extends Node2D
## The Ember Quarry's own light, layered over the SkyCycle shade (world/sky_cycle.gd):
##  - glow: lava pools, lava seams, vents, braziers and lamps add warm light onto the ground and the props they reach
##    (quarry_glow.gdshader). Each source flickers on the 6 fps step in core/lava_flicker.gd. Brighter at night.
##  - haze: drifting smoke, warm where the lava is close, cool and denser in the recesses, with slanted light shafts
##    from the top of the quarry (quarry_haze.gdshader). Soft alpha.
##  - heat shimmer: the picture over the lava and vents wavers by whole screen texels (heat_shimmer.gdshader).
## Presentation only. It owns its three materials and reads the sky's night level and the palette. Reduce Motion
## freezes the flicker, drift and shimmer. Reduce Flashing freezes the flicker. Reduce screen effects hides haze and shimmer.

const GLOW_SHADER: Shader = preload("res://render/shaders/quarry_glow.gdshader")
const HAZE_SHADER: Shader = preload("res://render/shaders/quarry_haze.gdshader")
const SHIMMER_SHADER: Shader = preload("res://render/shaders/heat_shimmer.gdshader")
const PROP_SHADER: Shader = preload("res://render/shaders/quarry_prop.gdshader")
const PROP_LIGHTS: int = 8              ## nearest sources that light one prop (quarry_prop.gdshader holds 8)
const PROP_REACH: float = 1.5           ## a prop feels a source out to this many times its falloff radius
const PROP_LIFT: float = 10.0           ## height of every source above a prop, in texels
const MAX_EMIT: int = 64
const KIND_LAVA: int = 0
const KIND_VENT: int = 1
const KIND_BRAZIER: int = 2
const KIND_LAMP: int = 3
## Palette roles for the quarry (docs/art-bible.md, Ember Quarry row): 3 ember orange, 4 amber gold, 6 mauve.
const ROLE_EMBER: int = 3
const ROLE_GOLD: int = 4
const ROLE_MAUVE: int = 6
## Margin in texels around the lava for the shimmer rect.
const SHIMMER_MARGIN: float = 30.0

var _sky: SkyCycle
var _cfg: SkyConfig
var _list: Array[Dictionary] = []     # emitters in pack order: {pos, radius, strength, kind, col}
var _glow_mat: ShaderMaterial
var _haze_mat: ShaderMaterial
var _shimmer_mat: ShaderMaterial
var _haze: ColorRect
var _shimmer: ColorRect
var _clock: float = 0.0
var _packed_frame: int = -1
var _packed_steady: bool = false
var _has_heat: bool = false
var _props: Array[Dictionary] = []     # {mat, origin, near}: a prop's material, its top-left texel, the sources that reach it
var _sun_key: Array = []               # last sun rim pushed to the props, to skip unchanged frames


## Every light source in the quarry, read from placements3d.json: braziers and lamps (sprites), lava pools and vents
## (anchors), and each lava seam tile. Braziers and lamps come first, so the MAX_EMIT cap drops seam tiles before them.
static func emitters(data: Dictionary, cfg: SkyConfig, cols: PackedColorArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ember: Color = cols[ROLE_EMBER]
	var gold: Color = cols[ROLE_GOLD]
	for s: Dictionary in data.get("sprites", []) as Array:
		var kind_name: String = String(s.get("kind", ""))
		var c := Vector2(float(s.x) + float(s.w) * 0.5, float(s.y) + float(s.h) * 0.4)   # the flame sits high on the sprite
		if kind_name == "brazier":
			out.append(_emit(c, cfg.brazier_radius, cfg.brazier_glow, KIND_BRAZIER, gold))
		elif kind_name == "iron_lamp":
			out.append(_emit(c, cfg.lamp_radius, cfg.lamp_glow, KIND_LAMP, gold))
	for a: Dictionary in data.get("anchors", []) as Array:
		match String(a.get("kind", "")):
			"lava":
				out.append(_emit(Vector2(float(a.sx), float(a.sy)), cfg.lava_pool_radius, 1.0, KIND_LAVA, ember))
			"vent":
				out.append(_emit(Vector2(float(a.sx), float(a.sy)), cfg.vent_radius, cfg.vent_glow, KIND_VENT, ember))
	for t: Dictionary in data.get("lava", []) as Array:
		var c := Vector2(float(t.x) + float(t.w) * 0.5, float(t.y) + float(t.h) * 0.5)
		out.append(_emit(c, cfg.lava_tile_radius, 0.5, KIND_LAVA, ember))
	if out.size() > MAX_EMIT:
		out.resize(MAX_EMIT)
	return out


static func _emit(pos: Vector2, radius: float, strength: float, kind: int, col: Color) -> Dictionary:
	return {"pos": pos, "radius": radius, "strength": strength, "kind": kind, "col": col}


## Builds the three layers over `area` (quarry texels). `sky` supplies the night level; `cfg` the tuning; `cols` the
## quarry palette (Palettes.colors). Call once, after the quarry's ground exists.
func setup(data: Dictionary, area: Rect2, sky: SkyCycle, cfg: SkyConfig, cols: PackedColorArray) -> void:
	_sky = sky
	_cfg = cfg
	_list = emitters(data, cfg, cols)
	_has_heat = false
	var heat_rect := Rect2()
	for d: Dictionary in _list:
		if int(d.kind) == KIND_LAVA or int(d.kind) == KIND_VENT:
			var p: Vector2 = d.pos
			var r: Rect2 = Rect2(p - Vector2.ONE * float(d.radius), Vector2.ONE * float(d.radius) * 2.0)
			heat_rect = r if not _has_heat else heat_rect.merge(r)
			_has_heat = true

	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_glow_mat.set_shader_parameter("halo_reach", cfg.glow_halo_reach)
	_glow_mat.set_shader_parameter("halo_gain", cfg.glow_halo_gain)
	_glow_mat.set_shader_parameter("hot_gain", cfg.glow_hot_gain)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.position = area.position
	glow.size = area.size
	glow.z_index = 7   # above the SkyCycle shade (z 5) so the lava stays bright at night, below the embers (z 10)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.material = _glow_mat
	add_child(glow)

	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = HAZE_SHADER
	_haze_mat.set_shader_parameter("density", cfg.quarry_haze)
	_haze_mat.set_shader_parameter("shaft", cfg.shaft_strength)
	_haze_mat.set_shader_parameter("cool_col", _rgb(cols[ROLE_MAUVE]))
	_haze_mat.set_shader_parameter("warm_col", _rgb(cols[ROLE_EMBER]))
	_haze_mat.set_shader_parameter("shaft_col", _rgb(cols[ROLE_GOLD]))
	_haze = ColorRect.new()
	_haze.name = "Haze"
	_haze.position = area.position
	_haze.size = area.size
	_haze.z_index = 6
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.material = _haze_mat
	add_child(_haze)

	_shimmer_mat = ShaderMaterial.new()
	_shimmer_mat.shader = SHIMMER_SHADER
	_shimmer_mat.set_shader_parameter("amount", cfg.shimmer_amount)
	_shimmer = ColorRect.new()
	_shimmer.name = "Shimmer"
	_shimmer.position = heat_rect.position - Vector2.ONE * SHIMMER_MARGIN if _has_heat else area.position
	_shimmer.size = heat_rect.size + Vector2.ONE * SHIMMER_MARGIN * 2.0 if _has_heat else Vector2.ZERO
	_shimmer.z_index = 8   # over the glow and the haze, under the embers
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shimmer.material = _shimmer_mat
	_shimmer.visible = false
	add_child(_shimmer)

	_pack(true)   # steady until the first frame, so a Reduce Motion start is already still
	_packed_frame = -1


## Material for one prop sprite: its normal map, plus the nearest sources that reach it. `origin` is the sprite's
## top-left texel in quarry coordinates, `size` its texture size. Call after setup.
func prop_material(origin: Vector2, size: Vector2, nrm: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PROP_SHADER
	mat.set_shader_parameter("nrm_tex", nrm)
	var p: Dictionary = {"mat": mat, "origin": origin, "near": nearest(_list, origin, size, PROP_LIGHTS)}
	_props.append(p)
	_sun_key = []   # the new prop takes the sun rim on the next frame
	_fill_prop(p, _packed_steady)
	return mat


## Indices of the `max_n` sources nearest a prop, in order. A source counts when it is within its reach of the prop.
static func nearest(list: Array[Dictionary], origin: Vector2, size: Vector2, max_n: int) -> Array[int]:
	var centre: Vector2 = origin + size * 0.5
	var cand: Array = []
	for i in range(list.size()):
		var d: Dictionary = list[i]
		var p: Vector2 = d.pos
		var reach: float = float(d.radius) * PROP_REACH
		var dist: float = p.distance_to(centre)
		if dist < reach + maxf(size.x, size.y) * 0.5:
			cand.append([dist, i])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[int] = []
	for c: Array in cand:
		if out.size() >= max_n:
			break
		out.append(int(c[1]))
	return out


func _process(delta: float) -> void:
	if _glow_mat == null:
		return
	var calm: bool = MeadowLife.reduce_motion
	var steady: bool = calm or FxConfig.reduce_flashing
	if not calm:
		_clock += delta
	var night: float = _sky.night01 if _sky != null else 0.0
	var f: int = LavaFlicker.frame(_clock)
	if f != _packed_frame or steady != _packed_steady:
		_packed_frame = f
		_packed_steady = steady
		_pack(steady)
	_glow_mat.set_shader_parameter("gain", _cfg.lava_glow * (1.0 + _cfg.lava_night_boost * night))
	var moving: float = 0.0 if calm else _clock
	_haze_mat.set_shader_parameter("clock", moving)
	_haze_mat.set_shader_parameter("night", night)
	_shimmer_mat.set_shader_parameter("clock", moving)
	_haze.visible = not FxConfig.reduce_screen_fx
	_shimmer.visible = _has_heat and not (calm or FxConfig.reduce_screen_fx)
	_push_sun()


## The sun's rim, from the SkyCycle rim material, so props catch the day's light as the other sprites do.
func _push_sun() -> void:
	if _sky == null or _sky.rim_material == null:
		return
	var rd: Variant = _sky.rim_material.get_shader_parameter("rim_dir")
	var ra: Variant = _sky.rim_material.get_shader_parameter("rim_amount")
	if not (rd is Vector2) or not (ra is float):
		return
	var key: Array = [rd, ra]
	if key == _sun_key:
		return
	_sun_key = key
	var dir: Vector2 = rd
	for p: Dictionary in _props:
		var mat: ShaderMaterial = p.mat
		mat.set_shader_parameter("sun_dir", Vector3(dir.x, dir.y, 1.0))
		mat.set_shader_parameter("sun_amount", float(ra))


## Packs every emitter into the three materials. Each strength has its flicker folded in (core/lava_flicker.gd).
func _pack(steady: bool) -> void:
	var pos_str := PackedVector4Array()
	var col_kind := PackedVector4Array()
	for i in range(MAX_EMIT):
		if i < _list.size():
			var d: Dictionary = _list[i]
			var c: Color = d.col
			var lvl: float = LavaFlicker.level(_clock, i, _depth(int(d.kind)), steady)
			var p: Vector2 = d.pos
			pos_str.append(Vector4(p.x, p.y, float(d.radius), float(d.strength) * lvl))
			col_kind.append(Vector4(c.r, c.g, c.b, float(d.kind)))
		else:
			pos_str.append(Vector4.ZERO)
			col_kind.append(Vector4.ZERO)
	var n: int = mini(_list.size(), MAX_EMIT)
	for m: ShaderMaterial in [_glow_mat, _haze_mat, _shimmer_mat]:
		m.set_shader_parameter("emit", pos_str)
		m.set_shader_parameter("emit_col", col_kind)
		m.set_shader_parameter("emit_count", n)
	for p: Dictionary in _props:
		_fill_prop(p, steady)


## Packs one prop's nearest sources: position relative to its top-left texel, and the strength after flicker.
func _fill_prop(p: Dictionary, steady: bool) -> void:
	var near: Array[int] = p.near
	if near.is_empty():
		return
	var origin: Vector2 = p.origin
	var lp := PackedVector4Array()
	var lc := PackedVector4Array()
	for i: int in near:
		var d: Dictionary = _list[i]
		var q: Vector2 = d.pos
		var c: Color = d.col
		var lvl: float = LavaFlicker.level(_clock, i, _depth(int(d.kind)), steady)
		lp.append(Vector4(q.x - origin.x, q.y - origin.y, PROP_LIFT, float(d.radius) * PROP_REACH))
		lc.append(Vector4(c.r, c.g, c.b, float(d.strength) * lvl * _cfg.prop_glow))
	while lp.size() < PROP_LIGHTS:
		lp.append(Vector4.ZERO)
		lc.append(Vector4.ZERO)
	var mat: ShaderMaterial = p.mat
	mat.set_shader_parameter("lp", lp)
	mat.set_shader_parameter("lc", lc)
	mat.set_shader_parameter("lcount", near.size())


func _depth(kind: int) -> float:
	match kind:
		KIND_VENT:
			return _cfg.flicker_vent
		KIND_BRAZIER:
			return _cfg.flicker_brazier
		KIND_LAMP:
			return _cfg.flicker_lamp
		_:
			return _cfg.flicker_lava


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
