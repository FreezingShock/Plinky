class_name AmbientScape
extends Node
## The layered ambient soundscape, a child of the Audio autoload. One looping player per layer on the Ambience bus,
## faded toward the mix AmbientMix gives for the current zone, time of day and season. Layers that are silent are stopped.
## Audio owns the zone and the bird one-shots; this owns the loops: Audio.set_zone calls set_area, and Audio's bird
## timer asks bird_scale(). The rain bed and the thunder rumbles are baked files (tools/audio/gen_audio.py weather), so
## nothing is synthesised on the main thread. Thunder and the chimes duck the loops (duck()), never the rumble itself.

const DIR: String = "res://assets/audio/amb/"
const FADE_PER_S: float = 0.35            # a layer takes about 3 s to fade fully in or out, so dawn and dusk glide
const POLL_S: float = 0.25                # the calendar is read four times a second, not every frame
const OFF: float = 0.003
const RAIN_LAYER: StringName = &"rain"
const THUNDER_VARIANTS: int = 4           ## amb/thunder_0..3.ogg, baked by gen_audio.py weather
const THUNDER_PITCH: float = 0.05         ## +-5% on each rumble, so two plays of one variant still differ
const THUNDER_DB: float = -4.0            ## at a full downpour, before the Ambience bus slider
const DUCK_DB: float = 3.0                ## the loops dip this far under a thunder rumble or a chime
const DUCK_HOLD_S: float = 0.5            ## the dip holds this long after the last trigger
const DUCK_ATTACK_S: float = 0.08         ## how fast the dip lands
const DUCK_RELEASE_S: float = 0.4         ## how slowly the loops come back
## Level of each layer at gain 1, in dB. The Ambience bus slider scales all of them.
const BASE_DB: Dictionary = {
	&"wind_day": -9.0, &"wind_night": -10.0, &"wind_winter": -9.0,
	&"crickets": -11.0, &"leaves": -12.0, &"crackle": -10.0,
	&"rain": -16.0,
}

var _players: Dictionary = {}     # layer -> AudioStreamPlayer
var _gain: Dictionary = {}        # layer -> current gain 0..1
var _target: Dictionary = {}      # layer -> wanted gain 0..1
var _layers: Array[StringName] = []
var _area: StringName = AmbientMix.AREA_MEADOW
var _clock: float = 0.0
var _bird: float = 1.0
var _day: float = 1.0
var _snow_w: float = 0.0           # winter weight: rain is snow then, so there is no thunder
var _thunder_player: AudioStreamPlayer
var _thunder_streams: Array[AudioStream] = []
var _thunder_last: int = -1        # the variant played last, so the next one is never the same
var _thunder_due: float = -1.0     # sky time the rumble is due, -1 when none is waiting
var _storm_window: int = -999999   # the 40 s lightning window the schedule last looked at
var _duck_hold: float = 0.0        # seconds left before the loops start coming back
var _duck_now: float = 0.0         # the dip applied to the loops right now, in dB (0 .. DUCK_DB)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layers = AmbientMix.LAYERS.duplicate()
	_layers.append(RAIN_LAYER)
	for l in _layers:
		var p := AudioStreamPlayer.new()
		p.bus = &"Ambience"
		p.volume_db = -80.0
		add_child(p)
		_players[l] = p
		_gain[l] = 0.0
		_target[l] = 0.0
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.bus = &"Ambience"
	add_child(_thunder_player)
	_load_thunder()


func set_area(area: StringName) -> void:
	_area = area
	_refresh(true)


func bird_scale() -> float:
	return _bird


## 0 at night, 1 by day: the old meadow loop (birds baked in) follows it.
func day_gain() -> float:
	return _day


func target(layer: StringName) -> float:
	return _target.get(layer, 0.0) as float


## Ducks the loops by DUCK_DB for a moment. Thunder and the chimes call it, so the bed steps aside and the sharp sound
## reads. The one-shots and the rumble keep their own level.
func duck() -> void:
	_duck_hold = DUCK_HOLD_S


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = POLL_S
		_refresh(false)
		_storm()
	_duck_step(delta)
	for l in _layers:
		var g: float = move_toward(_gain[l] as float, _target[l] as float, delta * FADE_PER_S)
		_gain[l] = g
		_apply(l, g)


func _duck_step(delta: float) -> void:
	if _duck_hold > 0.0:
		_duck_hold = maxf(_duck_hold - delta, 0.0)
		_duck_now = minf(_duck_now + delta * DUCK_DB / DUCK_ATTACK_S, DUCK_DB)
	else:
		_duck_now = maxf(_duck_now - delta * DUCK_DB / DUCK_RELEASE_S, 0.0)


