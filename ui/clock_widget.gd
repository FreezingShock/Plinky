class_name ClockWidget
extends PanelContainer
## The HUD clock: a sky dial that fills the chip's full height, with the sun or moon riding its arc, and the time
## with "Month · Day" centred under it. Reads the sim's calendar (core/game_calendar.gd) at 10 Hz and redraws the dial
## at 5 fps (stars twinkle, the sun pulses). Tooltip through Tip. Palette indices only for the dial. The season shows
## once: its month line takes the season's accent colour, and the same accent is the dial's bottom texel row.

const DIAL_W: int = 40              ## dial width in texels (one texel is one HUD pixel)
const DIAL_MIN_H: int = 30          ## the dial is never shorter than this; the text height sets it when taller
const DIAL_GROUND: float = 0.66     ## the horizon sits this far down the dial
const REFRESH: float = 0.1
const DIAL_STEP: float = 0.2
const LEFT_PAD: float = 2.0         ## frame to dial, so the dial reaches the frame's inner edge
const LEFT_PAD_NO_DIAL: float = 6.0
const RIGHT_PAD: float = 6.0
const TEXT_GAP: int = 8             ## dial to text
const SQUEEZE_TIME_ONLY: int = 2

var _cal: GameCalendar
var _dial: Control
var _time: Label
var _line: Label
var _events: SeasonalEvents
var _box: AsciiBox
var _squeeze: int = 0
var _widths: Array[float] = [0.0, 0.0, 0.0]
var _acc: float = 0.0
var _since: float = 0.0
var _beat: int = 0
var _last_text: String = ""
var _flash: float = 0.0
var _palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _sim: Sim
var _pal_id: StringName = Palettes.MEADOW
var _sun: int = 5   ## palette role of the sun disc; Ember Quarry uses amber (4) so its sun reads as ember


func setup(sim: Sim) -> void:
	_sim = sim
	_cal = sim.calendar
	_events = sim.events
	mouse_filter = Control.MOUSE_FILTER_PASS
	_box = AsciiBox.make(AsciiBox.Kind.PANEL, LEFT_PAD, 1.0)   # 1 texel top and bottom: the dial meets the frame
	_box.content_margin_right = RIGHT_PAD
	add_theme_stylebox_override("panel", _box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", TEXT_GAP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(DIAL_W, DIAL_MIN_H)
	_dial.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	_dial.resized.connect(_dial.queue_redraw)
	h.add_child(_dial)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_time)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_line)
	Tip.bind(self, Callable(self, "_tip_spec"))
	_cal.season_changed.connect(func(_s: int) -> void: _flash = 1.2)
	_refresh()


func _process(delta: float) -> void:
	if _cal == null:
		return
	_acc += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_line.modulate = Color.WHITE.lerp(Color(1.7, 1.7, 1.7), absf(sin(_flash * 9.0)) * clampf(_flash, 0.0, 1.0))
	var step: int = int(_acc / DIAL_STEP)
	if step != _beat:
		_beat = step
		_dial.queue_redraw()
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		_refresh()


## Squeeze the card when the top bar is tight: 0 full, 1 dial and time only, 2 time only. Never hides it (onboarding
## owns visibility). The HUD picks the smallest level that fits the room around the centre of the frame.
func set_squeeze(level: int) -> void:
	if level == _squeeze:
		return
	_squeeze = level
	_dial.visible = level < SQUEEZE_TIME_ONLY
	_line.visible = level < 1
	_box.content_margin_left = LEFT_PAD if _dial.visible else LEFT_PAD_NO_DIAL
	reset_size()


## Width of each squeeze level as last seen; unseen levels are guessed from the full one so the first pass is safe.
func remember_width() -> void:
	_widths[_squeeze] = get_combined_minimum_size().x


func width_at(level: int) -> float:
	if _widths[level] > 0.0:
		return _widths[level]
	var full: float = maxf(_widths[0], get_combined_minimum_size().x)
	return full if level == 0 else (full * 0.65 if level == 1 else full * 0.35)


func squeeze_level() -> int:
	return _squeeze


func _refresh() -> void:
	_follow_zone_palette()
	var n: Dictionary = _cal.now()
	var text: String = "%s|%s|%d" % [n["clock_text"], n["month_name"], int(n["day"])]
	if text == _last_text:
		return
	_last_text = text
	_time.text = String(n["clock_text"])
	_line.text = "%s · Day %d" % [String(n["month_name"]), int(n["day"])]
	_line.add_theme_color_override("font_color", _cal.season_color(int(n["season"])))
	reset_size()


