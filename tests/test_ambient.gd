extends RefCounted
## Ambient soundscape: the pure mix (core/ambient_mix.gd) follows zone, time of day and season, and every layer file exists.

const SPRING: Array[float] = [1.0, 0.0, 0.0, 0.0]
const SUMMER: Array[float] = [0.0, 1.0, 0.0, 0.0]
const AUTUMN: Array[float] = [0.0, 0.0, 1.0, 0.0]
const WINTER: Array[float] = [0.0, 0.0, 0.0, 1.0]
const D: float = 0.6   # daylight fraction of the day: sunrise at 0.2, sunset at 0.8

func run(t: Object) -> void:
	t.eq(AmbientMix.area_of(&"zone1"), AmbientMix.AREA_MEADOW, "the starting meadow uses the meadow scape")
	t.eq(AmbientMix.area_of(&"larkmoor"), AmbientMix.AREA_LARKMOOR, "Larkmoor has its own scape")
	t.eq(AmbientMix.area_of(&"zone2"), AmbientMix.AREA_QUARRY, "the Ember Quarry uses the quarry scape")

	t.near(AmbientMix.daylight(0.5, D), 1.0, 1e-6, "noon is full daylight")
	t.near(AmbientMix.daylight(0.0, D), 0.0, 1e-6, "midnight is dark")
	var mid: float = AmbientMix.daylight(0.2, D)
	t.ok(mid > 0.3 and mid < 0.7, "sunrise is halfway: it fades, it does not switch")

	var noon: Dictionary = AmbientMix.layers(AmbientMix.AREA_LARKMOOR, 0.5, D, SUMMER)
	var night: Dictionary = AmbientMix.layers(AmbientMix.AREA_LARKMOOR, 0.0, D, SUMMER)
	t.ok((noon[AmbientMix.L_WIND_DAY] as float) > 0.9 and (night[AmbientMix.L_WIND_DAY] as float) < 0.01, "day wind plays by day only")
	t.ok((night[AmbientMix.L_CRICKETS] as float) > 0.9 and (noon[AmbientMix.L_CRICKETS] as float) < 0.01, "summer crickets play at night only")
	t.ok((night[AmbientMix.L_WIND_NIGHT] as float) > 0.5, "night wind plays at night")
	t.near(night[AmbientMix.L_CRACKLE], 0.0, 1e-6, "no forge crackle in the meadows")

	var winter_night: Dictionary = AmbientMix.layers(AmbientMix.AREA_MEADOW, 0.0, D, WINTER)
	t.near(winter_night[AmbientMix.L_CRICKETS], 0.0, 1e-6, "no crickets in winter")
	t.ok((winter_night[AmbientMix.L_WIND_WINTER] as float) > 0.4, "winter has its own thin wind")
	var autumn_day: Dictionary = AmbientMix.layers(AmbientMix.AREA_MEADOW, 0.5, D, AUTUMN)
	var spring_day: Dictionary = AmbientMix.layers(AmbientMix.AREA_MEADOW, 0.5, D, SPRING)
	t.ok((autumn_day[AmbientMix.L_LEAVES] as float) > 0.5 and (spring_day[AmbientMix.L_LEAVES] as float) < 0.01, "leaves rustle in autumn only")

	var blend: Array[float] = [0.0, 0.5, 0.5, 0.0]
	var cr: float = AmbientMix.layers(AmbientMix.AREA_MEADOW, 0.0, D, blend)[AmbientMix.L_CRICKETS] as float
	t.ok(cr > 0.5 and cr < 0.9, "a season blend crossfades the crickets between its neighbours")

	var quarry_day: Dictionary = AmbientMix.layers(AmbientMix.AREA_QUARRY, 0.5, D, SUMMER)
	var quarry_night: Dictionary = AmbientMix.layers(AmbientMix.AREA_QUARRY, 0.0, D, SUMMER)
	t.ok((quarry_day[AmbientMix.L_CRACKLE] as float) >= 0.7, "the quarry crackles by day")
	t.ok((quarry_night[AmbientMix.L_CRACKLE] as float) > (quarry_day[AmbientMix.L_CRACKLE] as float), "and louder at night")
	t.near(quarry_night[AmbientMix.L_CRICKETS], 0.0, 1e-6, "no crickets in the quarry")

	t.near(AmbientMix.bird_scale(AmbientMix.AREA_MEADOW, 0.0, D, SPRING), 0.0, 1e-6, "no birdsong at night")
	t.near(AmbientMix.bird_scale(AmbientMix.AREA_QUARRY, 0.5, D, SPRING), 0.0, 1e-6, "no birdsong in the quarry")
	t.ok(AmbientMix.bird_scale(AmbientMix.AREA_MEADOW, 0.5, D, SPRING) > AmbientMix.bird_scale(AmbientMix.AREA_MEADOW, 0.5, D, WINTER), "spring has more birdsong than winter")
	t.ok(AmbientMix.bird_scale(AmbientMix.AREA_MEADOW, 0.23, D, SPRING) > AmbientMix.bird_scale(AmbientMix.AREA_MEADOW, 0.5, D, SPRING), "a dawn chorus is louder than noon")

	for l in AmbientMix.LAYERS:
		t.ok(FileAccess.file_exists("res://assets/audio/amb/%s.ogg" % l) or ResourceLoader.exists("res://assets/audio/amb/%s.ogg" % l), "layer file exists: %s" % l)

	# Rain bed: follows the rain, silent under snow and in the quarry.
	t.ok(AmbientMix.rain_gain(0.0, 0.0, AmbientMix.AREA_MEADOW) == 0.0, "no rain, no rain bed")
	t.ok(AmbientMix.rain_gain(1.0, 0.0, AmbientMix.AREA_MEADOW) > 0.99, "full rain plays the rain bed at full gain")
	t.ok(AmbientMix.rain_gain(0.6, 1.0, AmbientMix.AREA_MEADOW) == 0.0, "winter rain is snow, so no rain bed")
	t.ok(AmbientMix.rain_gain(0.6, 0.0, AmbientMix.AREA_QUARRY) == 0.0, "the quarry has no weather sound")
	t.ok(AmbientMix.rain_gain(2.0, 0.0, AmbientMix.AREA_LARKMOOR) <= 1.0, "rain gain stays within 0..1")
	t.ok(ResourceLoader.exists("res://assets/audio/amb/rain.ogg"), "the rain bed is a baked file, not made on the main thread")

	# Thunder picks: a rumble never plays twice in a row, every variant can come up, and the edges stay in range
	var seen: Dictionary = {}
	var repeats: int = 0
	var last_pick: int = -1
	for i in 400:
		var pick: int = AmbientMix.next_variant(last_pick, 4, float(i % 97) / 97.0)
		if pick == last_pick:
			repeats += 1
		seen[pick] = true
		last_pick = pick
	t.eq(repeats, 0, "a thunder pick never repeats the rumble just played")
	t.eq(seen.size(), 4, "every thunder variant can come up")
	t.eq(AmbientMix.next_variant(0, 1, 0.5), 0, "with one variant, it always plays")
	t.ok(AmbientMix.next_variant(-1, 4, 0.999) == 3 and AmbientMix.next_variant(-1, 4, 0.0) == 0, "the first pick covers the whole range")
	t.ok(AmbientMix.next_variant(2, 4, 0.0) != 2 and AmbientMix.next_variant(2, 4, 0.999) != 2, "the pick skips the last variant at both ends of the roll")
