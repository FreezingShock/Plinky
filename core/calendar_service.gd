extends Node
## Autoload `Calendar` (needs one line in project.godot, added by the main session:
## Calendar="*res://core/calendar_service.gd", after GameState). The one place UI and world code read the in-game
## calendar. A thin face over GameState.sim.calendar (core/game_calendar.gd), which ticks with the sim and is saved with it.
##   Calendar.now()              snapshot dict: year, day, month, month_name, season, season_id, season_name, hour,
##                               minute, clock_text, day_fraction, is_day, days_left_in_season, ...
##   Calendar.season_weights()   4 floats summing to 1, crossfaded at season edges
## Signals fire on EventBus (season_changed, month_changed, day_changed, year_changed) and are relayed here too.

signal season_changed(season: int)
signal month_changed(month: int)
signal day_changed(day_of_year: int)
signal year_changed(year: int)


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		return
	bus.season_changed.connect(func(s: int) -> void: season_changed.emit(s))
	bus.month_changed.connect(func(m: int) -> void: month_changed.emit(m))
	bus.day_changed.connect(func(d: int) -> void: day_changed.emit(d))
	bus.year_changed.connect(func(y: int) -> void: year_changed.emit(y))


func core() -> GameCalendar:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	var sim: Variant = gs.get("sim")
	return (sim as Sim).calendar if sim is Sim else null


func now() -> Dictionary:
	var c: GameCalendar = core()
	return c.now() if c != null else {}


func season_weights() -> Array[float]:
	var c: GameCalendar = core()
	if c == null:
		return [1.0, 0.0, 0.0, 0.0]
	return c.season_weights()


func season_color(i: int) -> Color:
	var c: GameCalendar = core()
	return c.season_color(i) if c != null else Color.WHITE


func seconds_to_next_season() -> float:
	var c: GameCalendar = core()
	return c.seconds_to_next_season() if c != null else 0.0


func skip_days(days: float) -> void:
	var c: GameCalendar = core()
	if c != null:
		c.skip_days(days)


func jump_to_season(i: int) -> void:
	var c: GameCalendar = core()
	if c != null:
		c.jump_to_season(i)