## The dial takes the palette of the zone you are in: meadow stays green, Ember Quarry glows ember. Checked at the
## refresh rate, so a zone change recolours the dial within a tenth of a second.
func _follow_zone_palette() -> void:
	if _sim == null:
		return
	var pid: StringName = Palettes.for_zone(_sim.zone_id)
	if pid == _pal_id:
		return
	_pal_id = pid
	_palette = Palettes.colors(pid)
	_sun = 4 if pid == Palettes.QUARRY else 5
	_dial.queue_redraw()


func _tip_spec() -> Dictionary:
	var n: Dictionary = _cal.now()
	var secs: float = _cal.seconds_to_next_season()
	var next_name: String = _cal.season_name((int(n["season"]) + 1) % GameCalendar.SEASONS)
	var mins: int = int(ceilf(secs / 60.0))
	var left: String = "%d min" % mins if mins < 120 else "%.1f h" % (secs / 3600.0)
	var event_line: String = ""
	if _events != null and _events.name_of(int(n["season"])) != "":
		event_line = "\n%s: %s" % [_events.name_of(int(n["season"])), _events.blurb_of(int(n["season"]))]
	return {
		"title": "%s, %s" % [String(n["season_name"]), String(n["month_name"])],
		"body": "Day %d of %d. Year %d. %s\n%s, %s.%s" % [int(n["day"]), int(n["days_in_month"]), int(n["year"]),
				String(n["season_blurb"]), String(n["clock_text"]), "daylight" if bool(n["is_day"]) else "night", event_line],
		"hint": "%s begins in %s." % [next_name, left],
		"color": _cal.season_color(int(n["season"])),
	}


func _texel(x: int, y: int, c: Color) -> void:
	_dial.draw_rect(Rect2(x, y, 1, 1), c)


## A sun or moon disc: a 5x5 octagon (no corners), so it reads as round at texel size.
func _disc(cx: int, cy: int, c: Color) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) == 2 and absi(dy) == 2:
				continue
			_texel(cx + dx, cy + dy, c)


func _draw_dial() -> void:
	if _cal == null:
		return
	var cols: int = int(_dial.size.x)
	var rows: int = int(_dial.size.y)
	if cols < 12 or rows < 12:
		return
	var ground: int = int(roundf(float(rows) * DIAL_GROUND))
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
	var height: float = sin(ang)    # 0 at the horizon, 1 at the top of the arc
	var radius: float = minf(float(cols) * 0.5 - 4.0, float(ground) - 3.0)
	var sx: int = int(roundf(float(cols - 1) * 0.5 + cos(ang) * radius))
	var sy: int = int(roundf(float(ground) - height * radius))
	var dusk: float = 1.0 - smoothstep(0.0, 0.45, height) if is_day else 0.0
	# sky: dithered vertical gradient from a top to a bottom palette index; a low sun warms the horizon
	var top_i: int = 2 if is_day else 0
	var bot_i: int = (6 if dusk > 0.5 else 4) if is_day else 1
	for y in ground:
		var k: float = float(y) / float(ground)
		for x in cols:
			var thr: float = MeadowLife.bayer(x, y)
			_texel(x, y, _palette[bot_i if k > thr * 0.9 + 0.1 else top_i])
	# stars, at night only, twinkling
	if not is_day:
		for i in 14:
			var tw: float = sin(float(_beat) * 0.9 + float(i) * 2.3)
			if tw > -0.5:
				var px: int = 2 + int(MeadowLife.hash01(i * 7 + 3) * float(cols - 4))
				var py: int = 1 + int(MeadowLife.hash01(i * 11 + 1) * float(ground - 8))
				_texel(px, py, _palette[7 if tw > 0.4 else 4])
	# ground: a horizon that rises and falls by one texel, with dithered grass tufts along its top edge
	for x in cols:
		var gy: int = ground + (1 if sin(float(x) * 0.31 + 0.8) > 0.2 else 0)
		_dial.draw_rect(Rect2(x, gy, 1, rows - gy), _palette[1])
		_texel(x, gy, _palette[3])
		if MeadowLife.hash01(x * 5 + 2) > 0.55:
			_texel(x, gy - 1, _palette[4])
	# the body on its arc, hidden once it is under the ground
	if sy < ground - 1:
		if is_day:
			var pulse: bool = _beat % 2 == 0
			_disc(sx, sy, _palette[_sun])
			_texel(sx - 1, sy - 1, _palette[7])
			if pulse:
				for o: Vector2i in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3)]:
					_texel(sx + o.x, sy + o.y, _palette[_sun])
		else:
			_disc(sx, sy, _palette[7])
			_texel(sx - 1, sy + 1, _palette[4])
			_texel(sx - 2, sy - 1, _palette[4])
	# the season's accent as the bottom texel row
	_dial.draw_rect(Rect2(0, rows - 1, cols, 1), _cal.season_color(int(_cal.now()["season"])))
