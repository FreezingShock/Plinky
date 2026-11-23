class_name SlotPanel
extends PanelContainer
## The Saves list on the title screen: three slots, each showing what it holds (rebirths, play time, presses, when it
## was saved) with Load (or Start, when empty) and a two-step Delete. It only reads files and emits; the title screen
## does the loading, so the panel is safe to build anywhere.

signal slot_chosen(slot: int)
signal slot_deleted(slot: int)

const WIDTH: float = 330.0
const CONFIRM_SECONDS: float = 3.0

## The slot Continue would load; its row is marked.
var active_slot: int = 1:
	set(v):
		active_slot = v
		if is_inside_tree():
			refresh()

var _rows: Dictionary = {}
var _hint: Label
var _armed: int = 0
var _armed_left: float = 0.0


## Pure: "2h 14m", "45m", "<1m".
static func format_playtime(seconds: float) -> String:
	var mins: int = int(seconds / 60.0)
	if mins < 1:
		return "<1m"
	if mins < 60:
		return "%dm" % mins
	return "%dh %02dm" % [floori(float(mins) / 60.0), mins % 60]


## Pure: the headline for a slot summary.
static func headline(s: Dictionary) -> String:
	if not bool(s["exists"]):
		return "Empty slot"
	var rb: int = int(s["rebirths"])
	return "%d rebirth%s, %s" % [rb, "" if rb == 1 else "s", format_playtime(float(s["play_seconds"]))]


## Pure: the small line under it.
static func detail(s: Dictionary) -> String:
	if not bool(s["exists"]):
		return "Start a new game here."
	var line: String = "%d presses" % int(s["presses"])
	if float(s["saved_at"]) > 0.0:
		line += ", saved %s" % Time.get_date_string_from_unix_time(int(s["saved_at"]))
	return line


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Saves"
	v.add_child(title)
	v.add_child(PanelDivider.new())
	for n in range(1, SaveSlots.SLOT_COUNT + 1):
		v.add_child(_build_row(n))
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(WIDTH, 0.0)
	v.add_child(_hint)
	visibility_changed.connect(func() -> void:
		if visible:
			_disarm()
			refresh())


func _build_row(n: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var num := Label.new()
	num.text = str(n)
	num.theme_type_variation = &"TitleLabel"
	num.custom_minimum_size = Vector2(14.0, 0.0)
	row.add_child(num)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var head := Label.new()
	info.add_child(head)
	var sub := Label.new()
	sub.add_theme_color_override("font_color", RelicStyle.dim)
	info.add_child(sub)
	var load_btn := PixelButton.new()
	load_btn.custom_minimum_size = Vector2(46.0, 0.0)
	load_btn.pressed.connect(func() -> void: slot_chosen.emit(n))
	row.add_child(load_btn)
	var del := PixelButton.new()
	del.custom_minimum_size = Vector2(46.0, 0.0)
	del.pressed.connect(_on_delete.bind(n))
	row.add_child(del)
	_rows[n] = {"num": num, "head": head, "sub": sub, "load": load_btn, "del": del}
	return row


## Re-read the three slots from disk.
func refresh() -> void:
	for n: int in _rows:
		var r: Dictionary = _rows[n]
		var s: Dictionary = SaveSlots.slot_summary(n)
		var exists: bool = bool(s["exists"])
		(r["head"] as Label).text = headline(s) + ("  (current)" if n == active_slot and exists else "")
		(r["head"] as Label).add_theme_color_override("font_color", RelicStyle.accent if n == active_slot and exists else RelicStyle.text)
		(r["sub"] as Label).text = detail(s)
		(r["load"] as PixelButton).text = "Load" if exists else "Start"
		var del: PixelButton = r["del"] as PixelButton
		del.visible = exists
		del.text = "Sure?" if n == _armed else "Delete"
		(r["num"] as Label).add_theme_color_override("font_color", RelicStyle.accent if exists else RelicStyle.dim)


func set_hint(text: String) -> void:
	_hint.text = text


func _on_delete(n: int) -> void:
	if _armed == n:
		_disarm()
		slot_deleted.emit(n)
		refresh()
		return
	_armed = n
	_armed_left = CONFIRM_SECONDS
	_hint.text = "Press Delete again to erase slot %d. This cannot be undone." % n
	refresh()


func _disarm() -> void:
	_armed = 0
	_armed_left = 0.0


func _process(delta: float) -> void:
	if _armed != 0:
		_armed_left -= delta
		if _armed_left <= 0.0:
			_disarm()
			_hint.text = ""
			refresh()
