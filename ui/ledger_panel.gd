class_name LedgerPanel
extends PanelContainer
## The Ledger: every achievement in eight categories, each with its own colour and icon. Done entries wear their
## category colour; locked ones show how far along you are. Read only: it shows Sim.achievements and never changes it.
## Same window style as History (title, divider, close X, scrolling body); opens through MenuRouter with the shared wipe.

const WIDTH: float = 260.0
const SCROLL_H: float = 196.0
const REFRESH: float = 0.5
const ICON_SIZE: int = 16
const NO_TITLE: String = "None Yet"

## One colour per category, the same fixed section colours the gallery tiles use. Bases match tools/art/gen_ledger.py.
const CATEGORY_COLORS: Dictionary = {
	&"presses": Color("f2c94c"), &"meadow": Color("7be08a"), &"streaks": Color("ff7f6e"), &"relics": Color("c77dff"),
	&"rebirth": Color("ff6fae"), &"growth": Color("55aaff"), &"quarry": Color("e8643c"), &"journey": Color("6fd6e8"),
}

var sim: Sim
var _body: VBoxContainer
var _scroll: ScrollContainer
var _count: Label
var _clock: float = 0.0
var _signature: int = 0


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
	title.text = "Ledger"
	head.add_child(title)
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_color_override("font_color", RelicStyle.good)
	head.add_child(_count)
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	v.add_child(PanelDivider.new())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.custom_minimum_size = Vector2(WIDTH, SCROLL_H)
	v.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	visibility_changed.connect(func() -> void:
		if visible:
			_signature = 0
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


static func color_of(cat: StringName) -> Color:
	return CATEGORY_COLORS.get(cat, RelicStyle.accent) as Color


## Pure: one row per achievement in Ledger order:
## {"def", "done", "progress" 0..1, "value" (capped at the target), "target", "color"}.
static func rows_for(sim: Sim) -> Array[Dictionary]:
	var counters: Dictionary = sim.achievement_counters()
	var out: Array[Dictionary] = []
	for d: AchievementDef in sim.achievements.sorted:
		var done: bool = sim.achievements.is_unlocked(d.id)
		out.append({"def": d, "done": done, "progress": sim.achievements.progress(d, counters),
			"value": d.target if done else minf(Achievements.value_of(d, counters), d.target),
			"target": d.target, "color": color_of(d.category)})
	return out


## Pure: "3 / 100" style progress text. Plain counts stay whole numbers; hours show one decimal below 10.
static func progress_text(value: float, target: float) -> String:
	return "%s / %s" % [_amount(value, target), NumberFormat.short(target)]


static func _amount(value: float, target: float) -> String:
	if target < 100.0 and value < target and absf(value - roundf(value)) > 0.001:
		return "%.1f" % (floorf(value * 10.0) / 10.0)
	return NumberFormat.short(floorf(value))


## Pure: a number that changes whenever the shown rows would, so the body is rebuilt only when it must be.
static func signature_of(rows: Array[Dictionary]) -> int:
	var h: int = rows.size()
	for r: Dictionary in rows:
		h = h * 31 + (1 if r["done"] else 0) * 101 + int(float(r["progress"]) * 100.0)
		h = h % 2147483647
	return h


static func icon_for(cat: StringName, locked: bool) -> Texture2D:
	var path: String = "res://assets/icons/ledger/%s_%d.png" % ["locked" if locked else String(cat), ICON_SIZE]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func refresh() -> void:
	if sim == null:
		return
	var rows: Array[Dictionary] = rows_for(sim)
	_count.text = "%d / %d" % [sim.achievements.unlocked_count(), sim.achievements.total()]
	var sig: int = signature_of(rows)
	if sig == _signature and _body.get_child_count() > 0:
		return
	_signature = sig
	var keep: int = _scroll.scroll_vertical
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var title: String = sim.achievements.current_title()
	_body.add_child(_pair("Title", title if title != "" else NO_TITLE, RelicStyle.text, RelicStyle.accent))
	var overall := HistoryBar.new(WIDTH - 14.0)
	overall.value = float(sim.achievements.unlocked_count()) / maxf(float(sim.achievements.total()), 1.0)
	overall.fill = RelicStyle.accent
	_body.add_child(overall)
	var cat: StringName = &""
	for r: Dictionary in rows:
		var d: AchievementDef = r["def"] as AchievementDef
		if d.category != cat:
			cat = d.category
			_body.add_child(_category_head(cat))
		_body.add_child(_row(r))
	_scroll.set_deferred("scroll_vertical", keep)


func _category_head(cat: StringName) -> Control:
	var col: Color = color_of(cat)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(_icon(icon_for(cat, false), Color.WHITE))
	var l := Label.new()
	l.theme_type_variation = &"TitleLabel"
	l.text = Achievements.category_name(cat)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", col)
	l.focus_mode = Control.FOCUS_ALL   # keyboard and pad can scroll through the list
	h.add_child(l)
	var n := Label.new()
	n.text = "%d / %d" % [sim.achievements.unlocked_in(cat), sim.achievements.in_category(cat).size()]
	n.add_theme_color_override("font_color", RelicStyle.dim)
	h.add_child(n)
	return h


func _row(r: Dictionary) -> Control:
	var d: AchievementDef = r["def"] as AchievementDef
	var done: bool = r["done"]
	var col: Color = r["color"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AsciiBox.panel(col if done else col.darkened(0.55)))
	card.custom_minimum_size.x = WIDTH - 14.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	card.add_child(h)
	h.add_child(_icon(icon_for(d.category, not done), Color.WHITE))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name_l := Label.new()
	name_l.text = d.display_name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", col if done else RelicStyle.text)
	name_l.focus_mode = Control.FOCUS_ALL
	top.add_child(name_l)
	var status := Label.new()
	status.text = "Done" if done else progress_text(r["value"], r["target"])
	status.add_theme_color_override("font_color", RelicStyle.good if done else RelicStyle.dim)
	top.add_child(status)
	var desc := Label.new()
	desc.text = d.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = WIDTH - 52.0
	desc.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(desc)
	if done and d.title != "":
		var t := Label.new()
		t.text = "Title: %s" % d.title
		t.add_theme_color_override("font_color", col)
		v.add_child(t)
	elif not done:
		var bar := HistoryBar.new(WIDTH - 52.0)
		bar.value = r["progress"]
		bar.fill = col
		v.add_child(bar)
	return card


func _icon(tex: Texture2D, tint: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.modulate = tint
	t.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _pair(left: String, right: String, lc: Color, rc: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = left
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_color_override("font_color", lc)
	a.focus_mode = Control.FOCUS_ALL
	h.add_child(a)
	var b := Label.new()
	b.text = right
	b.add_theme_color_override("font_color", rc)
	h.add_child(b)
	return h
