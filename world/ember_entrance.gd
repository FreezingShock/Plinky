class_name EmberEntrance
extends Node2D
## The Ember Quarry cave entrance in Larkmoor: the neon EMBER QUARRY sign and the ember light around the mine mouth.
## The cave, rails, dirt and decor are ordinary props (assets/art/zone1b/larkmoor/entrance/entrance.json, merged into
## the placements by larkmoor_scene.gd). This one node draws the self-lit parts: the sign (a lit texture and a dim one),
## an additive ember glow over the sign and the cave mouth, and a few blinking ember glints. It sits above the night
## shade (z_index 6) so it stays bright. Strength follows SkyCycle.night01. Reduce Motion freezes the glints and
## Reduce Flashing stops the neon flicker; the sign then stays steadily lit.

const DIR: String = "res://assets/art/zone1b/larkmoor/"
const GLINT_STEP: float = 3.0            ## clock steps per second for the glints (stepped, not smooth)
const FLICKER_EVERY: float = 9.0         ## seconds between neon flickers
const FLICKER_LEN: float = 0.5           ## seconds a flicker lasts
const FLICKER_STEP: float = 10.0         ## steps per second inside a flicker
const EMBER: Color = Color(0.95, 0.42, 0.18)
const GLINT: Color = Color(0.91, 0.66, 0.27)

var _sky: SkyCycle
var _sign_on: Texture2D
var _sign_dim: Texture2D
var _sign_pos: Vector2 = Vector2.ZERO
var _glow_cave: Vector4 = Vector4.ZERO     ## centre x, centre y, radius x, radius y
var _glow_sign: Vector4 = Vector4.ZERO
var _glints: PackedVector2Array = PackedVector2Array()
var _glow_tex: Texture2D
var _glow: Node2D                           ## additive child: the halos and glints
var _last_key: int = -1


## Reads the layout from entrance.json. Does nothing when the file is missing.
func setup(sky: SkyCycle) -> void:
	_sky = sky
	name = "EmberEntrance"
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path: String = DIR + "entrance/entrance.json"
	if not FileAccess.file_exists(path):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var s: Dictionary = data.get("sign", {}) as Dictionary
	if s.is_empty():
		return
	_sign_on = load(DIR + String(s.on)) as Texture2D
	_sign_dim = load(DIR + String(s.dim)) as Texture2D
	_sign_pos = Vector2(float(s.x), float(s.y))
	var g: Dictionary = data.get("glow", {}) as Dictionary
	var c: Array = g.get("cave", [0, 0, 1, 1]) as Array
	var sg: Array = g.get("sign", [0, 0, 1, 1]) as Array
	_glow_cave = Vector4(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	_glow_sign = Vector4(float(sg[0]), float(sg[1]), float(sg[2]), float(sg[3]))
	for p: Variant in data.get("glints", []) as Array:
		var a: Array = p as Array
		_glints.append(Vector2(float(a[0]), float(a[1])))
	_glow_tex = _make_glow_texture()
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	set_process(true)


## A soft radial falloff, 64x64, white with alpha. Drawn tinted, so it is the ember colour at any strength.
static func _make_glow_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d: float = Vector2(float(x) - 31.5, float(y) - 31.5).length() / 32.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)


## 0 steady, or the flicker's lit/dim state: true when the sign should show its dim frame right now.
func _dim_now(t: float) -> bool:
	if MeadowLife.reduce_motion or FxConfig.reduce_flashing:
		return false
	var phase: float = fmod(t, FLICKER_EVERY)
	if phase > FLICKER_LEN:
		return false
	return int(floor(phase * FLICKER_STEP)) % 2 == 0


func _process(_delta: float) -> void:
	if _sign_on == null or _sky == null:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var night_q: int = int(round(_sky.night01 * 16.0))
	var key: int = night_q + (1 if _dim_now(t) else 0) * 100
	if not MeadowLife.reduce_motion:
		key += int(floor(t * GLINT_STEP)) * 1000
	if key == _last_key:
		return
	_last_key = key
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	if _sign_on == null:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	draw_texture(_sign_dim if _dim_now(t) else _sign_on, _sign_pos)


func _draw_glow() -> void:
	if _sky == null or _glow_tex == null:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var night: float = floorf(_sky.night01 * 16.0 + 0.5) / 16.0
	var k: float = 0.22 + 0.6 * night            # the neon and the cave glow all day, and more at night
	if _dim_now(t):
		k *= 0.45
	_draw_halo(_glow_sign, Color(EMBER.r, EMBER.g, EMBER.b, k * 0.55))
	_draw_halo(_glow_cave, Color(EMBER.r, EMBER.g, EMBER.b, (0.18 + 0.55 * night) * 0.9))
	var step: int = 0 if MeadowLife.reduce_motion else int(floor(t * GLINT_STEP))
	for i in _glints.size():
		var on: bool = MeadowLife.reduce_motion or ((i * 7 + step * 3) % 5) < 2
		if not on:
			continue
		var a: float = 0.55 + 0.45 * night
		var p: Vector2 = _glints[i].floor()
		_glow.draw_rect(Rect2(p, Vector2.ONE), Color(GLINT.r, GLINT.g, GLINT.b, a))


func _draw_halo(h: Vector4, col: Color) -> void:
	_glow.draw_texture_rect(_glow_tex, Rect2(h.x - h.z, h.y - h.w, h.z * 2.0, h.w * 2.0), false, col)
