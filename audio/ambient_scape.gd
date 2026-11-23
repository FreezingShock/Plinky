class_name AmbientScape
extends Node
## The layered ambient soundscape, a child of the Audio autoload. One looping player per layer on the Ambience bus,
## faded toward the mix AmbientMix gives for the current zone, time of day and season. Layers that are silent are stopped.
## Audio owns the zone and the bird one-shots; this owns the loops: Audio.set_zone calls set_area, and Audio's bird
## timer asks bird_scale().

const DIR: String = "res://assets/audio/amb/"
const FADE_PER_S: float = 0.35            # a layer takes about 3 s to fade fully in or out, so dawn and dusk glide
const POLL_S: float = 0.25                # the calendar is read four times a second, not every frame
const OFF: float = 0.003
## Level of each layer at gain 1, in dB. The Ambience bus slider scales all of them.
const BASE_DB: Dictionary = {
	&"wind_day": -9.0, &"wind_night": -10.0, &"wind_winter": -9.0,
	&"crickets": -11.0, &"leaves": -12.0, &"crackle": -10.0,
}

var _players: Dictionary = {}     # layer -> AudioStreamPlayer
var _gain: Dictionary = {}        # layer -> current gain 0..1
var _target: Dictionary = {}      # layer -> wanted gain 0..1
var _area: StringName = AmbientMix.AREA_MEADOW
var _clock: float = 0.0
var _bird: float = 1.0
var _day: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for l in AmbientMix.LAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = &"Ambience"
		p.volume_db = -80.0
		add_child(p)
		_players[l] = p
		_gain[l] = 0.0
		_target[l] = 0.0


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
	for l in AmbientMix.LAYERS:
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
	for l in AmbientMix.LAYERS:
		_target[l] = mix.get(l, 0.0) as float
		if snap and not (_players[l] as AudioStreamPlayer).playing:
			_gain[l] = _target[l]    # first mix after a zone change or load: no slow fade up from silence
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
	var path: String = "%s%s.ogg" % [DIR, layer]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s
