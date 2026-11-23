class_name SkyCycle
extends Node2D
## Day/night cycle, rain and wind for the meadow. MeadowScene adds it as a child. It owns:
##  - a dithered shade overlay (render/shaders/day_night.gdshader) at z 5, above the walker, pads and props
##    and below LifeAir (z 10), so fireflies, lantern and shrine glow stay bright at night;
##  - SkyRain at z 11;
##  - the sway material that MeadowScene puts on trees and bushes, and the shared wind value that LifeGround reads.
## All timing comes from SkyModel (core/sky_model.gd), tuned by content/config/sky.tres.
## Reduce motion (MeadowLife.reduce_motion): no rain streaks, no sway. The shade still turns, slowly.

const CONFIG_PATH: String = "res://content/config/sky.tres"
const SHADE_SHADER: Shader = preload("res://render/shaders/day_night.gdshader")
const SWAY_SHADER: Shader = preload("res://render/shaders/wind_sway.gdshader")
const HAZE_SHADER: Shader = preload("res://render/shaders/sky_haze.gdshader")
const RAYS_SHADER: Shader = preload("res://render/shaders/god_rays.gdshader")
const GROUND_SHADER: Shader = preload("res://render/shaders/ground_light.gdshader")
const FOG_SHADER: Shader = preload("res://render/shaders/ground_fog.gdshader")
const LIGHT_SHADER: Shader = preload("res://render/shaders/light_grade.gdshader")
const MAX_LIGHTS: int = 24
const AREA: Rect2 = Rect2(-110.0, -70.0, 860.0, 500.0)   # covers the 840x480 bleed at (-100, -60) plus margin
const SWAY_PAD: int = 4                                    # transparent texels added each side of a swaying sprite
const SWAY_STEP: float = 1.0 / 8.0

## Debug and screenshot overrides. Negative = off.
static var debug_phase: float = -1.0
static var debug_rain: float = -1.0

## The rect the shade and rain cover. The meadow uses AREA; bigger scenes (Larkmoor) set their own before add_child.
var area: Rect2 = AREA
var model: SkyModel = SkyModel.new()
var sway_material: ShaderMaterial
var rain_layer: SkyRain
var shadows: SkyShadows                 # set by MeadowScene before this node enters the tree
var rim_material: ShaderMaterial        # for rocks and crystals: same shader as sway, with sway off
var atmosphere: bool = true             # false: no mountain haze or mist
## Where haze and mist are drawn, in world texels. Empty = the whole sky box (the meadow). Larkmoor gives the
## mountain strip, the sea band under it, and one small rect for each pond, so the shader only runs where it shows.
var haze_rects: Array[Rect2] = []
## Shader parameters for the haze placement (horizon_y, band_half, island_half, island, ground_origin): see sky_haze.gdshader.
var haze_params: Dictionary = {}
var ground_texture: Texture2D           # backdrop, so the haze shader can tell water from land
var ponds: Array = []                   # [Vector4(cx, cy, rx, ry)] for the lake and ponds
var _haze_mat: ShaderMaterial
var _rays_mat: ShaderMaterial
var _rays_rect: ColorRect
var _warm: int = 4                  # frames the rays stay drawn after the scene loads, so their shader compiles at load, not at the first sunset
var _screen: ScreenLight
var _lights: Array[Dictionary] = []     # {pos, radius, strength, kind}
var _walker: Node2D
var _shade_mat: ShaderMaterial
var _fog_mat: ShaderMaterial          # drifting ground fog (ground_fog.gdshader)
var _fog_rect: ColorRect
var _light_mat: ShaderMaterial          # full-frame light pass (light_grade.gdshader)
var _config: SkyConfig
var _t: float = 0.0
var _sway_step: int = -1
## Per-sprite materials for props that carry relight data (see prop_material). They share the sway and rim shader and
## get the same parameters as sway_material / rim_material; only the normal texture differs.
var _prop_mats: Array[ShaderMaterial] = []
var _rim_key: Array = []
var _ground_mats: Array[ShaderMaterial] = []
var _debug_view: int = 0
var _relight_key: Vector4 = Vector4(-99.0, 0.0, 0.0, 0.0)
## Seasons (core/game_calendar.gd, core/season_look.gd). The calendar clock drives the sun, so the sky and the HUD
## clock agree; with no calendar (tests, previews) the session clock runs as before and the look stays at spring.
var _cal: GameCalendar
var _cal_cfg: CalendarConfig
var _season: SeasonLook = SeasonLook.new()
var _season_key: Vector4 = Vector4(-99.0, 0.0, 0.0, 0.0)
var particles: SeasonParticles
## Debug and screenshot override: -1 off, else 0..3 pins the season (tools/screenshot).
static var debug_season: int = -1


