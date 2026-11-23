class_name AreaBanner
extends RefCounted
## Builds the arrival banner for an outdoor area: its name, then the season and date, then the time of day.
## Pure: the caller passes the calendar dictionary (Calendar.now(), may be empty) and the sky phase as a fallback.

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]


## Time of day word for a sky phase (0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset).
static func period_of(phase: float) -> String:
	var p: float = fposmod(phase, 1.0)
	if p < 0.2 or p >= 0.88:
		return "Night"
	if p < 0.3:
		return "Dawn"
	if p < 0.45:
		return "Morning"
	if p < 0.55:
		return "Midday"
	if p < 0.7:
		return "Afternoon"
	if p < 0.8:
		return "Dusk"
	return "Evening"


## {hour, minute} for a sky phase.
static func clock_of(phase: float) -> Dictionary:
	var minutes: int = int(floorf(fposmod(phase, 1.0) * 1440.0))
	return {"hour": floori(minutes / 60.0), "minute": minutes % 60}


static func clock_text(hour: int, minute: int) -> String:
	return "%02d:%02d" % [hour, minute]


## `cal` keys it understands, all optional: season (String or index 0 to 3), month, day, hour, minute, period.
## Missing time falls back to `phase`; a missing season or date just leaves that line out.
static func compose(area_name: String, cal: Dictionary, phase: float, icon: String = "") -> Dictionary:
	var lines: Array[String] = []
	var season: String = _season_name(cal.get("season", ""))
	var date_bits: Array[String] = []
	if season != "":
		date_bits.append(season)
	if cal.has("month"):
		date_bits.append("Month %d" % int(cal["month"]))
	if cal.has("day"):
		date_bits.append("Day %d" % int(cal["day"]))
	if not date_bits.is_empty():
		lines.append(" - ".join(date_bits))
	var hour: int
	var minute: int
	if cal.has("hour"):
		hour = int(cal["hour"])
		minute = int(cal.get("minute", 0))
	else:
		var c: Dictionary = clock_of(phase)
		hour = c["hour"]
		minute = c["minute"]
	var period: String = str(cal.get("period", period_of(float(hour * 60 + minute) / 1440.0)))
	lines.append("%s - %s" % [clock_text(hour, minute), period])
	return {"title": area_name, "lines": lines, "icon": icon, "key": "area:" + area_name}


static func _season_name(v: Variant) -> String:
	if v is int or v is float:
		var i: int = int(v)
		return SEASONS[i] if i >= 0 and i < SEASONS.size() else ""
	var s: String = str(v)
	return s.capitalize() if s != "" else ""
