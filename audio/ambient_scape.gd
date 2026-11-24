class_name AmbientScape
extends Node
## The layered ambient soundscape, a child of the Audio autoload. One looping player per layer on the Ambience bus,
## faded toward the mix AmbientMix gives for the current zone, time of day and season. Layers that are silent are stopped.
## Audio owns the zone and the bird one-shots; this owns the loops: Audio.set_zone calls set_area, and Audio's bird
## timer asks bird_scale(). The rain bed is made in code (no file) and follows SkyCycle's rain through MeadowLife.

const DIR: String = "res://assets/audio/amb/"
const FADE_PER_S: float = 0.35            # a layer takes about 3 s to fade fully in or out, so dawn and dusk glide
const POLL_S: float = 0.25                # the calendar is read four times a second, not every frame
const OFF: float = 0.003
const RAIN_LAYER: StringName = &"rain"
const RAIN_RATE: int = 11025              # rain is low, soft patter: a low rate costs little to make and sounds the same
const RAIN_SECONDS: float = 6.0
const THUNDER_RATE: int = 11025
const THUNDER_SECONDS: float = 4.5       ## a rumble: low-passed noise that rolls and dies away
const THUNDER_DB: float = -6.0           ## at a full downpour, before the Ambience bus slider
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
var _rain_stream: AudioStreamWAV = null
var _snow_w: float = 0.0           # winter weight: rain is snow then, so there is no thunder
var _thunder_player: AudioStreamPlayer
var _thunder_stream: AudioStreamWAV = null
var _thunder_due: float = -1.0     # sky time the rumble is due, -1 when none is waiting
var _storm_window: int = -999999   # the 40 s lightning window the schedule last looked at


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


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = POLL_S
		_refresh(false)
		_storm()
	for l in _layers:
		var g: float = move_toward(_gain[l] as float, _target[l] as float, delta * FADE_PER_S)
		_gain[l] = g
		_apply(l, g)


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
	p.volume_db = (BASE_DB.get(layer, -10.0) as float) + linear_to_db(g)


func _load(layer: StringName) -> AudioStream:
	if layer == RAIN_LAYER:
		return _rain()
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
		var heavy: float = clampf((rain01 - 0.7) / 0.3, 0.0, 1.0)
		_thunder_player.stream = _thunder()
		_thunder_player.volume_db = THUNDER_DB + linear_to_db(maxf(heavy, 0.05))
		_thunder_player.play()


## One rumble, made once on first use: low-passed noise under a fast attack and a slow decay, rolling a little.
func _thunder() -> AudioStreamWAV:
	if _thunder_stream != null:
		return _thunder_stream
	var n: int = int(THUNDER_RATE * THUNDER_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	var peak: float = 0.0
	for i in n:
		var sec: float = float(i) / float(THUNDER_RATE)
		lp = lp * 0.985 + rng.randf_range(-1.0, 1.0) * 0.015
		var env: float = minf(sec / 0.06, 1.0) * exp(-sec * 1.1)
		var roll: float = 0.7 + 0.3 * sin(TAU * 2.3 * sec)
		buf[i] = lp * env * roll
		peak = maxf(peak, absf(buf[i]))
	var gain: float = 0.85 / maxf(peak, 0.0001)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = THUNDER_RATE
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	w.data = bytes
	_thunder_stream = w
	return w


## The rain bed, made once on first use: low-passed noise (the patter, not hiss) with a few soft ticks for drops on
## leaves. The last fraction of a second is blended into the head, so the loop seam does not click.
func _rain() -> AudioStreamWAV:
	if _rain_stream != null:
		return _rain_stream
	var n: int = int(RAIN_RATE * RAIN_SECONDS)
	var fade: int = RAIN_RATE / 4
	var body: int = n - fade
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in n:
		lp = lp * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
		buf[i] = lp * 1.6
	for k in int(RAIN_SECONDS * 5.0):
		var at: int = rng.randi() % n
		for j in 30:
			buf[(at + j) % n] += 0.12 * (1.0 - float(j) / 30.0) * rng.randf_range(-1.0, 1.0)
	for i in fade:
		var t: float = float(i) / float(fade)
		buf[i] = buf[i] * t + buf[body + i] * (1.0 - t)
	var bytes := PackedByteArray()
	bytes.resize(body * 2)
	for i in body:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RAIN_RATE
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = body
	w.data = bytes
	_rain_stream = w
	return w