func _ready() -> void:
	z_index = 5
	_config = load(CONFIG_PATH) as SkyConfig
	if _config == null:
		_config = SkyConfig.new()
	_apply_config()
	_find_calendar()
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = HAZE_SHADER
	if ground_texture != null:
		_haze_mat.set_shader_parameter("ground", ground_texture)
	_haze_mat.set_shader_parameter("ponds", _pond_array())
	for k: String in haze_params:
		_haze_mat.set_shader_parameter(k, haze_params[k])
	var rects: Array[Rect2] = []
	rects.assign(haze_rects if not haze_rects.is_empty() else [AREA])
	for i in rects.size():
		var haze := ColorRect.new()
		haze.name = "Haze" if i == 0 else "Haze%d" % (i + 1)
		haze.visible = atmosphere
		haze.position = rects[i].position
		haze.size = rects[i].size
		haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		haze.material = _haze_mat
		add_child(haze)
	var rays := ColorRect.new()
	rays.name = "Rays"
	rays.position = area.position
	rays.size = area.size
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays_mat = ShaderMaterial.new()
	_rays_mat.shader = RAYS_SHADER
	rays.material = _rays_mat
	_rays_rect = rays
	add_child(rays)
	var fog := ColorRect.new()
	fog.name = "GroundFog"
	fog.position = area.position
	fog.size = area.size
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG_SHADER
	_fog_mat.set_shader_parameter("top_y", area.position.y)
	_fog_mat.set_shader_parameter("span_y", area.size.y)
	fog.material = _fog_mat
	_fog_rect = fog
	fog.visible = atmosphere
	add_child(fog)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.position = area.position
	shade.size = area.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = SHADE_SHADER
	shade.material = _shade_mat
	add_child(shade)
	var lg := ColorRect.new()
	lg.name = "LightGrade"
	lg.position = area.position
	lg.size = area.size
	lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = LIGHT_SHADER
	_light_mat.set_shader_parameter("area_center", area.get_center())
	_light_mat.set_shader_parameter("area_half", area.size * 0.5)
	lg.material = _light_mat
	add_child(lg)
	rain_layer = SkyRain.new()
	rain_layer.name = "Rain"
	rain_layer.z_index = 6   # relative to this node: z 11 overall
	rain_layer.area = area
	rain_layer.drops = int(round(float(_config.rain_drops) * minf(area.get_area() / AREA.get_area(), 2.0)))   # denser over a bigger field, capped for cost
	add_child(rain_layer)
	particles = SeasonParticles.new()
	particles.name = "SeasonParticles"
	particles.z_index = 6
	particles.area = area
	particles.config = _cal_cfg
	add_child(particles)
	sway_material = ShaderMaterial.new()
	sway_material.shader = SWAY_SHADER
	sway_material.set_shader_parameter("max_texels", _config.sway_max_texels)
	rim_material = ShaderMaterial.new()
	rim_material.shader = SWAY_SHADER
	rim_material.set_shader_parameter("max_texels", 0.0)
	rim_material.set_shader_parameter("enabled", 0.0)
	_screen = ScreenLight.new()
	_screen.name = "ScreenLight"
	_screen.world_ref = self
	var host: Node = _find_host()
	if host != null:
		host.add_child.call_deferred(_screen)
	_update(0.0)


## The first Control above us is the main frame; the vignette lives there so it is fixed to the screen.
func _find_host() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n is Control:
			return n
		n = n.get_parent()
	return null


func _pond_array() -> Array:
	var out: Array = []
	for i in 3:
		out.append(ponds[i] if i < ponds.size() else Vector4(0.0, 0.0, 0.0, 0.0))
	return out


## Add a light pool. `follow` (optional) is a node the pool tracks each frame.
func add_light(pos: Vector2, radius: float, strength: float, kind: StringName = &"fixed") -> void:
	if _lights.size() >= MAX_LIGHTS:
		return
	_lights.append({"pos": pos, "radius": radius, "strength": strength, "kind": kind})


