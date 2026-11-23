class_name ClockWidget
extends PanelContainer
## The HUD clock: a small sky dial with the sun or moon riding its arc, the time, and the day, month and season.
## Reads the sim's calendar (core/game_calendar.gd) at 10 Hz and redraws the dial at 5 fps (stars twinkle, the sun
## pulses). Tooltip through Tip. Palette indices only for the dial; the season name takes the season's accent colour.

const DIAL: Vector2i = Vector2i(34, 22)
const HORIZON: int = 17
const RADIUS: float = 13.0
const REFRESH: float = 0.1
const DIAL_STEP: float = 0.2

var _cal: GameCalendar
var _dial: Control
var _time: Label
var _season: Label
var _date: Label
var _acc: float = 0.0
var _since: float = 0.0
var _beat: int = 0
var _last_text: String = ""
var _flash: float = 0.0
var _palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)


func setup(sim: Sim) -> void:
	_cal = sim.calendar
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 6.0, 3.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(DIAL)
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	h.add_child(_dial)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_time = Label.new()
	var face := FontVariation.new()
	face.base_font = preload("res://fonts/PixelifySans.ttf")
	face.variation_embolden = 0.6
	_time.add_theme_font_override("font", face)
	_time.add_theme_font_size_override("font_size", 14)
	_time.add_theme_color_override("font_color", RelicStyle.text)
	_time.add_theme_color_override("font_outline_color", RelicStyle.ink)
	_time.add_theme_constant_override("outline_size", 2)
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_time)
	_season = Label.new()
	_season.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_season)
	_date = Label.new()
	_date.add_theme_color_override("font_color", RelicStyle.dim)
	_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_date)
	Tip.bind(self, Callable(self, "_tip_spec"))
	_cal.season_changed.connect(func(_s: int) -> void: _flash = 1.2)
	_refresh()


func _process(delta: float) -> void:
	if _cal == null:
		return
	_acc += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_season.modulate = Color.WHITE.lerp(Color(1.7, 1.7, 1.7), absf(sin(_flash * 9.0)) * clampf(_flash, 0.0, 1.0))
	var step: int = int(_acc / DIAL_STEP)
	if step != _beat:
		_beat = step
		_dial.queue_redraw()
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		_refresh()


func _refresh() -> void:
	var n: Dictionary = _cal.now()
	var text: String = "%s|%s|%d" % [n["clock_text"], n["season_name"], int(n["day_of_year"])]
	if text == _last_text:
		return
	_last_text = text
	_time.text = String(n["clock_text"])
	_season.text = String(n["season_name"])
	_season.add_theme_color_override("font_color", _cal.season_color(int(n["season"])))
	_date.text = "Day %d  %s" % [int(n["day"]), String(n["month_name"])]
	reset_size()


func _tip_spec() -> Dictionary:
	var n: Dictionary = _cal.now()
	var secs: float = _cal.seconds_to_next_season()
	var next_name: String = _cal.season_name((int(n["season"]) + 1) % GameCalendar.SEASONS)
	var mins: int = int(ceilf(secs / 60.0))
	var left: String = "%d min" % mins if mins < 120 else "%.1f h" % (secs / 3600.0)
	return {
		"title": "%s, %s" % [String(n["season_name"]), String(n["month_name"])],
		"body": "Day %d of %d. Year %d. %s\n%s, %s." % [int(n["day"]), int(n["days_in_month"]), int(n["year"]),
				String(n["season_blurb"]), String(n["clock_text"]), "daylight" if bool(n["is_day"]) else "night"],
		"hint": "%s begins in %s." % [next_name, left],
		"color": _cal.season_color(int(n["season"])),
	}


func _draw_dial() -> void:
	if _cal == null:
		return
	var f: float = _cal.day_fraction()
	var d: float = clampf(_cal.daylight_fraction, 0.2, 0.8)
	var rise: float = (1.0 - d) * 0.5
	var is_day: bool = f >= rise and f < rise + d
	var u: float
	if is_day:
		u = (f - rise) / d
	else:
		u = fposmod(f - (rise + d), 1.0) / (1.0 - d)
	var ang: float = PI * (1.0 - u)
	var cx: float = float(DIAL.x) * 0.5
	var sx: int = int(roundf(cx + cos(ang) * RADIUS))
	var sy: int = int(roundf(float(HORIZON) - sin(ang) * RADIUS))
	var height: float = sin(ang)    # 0 at the horizon, 1 at the top of the arc
	var dusk: float = 1.0 - smoothstep(0.0, 0.45, height) if is_day else 0.0
	# sky: dithered vertical gradient between a top and a bottom palette index
	var top_i: int = 2 if is_day else 0
	var bot_i: int = (6 if dusk > 0.5 else 3) if is_day else 1
	if is_day and dusk <= 0.5:
		top_i = 3
		bot_i = 4
	for y in HORIZON:
		var k: float = float(y) / float(HORIZON)
		for x in DIAL.x:
			var thr: float = MeadowLife.bayer(x, y)
			_dial.draw_rect(Rect2(x, y, 1, 1), _palette[bot_i if k > thr * 0.9 + 0.1 else top_i])
	# stars
	if not is_day or height < 0.12:
		var fade: float = 1.0 if not is_day else 0.0
		if fade > 0.0:
			for i in 9:
				var tw: float = sin(float(_beat) * 0.9 + float(i) * 2.3)
				if tw > -0.5:
					var px: int = 2 + int(MeadowLife.hash01(i * 7 + 3) * float(DIAL.x - 4))
					var py: int = 1 + int(MeadowLife.hash01(i * 11 + 1) * 11.0)
					_dial.draw_rect(Rect2(px, py, 1, 1), _palette[7 if tw > 0.4 else 4])
	# ground and horizon
	_dial.draw_rect(Rect2(0, HORIZON, DIAL.x, DIAL.y - HORIZON), _palette[1])
	_dial.draw_rect(Rect2(0, HORIZON, DIAL.x, 1), _palette[2])
	for x in range(0, DIAL.x, 2):
		_dial.draw_rect(Rect2(x, HORIZON + 1 + (x / 2) % 2, 1, 1), _palette[2])
	# the body on its arc (hidden once it is under the ground)
	if is_day:
		var pulse: bool = _beat % 2 == 0
		_dial.draw_rect(Rect2(sx - 1, sy - 1, 3, 3), _palette[5])
		_dial.draw_rect(Rect2(sx, sy - 2 if pulse else sy - 1, 1, 1), _palette[7])
		if pulse:
			for o: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2)]:
				_dial.draw_rect(Rect2(sx + o.x, sy + o.y, 1, 1), _palette[5])
	else:
		_dial.draw_rect(Rect2(sx - 1, sy - 1, 3, 3), _palette[7])
		_dial.draw_rect(Rect2(sx, sy - 1, 1, 2), _palette[4])
		_dial.draw_rect(Rect2(sx + 1, sy - 1, 1, 1), _palette[0])
	# the season's accent as a one texel frame line under the dial
	_dial.draw_rect(Rect2(0, DIAL.y - 1, DIAL.x, 1), _cal.season_color(int(_cal.now()["season"])))
