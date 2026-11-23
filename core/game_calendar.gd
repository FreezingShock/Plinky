class_name GameCalendar
extends RefCounted
## The in-game calendar: a pure function of `elapsed_days` (days since Day 1 00:00, saved). A year is
## days_per_month * months_per_season * 4 days, 40 by default. Real time in, calendar time out; one in-game day
## is `day_seconds` real seconds (content/config/sky.tres). No nodes. GameState forwards the signals to EventBus.
##
## API for UI and world code:
##   now()                    a Dictionary snapshot, see below
##   season_weights()         4 floats that sum to 1 (crossfade at season edges), for looks that must not pop
##   seconds_to_next_season() real seconds
## now() keys: year, day (of month, 1-based), day_of_year (1-based), month (0..7), month_name, season (0..3),
##   season_id, season_name, hour, minute, clock_text ("07:12"), day_fraction (0 midnight .. 1), is_day,
##   elapsed_days, days_left_in_season.

signal day_changed(day_of_year: int)       # 0-based
signal month_changed(month_index: int)     # 0-based, within the year
signal season_changed(season_index: int)
signal year_changed(year: int)

const SEASONS: int = 4

var config: CalendarConfig
var day_seconds: float = 300.0
var elapsed_days: float = 0.3
## Daylight share of a day. Only used for is_day; the sky owns the real curve.
var daylight_fraction: float = 0.6

var _day: int = 0
var _month: int = 0
var _season: int = 0
var _year: int = 1


func _init(p_config: CalendarConfig = null, p_day_seconds: float = 300.0) -> void:
	config = p_config if p_config != null else CalendarConfig.new()
	day_seconds = maxf(p_day_seconds, 1.0)
	reset()


func reset() -> void:
	elapsed_days = config.start_elapsed_days
	_sync_marks()


func days_per_season() -> int:
	return maxi(config.days_per_month, 1) * maxi(config.months_per_season, 1)


func days_per_year() -> int:
	return days_per_season() * SEASONS


## Real seconds -> calendar time. Emits a signal for every boundary crossed, once each (a long jump emits once).
func advance(real_seconds: float) -> void:
	if real_seconds <= 0.0:
		return
	elapsed_days += real_seconds / day_seconds
	_emit_changes()


## Jump forward by whole or fractional days (dev console, tests).
func skip_days(days: float) -> void:
	if days <= 0.0:
		return
	elapsed_days += days
	_emit_changes()


## Jump to the start (06:00) of the given season, same year or the next one (dev console).
func jump_to_season(season_index: int) -> void:
	var s: int = clampi(season_index, 0, SEASONS - 1)
	var year_start: float = floorf(elapsed_days / float(days_per_year())) * float(days_per_year())
	var target: float = year_start + float(s * days_per_season()) + 0.25
	if target < elapsed_days:
		target += float(days_per_year())
	elapsed_days = target
	_emit_changes()


func day_index() -> int:
	return int(floorf(elapsed_days))


func day_of_year() -> int:
	return posmod(day_index(), days_per_year())


func month_of_year() -> int:
	return day_of_year() / maxi(config.days_per_month, 1)


func season_index() -> int:
	return clampi(month_of_year() / maxi(config.months_per_season, 1), 0, SEASONS - 1)


func year() -> int:
	return day_index() / days_per_year() + 1


## 0 midnight .. 1.
func day_fraction() -> float:
	return fposmod(elapsed_days, 1.0)


func now() -> Dictionary:
	var f: float = day_fraction()
	var minutes_total: int = int(floorf(f * 1440.0))
	var hour: int = minutes_total / 60
	var minute: int = minutes_total % 60
	var doy: int = day_of_year()
	var dpm: int = maxi(config.days_per_month, 1)
	var mo: int = month_of_year()
	var se: int = season_index()
	var sunrise: float = (1.0 - daylight_fraction) * 0.5
	return {
		"year": year(),
		"day": doy % dpm + 1,
		"day_of_year": doy + 1,
		"days_in_month": dpm,
		"month": mo,
		"month_name": _pick(config.month_names, mo, "Month %d" % (mo + 1)),
		"season": se,
		"season_id": StringName(_pick(config.season_ids, se, "season%d" % se)),
		"season_name": _pick(config.season_names, se, "Season %d" % (se + 1)),
		"season_blurb": _pick(config.season_blurbs, se, ""),
		"hour": hour,
		"minute": minute,
		"clock_text": "%02d:%02d" % [hour, minute],
		"day_fraction": f,
		"is_day": f >= sunrise and f < sunrise + daylight_fraction,
		"elapsed_days": elapsed_days,
		"days_left_in_season": float(days_per_season()) - fposmod(elapsed_days, float(days_per_season())),
	}


func season_name(i: int) -> String:
	return _pick(config.season_names, i, "Season %d" % (i + 1))


func season_color(i: int) -> Color:
	if i >= 0 and i < config.season_colors.size():
		return config.season_colors[i]
	return Color.WHITE


## How much of each season is showing. Sums to 1. A smoothstep crossfade over blend_days around each boundary.
func season_weights() -> Array[float]:
	var w: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var len: float = float(days_per_season())
	var pos: float = fposmod(elapsed_days, float(days_per_year()))
	var i: int = clampi(int(floorf(pos / len)), 0, SEASONS - 1)
	var local: float = pos - float(i) * len
	var half: float = clampf(config.blend_days, 0.0, len) * 0.5
	w[i] = 1.0
	if half > 0.0 and local < half:
		var t: float = smoothstep(0.0, 1.0, 0.5 + local / (half * 2.0))
		w[i] = t
		w[posmod(i - 1, SEASONS)] = 1.0 - t
	elif half > 0.0 and local > len - half:
		var t2: float = smoothstep(0.0, 1.0, (local - (len - half)) / (half * 2.0))
		w[i] = 1.0 - t2
		w[(i + 1) % SEASONS] = t2
	return w


func seconds_to_next_season() -> float:
	return (float(days_per_season()) - fposmod(elapsed_days, float(days_per_season()))) * day_seconds


func to_dict() -> Dictionary:
	return {"elapsed_days": elapsed_days}


## Missing or bad data keeps the new-game start. No signals: a load is not a day passing.
func from_dict(d: Variant) -> void:
	reset()
	if d is Dictionary and (d as Dictionary).has("elapsed_days"):
		var v: float = float((d as Dictionary)["elapsed_days"])
		if is_finite(v) and v >= 0.0:
			elapsed_days = v
	_sync_marks()


func _sync_marks() -> void:
	_day = day_of_year()
	_month = month_of_year()
	_season = season_index()
	_year = year()


func _emit_changes() -> void:
	var d: int = day_of_year()
	var mo: int = month_of_year()
	var se: int = season_index()
	var y: int = year()
	var any: bool = d != _day or y != _year
	_day = d
	if mo != _month or y != _year:
		_month = mo
		month_changed.emit(mo)
	if se != _season or y != _year:
		_season = se
		season_changed.emit(se)
	if y != _year:
		_year = y
		year_changed.emit(y)
	if any:
		day_changed.emit(d)


static func _pick(a: PackedStringArray, i: int, fallback: String) -> String:
	return a[i] if i >= 0 and i < a.size() else fallback