func light_config() -> SkyConfig:
	if _config == null:
		_config = load(CONFIG_PATH) as SkyConfig
		if _config == null:
			_config = SkyConfig.new()
	return _config


func _apply_config() -> void:
	model.day_seconds = _config.day_seconds
	model.start_phase = _config.start_phase
	model.daylight_fraction = _config.daylight_fraction
	model.night_strength = _config.night_strength
	model.dusk_strength = _config.dusk_strength
	model.rain_period_a = _config.rain_period_a
	model.rain_period_b = _config.rain_period_b
	model.rain_phase_a = _config.rain_phase_a
	model.rain_phase_b = _config.rain_phase_b
	model.rain_threshold = _config.rain_threshold
	model.rain_max = _config.rain_max
	model.wind_calm = _config.wind_calm
	model.wind_rain_boost = _config.wind_rain_boost
	model.gust_period_a = _config.gust_period_a
	model.gust_period_b = _config.gust_period_b


func _process(delta: float) -> void:
	_t += delta
	_update(_t)


## Time to feed the model: a debug phase pins the time of day, otherwise session time runs.
func _model_time(t: float) -> float:
	if debug_phase >= 0.0:
		return (model.clock_of_phase(debug_phase) - model.clock_of_phase(model.start_phase)) * model.day_seconds
	if _cal != null:
		return (_cal.elapsed_days - model.clock_of_phase(model.start_phase)) * model.day_seconds
	return t


func _find_calendar() -> void:
	_cal_cfg = load("res://content/config/calendar.tres") as CalendarConfig
	var gs: Node = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs != null and gs.get("sim") is Sim:
		_cal = (gs.get("sim") as Sim).calendar
		if _cal != null:
			_cal_cfg = _cal.config
	if _cal_cfg == null:
		_cal_cfg = CalendarConfig.new()


## Mix the four seasons by their weights and push the result to every ground and prop material.
func _update_season() -> void:
	var w: Array[float] = [1.0, 0.0, 0.0, 0.0]
	if debug_season >= 0:
		w = [0.0, 0.0, 0.0, 0.0]
		w[clampi(debug_season, 0, 3)] = 1.0
	elif _cal != null:
		w = _cal.season_weights()
	_season = SeasonLook.blend(_cal_cfg, w)
	var key: Vector4 = _season.key()
	if key == _season_key:
		return
	_season_key = key
	for gm: ShaderMaterial in _ground_mats:
		_push_season(gm, true)
	for pm: ShaderMaterial in _prop_mats:
		_push_season(pm, false)
	_push_season(sway_material, false)
	_push_season(rim_material, false)
	if particles != null:
		particles.weights = _season.weights


func _push_season(m: ShaderMaterial, ground: bool) -> void:
	if m == null:
		return
	m.set_shader_parameter("season_col", _season.ground_col if ground else _season.prop_col)
	m.set_shader_parameter("season_col2", _season.ground_col2 if ground else _season.prop_col2)
	m.set_shader_parameter("season_amt", _season.ground_amt if ground else _season.prop_amt)
	m.set_shader_parameter("season_snow", _season.ground_snow if ground else _season.prop_snow)


func _update(t: float) -> void:
	var mt: float = _model_time(t)
	_update_season()
	_shade_mat.set_shader_parameter("night", clampf(model.night(mt) / maxf(model.night_strength, 0.001), 0.0, 1.0) * _config.night_shade)
	var ramp: float = model.ramp(mt)
	if _config.grade_tint != null:
		var gc: Color = _config.grade_tint.sample(ramp)
		_shade_mat.set_shader_parameter("grade_col", Color(gc.r * _season.grade.r, gc.g * _season.grade.g, gc.b * _season.grade.b, 1.0))
	if _config.grade_amount != null:
		_shade_mat.set_shader_parameter("grade_amount", _config.grade_amount.sample(ramp).r)
	_shade_mat.set_shader_parameter("pool_strength", _config.pool_strength)
	var rain: float = model.rain(t) if debug_rain < 0.0 else debug_rain
	var wind: float = model.wind(t)
	if debug_rain >= 0.0:
		wind = maxf(wind, 0.5)
	_shade_mat.set_shader_parameter("rain", rain)
	MeadowLife.wind = 0.0 if MeadowLife.reduce_motion else wind
	rain_layer.visible = not MeadowLife.reduce_motion
	var snow_w: float = _season.weights[3]
	rain_layer.intensity = rain / maxf(model.rain_max, 0.001) * (1.0 - snow_w)   # winter precipitation is snow
	if particles != null:
		particles.snow_precip = rain / maxf(model.rain_max, 0.001) * snow_w
		particles.wind = wind
	rain_layer.wind = wind
	_update_light(t, mt, rain)
	var s: int = int(t / SWAY_STEP)
	if s != _sway_step:
		_sway_step = s
		sway_material.set_shader_parameter("step_time", float(s) * SWAY_STEP)
		sway_material.set_shader_parameter("wind", wind)
		sway_material.set_shader_parameter("enabled", 0.0 if MeadowLife.reduce_motion else 1.0)
		for m: ShaderMaterial in _prop_mats:
			if m.get_shader_parameter("max_texels") > 0.0:     # the sway ones; rocks and crystals stay put
				m.set_shader_parameter("step_time", float(s) * SWAY_STEP)
				m.set_shader_parameter("wind", wind)
				m.set_shader_parameter("enabled", 0.0 if MeadowLife.reduce_motion else 1.0)


