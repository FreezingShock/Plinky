class_name SeasonalEvents
extends RefCounted
## The current season's event, as plain multipliers. Pure: give it the config and a season index (0..3).
## Sim asks it for the numbers; it never touches nodes. Missing config or a bad index means "no event" (all 1.0).

var config: SeasonalEventsConfig


func _init(p_config: SeasonalEventsConfig = null) -> void:
	config = p_config


func name_of(season: int) -> String:
	return _str(config.event_names if config != null else PackedStringArray(), season)


func blurb_of(season: int) -> String:
	return _str(config.event_blurbs if config != null else PackedStringArray(), season)


func critter_interval_mult(season: int) -> float:
	return _mult(config.critter_interval_mult if config != null else PackedFloat32Array(), season)


func day_income_mult(season: int, is_day: bool) -> float:
	if not is_day:
		return 1.0
	return _mult(config.day_income_mult if config != null else PackedFloat32Array(), season)


func relic_roll_mult(season: int) -> float:
	return _mult(config.relic_roll_mult if config != null else PackedFloat32Array(), season)


func momentum_decay_mult(season: int) -> float:
	return _mult(config.momentum_decay_mult if config != null else PackedFloat32Array(), season)


static func _mult(a: PackedFloat32Array, i: int) -> float:
	return maxf(a[i], 0.01) if i >= 0 and i < a.size() else 1.0


static func _str(a: PackedStringArray, i: int) -> String:
	return a[i] if i >= 0 and i < a.size() else ""