## Reads the calendar. With no calendar yet (title screen, tests) it falls back to a sunny spring noon.
func _refresh(snap: bool) -> void:
	var day_fraction: float = 0.5
	var daylight_fraction: float = 0.6
	var weights: Array[float] = [1.0, 0.0, 0.0, 0.0]
	var cal: Node = get_node_or_null("/root/Calendar")
	if cal != null:
		var core: Variant = cal.call("core")
		if core is GameCalendar:
			var gc: GameCalendar = core as GameCalendar
			day_fraction = gc.day_fraction()
			daylight_fraction = gc.daylight_fraction
			weights = gc.season_weights()
	var mix: Dictionary = AmbientMix.layers(_area, day_fraction, daylight_fraction, weights)
	for l in _layers:
		if l == RAIN_LAYER:
			_target[l] = AmbientMix.rain_gain(MeadowLife.rain, weights[3] if weights.size() > 3 else 0.0, _area)
		else:
			_target[l] = mix.get(l, 0.0) as float
		if snap and not (_players[l] as AudioStreamPlayer).playing:
			_gain[l] = _target[l]    # first mix after a zone change or load: no slow fade up from silence
	_snow_w = weights[3] if weights.size() > 3 else 0.0
	_day = AmbientMix.daylight(day_fraction, daylight_fraction)
	_bird = AmbientMix.bird_scale(_area, day_fraction, daylight_fraction, weights)


func _apply(layer: StringName, g: float) -> void:
	var p: AudioStreamPlayer = _players[layer] as AudioStreamPlayer
	if g <= OFF:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		var s: AudioStream = _load(layer)
		if s == null:
			return
		p.stream = s
		p.volume_db = -80.0
		p.play(randf() * 10.0)     # random start so re-entering a zone never sounds the same
	p.volume_db = (BASE_DB.get(layer, -10.0) as float) + linear_to_db(g) - _duck_now


## A loop layer's baked file. The rain bed is one of them: amb/rain.ogg.
func _load(layer: StringName) -> AudioStream:
	var path: String = "%s%s.ogg" % [DIR, layer]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


## Thunder: the rumble trails each heavy-rain lightning strike (SkyModel.strike_time) by a hashed delay, so the flash comes
## first and the sound after. Only where it rains: no thunder in the quarry or in snow. The sky's own clock comes from
## MeadowLife.sky_time, so the rumble lands on the same strike the screen flashes for.
func _storm() -> void:
	var t: float = MeadowLife.sky_time
	var rain01: float = clampf(MeadowLife.rain, 0.0, 1.0)
	var w: int = int(floorf(t / 40.0))
	if w != _storm_window:
		_storm_window = w
		var st: float = SkyModel.strike_time(w)
		if st >= 0.0 and st > t - 0.5 and rain01 >= 0.7 and AmbientMix.rain_gain(rain01, _snow_w, _area) > 0.0:
			_thunder_due = st + SkyModel.thunder_delay(w)
	if _thunder_due >= 0.0 and t >= _thunder_due:
		_thunder_due = -1.0
		var s: AudioStream = _thunder()
		if s == null:
			return
		var heavy: float = clampf((rain01 - 0.7) / 0.3, 0.0, 1.0)
		_thunder_player.stream = s
		_thunder_player.volume_db = THUNDER_DB + linear_to_db(maxf(heavy, 0.05))
		_thunder_player.pitch_scale = randf_range(1.0 - THUNDER_PITCH, 1.0 + THUNDER_PITCH)
		_thunder_player.play()
		duck()


## The next rumble: one of the baked variants, never the one played last. Loads from the cache (or the disk once, if
## the preload has not reached it yet) and returns null only if the files are missing.
func _thunder() -> AudioStream:
	if _thunder_streams.size() < THUNDER_VARIANTS:
		_load_thunder()
	if _thunder_streams.is_empty():
		return null
	_thunder_last = AmbientMix.next_variant(_thunder_last, _thunder_streams.size(), randf())
	return _thunder_streams[_thunder_last]


func _load_thunder() -> void:
	_thunder_streams.clear()
	for k in THUNDER_VARIANTS:
		var path: String = "%sthunder_%d.ogg" % [DIR, k]
		if not ResourceLoader.exists(path):
			continue
		var s: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
		if s == null:
			continue
		s.loop = false             # a rumble plays once
		_thunder_streams.append(s)
	if _thunder_streams.size() < THUNDER_VARIANTS:
		_thunder_last = -1