## A material for one prop sprite with relight data `nrm` (tools/art/depth_pass.py `_n.png`, padded like the sprite
## when `sways`). The sun direction, relight strength, rim and sway parameters follow the sky.
func prop_material(sways: bool, nrm: Texture2D) -> ShaderMaterial:
	var base: ShaderMaterial = sway_material if sways else rim_material
	if base == null:      # _ready has not run yet (tests, early spawn): nothing to follow
		return null
	var m: ShaderMaterial = base.duplicate() as ShaderMaterial
	m.set_shader_parameter("nrm_tex", nrm)
	_prop_mats.append(m)
	_season_key = Vector4(-99.0, 0.0, 0.0, 0.0)
	_relight_key = Vector4(-99.0, 0.0, 0.0, 0.0)   # push the sun and rim to the new material on the next update
	_rim_key = []
	return m


## Material for the baked ground sprite, relit per texel from its G-buffer (nrm: normal/material/light, height: world z).
func ground_material(nrm: Texture2D, height: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("nrm_tex", nrm)
	m.set_shader_parameter("h_tex", height)
	_ground_mats.append(m)
	_season_key = Vector4(-99.0, 0.0, 0.0, 0.0)
	_relight_key = Vector4(-99.0, 0.0, 0.0, 0.0)
	return m


## F6 cycles a debug view of the ground relight: off, albedo, normal, height, shadow only. Shows whether the maps are sampled.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F6:
		_debug_view = (_debug_view + 1) % 5
		for gm: ShaderMaterial in _ground_mats:
			gm.set_shader_parameter("debug_view", _debug_view)


func _each_prop_material(param: StringName, value: Variant) -> void:
	for m: ShaderMaterial in _prop_mats:
		m.set_shader_parameter(param, value)


## Copy of `tex` with SWAY_PAD transparent texels each side, so a leaning crown is not clipped by the sprite edge.
static func padded(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out: Image = Image.create(img.get_width() + SWAY_PAD * 2, img.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(SWAY_PAD, 0))
	return ImageTexture.create_from_image(out)


## Sun, shadows, rim light, haze, mist, rays, vignette and light pools for this moment.
func _update_light(t: float, mt: float, rain: float) -> void:
	MeadowLife.night = clampf(model.night(mt) / maxf(model.night_strength, 0.001), 0.0, 1.0)
	MeadowLife.low_sun = model.low_sun(mt)
	MeadowLife.rain = clampf(rain / maxf(model.rain_max, 0.001), 0.0, 1.0)
	var calm: bool = MeadowLife.reduce_motion
	var steady: bool = calm or FxConfig.reduce_flashing
	var az: float = model.azimuth(mt)
	var ramp: float = model.ramp(mt)
	var rain01: float = clampf(rain / maxf(model.rain_max, 0.001), 0.0, 1.0)
	# cast shadows
	var low_sun_k: float = model.low_sun(mt)
	if shadows != null:
		var len: float = model.shadow_length(mt, _config.shadow_len_noon, _config.shadow_len_low, _config.shadow_len_moon)
		shadows.set_sun(az, len, model.shadow_strength(mt, _config.shadow_moon, rain01),
				{"foot": _config.shadow_density_foot, "tip": _config.shadow_density_tip, "low": low_sun_k})
	# rim light on props: whole-texel direction toward the light, warm when the sun is low, cool under the moon
	var low: float = model.low_sun(mt)
	var night_k: float = clampf(-model.sun_of(model.phase(mt)) * 2.0, 0.0, 1.0)
	var rim_amt: float = _config.rim_strength * (0.35 + 0.65 * low) * (1.0 - 0.9 * rain01)
	rim_amt = maxf(rim_amt * (1.0 - night_k), 0.45 * _config.rim_strength * night_k * (1.0 - rain01))
	var rim_dir := Vector2(clampf(roundf(az * 1.2), -1.0, 1.0), -1.0)   # toward the light
	var rim_col: Color = _config.ray_color.sample(ramp) if _config.ray_color != null else Color(1.0, 0.95, 0.75)
	for m: ShaderMaterial in [sway_material, rim_material]:
		m.set_shader_parameter("rim_dir", rim_dir)
		m.set_shader_parameter("rim_amount", rim_amt)
		m.set_shader_parameter("rim_col", rim_col)
	# sun-driven relight (render/shaders/wind_sway.gdshader): world-space sun direction, same frame as the baked
	# normals (u, v, up). az is the screen side, so u = +az and v = -az put the light on that side; it climbs with the sun.
	var sun_h: float = SkyModel.sun_of(model.phase(mt))
	var relight: float = (1.0 - 0.5 * night_k) * (1.0 - 0.6 * rain01)
	var key := Vector4(roundf(az * 32.0) / 32.0, roundf(maxf(sun_h, 0.0) * 32.0) / 32.0, roundf(relight * 32.0) / 32.0, 0.0)
	if key != _relight_key:      # quantised: the 70-odd prop materials are only written when the sun has really moved
		_relight_key = key
		var sun := Vector3(key.x * 0.45, -key.x * 0.45, 0.35 + 0.5 * key.y).normalized()
		_each_prop_material(&"sun_dir", sun)
		_each_prop_material(&"relight", key.z)
		for gm: ShaderMaterial in _ground_mats:
			gm.set_shader_parameter("sun_dir", sun)
	if not _ground_mats.is_empty():
		var sun_px := Vector2(clampf(az * 1.2, -1.0, 1.0), -0.6)    # toward the sun on screen, texels per march step
		var shadow_k: float = _config.ground_shadow * (1.0 - 0.8 * rain01) * (1.0 - night_k * 0.6)
		var fog_col: Color = _season.tint_haze(_config.haze_color.sample(ramp) if _config.haze_color != null else Color(0.62, 0.82, 0.7))
		for gm: ShaderMaterial in _ground_mats:
			gm.set_shader_parameter("sun_px", sun_px)
			gm.set_shader_parameter("relight", _config.ground_relight * (0.4 + 0.6 * low_sun_k) * (1.0 - 0.5 * night_k))   # eased at high sun so noon grass keeps its detail
			gm.set_shader_parameter("shadow_amt", shadow_k * (0.5 + 0.5 * low_sun_k))
			gm.set_shader_parameter("shadow_slope", lerpf(2.4, 1.0, clampf(low_sun_k + 0.35, 0.0, 1.0)))
			gm.set_shader_parameter("shadow_reach", lerpf(1.6, 3.4, low_sun_k))
			gm.set_shader_parameter("ao_amt", _config.ground_ao)
			gm.set_shader_parameter("fog_col", fog_col)
			gm.set_shader_parameter("fog_amt", _config.ground_fog * _season.fog_mult * (0.5 + 0.5 * model.mist(mt, rain01)))
	var rim_key: Array = [rim_dir, snappedf(rim_amt, 0.02), rim_col]
	if rim_key != _rim_key:
		_rim_key = rim_key
		_each_prop_material(&"rim_dir", rim_dir)
		_each_prop_material(&"rim_amount", rim_amt)
		_each_prop_material(&"rim_col", rim_col)
	# haze over the mountains, mist over the water
	var haze_col: Color = _season.tint_haze(_config.haze_color.sample(ramp) if _config.haze_color != null else Color(0.62, 0.82, 0.7))
	_haze_mat.set_shader_parameter("haze_col", haze_col)
	_haze_mat.set_shader_parameter("haze", _config.haze_strength * (0.55 + 0.45 * model.mist(mt, rain01)))
	_haze_mat.set_shader_parameter("mist", _config.mist_strength * _season.fog_mult * model.mist(mt, rain01))
	var drift: float = 0.0 if calm else floorf(mt / maxf(_config.mist_drift_seconds, 1.0) * 860.0)
	_haze_mat.set_shader_parameter("drift", drift)
	# ground fog: thickest at dawn and dusk, heavier in rain, drifting sideways; world-anchored dither
	var fog_amt: float = _config.fog_ground * _season.fog_mult * model.mist(mt, rain01) * (1.0 - 0.5 * clampf(model.night(mt) / maxf(model.night_strength, 0.001), 0.0, 1.0))
	_fog_rect.visible = atmosphere and fog_amt > 0.01
	_fog_mat.set_shader_parameter("amount", fog_amt)
	_fog_mat.set_shader_parameter("fog_col", Color(0.62, 0.7, 0.66).lerp(haze_col, 0.3))   # pale and cool: a dawn haze colour painted the fog orange-red
	_fog_mat.set_shader_parameter("drift", 0.0 if calm else floorf(mt / maxf(_config.mist_drift_seconds, 1.0) * 520.0))
	# god rays: sun point sits above the frame on the side the sun is on
	var ray_amt: float = _config.ray_strength * model.rays(mt, rain01)
	# The rays are only lit at dawn and dusk. Skip the full-area atan and sin pass the rest of the day.
	_rays_rect.visible = ray_amt > 0.002 or _warm > 0
	_warm = maxi(_warm - 1, 0)
	_rays_mat.set_shader_parameter("amount", ray_amt)
	_rays_mat.set_shader_parameter("sun", Vector2(area.get_center().x + az * area.size.x * 0.465, area.position.y - 50.0))
	_rays_mat.set_shader_parameter("ray_col", rim_col)
	_rays_mat.set_shader_parameter("sway", 0.0 if steady else floorf(mt * 0.5) * 0.25)
	# full-frame light pass: sun side lifts and warms, away side shades cool (magenta at dusk), highlights and shadows split
	var lit_k: float = (1.0 - clampf(model.night(mt) / maxf(model.night_strength, 0.001), 0.0, 1.0) * 0.75) * (1.0 - 0.7 * rain01)
	_light_mat.set_shader_parameter("sun_dir", Vector2(az, -1.0))
	_light_mat.set_shader_parameter("light_col", rim_col)
	_light_mat.set_shader_parameter("shade_col", Color(0.62, 0.68, 0.88).lerp(Color(0.74, 0.52, 0.78), low_sun_k))
	_light_mat.set_shader_parameter("side_amount", _config.light_side * lit_k)
	_light_mat.set_shader_parameter("split_amount", _config.light_split * (0.4 + 0.6 * lit_k))
	_light_mat.set_shader_parameter("lift", _config.light_lift)
	# vignette
	if _screen != null:
		_screen.set_strength(_config.vignette_strength)
	_push_lights(t, steady)


func _find_walker() -> Node2D:
	var world: Node = get_parent().get_parent() if get_parent() != null else null
	if world == null:
		return null
	for c: Node in world.get_children():
		if c.is_in_group("walker") or (c.get_script() != null and (c.get_script() as Script).get_global_name() == &"TexelWalker"):
			return c as Node2D
	return null


## Radius wobble of a light pool in texels, -1..1, on a 6 fps beat. Zero when `steady` (Reduce motion or Reduce flashing).
static func light_flicker(t: float, key: int, steady: bool) -> float:
	if steady:
		return 0.0
	return (MeadowLife.hash01(int(t * 6.0) * 7 + key) - 0.5) * 2.0


func _push_lights(t: float, steady: bool) -> void:
	var arr: Array = []
	for L: Dictionary in _lights:
		var pos: Vector2 = L.pos
		if L.kind == &"walker":
			if _walker == null or not is_instance_valid(_walker):
				_walker = _find_walker()
			if _walker == null:
				continue
			pos = _walker.position
		var flick: float = light_flicker(t, int(pos.x), steady)
		arr.append(Vector4(pos.x, pos.y - 4.0, float(L.radius) + flick, float(L.strength)))
	while arr.size() < MAX_LIGHTS:
		arr.append(Vector4(0.0, 0.0, 0.0, 0.0))
	_shade_mat.set_shader_parameter("lights", arr)
