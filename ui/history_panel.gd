class_name HistoryPanel
extends PanelContainer
## The History screen: a pixel graph of income over the last 10 minutes, personal bests, time spent in each zone and
## lifetime totals. Read only: it shows Sim and RunStats and never changes them. Same window style as the Stats and
## Attributes gallery (title, divider, close X, scrolling body); opens through MenuRouter with the shared dither wipe.

const WIDTH: float = 316.0
const SCROLL_H: float = 172.0
const REFRESH: float = 0.5

var sim: Sim
var _graph: HistoryGraph
var _graph_note: Label
var _body: VBoxContainer
var _clock: float = 0.0


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "History"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	v.add_child(PanelDivider.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(WIDTH, SCROLL_H)
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())


func bind(p_sim: Sim) -> void:
	sim = p_sim


func _process(delta: float) -> void:
	if not visible or sim == null:
		return
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		refresh()


## Pure: "12 min" / "1 h 05 min" for a length of play time.
static func span_text(seconds: float) -> String:
	var s: int = int(maxf(seconds, 0.0))
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min" % (s / 60)
	return "%d h %02d min" % [s / 3600, (s / 60) % 60]


## Pure: the text rows of the bests and totals sections, [{"section": String, "name": String, "value": String}].
static func rows_for(sim: Sim) -> Array[Dictionary]:
	var rs: RunStats = sim.run_stats
	var out: Array[Dictionary] = []
	var tier_name: String = sim.momentum_tier_name(rs.best_tier)
	out.append({"section": "Bests", "name": "Best income", "value": "%s /s" % rs.best_income.format()})
	out.append({"section": "Bests", "name": "Longest chain", "value": "%d pads" % rs.best_chain})
	out.append({"section": "Bests", "name": "Highest Momentum", "value": tier_name})
	out.append({"section": "Bests", "name": "Chains finished", "value": str(rs.streaks_done)})
	out.append({"section": "Totals", "name": "Time played", "value": span_text(sim.play_seconds)})
	out.append({"section": "Totals", "name": "This session", "value": span_text(rs.session_seconds)})
	out.append({"section": "Totals", "name": "Presses", "value": NumberFormat.short(float(sim.press_count))})
	out.append({"section": "Totals", "name": "Critical hits", "value": NumberFormat.short(float(rs.crits))})
	out.append({"section": "Totals", "name": "Rebirths", "value": str(sim.rebirth_count)})
	out.append({"section": "Totals", "name": "Relics found", "value": str(sim.relic_drops)})
	return out


func refresh() -> void:
	if sim == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var rs: RunStats = sim.run_stats
	var sd: StatDef = sim.stat_defs.get(sim.config.income_stat) as StatDef
	_body.add_child(_heading("%s per second, last 10 minutes" % (sd.display_name if sd != null else "Income")))
	_graph = HistoryGraph.new(WIDTH - 14.0)
	_graph.samples = rs.samples
	_graph.marks = rs.rebirth_marks
	_body.add_child(_graph)
	_graph_note = _line("Log scale. Gold lines mark rebirths.", RelicStyle.dim)
	if rs.samples.size() < 2:
		_graph_note.text = "Collecting data. A bar is added every %d seconds." % int(RunStats.SAMPLE_EVERY)
	_body.add_child(_graph_note)
	var section: String = ""
	for r: Dictionary in rows_for(sim):
		if r["section"] != section:
			section = r["section"]
			_body.add_child(_heading(section))
		_body.add_child(_pair(r["name"], r["value"]))
	_body.add_child(_heading("Time in each zone"))
	var rows: Array[Dictionary] = rs.zone_rows()
	var total: float = 0.0
	for z: Dictionary in rows:
		total += float(z["seconds"])
	if rows.is_empty():
		_body.add_child(_line("Nothing yet.", RelicStyle.dim))
	for z: Dictionary in rows:
		var zd: ZoneDef = sim.zone_defs.get(z["zone"]) as ZoneDef
		var name_text: String = zd.display_name if zd != null else String(z["zone"])
		_body.add_child(_pair(name_text, span_text(z["seconds"])))
		var bar := HistoryBar.new(WIDTH - 14.0)
		bar.value = float(z["seconds"]) / maxf(total, 0.001)
		_body.add_child(bar)


func _heading(text: String) -> Label:
	var l := _line(text, RelicStyle.accent)
	l.theme_type_variation = &"TitleLabel"
	return l


func _line(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 14.0
	l.focus_mode = Control.FOCUS_ALL   # keyboard and pad can scroll through it
	l.add_theme_color_override("font_color", color)
	return l


func _pair(left: String, right: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = left
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_color_override("font_color", RelicStyle.text)
	h.add_child(a)
	var b := Label.new()
	b.text = right
	b.add_theme_color_override("font_color", RelicStyle.good)
	h.add_child(b)
	return h
